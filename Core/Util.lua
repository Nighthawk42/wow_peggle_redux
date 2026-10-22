local _, ns = ...
local Peggle = ns.addon
local C = ns.C

-- Shared helpers: number formatting, backdrops, angles, chat and group compatibility shims.

local Util = {}
ns.Util = Util

function Util.CommaNumber(number)
    local formatted = tostring(math.floor(number))
    local count
    repeat
        formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until count == 0
    return formatted
end

-- Minutes and seconds, seconds rounded down.
function Util.MinutesSeconds(seconds)
    local minutes = math.floor(seconds / 60)
    return minutes, math.floor(seconds - minutes * 60)
end

function Util.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFDD00Peggle:|r " .. text)
end

-- Backdrop styles used by the original's windows and panels.
local TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local PANEL_EDGE = "Interface\\Glues\\Common\\TextPanel-Border"

local BACKDROPS = {
    -- The main window and the summary screen.
    window = {
        bgFile = C.ART_PATH .. "windowBackground",
        edgeFile = C.ART_PATH .. "windowBorder",
        tile = true,
        tileSize = 64,
        edgeSize = 32,
        insets = { left = 5, right = 3, top = 5, bottom = 5 },
    },
    -- Menus and popups over the board: stone background, gold text-panel border.
    popup = {
        bgFile = C.ART_PATH .. "windowBackground",
        edgeFile = PANEL_EDGE,
        tile = true,
        tileSize = 128,
        edgeSize = 32,
        insets = { left = 5, right = 5, top = 3, bottom = 5 },
    },
    -- Panels inside the menu tabs: dark tooltip background, text-panel border.
    panel = {
        bgFile = TOOLTIP_BG,
        edgeFile = PANEL_EDGE,
        tile = true,
        tileSize = 128,
        edgeSize = 32,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    },
    tooltip = {
        bgFile = TOOLTIP_BG,
        edgeFile = TOOLTIP_EDGE,
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    },
}

-- Applies a named backdrop style to a frame created with "BackdropTemplate".
function Util.SetBackdrop(frame, style, r, g, b, a, borderR, borderG, borderB)
    frame:SetBackdrop(BACKDROPS[style])
    if r then
        frame:SetBackdropColor(r, g, b, a or 1)
    end
    if borderR then
        frame:SetBackdropBorderColor(borderR, borderG, borderB)
    end
end

-- The original used WoW's degree-based atan2 global; Lua's returns radians.
local atan2, deg = math.atan2, math.deg
function Util.Atan2(y, x)
    return deg(atan2(y, x))
end

-- Chat filters moved under ChatFrameUtil in 11.x; older clients keep the globals.
function Util.AddChatFilter(event, func)
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    add(event, func)
end

function Util.RemoveChatFilter(event, func)
    local remove = (ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter) or ChatFrame_RemoveMessageEventFilter
    remove(event, func)
end

-- Unit names and event payloads can be secret values in Midnight instances.
function Util.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Comparable player name: "Name" for the player's realm, "Name-Realm" otherwise.
function Util.NormalizeName(name)
    if type(name) ~= "string" or name == "" or Util.IsSecret(name) then
        return nil
    end
    return Ambiguate(name, "none")
end

function Util.PlayerName()
    return UnitName("player")
end

function Util.IsPlayer(name)
    return Util.NormalizeName(name) == Util.PlayerName()
end

-- Group members other than the player, as normalized names.
function Util.GroupMembers()
    local names = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            name = Util.NormalizeName(name)
            if name and not Util.IsPlayer(name) then
                table.insert(names, name)
            end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            local name = Util.NormalizeName(GetUnitName("party" .. i, true))
            if name then
                table.insert(names, name)
            end
        end
    end
    return names
end

function Util.GroupChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
end

function Util.IsGroupOfficer()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Chat sends are blocked during Midnight encounter lockdowns.
function Util.InChatLockdown()
    return C_ChatInfo.InChatMessagingLockdown ~= nil and C_ChatInfo.InChatMessagingLockdown()
end

function Peggle:Print(text)
    Util.Print(text)
end
