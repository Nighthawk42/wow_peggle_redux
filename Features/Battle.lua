local _, ns = ...
local Peggle = ns.addon
local C = ns.C
local L = ns.L
local Util = ns.Util
local MP = ns.Multiplayer

-- Battles: a creator picks a level, a shot count and a duration (12, 24 or 48 hours) and invites
-- friends, guildmates or channel members. Each participant plays the shared layout once; the
-- standings are each player's best score. There is no host: every participant keeps the whole
-- record and whispers it to online participants on login, when the Battle tab opens, after
-- playing, every 180 s to participants not yet known to have it, and when a participant comes
-- online. Receivers merge scores (best per player) and answer if the sender's copy was missing some.
-- An ended battle stays listed (grey) for another duration, then shows "Expired" and is deleted
-- at the next login.
-- Protocol (ns.Comm op, WHISPER only):
--   battle { b = { id, creator, level, shots, layout, created, duration, names, note, scores } }
--     names and creator are "Name-Realm"; created is GetServerTime(); duration in seconds;
--     scores = { ["Name-Realm"] = { score, character, beaten, cleared } } for players who have played.

local Battle = {}
ns.Battle = Battle

Battle.DURATIONS = { 12 * 3600, 24 * 3600, 48 * 3600 }
Battle.MAX_SHOTS = 10
Battle.MAX_ACTIVE = 5 -- battles the player created that are still running
local MAX_NAMES = 200
local MAX_STORED = 60
local MAX_ID = 100
local CLOCK_SKEW = 3600 -- accepted difference between our server time and a record's creation time
local GOSSIP_COOLDOWN = 300 -- per battle and participant
local REPLY_COOLDOWN = 60
local RESEND_INTERVAL = 180
local OFFLINE_TTL = 600 -- how long a "player not found" keeps us from whispering them
local LOGIN_DELAY = 15

local lastSent = {} -- "id\nname" -> GetTime()
local lastReply = {}
local offline = {} -- name -> GetTime() of the bounce
local guildOnline -- name -> online, nil until built
local friendOnline
local currentId -- battle being played

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function battles()
    return ns.db.char.battles
end

local function notify()
    Peggle:SendMessage("PEGGLE_BATTLE_UPDATE")
end

local function now()
    return GetServerTime()
end

function Battle.EndTime(rec)
    return rec.created + rec.duration
end

-- "active", "ended" (grace period) or "expired", and the seconds left in that state.
function Battle.Status(rec)
    local t, finish = now(), Battle.EndTime(rec)
    if t < finish then
        return "active", finish - t
    elseif t < finish + rec.duration then
        return "ended", finish + rec.duration - t
    end
    return "expired", 0
end

local function includes(rec, name)
    for _, member in ipairs(rec.names) do
        if member == name then
            return true
        end
    end
    return false
end

-- Presence

local function buildGuildOnline()
    if not IsInGuild() then
        return {}
    end
    local clubId = C_Club.GetGuildClubId()
    if not clubId then
        return nil
    end
    local roster, count = {}, 0
    local offlinePresence = Enum.ClubMemberPresence.Offline
    for _, memberId in ipairs(C_Club.GetClubMembers(clubId) or {}) do
        local info = C_Club.GetMemberInfo(clubId, memberId)
        local name = info and Util.NormalizeName(info.name)
        if name then
            roster[name] = info.presence ~= offlinePresence
            count = count + 1
        end
    end
    return count > 0 and roster or nil
end

local function buildFriendOnline()
    local friends = {}
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        local name = info and Util.NormalizeName(info.name)
        if name then
            friends[name] = info.connected and true or false
        end
    end
    return friends
end

-- False only when we know the player is offline; unknown players are tried and bounce back.
local function isOnline(name)
    local bounced = offline[name]
    if bounced and GetTime() - bounced < OFFLINE_TTL then
        return false
    end
    for _, member in ipairs(Util.GroupMembers()) do
        if member == name then
            return true
        end
    end
    friendOnline = friendOnline or buildFriendOnline()
    if friendOnline[name] ~= nil then
        return friendOnline[name]
    end
    guildOnline = guildOnline or buildGuildOnline()
    if guildOnline and guildOnline[name] ~= nil then
        return guildOnline[name]
    end
    return true
end
Battle.IsOnline = isOnline

-- Wire format

local function toWire(rec)
    local names, scores = {}, {}
    for i, name in ipairs(rec.names) do
        names[i] = MP.FullName(name)
    end
    for name, entry in pairs(rec.scores) do
        scores[MP.FullName(name)] = {
            score = entry.score,
            character = entry.character,
            beaten = entry.beaten,
            cleared = entry.cleared,
        }
    end
    return {
        id = rec.id,
        creator = MP.FullName(rec.creator),
        level = rec.level,
        shots = rec.shots,
        layout = MP.CopyLayout(rec.layout),
        created = rec.created,
        duration = rec.duration,
        names = names,
        note = rec.note,
        scores = scores,
    }
end

local function validDuration(duration)
    for _, allowed in ipairs(Battle.DURATIONS) do
        if duration == allowed then
            return true
        end
    end
    return false
end

local function validEntry(entry)
    return type(entry) == "table" and MP.ValidInt(entry.score, 0, MP.MAX_SCORE)
        and MP.ValidCharacter(entry.character)
        and MP.ValidInt(entry.beaten, 0, C.NUM_LEVELS) and MP.ValidInt(entry.cleared, 0, C.NUM_LEVELS)
end

-- Validated record with local names, or nil.
local function fromWire(b)
    if type(b) ~= "table" or not MP.ValidString(b.id, MAX_ID) or #b.id == 0 then
        return nil
    end
    if not MP.ValidName(b.creator) or not MP.ValidInt(b.shots, 1, Battle.MAX_SHOTS)
        or not MP.ValidLayout(b.level, b.layout) or not validDuration(b.duration)
        or not MP.ValidString(b.note, MP.MAX_NOTE) or type(b.names) ~= "table" or type(b.scores) ~= "table" then
        return nil
    end
    if not MP.ValidInt(b.created, 0, now() + CLOCK_SKEW) or #b.names < 1 then
        return nil
    end
    local names, seen = {}, {}
    for i = 1, #b.names do
        local full = b.names[i]
        local name = MP.ValidName(full) and MP.LocalName(full)
        if not name or seen[name] or i > MAX_NAMES then
            return nil
        end
        seen[name] = true
        names[i] = name
    end
    local creator = MP.LocalName(b.creator)
    if not seen[creator] then
        return nil
    end
    local scores = {}
    for full, entry in pairs(b.scores) do
        local name = MP.ValidName(full) and MP.LocalName(full)
        if name and seen[name] and validEntry(entry) then
            scores[name] = { score = entry.score, character = entry.character, beaten = entry.beaten, cleared = entry.cleared }
        end
    end
    return {
        id = b.id,
        creator = creator,
        level = b.level,
        shots = b.shots,
        layout = MP.CopyLayout(b.layout),
        created = b.created,
        duration = b.duration,
        names = names,
        note = b.note,
        scores = scores,
        has = {},
    }
end

-- Sending

local function sendTo(rec, name, force)
    if Util.IsPlayer(name) or Battle.Status(rec) == "expired" then
        return
    end
    local key = rec.id .. "\n" .. name
    local t = GetTime()
    if not force and lastSent[key] and t - lastSent[key] < GOSSIP_COOLDOWN then
        return
    end
    if not isOnline(name) then
        return
    end
    lastSent[key] = t
    ns.Comm.Send("battle", { b = toWire(rec) }, "WHISPER", name)
end

local function gossipRecord(rec, force, onlyMissing)
    for _, name in ipairs(rec.names) do
        if not onlyMissing or not rec.has[name] then
            sendTo(rec, name, force)
        end
    end
end

-- Sends every battle to its online participants (respecting the per-player cooldown).
function Battle.Gossip()
    for _, rec in pairs(battles()) do
        gossipRecord(rec, false)
    end
end

local function gossipToPlayer(name)
    for _, rec in pairs(battles()) do
        if includes(rec, name) then
            sendTo(rec, name, false)
        end
    end
end

-- Receiving

-- Takes the best score per player. Returns changedLocal, senderMissing.
local function merge(rec, incoming)
    local changed, missing = false, false
    for name, entry in pairs(incoming.scores) do
        local mine = rec.scores[name]
        if includes(rec, name) and (not mine or entry.score > mine.score) then
            rec.scores[name] = entry
            changed = true
        end
    end
    for name, entry in pairs(rec.scores) do
        local theirs = incoming.scores[name]
        if not theirs or theirs.score < entry.score then
            missing = true
        end
    end
    return changed, missing
end

local function storedCount()
    local count = 0
    for _ in pairs(battles()) do
        count = count + 1
    end
    return count
end

ns.Comm.Register("battle", function(msg, sender, distribution)
    if distribution ~= "WHISPER" then
        return
    end
    local incoming = fromWire(msg.b)
    local me = Util.PlayerName()
    if not incoming or not includes(incoming, sender) or not includes(incoming, me) then
        return
    end
    offline[sender] = nil
    local rec = battles()[incoming.id]
    if rec then
        rec.has = rec.has or {}
        rec.has[sender] = true
        local changed, missing = merge(rec, incoming)
        local t = GetTime()
        if missing and (not lastReply[sender] or t - lastReply[sender] >= REPLY_COOLDOWN) then
            lastReply[sender] = t
            sendTo(rec, sender, true)
        end
        if changed then
            notify()
        end
        return
    end
    if Battle.Status(incoming) == "expired" or storedCount() >= MAX_STORED then
        return
    end
    incoming.has[sender] = true
    incoming.new = true
    battles()[incoming.id] = incoming
    if ns.Menu and ns.Menu.SetTabSparkle then
        ns.Menu.SetTabSparkle("battle", true)
    end
    MP.Alert(string.format(L["_BATTLE_INVITE"], incoming.creator, L["_LEVEL_NAME" .. incoming.level]))
    notify()
end)

ns.Comm.OnPlayerNotFound(function(name)
    offline[name] = GetTime()
end)

-- Public API

-- Records sorted oldest first, as the original listed them.
function Battle.List()
    local list = {}
    for _, rec in pairs(battles()) do
        table.insert(list, rec)
    end
    table.sort(list, function(a, b)
        if a.created ~= b.created then
            return a.created < b.created
        end
        return a.id < b.id
    end)
    return list
end

function Battle.Get(id)
    return battles()[id]
end

function Battle.ActiveCreatedCount()
    local me, count = Util.PlayerName(), 0
    for _, rec in pairs(battles()) do
        if rec.creator == me and Battle.Status(rec) == "active" then
            count = count + 1
        end
    end
    return count
end

function Battle.CanCreate()
    return Battle.ActiveCreatedCount() < Battle.MAX_ACTIVE
end

function Battle.HasPlayed(rec)
    return rec.scores[Util.PlayerName()] ~= nil
end

function Battle.CanPlay(rec)
    return Battle.Status(rec) == "active" and not Battle.HasPlayed(rec)
end

function Battle.MarkSeen(id)
    local rec = battles()[id]
    if rec then
        rec.new = nil
    end
end

-- { name, score, character, beaten, cleared } rows: players who have played by score, then the rest by name.
function Battle.Standings(rec)
    local rows = {}
    for _, name in ipairs(rec.names) do
        local entry = rec.scores[name]
        table.insert(rows, {
            name = name,
            score = entry and entry.score,
            character = entry and entry.character,
            beaten = entry and entry.beaten,
            cleared = entry and entry.cleared,
        })
    end
    table.sort(rows, function(a, b)
        if (a.score ~= nil) ~= (b.score ~= nil) then
            return a.score ~= nil
        end
        if a.score and a.score ~= b.score then
            return a.score > b.score
        end
        return a.name < b.name
    end)
    return rows
end

-- The player's rank among those who have played, and how many have played.
function Battle.Rank(rec)
    local mine = rec.scores[Util.PlayerName()]
    local played, lower = 0, 0
    for _, entry in pairs(rec.scores) do
        played = played + 1
        if mine and entry.score < mine.score then
            lower = lower + 1
        end
    end
    return mine and (played - lower) or nil, played
end

-- names: local names including the player. Returns the new record, or nil when invalid or over the limit.
function Battle.Create(level, shots, duration, names, note)
    if not Battle.CanCreate() or not MP.ValidLevel(level) or not MP.ValidInt(shots, 1, Battle.MAX_SHOTS)
        or not validDuration(duration) then
        return nil
    end
    local me = Util.PlayerName()
    local list, seen = {}, {}
    for _, name in ipairs(names) do
        name = Util.NormalizeName(name)
        if name and not seen[name] and #list < MAX_NAMES then
            seen[name] = true
            table.insert(list, name)
        end
    end
    if not seen[me] then
        table.insert(list, me)
    end
    table.sort(list)
    note = note and strtrim(note) or ""
    if #note > MP.MAX_NOTE then
        note = note:sub(1, MP.MAX_NOTE)
    end
    local created = now()
    local rec = {
        id = string.format("%s:%d:%d", MP.FullName(me), created, math.random(0, 65535)),
        creator = me,
        level = level,
        shots = shots,
        layout = ns.Levels.RandomLayout(level),
        created = created,
        duration = duration,
        names = list,
        note = note,
        scores = {},
        has = { [me] = true },
    }
    battles()[rec.id] = rec
    gossipRecord(rec, true)
    notify()
    return rec
end

function Battle.Play(id)
    local rec = battles()[id]
    if not rec or not Battle.CanPlay(rec) then
        return false
    end
    rec.new = nil
    currentId = id
    if ns.Duel.IsActive() then
        ns.Duel.Forfeit()
    end
    if ns.Game.IsInProgress() then
        ns.Game.Abandon()
    end
    ns.Game.Start(rec.level, { mode = "battle", layout = MP.CopyLayout(rec.layout), balls = rec.shots })
    return true
end

-- Game events and timers

local function onLevelEnd(_, result)
    if type(result) ~= "table" or result.mode ~= "battle" or not currentId then
        return
    end
    local rec = battles()[currentId]
    currentId = nil
    if not rec then
        return
    end
    local me = Util.PlayerName()
    local entry = {
        score = math.floor(result.score or 0),
        character = result.character or C.CHAR_GUIDE,
        beaten = result.beaten or 0,
        cleared = result.cleared or 0,
    }
    if not validEntry(entry) then
        return
    end
    local old = rec.scores[me]
    if not old or entry.score > old.score then
        rec.scores[me] = entry
    end
    gossipRecord(rec, true)
    notify()
end

-- Deletes battles past their grace period (the original did this at login).
local function purge()
    local list = battles()
    for id, rec in pairs(list) do
        if type(rec) ~= "table" or type(rec.created) ~= "number" or type(rec.duration) ~= "number"
            or type(rec.names) ~= "table" or type(rec.scores) ~= "table" or Battle.Status(rec) == "expired" then
            list[id] = nil
        else
            rec.has = rec.has or {}
        end
    end
end

-- Whispers battles to participants who just came online.
local function onRosterChanged(old, new)
    if not old or not new then
        return
    end
    for name, online in pairs(new) do
        if online and old[name] == false then
            offline[name] = nil
            gossipToPlayer(name)
        end
    end
end

ns.RegisterEnabler("Battle", function()
    purge()
    events:RegisterMessage("PEGGLE_LEVEL_END", onLevelEnd)
    events:RegisterMessage("PEGGLE_LEVEL_ABANDONED", function(_, mode)
        if mode == "battle" then
            currentId = nil
        end
    end)
    events:RegisterEvent("FRIENDLIST_UPDATE", function()
        local old = friendOnline
        friendOnline = buildFriendOnline()
        onRosterChanged(old, friendOnline)
    end)
    events:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        local old = guildOnline
        guildOnline = buildGuildOnline()
        onRosterChanged(old, guildOnline)
    end)
    events:RegisterEvent("PLAYER_GUILD_UPDATE", function()
        guildOnline = nil
    end)
    C_FriendList.ShowFriends()
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    C_Timer.After(LOGIN_DELAY, Battle.Gossip)
    C_Timer.NewTicker(RESEND_INTERVAL, function()
        for _, rec in pairs(battles()) do
            if Battle.Status(rec) == "active" then
                gossipRecord(rec, false, true)
            end
        end
    end)
    C_Timer.NewTicker(60, notify)
end)
