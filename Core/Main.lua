local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

-- Login glue: the category screen, the one-time PopCap notice (its Okay starts the splash), and the
-- newer-version notice (bottom line on the menu plus a popup, once per session).

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local outdatedPopup

-- Stone popup with the window border, a text block and an Okay button under it.
local function notice(width, textWidth, textTop, text, onOkay)
    local popup = Widgets.Panel(ns.addon.window, "window", 0.43, 0.43, 0.43, 1, 1, 1, 1)
    popup:SetWidth(width)
    popup:SetToplevel(true)
    popup:SetFrameStrata("HIGH")
    popup:SetPoint("CENTER")
    popup:EnableMouse(true)
    local body = popup:CreateFontString(nil, "OVERLAY")
    body:SetFont(STANDARD_TEXT_FONT, 12)
    body:SetShadowColor(0, 0, 0)
    body:SetShadowOffset(1, -1)
    body:SetTextColor(1, 1, 1)
    body:SetPoint("TOP", 0, textTop)
    body:SetWidth(textWidth)
    body:SetText(text)
    local okay = Widgets.ArtButton(popup, "buttonOkay", 40, onOkay)
    popup.body, popup.okay = body, okay
    return popup
end

local function showLegal()
    local window = ns.addon.window
    local legal
    legal = notice(320, 288, -78, L["LEGAL2"], function()
        legal:Hide()
        ns.db.global.legalDisplayed = true
        ns.Splash.Start()
    end)
    local title = Widgets.Caption(legal, "Peggle", 25, 1, 0.4, 0, true, "")
    title:SetShadowColor(0, 0, 0)
    title:SetShadowOffset(1, -1)
    title:SetPoint("TOP", 0, -38)
    title:SetWidth(288)
    legal.okay:SetPoint("TOP", legal.body, "BOTTOM", 0, -16)
    legal:SetHeight(legal.body:GetStringHeight() + 40 + 120)
    window:Show()
end

local function showOutdated()
    if not outdatedPopup then
        outdatedPopup = notice(290, 270, -32, L["OUT_OF_DATE"], function()
            outdatedPopup:Hide()
        end)
        outdatedPopup.okay:SetPoint("TOP", outdatedPopup.body, "BOTTOM", 0, -12)
        outdatedPopup:SetHeight(outdatedPopup.body:GetStringHeight() + 40 + 64)
    end
    outdatedPopup:Show()
end

function events:PEGGLE_NEWER_VERSION()
    ns.Menu.SetOutdated(true)
    if not self.outdatedShown then
        self.outdatedShown = true
        showOutdated()
    end
end

ns.RegisterEnabler("Main", function()
    local global = ns.db.global
    if not ns.Game.IsInProgress() then
        ns.Game.ShowMenu()
    end
    local seen = global.newerVersionSeen
    if seen and seen == ns.addon.version then
        global.newerVersionSeen = nil
    elseif seen then
        ns.Menu.SetOutdated(true)
    end
    events:RegisterMessage("PEGGLE_NEWER_VERSION")

    if global.legalDisplayed then
        ns.Splash.Start()
    else
        showLegal()
    end
end)
