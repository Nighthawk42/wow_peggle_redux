local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

-- Settings: one AceConfig table shown in the Options tab (rendered into an AceGUI container while
-- the tab is open) and in the Blizzard Settings panel. Also owns the show/hide keybinding.
-- Every change fires "PEGGLE_SETTING_CHANGED", key so the window and title bar can follow.

local APP_NAME = "PeggleRedux"
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local Options = {}
ns.Options = Options

local toggleButton
local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function notify(key)
    ns.addon:SendMessage("PEGGLE_SETTING_CHANGED", key)
end

-- Override bindings cannot change in combat; retry once combat ends.
local function applyKeybinding()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            events:UnregisterEvent("PLAYER_REGEN_ENABLED")
            applyKeybinding()
        end)
        return
    end
    ClearOverrideBindings(toggleButton)
    local key = ns.db.profile.keybinding
    if key and key ~= "" then
        SetOverrideBindingClick(toggleButton, false, key, toggleButton:GetName())
    end
end

local function applyWindowAlpha()
    ns.addon.window:SetAlpha(ns.db.profile.mouseOnAlpha)
end

local function onProfileChanged()
    applyWindowAlpha()
    applyKeybinding()
    ns.Broker.Refresh()
    notify()
end

local function getSetting(info)
    return ns.db.profile[info[#info]]
end

local function setSetting(info, value)
    local key = info[#info]
    ns.db.profile[key] = value
    notify(key)
end

-- Original option labels end with ":" as captions; group names drop it.
local function heading(key)
    return (L[key]:gsub(":$", ""))
end

local function toggle(label, order)
    return { type = "toggle", name = label, order = order, width = "full" }
end

local function buildOptions()
    return {
        type = "group",
        name = "Peggle Redux",
        childGroups = "tab",
        get = getSetting,
        set = setSetting,
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    mouseOnAlpha = {
                        type = "range",
                        name = L["OPT_TRANS_DEFAULT"],
                        order = 1,
                        width = "full",
                        min = 0.1,
                        max = 1,
                        step = 0.01,
                        isPercent = true,
                        set = function(_, value)
                            ns.db.profile.mouseOnAlpha = value
                            applyWindowAlpha()
                            notify("mouseOnAlpha")
                        end,
                    },
                    mouseOffAlpha = {
                        type = "range",
                        name = L["OPT_TRANS_MOUSE"],
                        order = 2,
                        width = "full",
                        min = 0,
                        max = 1,
                        step = 0.01,
                        isPercent = true,
                    },
                    sound = {
                        type = "select",
                        name = heading("OPT_SOUNDS"),
                        order = 3,
                        values = { normal = L["OPT_SOUNDS_NORMAL"], quiet = L["OPT_SOUNDS_QUIET"], off = L["OPT_SOUNDS_OFF"] },
                        sorting = { "normal", "quiet", "off" },
                    },
                    keybinding = {
                        type = "keybinding",
                        name = "Show/Hide Key",
                        desc = "Key that shows or hides the game window.",
                        order = 4,
                        get = function()
                            return ns.db.profile.keybinding or ""
                        end,
                        set = function(_, value)
                            ns.db.profile.keybinding = value ~= "" and value or nil
                            applyKeybinding()
                        end,
                    },
                    showMinimap = {
                        type = "toggle",
                        name = L["OPT_MINIMAP"],
                        order = 5,
                        width = "full",
                        get = function()
                            return not ns.db.profile.minimap.hide
                        end,
                        set = function(_, value)
                            ns.db.profile.minimap.hide = not value
                            ns.Broker.Refresh()
                        end,
                    },
                    lockWindow = toggle(L["OPT_LOCK"], 6),
                    colorBlindMode = toggle(L["OPT_COLORBLIND"], 7),
                    hideOutdated = toggle(L["OPT_HIDEOUTDATED"], 8),
                    defaultPublish = {
                        type = "select",
                        name = "Brag Channel",
                        desc = "Where scores and duel results go when you brag about them.",
                        order = 9,
                        values = { GUILD = L["_PUBLISH_1"], PARTY = L["_PUBLISH_2"], RAID = L["_PUBLISH_3"] },
                        sorting = { "GUILD", "PARTY", "RAID" },
                    },
                },
            },
            autoOpen = {
                type = "group",
                name = heading("OPT_AUTO_OPEN"),
                order = 2,
                args = {
                    openFlightStart = toggle(L["OPT_AUTO_OPEN1"], 1),
                    openOnDeath = toggle(L["OPT_AUTO_OPEN2"], 2),
                    openLogin = toggle(L["OPT_AUTO_OPEN3"], 3),
                    openDuel = toggle(L["OPT_AUTO_OPEN4"], 4),
                },
            },
            autoClose = {
                type = "group",
                name = heading("OPT_AUTO_CLOSE"),
                order = 3,
                args = {
                    closeFlightEnd = toggle(L["OPT_AUTO_CLOSE1"], 1),
                    closeReadyCheck = toggle(L["OPT_AUTO_CLOSE2"], 2),
                    closeCombat = toggle(L["OPT_AUTO_CLOSE3"], 3),
                    closeDuelComplete = toggle(L["OPT_AUTO_CLOSE4"], 4),
                    closePeggleLoot = toggle(L["OPT_AUTO_CLOSE5"], 5),
                },
            },
            invites = {
                type = "group",
                name = heading("OPT_DUEL_INVITES"),
                order = 4,
                args = {
                    inviteChat = toggle(L["OPT_DUEL_INVITES1"], 1),
                    inviteRaidWarning = toggle(L["OPT_DUEL_INVITES2"], 2),
                    inviteMinimap = toggle(L["OPT_DUEL_INVITES3"], 3),
                    inviteDecline = toggle(L["OPT_DUEL_INVITES4"], 4),
                },
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(ns.db),
        },
    }
end

-- The tab renders the options into an AceGUI container while it is shown.
local function embedOptions(holder)
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Fill")
    container.noAutoHeight = true
    local frame = container.frame
    frame:SetParent(holder)
    frame:SetFrameStrata(holder:GetFrameStrata())
    frame:SetFrameLevel(holder:GetFrameLevel() + 1)
    frame:ClearAllPoints()
    frame:SetAllPoints(holder)
    frame:Show()
    AceConfigDialog:Open(APP_NAME, container)
    return container
end

local function releaseOptions(container)
    container.frame:SetFrameStrata("FULLSCREEN_DIALOG") -- SimpleGroup's own strata, for the next user
    AceGUI:Release(container)
end

local function createPage()
    local page = ns.Menu.CreatePage()
    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", 12, -12)
    holder:SetPoint("BOTTOMRIGHT", -12, 64)

    local about = Widgets.ArtButton(page, "buttonAbout", 44, function()
        ns.About.ShowAbout()
    end, true)
    about:SetPoint("BOTTOM", -90, 14)
    local credits = Widgets.ArtButton(page, "buttonCredits", 44, function()
        ns.About.ShowCredits()
    end, true)
    credits:SetPoint("BOTTOM", 90, 14)

    page:SetScript("OnShow", function(self)
        if not self.container then
            self.container = embedOptions(holder)
        end
    end)
    page:SetScript("OnHide", function(self)
        if self.container then
            releaseOptions(self.container)
            self.container = nil
        end
    end)
    ns.Menu.AddTab("options", 6, "tabOptions", page)
end

-- Shows the window with the Options tab selected.
function Options.Open()
    local window = ns.addon.window
    if not window:IsShown() then
        ns.Broker.ToggleWindow()
    end
    -- Mid-round this is the original's R(false): the menu covers the board, the round stays.
    if not ns.Menu.IsShown() then
        ns.Game.ShowMenu()
    end
    ns.Menu.SelectTab("options")
end

ns.RegisterBuilder("Options", function()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, buildOptions())
    AceConfigDialog:AddToBlizOptions(APP_NAME, "Peggle Redux")

    toggleButton = CreateFrame("Button", "PeggleReduxToggleButton", UIParent)
    toggleButton:Hide()
    toggleButton:RegisterForClicks("AnyUp")
    toggleButton:SetScript("OnClick", function()
        ns.Broker.ToggleWindow()
    end)

    ns.db.RegisterCallback(events, "OnProfileChanged", onProfileChanged)
    ns.db.RegisterCallback(events, "OnProfileCopied", onProfileChanged)
    ns.db.RegisterCallback(events, "OnProfileReset", onProfileChanged)

    createPage()
end)

ns.RegisterEnabler("Options", function()
    applyWindowAlpha()
    applyKeybinding()
end)
