-- Loads the original Peggle 1.02 (original/Peggle.lua) on the same stubbed API, with the
-- WotLK-era globals it expects, and exposes its file-level functions as __ORIG.
-- Globals in: HARNESS, ROOT, ORIGINAL (path to Peggle.lua).
SKIP_ADDON = true
dofile(HARNESS)
H.autoRegions = true

local function stub() end
local deg, atan, atan2 = math.deg, math.atan, math.atan2
_G.atan2 = function(y, x)
    return deg(atan2(y, x))
end
_G.atan = function(v)
    return deg(atan(v))
end
_G.getglobal = function(name)
    return rawget(_G, name) or CreateFrame("Frame", name)
end
_G.CalendarGetDate = function()
    return 4, 10, 22, 2026
end
_G.GetGameTime = function()
    return 12, 0
end
_G.GetNumRaidMembers = function()
    return 0
end
_G.GetNumPartyMembers = function()
    return 0
end
_G.GetNumFriends = function()
    return 0
end
_G.GetLootMethod = function()
    return "freeforall"
end
_G.EnumerateServerChannels = function()
    return "General", "Trade"
end
_G.MouseIsOver = function()
    return false
end
_G.CreateFont = function(name)
    return CreateFrame("Font", name)
end
_G.HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
_G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
_G.TALENT_BRANCH_TEXTURECOORDS = { down = { [1] = { 0, 1, 0, 1 }, [-1] = { 0, 1, 0, 1 } } }
_G.TALENT_ARROW_TEXTURECOORDS = { top = { [1] = { 0, 1, 0, 1 }, [-1] = { 0, 1, 0, 1 } } }
for _, name in ipairs({
    "SendAddonMessage",
    "SetDesaturation",
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetText",
    "UIDropDownMenu_SetSelectedValue",
    "UIDropDownMenu_SetSelectedName",
    "UIDropDownMenu_SetAnchor",
    "UIDropDownMenu_AddButton",
    "ToggleDropDownMenu",
    "AchievementFrame_LoadUI",
    "AchievementShield_SetPoints",
    "IsRaidOfficer",
    "GetFriendInfo",
    "GuildRoster",
    "SetGuildRosterShowOffline",
    "SortGuildRoster",
    "DrawRouteLine",
}) do
    _G[name] = stub
end
_G.message = print
_G.GameFontNormal, _G.GameFontNormalSmall, _G.GameFontHighlight = CreateFrame("Font"), CreateFrame("Font"), CreateFrame("Font")

local file = assert(io.open(ORIGINAL, "rb"))
local source = file:read("*a")
file:close()
-- Every file-level function the tests drive is in scope at the end of the chunk.
source = source .. "\n__ORIG = { R = R, Et = Et, Ae = Ae, it = it, ie = ie, e = e, t = t, d = d, r = r, h = h }\n"
local chunk = assert(loadstring(source, "=Peggle.lua"))
local ok, err = pcall(chunk)
if not ok then
    print("ORIGINAL LOAD ERROR", err)
end
H.fire("VARIABLES_LOADED")
