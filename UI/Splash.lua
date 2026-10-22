local _, ns = ...
local L = ns.L
local Art = ns.Art
local Widgets = ns.Widgets

-- Splash over the category screen at first open: the Peggle bringer for 3 s, then a 1 s fade.
-- It waits for Start (the legal notice's Okay) and blocks clicks until it is gone. Being a child
-- of the window, it only runs while the window is shown.

local Splash = {}
ns.Splash = Splash

local splash

local function setPagesAlpha(alpha)
    for _, page in ipairs(ns.Menu.GetPages()) do
        page:SetAlpha(alpha)
    end
    ns.Menu.GetOutdatedText():SetAlpha(alpha)
end

local function onUpdate(self, elapsed)
    if not self.elapsed then
        return
    end
    self.elapsed = self.elapsed + math.min(elapsed, 0.2)
    if self.elapsed >= 4 then
        self:Hide()
        self:SetScript("OnUpdate", nil)
        splash = nil
        return
    end
    if self.elapsed > 3 then
        if not self.pagesShown then
            self.pagesShown = true
            setPagesAlpha(1)
        end
        self:SetAlpha(math.max(1 - (self.elapsed - 3), 0))
    end
end

-- Starts the countdown; until then the splash holds.
function Splash.Start()
    if splash then
        splash.elapsed = 0
    end
end

function Splash.IsActive()
    return splash ~= nil
end

ns.RegisterBuilder("Splash", function()
    splash = CreateFrame("Frame", nil, ns.Menu.GetScreen())
    splash:SetPoint("TOPLEFT", 5, -9)
    splash:SetPoint("BOTTOMRIGHT", -4, 4)
    splash:SetFrameLevel(splash:GetFrameLevel() + 10)
    splash:EnableMouse(true)
    splash:Hide()
    splash:SetScript("OnShow", function()
        setPagesAlpha(0)
    end)
    splash:SetScript("OnHide", function()
        setPagesAlpha(1)
    end)
    splash:SetScript("OnUpdate", onUpdate)

    local legal = Widgets.Caption(splash, L["LEGAL1"], 12, 1, 1, 1)
    legal:SetPoint("BOTTOM", splash, "BOTTOM", 0, 20)

    local background = splash:CreateTexture(nil, "ARTWORK")
    background:SetSize(640, 640)
    background:SetPoint("CENTER", 1, 0)
    background:SetTexture(Art.Path("splashBackground"))

    local left, right, top, bottom = Art.Coords("splashBringer")
    local foreground = splash:CreateTexture(nil, "OVERLAY")
    foreground:SetSize(math.floor((right - left) * 520 + 0.5), math.floor((bottom - top) * 520 + 0.5))
    foreground:SetPoint("CENTER")
    Art.Apply(foreground, "splashBringer")
end)

ns.RegisterEnabler("Splash", function()
    splash:Show()
end)
