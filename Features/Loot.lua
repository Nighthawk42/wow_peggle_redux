local _, ns = ...
local C = ns.C
local L = ns.L
local Util = ns.Util
local MP = ns.Multiplayer

-- Peggle Loot: the master looter (or, where master loot no longer exists, the group leader or an
-- assistant) starts a one-shot contest for an item. Every group member with the addon gets a
-- dialog and 30 seconds to play one ball as Space Blast with talents off on a shared layout; the
-- starter collects scores for 40 seconds and posts the results to group chat.
-- Protocol (ns.Comm ops):
--   lootStart { id, item, level, layout }   starter -> group (RAID, PARTY or INSTANCE_CHAT)
--   lootScore { id, score } or { id, pass = true }   participant -> starter (WHISPER)

local Loot = {}
ns.Loot = Loot

local PLAY_TIME = 30
local RESULT_TIME = 40
local REMINDERS = { 30, 20, 10 }
local MAX_ITEM = 255
local MAX_ID = 100
local TICK = 0.2

local host -- contest we started: { id, item, deadline, scores = { [name] = score or -1 }, reminder }
local entry -- contest we take part in: { id, item, level, layout, starter, deadline, playing, done }
local ticker

local function groupDistribution()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    return Util.GroupChannel()
end

-- Whether this client still has master loot (Retail removed it).
-- TODO(in-game): confirm IsLootMethodAvailable(Masterlooter) is true in a group on Classic Era, TBC, MoP and Titan, and false on Retail and Forever.
local function masterLootExists()
    local available = C_PartyInfo.IsLootMethodAvailable
    if available then
        return available(Enum.LootMethod.Masterlooter) and true or false
    end
    return WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
end

local function unitFor(name)
    if Util.IsPlayer(name) then
        return "player"
    end
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        if Util.NormalizeName(GetUnitName(unit, true)) == name then
            return unit
        end
    end
end

local function masterLooterName()
    local method, partyID, raidID = C_PartyInfo.GetLootMethod()
    if method ~= Enum.LootMethod.Masterlooter then
        return nil
    end
    if IsInRaid() then
        return raidID and Util.NormalizeName((GetRaidRosterInfo(raidID)))
    elseif partyID == 0 then
        return Util.PlayerName()
    elseif partyID then
        return Util.NormalizeName(GetUnitName("party" .. partyID, true))
    end
end

-- Whether name may start a contest in our group.
-- TODO(in-game): in Midnight instances roster names can be secret; check a leader in a dungeon group is still recognised.
local function isAuthorized(name)
    local looter = masterLooterName()
    if looter then
        return looter == name
    end
    if masterLootExists() then
        return false
    end
    local unit = unitFor(name)
    return unit ~= nil and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) and true or false
end

-- Nil when the player may start a contest, else the reason to print.
local function startBlocker()
    if not IsInGroup() then
        return L["_PEGGLELOOT_NOGROUP"]
    end
    local method, partyID = C_PartyInfo.GetLootMethod()
    if method == Enum.LootMethod.Masterlooter then
        return partyID ~= 0 and L["_PEGGLELOOT_NOTMASTERLOOTER"] or nil
    end
    if masterLootExists() then
        return L["_PEGGLELOOT_WRONGMETHOD"]
    end
    return not Util.IsGroupOfficer() and L["_PEGGLELOOT_NOTLEADER"] or nil
end

local function chat(text, chatType)
    ns.Comm.Chat("[Peggle]: " .. text, chatType)
end

local function stopTicker()
    if ticker and not host and not entry then
        ticker:Cancel()
        ticker = nil
    end
end

local function dialog()
    return ns.LootDialog
end

local function postResults()
    local rows = {}
    for name, score in pairs(host.scores) do
        table.insert(rows, { name = name, score = score })
    end
    table.sort(rows, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.name < b.name
    end)
    local channel = groupDistribution()
    local function say(text)
        if channel then
            chat(text, channel)
        else
            Util.Print(text)
        end
    end
    say(L["_PEGGLELOOT_RESULTS"])
    for i, row in ipairs(rows) do
        local result = row.score >= 0 and (Util.CommaNumber(row.score) .. " pts") or DECLINE
        say(i .. " - " .. row.name .. " - " .. result)
    end
    if rows[1] and rows[1].score >= 0 then
        say(string.format(L["_PEGGLELOOT_WINNER"], rows[1].name))
    else
        say(L["_PEGGLELOOT_NOWINNER"])
    end
end

local function timeCaption(remaining)
    return string.format(L["SCORE_TIME_LEFT"], math.ceil(remaining) .. " sec")
end

local function inLootGame()
    return ns.Game.IsInProgress() and ns.Game.GetMode() == "loot"
end

local function entryTimeout()
    dialog().Hide()
    entry.done = true
    if entry.playing and inLootGame() then
        if ns.Game.IsShotInFlight() then
            -- The score is sent when the forced shot ends the round.
            ns.Game.ForceEndShot()
            return
        end
        if not ns.Game.HasShot() then
            ns.Game.Abandon()
        end
        return
    end
    entry = nil
end

local function tick()
    local now = GetTime()
    if host then
        local remaining = host.deadline - now
        local reminder = REMINDERS[host.reminder]
        if reminder and remaining < reminder then
            host.reminder = host.reminder + 1
            Util.Print(string.format(L["_PEGGLELOOT_CHAT_REMAINING"], reminder))
        end
        if remaining <= 0 then
            postResults()
            host = nil
        end
    end
    if entry and not entry.done then
        local remaining = entry.deadline - now
        if remaining <= 0 then
            entryTimeout()
        else
            dialog().SetRemaining(math.ceil(remaining))
            if entry.playing and inLootGame() then
                ns.HUD.SetTimerCaption(timeCaption(remaining))
            end
        end
    end
    stopTicker()
end

local function startTicker()
    ticker = ticker or C_Timer.NewTicker(TICK, tick)
end

local function recordScore(name, score)
    if host and host.scores[name] == nil then
        host.scores[name] = score
    end
end

local function sendScore(payload)
    payload.id = entry.id
    if Util.IsPlayer(entry.starter) then
        recordScore(entry.starter, payload.pass and -1 or payload.score)
    else
        ns.Comm.Send("lootScore", payload, "WHISPER", entry.starter)
    end
end

local function join(id, item, level, layout, starter)
    entry = {
        id = id,
        item = item,
        level = level,
        layout = MP.CopyLayout(layout),
        starter = starter,
        deadline = GetTime() + PLAY_TIME,
    }
    dialog().Show(item)
    dialog().SetRemaining(PLAY_TIME)
    startTicker()
end

-- Public API

-- /peggleloot [item]
function Loot.Start(itemText)
    local item = strtrim(itemText or "")
    if item == "" then
        item = L["_THE_ITEM"]
    elseif #item > MAX_ITEM then
        item = item:sub(1, MAX_ITEM)
    end
    local active = host or (entry and not entry.done and entry)
    if active then
        local remaining = math.max(0, active.deadline - GetTime())
        Util.Print(string.format(L["_PEGGLELOOT_ISACTIVE"], math.ceil(remaining)))
        return
    end
    local blocker = startBlocker()
    if blocker then
        Util.Print(blocker)
        return
    end
    if ns.Duel.IsActive() then
        ns.Duel.Forfeit()
    end
    if ns.Game.IsInProgress() then
        ns.Game.Abandon()
    end
    local level = math.random(1, C.NUM_LEVELS)
    local layout = ns.Levels.RandomLayout(level)
    local me = Util.PlayerName()
    local id = string.format("%s:%d:%d", MP.FullName(me), GetServerTime(), math.random(0, 65535))
    host = { id = id, item = item, deadline = GetTime() + RESULT_TIME, scores = {}, reminder = 1 }
    local distribution = groupDistribution()
    local notice = string.format(L["_PEGGLELOOT_NOTIFY"], item)
    if distribution == "RAID" then
        chat(notice, Util.IsGroupOfficer() and "RAID_WARNING" or "RAID")
    elseif distribution == "PARTY" then
        chat(notice, UnitIsGroupLeader("player") and "RAID_WARNING" or "PARTY")
    else
        chat(notice, distribution)
    end
    ns.Comm.Send("lootStart", { id = id, item = item, level = level, layout = MP.CopyLayout(layout) }, distribution)
    join(id, item, level, layout, me)
end

function Loot.IsActive()
    return entry ~= nil and not entry.done
end

-- Dialog Go: play the shot.
function Loot.Play()
    if not entry or entry.done or entry.playing then
        return
    end
    entry.playing = true
    dialog().Hide()
    if ns.Duel.IsActive() then
        ns.Duel.Forfeit()
    end
    if ns.Game.IsInProgress() then
        ns.Game.Abandon()
    end
    MP.ShowWindow()
    ns.Game.Start(entry.level, { mode = "loot", layout = MP.CopyLayout(entry.layout), balls = 1 })
    ns.HUD.SetTimerCaption(timeCaption(entry.deadline - GetTime()))
end

-- Dialog Decline: tell the starter we pass.
function Loot.Pass()
    if not entry or entry.done or entry.playing then
        return
    end
    sendScore({ pass = true })
    dialog().Hide()
    entry = nil
    stopTicker()
end

-- Receiving

ns.Comm.Register("lootStart", function(msg, sender, distribution)
    if distribution ~= "RAID" and distribution ~= "PARTY" and distribution ~= "INSTANCE_CHAT" then
        return
    end
    if (entry and not entry.done) or not isAuthorized(sender) then
        return
    end
    local id, item = msg.id, msg.item
    if not MP.ValidString(id, MAX_ID) or #id == 0 or not MP.ValidString(item, MAX_ITEM) or item == "" then
        return
    end
    if not MP.ValidLayout(msg.level, msg.layout) then
        return
    end
    join(id, item, msg.level, msg.layout, sender)
end)

ns.Comm.Register("lootScore", function(msg, sender, distribution)
    if distribution ~= "WHISPER" or not host or msg.id ~= host.id or not unitFor(sender) then
        return
    end
    if msg.pass == true then
        recordScore(sender, -1)
    elseif MP.ValidInt(msg.score, 0, MP.MAX_SCORE) then
        recordScore(sender, msg.score)
    end
end)

-- Game events

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

ns.RegisterEnabler("Loot", function()
    events:RegisterMessage("PEGGLE_LEVEL_END", function(_, result)
        if type(result) ~= "table" or result.mode ~= "loot" or not entry or not entry.playing then
            return
        end
        ns.HUD.SetTimerCaption(nil)
        sendScore({ score = math.floor(result.score or 0) })
        entry = nil
        stopTicker()
    end)
    events:RegisterMessage("PEGGLE_LEVEL_ABANDONED", function(_, mode)
        if mode == "loot" and entry and entry.playing then
            ns.HUD.SetTimerCaption(nil)
            entry = nil
            stopTicker()
        end
    end)
    events:RegisterMessage("PEGGLE_SUMMARY_CLOSED", function(_, mode)
        if mode == "loot" and ns.db.profile.closePeggleLoot then
            MP.HideWindow()
        end
    end)
end)
