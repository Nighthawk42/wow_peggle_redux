local _, ns = ...
local Peggle = ns.addon
local C = ns.C
local Util = ns.Util

-- Addon messages (AceComm, prefix C.COMM_PREFIX). Every message is a serialized table
-- { v = protocol version, op = message type, ... }. Features register a handler per op:
--   ns.Comm.Register("duelInvite", function(msg, sender, distribution) ... end)
--   ns.Comm.Send("duelInvite", { level = 3 }, "WHISPER", "Name")
-- Messages from a different protocol version are dropped; the player is told once per sender.
-- Sends during a chat lockdown wait in an outbox until it lifts.

local Comm = {}
ns.Comm = Comm

local LOCKDOWN_RETRY = 5
local NOT_FOUND_WINDOW = 10 -- seconds a whisper target's "not found" error is attributed to us

local handlers = {}
local outbox = {} -- functions to run once the lockdown lifts
local retryTimer
local warnedSenders = {}
local recentWhispers = {} -- name -> time of our last whisper
local notFoundCallbacks = {}

local function flushOutbox()
    retryTimer = nil
    if Util.InChatLockdown() then
        retryTimer = C_Timer.NewTimer(LOCKDOWN_RETRY, flushOutbox)
        return
    end
    local pending = outbox
    outbox = {}
    for _, send in ipairs(pending) do
        send()
    end
end

-- Runs send now, or later if chat is locked down.
local function sendOrQueue(send)
    if Util.InChatLockdown() then
        table.insert(outbox, send)
        retryTimer = retryTimer or C_Timer.NewTimer(LOCKDOWN_RETRY, flushOutbox)
    else
        send()
    end
end

function Comm.Register(op, handler)
    handlers[op] = handler
end

-- func(name) runs when a whisper we sent bounced because the player is offline.
function Comm.OnPlayerNotFound(func)
    table.insert(notFoundCallbacks, func)
end

function Comm.Send(op, payload, distribution, target)
    if distribution == "GUILD" and not IsInGuild() then
        return
    end
    payload = payload or {}
    payload.v = C.PROTOCOL_VERSION
    payload.op = op
    payload.ver = Peggle.version
    local message = Peggle:Serialize(payload)
    sendOrQueue(function()
        if distribution == "WHISPER" then
            recentWhispers[Util.NormalizeName(target) or target] = GetTime()
        end
        Peggle:SendCommMessage(C.COMM_PREFIX, message, distribution, target)
    end)
end

-- Plain chat (brag, PeggleLoot announcements and results).
function Comm.Chat(text, chatType, channel)
    sendOrQueue(function()
        SendChatMessage(text, chatType, nil, channel)
    end)
end

local function warnVersion(sender, theirVersion, theirAddonVersion)
    if warnedSenders[sender] then
        return
    end
    warnedSenders[sender] = true
    if theirVersion > C.PROTOCOL_VERSION then
        ns.db.global.newerVersionSeen = theirAddonVersion or "?"
        Peggle:SendMessage("PEGGLE_NEWER_VERSION", sender, theirAddonVersion)
    elseif not ns.db.profile.hideOutdated then
        Util.Print(string.format(ns.L["_OUTDATED_PEER"], sender))
    end
end

local function onCommReceived(_, message, distribution, sender)
    sender = Util.NormalizeName(sender)
    -- Our own guild and group broadcasts come back to us.
    if not sender or (Util.IsPlayer(sender) and distribution ~= "WHISPER") then
        return
    end
    local ok, payload = Peggle:Deserialize(message)
    if not ok or type(payload) ~= "table" or type(payload.op) ~= "string" then
        return
    end
    if payload.v ~= C.PROTOCOL_VERSION then
        if type(payload.v) == "number" then
            warnVersion(sender, payload.v, payload.ver)
        end
        return
    end
    local handler = handlers[payload.op]
    if handler then
        xpcall(function()
            handler(payload, sender, distribution)
        end, geterrorhandler())
    end
end

-- Hides "No player named X is currently playing" for players we just whispered, and reports them.
local notFoundPattern = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("%%s", "(.+)")
local function playerNotFoundFilter(_, _, message)
    local name = type(message) == "string" and not Util.IsSecret(message) and message:match(notFoundPattern)
    name = name and Util.NormalizeName(name)
    local sentAt = name and recentWhispers[name]
    if not sentAt or GetTime() - sentAt > NOT_FOUND_WINDOW then
        return false
    end
    for _, func in ipairs(notFoundCallbacks) do
        xpcall(function()
            func(name)
        end, geterrorhandler())
    end
    return true
end

ns.RegisterEnabler("Comm", function()
    Peggle:RegisterComm(C.COMM_PREFIX, onCommReceived)
    Util.AddChatFilter("CHAT_MSG_SYSTEM", playerNotFoundFilter)
end)
