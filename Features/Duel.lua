local _, ns = ...
local Peggle = ns.addon
local C = ns.C
local L = ns.L
local Util = ns.Util

-- Duels: two players play the same level and peg layout with ten balls; higher score wins.
-- The invite, the opponent's game and the result screen share one 300 second timer.
-- Protocol (ns.Comm ops, WHISPER between the two players; id = the challenger's duel id):
--   duelInvite  { id, level, note, layout }  challenger -> opponent
--   duelAck     { id }                       opponent got the invite and is deciding
--   duelBusy    { id }                       opponent is already in a duel
--   duelDecline { id }                       opponent declined (or auto-declines duels)
--   duelCancel  { id }                       challenger withdrew the invite
--   duelAccept  { id }                       opponent accepted; both start the level
--   duelResult  { id, forfeit = true } or { id, score, character, beaten, cleared, talent, style, fever }
-- Also defines ns.Multiplayer: validation and alert helpers shared with Battle and Loot.

local MP = {}
ns.Multiplayer = MP

MP.MAX_SCORE = 10000000
MP.MAX_NAME = 64
MP.MAX_NOTE = 64

local function validInt(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end
MP.ValidInt = validInt

function MP.ValidString(value, maxLength)
    return type(value) == "string" and not Util.IsSecret(value) and #value <= maxLength
end

-- Character names as sent on the wire: "Name-Realm", no spaces or separators.
function MP.ValidName(name)
    return type(name) == "string" and not Util.IsSecret(name) and #name >= 2 and #name <= MP.MAX_NAME
        and not name:find("[%s%c,]")
end

function MP.ValidLevel(level)
    return validInt(level, 1, C.NUM_LEVELS)
end

-- C.LAYOUT_SIZE distinct object indices into ns.Levels[level].objects.
function MP.ValidLayout(level, layout)
    if not MP.ValidLevel(level) or type(layout) ~= "table" then
        return false
    end
    local count = #ns.Levels[level].objects
    local seen, entries = {}, 0
    for key, index in pairs(layout) do
        entries = entries + 1
        if not validInt(key, 1, C.LAYOUT_SIZE) or not validInt(index, 1, count) or seen[index] then
            return false
        end
        seen[index] = true
    end
    return entries == C.LAYOUT_SIZE
end

function MP.CopyLayout(layout)
    local copy = {}
    for i = 1, C.LAYOUT_SIZE do
        copy[i] = layout[i]
    end
    return copy
end

function MP.ValidCharacter(character)
    return character == C.CHAR_GUIDE or character == C.CHAR_BLAST
end

-- Names are stored as Ambiguate(name, "none"); the wire carries "Name-Realm" so every receiver
-- resolves the same character whatever its own realm.
function MP.FullName(name)
    if name:find("-", 1, true) then
        return name
    end
    local realm = GetNormalizedRealmName()
    return realm and (name .. "-" .. realm) or name
end

function MP.LocalName(name)
    return Util.NormalizeName(name)
end

-- First letter upper case, as the original stored opponents.
function MP.Capitalize(name)
    return (name:gsub("^%l", string.upper))
end

-- "12h 5m" for battle lists.
function MP.HoursMinutes(seconds)
    seconds = math.max(0, seconds)
    local hours = math.floor(seconds / 3600)
    return string.format("%dh %dm", hours, math.floor((seconds - hours * 3600) / 60))
end

-- "4m 59s" for the duel clock.
function MP.ClockText(seconds)
    local minutes, secs = Util.MinutesSeconds(math.ceil(math.max(0, seconds)))
    return (minutes > 0 and (minutes .. "m ") or "") .. (secs > 0 and (secs .. "s") or "")
end

-- Invite announcements, following the Duel/Battle Invites settings.
function MP.Alert(text)
    local profile = ns.db.profile
    if profile.inviteChat then
        Util.Print(text)
    end
    if profile.inviteRaidWarning then
        local color = ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]
        if RaidWarningUtil and RaidWarningUtil.AddMessage then
            RaidWarningUtil.AddMessage("Peggle: " .. text, color)
        elseif RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, "Peggle: " .. text, color)
        end
    end
end

function MP.ShowWindow()
    local window = ns.addon.window
    if window and not window:IsShown() then
        window:Show()
    end
end

function MP.HideWindow()
    local window = ns.addon.window
    if window then
        window:Hide()
    end
end

-- Duel state

local Duel = {}
ns.Duel = Duel

local DUEL_TIME = 300
local ACK_TIMEOUT = 5
local RESULT_GRACE = 30 -- extra wait for the opponent's result after the clock runs out
local NOTE_BYTES = 48
local MAX_HISTORY = 10
local MAX_ID = 80

-- Outcome of a finished duel.
Duel.WON, Duel.LOST, Duel.BOTH_FORFEIT, Duel.TIED = 1, 2, 3, 4

-- duel.phase: "sending" (invite out, no answer yet), "waiting" (opponent deciding), "invited" (we decide),
-- "closed" (error or answer shown; message in duel.status), "playing" (results screen until both
-- results are in), "done" (outcome known).
local duel
local ticker, ackTimer
local pendingClose

local function notify()
    Peggle:SendMessage("PEGGLE_DUEL_UPDATE")
end

local function setInviteFlags(shown)
    if ns.Menu and ns.Menu.SetTabSparkle then
        ns.Menu.SetTabSparkle("duel", shown)
    end
    if ns.Broker and ns.Broker.SetNotice then
        ns.Broker.SetNotice(shown and ns.db.profile.inviteMinimap or false)
    end
end

local function stopTimers()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if ackTimer then
        ackTimer:Cancel()
        ackTimer = nil
    end
end

local function send(op, payload)
    payload = payload or {}
    payload.id = duel.id
    ns.Comm.Send(op, payload, "WHISPER", duel.opponent)
end

local function record(key, store)
    local entry = store[key]
    if type(entry) ~= "table" then
        entry = { won = 0, lost = 0 }
        store[key] = entry
    end
    return entry
end

local function addHistory(name)
    local history = ns.db.char.lastDuels
    for i = #history, 1, -1 do
        if history[i] == name then
            table.remove(history, i)
        end
    end
    table.insert(history, 1, name)
    while #history > MAX_HISTORY do
        table.remove(history)
    end
end

local function close(status)
    stopTimers()
    duel.phase = "closed"
    duel.status = status
    setInviteFlags(false)
    notify()
end

local function inDuelGame()
    return ns.Game.IsInProgress() and ns.Game.GetMode() == "duel"
end

local function evaluate()
    if duel.phase ~= "playing" then
        return
    end
    local mine, theirs = duel.mine, duel.theirs
    local outcome
    if type(mine) == "table" and type(theirs) == "table" then
        if mine.score > theirs.score then
            outcome = Duel.WON
        elseif mine.score < theirs.score then
            outcome = Duel.LOST
        else
            outcome = Duel.TIED
        end
    elseif mine == "forfeit" and theirs == "forfeit" then
        outcome = Duel.BOTH_FORFEIT
    elseif mine == "forfeit" and type(theirs) == "table" then
        outcome = Duel.LOST
    elseif theirs == "forfeit" and type(mine) == "table" then
        outcome = Duel.WON
    end
    if not outcome then
        notify()
        return
    end
    stopTimers()
    duel.phase = "done"
    duel.outcome = outcome
    local char = ns.db.char
    local vs = record(duel.opponent, char.duelRecord)
    local level = record(duel.level, char.levelRecord)
    local me = Util.PlayerName()
    if outcome == Duel.WON then
        vs.won, level.won = vs.won + 1, level.won + 1
        ns.Sound.Play(C.SOUND_APPLAUSE)
        duel.publishInfo = string.format(L["_PUBLISH_DUEL_W"], me, duel.opponent)
    elseif outcome == Duel.LOST then
        vs.lost, level.lost = vs.lost + 1, level.lost + 1
        ns.Sound.Play(C.SOUND_SIGH)
        duel.publishInfo = string.format(L["_PUBLISH_DUEL_L"], me, duel.opponent)
    end
    if ns.db.profile.closeDuelComplete then
        if inDuelGame() then
            pendingClose = true
        else
            MP.HideWindow()
        end
    end
    notify()
end

local function tick()
    if not duel then
        stopTimers()
        return
    end
    local remaining = duel.deadline - GetTime()
    if duel.phase == "playing" and duel.mine == nil then
        if remaining <= 0 then
            Duel.Forfeit()
            if inDuelGame() then
                ns.Game.Abandon()
            end
        else
            ns.HUD.SetTimerCaption(string.format(L["SCORE_TIME_LEFT"], MP.ClockText(remaining)))
        end
    elseif duel.phase == "playing" then
        -- Opponent never reported (offline or crashed): count it as their forfeit.
        if remaining <= -RESULT_GRACE and duel.theirs == nil then
            duel.theirs = "forfeit"
            evaluate()
        end
    elseif remaining <= 0 then
        if duel.phase == "invited" then
            Duel.Decline()
        elseif duel.phase == "sending" or duel.phase == "waiting" then
            Duel.Cancel()
        end
    end
    if duel then
        Peggle:SendMessage("PEGGLE_DUEL_TICK", math.max(0, remaining))
    end
end

local function startClock()
    duel.deadline = GetTime() + DUEL_TIME
    if ticker then
        ticker:Cancel()
    end
    ticker = C_Timer.NewTicker(1, tick)
end

local function startGame()
    if ackTimer then
        ackTimer:Cancel()
        ackTimer = nil
    end
    duel.phase = "playing"
    duel.mine, duel.theirs = nil, nil
    setInviteFlags(false)
    if ns.Game.IsInProgress() then
        ns.Game.Abandon()
    end
    MP.ShowWindow()
    ns.Game.Start(duel.level, { mode = "duel", layout = MP.CopyLayout(duel.layout) })
    ns.HUD.SetTimerCaption(string.format(L["SCORE_TIME_LEFT"], MP.ClockText(duel.deadline - GetTime())))
    notify()
end

-- Public API

function Duel.GetState()
    return duel
end

-- True while the player's own duel game is running (Restart is not allowed then).
function Duel.IsActive()
    return duel ~= nil and duel.phase == "playing" and duel.mine == nil
end

function Duel.GetRemaining()
    return duel and duel.deadline and math.max(0, duel.deadline - GetTime()) or DUEL_TIME
end

-- Win/loss against one opponent, on one level, and over all levels.
function Duel.GetRecordVs(name)
    local entry = ns.db.char.duelRecord[name]
    return entry and entry.won or 0, entry and entry.lost or 0
end

function Duel.GetLevelRecord(level)
    local entry = ns.db.char.levelRecord[level]
    return entry and entry.won or 0, entry and entry.lost or 0
end

function Duel.GetTotalRecord()
    local won, lost = 0, 0
    for level = 1, C.NUM_LEVELS do
        local w, l = Duel.GetLevelRecord(level)
        won, lost = won + w, lost + l
    end
    return won, lost
end

function Duel.GetHistory()
    return ns.db.char.lastDuels
end

function Duel.CanInvite()
    return duel == nil or duel.phase == "closed" or duel.phase == "done"
end

-- False when the name is empty or the player, or another duel is still open.
function Duel.Invite(name, level, note)
    name = Util.NormalizeName(name and strtrim(name))
    if not name or not Duel.CanInvite() or not MP.ValidLevel(level) then
        return false
    end
    name = MP.Capitalize(name)
    if Util.IsPlayer(name) then
        return false
    end
    note = note and strtrim(note) or ""
    if #note > NOTE_BYTES then
        note = note:sub(1, NOTE_BYTES)
    end
    duel = {
        id = string.format("%s:%d:%d", MP.FullName(Util.PlayerName()), GetServerTime(), math.random(0, 65535)),
        opponent = name,
        challenger = true,
        level = level,
        layout = ns.Levels.RandomLayout(level),
        note = note,
        phase = "sending",
    }
    startClock()
    local sent = duel
    ackTimer = C_Timer.NewTimer(ACK_TIMEOUT, function()
        ackTimer = nil
        if duel == sent and duel.phase == "sending" then
            close(L["DUEL_STATUS4"])
        end
    end)
    send("duelInvite", { level = level, note = note, layout = MP.CopyLayout(duel.layout) })
    notify()
    return true
end

-- Challenger withdraws the invite.
function Duel.Cancel()
    if not duel or not duel.challenger or (duel.phase ~= "sending" and duel.phase ~= "waiting") then
        return
    end
    send("duelCancel")
    stopTimers()
    duel = nil
    notify()
end

function Duel.Accept()
    if not duel or duel.phase ~= "invited" then
        return
    end
    send("duelAccept")
    startGame()
end

function Duel.Decline()
    if not duel or duel.phase ~= "invited" then
        return
    end
    send("duelDecline")
    stopTimers()
    setInviteFlags(false)
    duel = nil
    notify()
end

-- Dismisses an error or answer message, or the result screen.
function Duel.Dismiss()
    if duel and (duel.phase == "closed" or duel.phase == "done") then
        stopTimers()
        duel = nil
        notify()
    end
end

function Duel.Forfeit()
    if not Duel.IsActive() then
        return
    end
    duel.mine = "forfeit"
    send("duelResult", { forfeit = true })
    ns.HUD.SetTimerCaption(nil)
    evaluate()
end

-- Receiving

local function validId(id)
    return MP.ValidString(id, MAX_ID) and #id > 0
end

local function fromOpponent(msg, sender)
    return duel and duel.opponent == MP.Capitalize(sender) and msg.id == duel.id
end

ns.Comm.Register("duelInvite", function(msg, sender, distribution)
    if distribution ~= "WHISPER" or not validId(msg.id) then
        return
    end
    local reply = { id = msg.id }
    if ns.db.profile.inviteDecline then
        ns.Comm.Send("duelDecline", reply, "WHISPER", sender)
        return
    end
    if not Duel.CanInvite() then
        ns.Comm.Send("duelBusy", reply, "WHISPER", sender)
        return
    end
    local note = msg.note
    if not MP.ValidLayout(msg.level, msg.layout) or not MP.ValidString(note, MP.MAX_NOTE) then
        return
    end
    stopTimers()
    local name = MP.Capitalize(sender)
    duel = {
        id = msg.id,
        opponent = name,
        challenger = false,
        level = msg.level,
        layout = MP.CopyLayout(msg.layout),
        note = note,
        phase = "invited",
    }
    startClock()
    ns.Comm.Send("duelAck", reply, "WHISPER", sender)
    addHistory(name)
    setInviteFlags(true)
    MP.Alert(string.format(L["DUEL_CHALLENGE"], name))
    if ns.db.profile.openDuel then
        MP.ShowWindow()
        if ns.Menu.IsShown() then
            ns.Menu.SelectTab("duel")
        end
    end
    notify()
end)

ns.Comm.Register("duelAck", function(msg, sender)
    if fromOpponent(msg, sender) and duel.challenger and duel.phase == "sending" then
        if ackTimer then
            ackTimer:Cancel()
            ackTimer = nil
        end
        duel.phase = "waiting"
        addHistory(duel.opponent)
        notify()
    end
end)

local function answered(status)
    return function(msg, sender)
        if fromOpponent(msg, sender) and duel.challenger and (duel.phase == "sending" or duel.phase == "waiting") then
            close(status)
        end
    end
end
ns.Comm.Register("duelDecline", answered(L["DUEL_STATUS3"]))
ns.Comm.Register("duelBusy", answered(L["DUEL_STATUS5"]))

ns.Comm.Register("duelCancel", function(msg, sender)
    if fromOpponent(msg, sender) and duel.phase == "invited" then
        close(L["DUEL_STATUS6"])
    end
end)

ns.Comm.Register("duelAccept", function(msg, sender)
    if fromOpponent(msg, sender) and duel.challenger and (duel.phase == "sending" or duel.phase == "waiting") then
        startGame()
    end
end)

local function validResult(msg)
    local max = MP.MAX_SCORE
    return validInt(msg.score, 0, max) and MP.ValidCharacter(msg.character)
        and validInt(msg.beaten, 0, C.NUM_LEVELS) and validInt(msg.cleared, 0, C.NUM_LEVELS)
        and validInt(msg.talent, 0, max) and validInt(msg.style, 0, max) and validInt(msg.fever, 0, max)
end

ns.Comm.Register("duelResult", function(msg, sender)
    if not fromOpponent(msg, sender) or duel.phase ~= "playing" or duel.theirs ~= nil then
        return
    end
    if msg.forfeit == true then
        duel.theirs = "forfeit"
    elseif validResult(msg) then
        duel.theirs = {
            score = msg.score,
            character = msg.character,
            beaten = msg.beaten,
            cleared = msg.cleared,
            talent = msg.talent,
            style = msg.style,
            fever = msg.fever,
        }
    else
        return
    end
    evaluate()
end)

ns.Comm.OnPlayerNotFound(function(name)
    if duel and duel.challenger and duel.opponent == MP.Capitalize(name)
        and (duel.phase == "sending" or duel.phase == "waiting") then
        close(string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, name))
    end
end)

-- Game events

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function onLevelEnd(_, result)
    if type(result) ~= "table" or result.mode ~= "duel" or not Duel.IsActive() then
        return
    end
    local stats = result.stats or {}
    local mine = {
        score = result.score or 0,
        character = result.character or C.CHAR_GUIDE,
        beaten = result.beaten or 0,
        cleared = result.cleared or 0,
        talent = stats.talentScore or 0,
        style = stats.styleScore or 0,
        fever = stats.feverScore or 0,
    }
    duel.mine = mine
    local payload = {}
    for key, value in pairs(mine) do
        payload[key] = value
    end
    send("duelResult", payload)
    ns.HUD.SetTimerCaption(nil)
    evaluate()
end

ns.RegisterEnabler("Duel", function()
    events:RegisterMessage("PEGGLE_LEVEL_END", onLevelEnd)
    events:RegisterMessage("PEGGLE_LEVEL_ABANDONED", function(_, mode)
        if mode == "duel" then
            Duel.Forfeit()
        end
    end)
    events:RegisterMessage("PEGGLE_SUMMARY_CLOSED", function(_, mode)
        if mode ~= "duel" then
            return
        end
        if pendingClose then
            pendingClose = nil
            MP.HideWindow()
        elseif ns.Menu.IsShown() then
            ns.Menu.SelectTab("duel")
        end
    end)
end)
