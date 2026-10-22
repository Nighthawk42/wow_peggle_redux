-- Headless harness: loads PeggleRedux in TOC order on a stubbed WoW API (Lua 5.1) and exposes
-- helpers to drive frames, events and time. Usage: dofile(harness); then H.* functions.
local ROOT = assert(ROOT, "set ROOT to the addon folder (with a trailing slash)")
H = { errors = {}, missing = {}, chat = {}, comm = {}, sounds = 0, now = 1000 }

local function noop() end
local function report(kind, msg)
    local key = kind .. ": " .. tostring(msg)
    if not H.errors[key] then
        H.errors[key] = 0
        print(key)
        if H.trace then print(debug.traceback()) end
    end
    H.errors[key] = H.errors[key] + 1
end
H.report = report

-- Regions
local Region = {}
local newRegion
local regionMeta = { __index = function(self, key)
    local v = Region[key]
    if v ~= nil then return v end
    if type(key) == "string" and key:match("^%u") then
        if H.autoRegions and key:match("^Get") then
            return function(self) local r = rawget(self, "_auto_" .. key) or newRegion("Texture", nil, self); rawset(self, "_auto_" .. key, r); return r end
        end
        return noop
    end
end }
local created = {}
H.created = created
local frames = {}
newRegion = function(kind, name, parent)
    local r = setmetatable({ _kind = kind, _scripts = {}, _shown = true, _w = 0, _h = 0, _parent = parent,
        _alpha = 1, _scale = 1, _events = {}, _level = parent and parent._level and parent._level + 1 or 1 }, regionMeta)
    created[#created + 1] = r
    if name then _G[name] = r; r._name = name end
    return r
end
local function checkNumber(v, what)
    if type(v) ~= "number" or v ~= v then report("BAD NUMBER", what .. " " .. tostring(v)) end
end
function Region:SetScript(k, fn) self._scripts[k] = fn end
function Region:GetScript(k) return self._scripts[k] end
function Region:HookScript(k, fn)
    local old = self._scripts[k]
    self._scripts[k] = old and function(...) old(...) fn(...) end or fn
end
function Region:Show() local was = self._shown; self._shown = true; if not was and self._scripts.OnShow and self:IsVisible() then self._scripts.OnShow(self) end end
function Region:Hide() local was = self._shown; self._shown = false; if was and self._scripts.OnHide then self._scripts.OnHide(self) end end
function Region:SetShown(s) if s then self:Show() else self:Hide() end end
function Region:IsShown() return self._shown end
function Region:IsVisible() local f = self; while f do if not f._shown then return false end f = f._parent end return true end
function Region:SetSize(w, h) checkNumber(w, "SetSize w"); checkNumber(h, "SetSize h"); self._w, self._h = w, h end
function Region:SetWidth(w) checkNumber(w, "SetWidth"); self._w = w end
function Region:SetHeight(h) checkNumber(h, "SetHeight"); self._h = h end
function Region:GetWidth() return self._w end
function Region:GetHeight() return self._h end
function Region:GetSize() return self._w, self._h end
function Region:GetRect() return 100, 100, self._w, self._h end
function Region:GetEffectiveScale() return 1 end
function Region:GetScale() return self._scale end
function Region:SetScale(s) checkNumber(s, "SetScale"); self._scale = s end
function Region:GetStringWidth() return #(tostring(self._text or "")) * 7 end
function Region:GetStringHeight() return 14 end
function Region:GetFrameLevel() return self._level end
function Region:SetFrameLevel(l) checkNumber(l, "SetFrameLevel"); self._level = l end
function Region:GetFrameStrata() return "MEDIUM" end
function Region:SetID(id) self._id = id end
function Region:GetID() return self._id or 0 end
function Region:SetParent(p) self._parent = p end
function Region:GetParent() return self._parent end
function Region:SetAlpha(a) checkNumber(a, "SetAlpha"); self._alpha = a end
function Region:GetAlpha() return self._alpha end
function Region:GetName() return self._name end
function Region:IsMouseOver() return H.mouseOver or false end
function Region:SetText(t)
    if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then report("SETTEXT TYPE", type(t)) end
    self._text = t
end
function Region:GetText() return self._text end
function Region:SetFormattedText(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    if not ok then report("FORMAT", s .. " fmt=" .. tostring(fmt)) else self._text = s end
end
function Region:SetFont(path, size) if type(path) ~= "string" then report("SETFONT", tostring(path)) end checkNumber(size, "font size"); return true end
function Region:GetFont() return "font", 12, "" end
function Region:SetTexture(t) self._texture = t; return true end
function Region:GetTexture() return self._texture end
function Region:SetChecked(v) self._checked = v end
function Region:GetChecked() return self._checked end
function Region:CreateTexture(name) return newRegion("Texture", name, self) end
function Region:CreateFontString(name) return newRegion("FontString", name, self) end
function Region:CreateLine(name) return newRegion("Line", name, self) end
function Region:CreateMaskTexture(name) return newRegion("MaskTexture", name, self) end
function Region:CreateAnimationGroup() return newRegion("AnimationGroup", nil, self) end
function Region:SetPoint(point, ...)
    if type(point) ~= "string" then report("SETPOINT", tostring(point)) end
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" then checkNumber(v, "SetPoint offset") end
    end
end
function Region:SetTexCoord(...)
    local n = select("#", ...)
    if n ~= 4 and n ~= 8 then report("TEXCOORD ARGS", n) end
    for i = 1, n do checkNumber((select(i, ...)), "texcoord") end
end
function Region:SetVertexColor(r, g, b, a) checkNumber(r, "color r"); checkNumber(g, "color g"); checkNumber(b, "color b") end
function Region:RegisterEvent(e) self._events[e] = true end
function Region:UnregisterEvent(e) self._events[e] = nil end
function Region:UnregisterAllEvents() self._events = {} end
function Region:IsEventRegistered(e) return self._events[e] end
function Region:GetObjectType() return self._kind end
function Region:SetupMenu(fn) self._menu = fn; self:GenerateMenu() end
function Region:GenerateMenu()
    if not self._menu then return end
    local desc
    desc = setmetatable({}, { __index = function(_, key)
        return function(_, text, isSelected, setSelected, data)
            if key:match("^Create") and key ~= "CreateDivider" and key ~= "CreateSpacer" and type(text) ~= "string" then
                report("MENU TEXT", key .. " " .. type(text))
            end
            if type(isSelected) == "function" then isSelected(data) end
            return desc
        end
    end })
    self._menu(self, desc)
end
function Region:GetNumPoints() return 1 end
function Region:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Region:GetLeft() return 100 end
function Region:GetRight() return 100 + self._w end
function Region:GetTop() return 100 + self._h end
function Region:GetBottom() return 100 end
function Region:GetCenter() return 100 + self._w / 2, 100 + self._h / 2 end
function Region:GetNumChildren() return 0 end
function Region:GetChildren() end
function Region:GetVerticalScroll() return 0 end
function Region:SetVerticalScroll(v) if self._kind ~= "ScrollFrame" then error("attempt to call a nil value (SetVerticalScroll on " .. self._kind .. ")") end end
function Region:Click(button) if self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton", true) end end
function Region:IsEnabled() return true end
function Region:GetValue() return self._value or 0 end
function Region:SetValue(v) self._value = v; if self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v, true) end end
function Region:GetMinMaxValues() return 0, 1 end

_G.CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, name, parent)
    f._template = template
    -- Like the client, the scroll bar template scrolls its parent as a ScrollFrame on value changes.
    if template == "UIPanelScrollBarTemplate" then
        f._scripts.OnValueChanged = function(self, value)
            self:GetParent():SetVerticalScroll(value)
        end
    end
    if template and (template:find("CheckButton") or template:find("Slider")) then
        f.Text = newRegion("FontString", nil, f)
        f.Low = newRegion("FontString", nil, f)
        f.High = newRegion("FontString", nil, f)
    end
    frames[#frames + 1] = f
    return f
end
_G.UIParent = newRegion("Frame", "UIParent")
_G.WorldFrame = newRegion("Frame", "WorldFrame")
_G.Minimap = newRegion("Frame", "Minimap")
_G.GameTooltip = newRegion("GameTooltip", "GameTooltip")
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) H.chat[#H.chat + 1] = m; if H.echoChat then print("CHAT", m) end end }
_G.RaidNotice_AddMessage = noop
_G.RaidWarningFrame = newRegion("Frame")
_G.ChatTypeInfo = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.CHAT_MSG_GUILD, _G.CHAT_MSG_PARTY, _G.CHAT_MSG_RAID = "Guild", "Party", "Raid"
_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
_G.OKAY, _G.CANCEL, _G.ACCEPT, _G.DECLINE, _G.NONE, _G.YES, _G.NO = "Okay", "Cancel", "Accept", "Decline", "None", "Yes", "No"
_G.MAX_WOW_CHAT_CHANNELS = 20
_G.LE_PARTY_CATEGORY_HOME, _G.LE_PARTY_CATEGORY_INSTANCE = 1, 2
_G.Enum = setmetatable({ PermanentChatChannelType = { None = 0, Zone = 1, Communities = 2, Custom = 3 },
    LootMethod = { Freeforall = 0, Roundrobin = 1, Masterlooter = 2, Group = 3, Needbeforegreed = 4, Personal = 5 } },
    { __index = function(t, k) local v = setmetatable({}, { __index = function() return 0 end }); rawset(t, k, v); return v end })
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = _G.wipe
_G.tinsert, _G.tremove = table.insert, table.remove
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.strsplit = function(sep, s) local out = {} for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end return unpack(out) end
_G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
_G.format = string.format
_G.max, _G.min, _G.floor, _G.ceil, _G.abs = math.max, math.min, math.floor, math.ceil, math.abs
_G.date = os.date
_G.time = function() return math.floor(H.now) + 1700000000 end
_G.GetTime = function() return H.now end
_G.GetServerTime = _G.time
_G.debugprofilestop = function() return H.now * 1000 end
_G.InCombatLockdown = function() return false end
_G.ClearOverrideBindings, _G.SetOverrideBindingClick = noop, noop
_G.UnitOnTaxi = function() return false end
_G.hooksecurefunc = noop
_G.geterrorhandler = function() return function(e) report("ERROR", e) end end
_G.seterrorhandler = noop
_G.securecallfunction = function(f, ...) return f(...) end
_G.C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end, IsAddOnLoaded = function() return false end, LoadAddOn = noop }
_G.Ambiguate = function(n) return (n:gsub("%-.*", "")) end
_G.UnitName = function(u) if u == "player" then return rawget(_G, "PLAYER_NAME") or "Tester" end local i = type(u) == "string" and tonumber(u:match("^party(%d)$")) if i and H.party then return H.party[i] end return nil end
_G.GetUnitName = function(u) return _G.UnitName(u) end
_G.UnitIsConnected = function() return true end
_G.UnitExists = function(u) return _G.UnitName(u) ~= nil end
_G.UnitInParty = function() return true end
_G.UnitInRaid = function() return nil end
_G.UnitGUID = function() return "Player-1-0001" end
_G.GetRealmName = function() return "Realm" end
_G.GetNormalizedRealmName = function() return "Realm" end
_G.IsInGuild = function() return true end
_G.IsInRaid = function() return H.inRaid or false end
_G.IsInGroup = function() return H.inGroup or false end
_G.GetNumGroupMembers = function() return H.groupSize or 0 end
_G.GetNumSubgroupMembers = function() return H.party and #H.party or 0 end
_G.GetRaidRosterInfo = function(i) return "Raider" .. i end
_G.UnitIsGroupLeader = function() return true end
_G.UnitIsGroupAssistant = function() return false end
_G.GetChannelName = function(id) if id == 5 then return 5, "mychannel" end return 0, nil end
_G.SendChatMessage = function(msg, chatType, _, target) H.chat[#H.chat + 1] = "SEND " .. tostring(chatType) .. " " .. tostring(target) .. ": " .. msg end
_G.PlaySoundFile = function(path) if type(path) ~= "string" then report("SOUND", tostring(path)) end H.sounds = H.sounds + 1; return true end
_G.PlaySound = function() return true end
_G.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
_G.GetCursorPosition = function() return H.cursorX or 377, H.cursorY or 200 end
_G.issecretvalue = nil
_G.C_Timer = {
    After = function(d, fn) H.timers[#H.timers + 1] = { at = H.now + d, fn = fn } end,
    NewTimer = function(d, fn) local t = { at = H.now + d, fn = fn, Cancel = function(self) self.cancelled = true end }; H.timers[#H.timers + 1] = t; return t end,
    NewTicker = function(d, fn, n) local t = { at = H.now + d, every = d, fn = fn, left = n, Cancel = function(self) self.cancelled = true end }; H.timers[#H.timers + 1] = t; return t end,
}
H.timers = {}
_G.C_ChatInfo = {
    InChatMessagingLockdown = function() return false end,
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = noop,
    GetChannelInfoFromIdentifier = function(name) return { name = name, zoneChannelID = 0, channelType = 0 } end,
}
_G.C_PartyInfo = { GetLootMethod = function() return 2, 0, 0 end }
_G.C_FriendList = { ShowFriends = noop, GetNumFriends = function() return 0 end, GetFriendInfoByIndex = noop, GetNumOnlineFriends = function() return 0 end, IsFriend = function() return false end }
_G.C_GuildInfo = { GuildRoster = noop }
_G.C_Club = { GetGuildClubId = function() return nil end }
_G.GetNumGuildMembers = function() return 0, 0, 0 end
_G.GetGuildRosterInfo = noop
_G.C_BattleNet = { GetFriendNumGameAccounts = function() return 0 end }
_G.BNGetNumFriends = function() return 0, 0 end
_G.ChatFrame_AddMessageEventFilter = function(event, fn) H.filters = H.filters or {}; H.filters[#H.filters + 1] = { event, fn } end
_G.ChatFrame_RemoveMessageEventFilter = noop
_G.ChatFrameUtil = nil
_G.Settings = { RegisterCanvasLayoutCategory = function() return { ID = 1 } end, RegisterAddOnCategory = noop, OpenToCategory = noop }
_G.GetLocale = function() return "enUS" end
_G.GetBuildInfo = function() return "12.1.0", "1", "", 120100 end
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
_G.ACHIEVEMENT_UNLOCKED = "Achievement Earned"
_G.TOOLTIP_TALENT_LEARN = "Click to learn"
_G.MOUSE_OVER = nil
_G.IsLoggedIn = function() return H.loggedIn end
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.UnitClass = function() return "Mage", "MAGE", 8 end
_G.UnitRace = function() return "Human", "Human", 1 end
_G.GetCurrentRegion = function() return 1 end
_G.GetCurrentRegionName = function() return "US" end
_G.TOOLTIP_TALENT_NEXT_RANK = "Next Rank:"
_G.UnitNameUnmodified = _G.UnitName
_G.RegionalUniqueNamesEnabled = function() return false end
_G.LibStub = nil

-- Unknown capitalized globals are reported once.
setmetatable(_G, { __index = function(_, key)
    if type(key) == "string" and key:match("^%u") and key ~= "LibStub" and not H.missing[key] then
        H.missing[key] = true
        print("MISSING GLOBAL: " .. key)
    end
end })

-- Libraries: real LibStub, CallbackHandler, AceAddon, AceEvent, AceDB, AceSerializer, AceConsole, AceTimer.
local function runFile(path, ...)
    local chunk, err = loadfile(path)
    if not chunk then report("LOAD", err); return end
    local ok, e = pcall(chunk, ...)
    if not ok then report("RUN " .. path, e) end
end
H.runFile = runFile
local LIBS = ROOT .. "Libs/"
runFile(LIBS .. "LibStub/LibStub.lua")
runFile(LIBS .. "CallbackHandler-1.0/CallbackHandler-1.0.lua")
runFile(LIBS .. "AceAddon-3.0/AceAddon-3.0.lua")
runFile(LIBS .. "AceEvent-3.0/AceEvent-3.0.lua")
runFile(LIBS .. "AceDB-3.0/AceDB-3.0.lua")
runFile(LIBS .. "AceSerializer-3.0/AceSerializer-3.0.lua")
runFile(LIBS .. "AceConsole-3.0/AceConsole-3.0.lua")
runFile(LIBS .. "AceTimer-3.0/AceTimer-3.0.lua")

local AceComm = LibStub:NewLibrary("AceComm-3.0", 999)
AceComm.embeds = {}
function AceComm:Embed(target)
    target.RegisterComm = function(self, prefix, method) H.commHandlers = H.commHandlers or {}; H.commHandlers[prefix] = { self, method } end
    target.SendCommMessage = function(self, prefix, text, distribution, targetName)
        H.comm[#H.comm + 1] = { prefix = prefix, text = text, distribution = distribution, target = targetName }
    end
end
local function stubLib(name, t) local lib = LibStub:NewLibrary(name, 999); for k, v in pairs(t) do lib[k] = v end; return lib end
stubLib("AceGUI-3.0", { Create = function(_, kind)
    local w = { frame = CreateFrame("Frame"), content = CreateFrame("Frame"), type = kind }
    return setmetatable(w, { __index = function(_, k) return noop end })
end, Release = noop, RegisterAsContainer = noop })
stubLib("AceConfig-3.0", { RegisterOptionsTable = function(_, name, t) H.options = t end })
stubLib("AceConfigRegistry-3.0", { NotifyChange = noop, RegisterOptionsTable = noop, GetOptionsTable = function() return function() return H.options end end })
stubLib("AceConfigDialog-3.0", { Open = noop, AddToBlizOptions = function() return {}, "id" end, SetDefaultSize = noop, Close = noop, SelectGroup = noop })
stubLib("AceDBOptions-3.0", { GetOptionsTable = function() return { type = "group", args = {} } end })
stubLib("LibDataBroker-1.1", { NewDataObject = function(_, name, t) H.ldb = t; return t end })
stubLib("LibDBIcon-1.0", { Register = noop, Refresh = noop, Show = noop, Hide = noop, GetMinimapButton = function() return CreateFrame("Button") end })

-- Addon files in TOC order, sharing one namespace.
H.ns = {}
local function loadAddonFile(rel)
    local chunk, err = loadfile(ROOT .. rel)
    if not chunk then report("SYNTAX", err); return end
    local env = setmetatable({}, { __index = _G, __newindex = function(_, k, v)
        if not rel:find("Locale") then report("GLOBAL WRITE", rel .. ": " .. tostring(k)) end
        rawset(_G, k, v)
    end })
    setfenv(chunk, env)
    local ok, e = pcall(chunk, "PeggleRedux", H.ns)
    if not ok then report("LOAD " .. rel, e) end
end
H.allowedGlobals = {}
for line in (SKIP_ADDON and function() end or io.lines(ROOT .. "PeggleRedux.toc")) do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then
        loadAddonFile((line:gsub("\\", "/")))
    end
end

-- Events
function H.fire(event, ...)
    for _, f in ipairs(frames) do
        if f._events[event] and f._scripts.OnEvent then
            local ok, e = pcall(f._scripts.OnEvent, f, event, ...)
            if not ok then report("EVENT " .. event, e) end
        end
    end
end

-- Advances time: timers and every visible frame's OnUpdate.
function H.step(dt)
    H.now = H.now + dt
    local due = {}
    for i = #H.timers, 1, -1 do
        local t = H.timers[i]
        if t.cancelled then table.remove(H.timers, i)
        elseif H.now >= t.at then
            if t.every and (not t.left or t.left > 1) then
                t.at = t.at + t.every
                if t.left then t.left = t.left - 1 end
            else
                table.remove(H.timers, i)
            end
            due[#due + 1] = t
        end
    end
    for _, t in ipairs(due) do
        local ok, e = pcall(t.fn, t)
        if not ok then report("TIMER", e) end
    end
    for i = 1, #frames do
        local f = frames[i]
        local script = f._scripts.OnUpdate
        if script and f:IsVisible() then
            local ok, e = pcall(script, f, dt)
            if not ok then report("ONUPDATE", e) end
        end
    end
end

function H.boot()
    H.fire("ADDON_LOADED", "PeggleRedux")
    H.loggedIn = true
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD", true, false)
end

function H.frames() return frames end
