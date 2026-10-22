local _, ns = ...
local L = ns.L
local Art = ns.Art
local Widgets = ns.Widgets

-- "Exhibit A": a joke achievement for finishing a real WoW duel while a Peggle duel is running.
-- The original borrowed AchievementAlertFrameTemplate; this is a look-alike toast that works on
-- every client, including those without achievements. /peggle achievement replays it once earned.

local Achievement = {}
ns.Achievement = Achievement

local FADE_IN, HOLD, FADE_OUT = 0.2, 5, 1.5

local toast
local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function onUpdate(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    local t = self.elapsed
    if t < FADE_IN then
        self:SetAlpha(t / FADE_IN)
    elseif t < FADE_IN + HOLD then
        self:SetAlpha(1)
    elseif t < FADE_IN + HOLD + FADE_OUT then
        self:SetAlpha(1 - (t - FADE_IN - HOLD) / FADE_OUT)
    else
        self:Hide()
    end
end

function Achievement.Show()
    toast.elapsed = 0
    toast:SetAlpha(0)
    toast:Show()
end

function Achievement.IsEarned()
    return ns.db.global.exhibitA and true or false
end

local function build()
    toast = Widgets.Panel(UIParent, "popup", 0.7, 0.7, 0.7, 1, 1, 0.8, 0.45)
    toast:SetSize(526, 160)
    toast:SetPoint("BOTTOM", 0, 128)
    toast:SetFrameStrata("DIALOG")
    toast:EnableMouse(false)
    toast.elapsed = 0
    toast:Hide()
    toast:SetScript("OnUpdate", onUpdate)

    local unlocked = Widgets.Caption(toast, L["_ACHIEVEMENT_EARNED"], 14, 1, 0.82, 0, false, "")
    unlocked:SetShadowOffset(1, -1)
    unlocked:SetPoint("TOP", 0, -30)

    -- The banner art (title and description) is stored on its side in the atlas.
    local width, height = Art.Size("exhibitA")
    local banner = toast:CreateTexture(nil, "ARTWORK")
    banner:SetSize(height, width)
    Art.Apply(banner, "exhibitA", true)
    banner:SetPoint("TOP", 0, -50)

    local icon = toast:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("LEFT", 24, -8)
    Art.Apply(icon, "exhibitA2")

    -- TODO(in-game): check the toast layout: header above the banner art, icon and points clear of the border.
    local points = Widgets.Caption(toast, "10", 26, 1, 0.82, 0, true)
    points:SetPoint("RIGHT", -34, -8)
end

local function onDuelFinished()
    if ns.Duel and ns.Duel.IsActive and ns.Duel.IsActive() and not ns.db.global.exhibitA then
        ns.db.global.exhibitA = true
        Achievement.Show()
    end
end

ns.RegisterBuilder("Achievement", build)

ns.RegisterEnabler("Achievement", function()
    if not ns.db.global.exhibitA then
        events:RegisterEvent("DUEL_FINISHED", function()
            onDuelFinished()
            if ns.db.global.exhibitA then
                events:UnregisterEvent("DUEL_FINISHED")
            end
        end)
    end
end)
