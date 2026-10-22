local _, ns = ...
local C = ns.C
local L = ns.L
local Art = ns.Art
local Util = ns.Util
local Widgets = ns.Widgets

-- Quick Play tab: level list, thumbnail, personal best and most recent score, the two talent-point
-- banners for the selected level, and Go.

local page

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function setBanner(banner, earned)
    if earned then
        banner:SetText(banner.caption2)
        banner.tex:SetTexCoord(Art.Coords(banner.tex.on))
        banner:SetTextColor(0, 1, 0)
    else
        banner:SetText(banner.caption1)
        banner.tex:SetTexCoord(Art.Coords("bannerSmall3"))
        banner:SetTextColor(1, 1, 0)
    end
end

local function updateDisplay()
    local level = page.levelList:GetLevel()
    local best = ns.Progress.GetBest(level)
    if best == 0 then
        page.beatLevel:Show()
        page.best:Hide()
        page.points:Hide()
        page.mostRecentFrame:Hide()
    else
        page.beatLevel:Hide()
        page.best:Show()
        page.points:Show()
        page.points:SetText(Util.CommaNumber(best))
        page.mostRecentFrame:Show()
        page.mostRecentPoints:SetText(Util.CommaNumber(ns.Progress.GetRecent(level) or best))
    end
    local medal = ns.Progress.GetMedal(level)
    setBanner(page.talent1, medal >= C.MEDAL_BEATEN)
    setBanner(page.talent2, medal >= C.MEDAL_CLEARED)
end

local function scoreBox(anchorTo)
    local frame = Widgets.Panel(page, "popup", 0, 0, 0, 0.5, 1, 1, 1)
    frame:SetSize(256, 60)
    if anchorTo then
        frame:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, -4)
    else
        frame:SetPoint("TOPRIGHT", -34, -236)
    end
    return frame
end

local function banner(artKey, y, caption1, caption2, captionParent)
    local width, height = Art.Size(artKey)
    local tex = page:CreateTexture(nil, "ARTWORK")
    tex:SetSize(width, height)
    tex:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 50, y)
    Art.Apply(tex, artKey)
    tex.on = artKey
    local text = Widgets.Caption(captionParent, caption1, 14, 0, 1, 0)
    text:SetPoint("TOPLEFT", tex, "TOPRIGHT", 0, -8)
    text:SetWidth(220)
    text.caption1, text.caption2, text.tex = caption1, caption2, tex
    return text
end

local function build()
    page = ns.Menu.CreatePage()
    ns.Menu.Title(page, L["QUICK_PLAY"])

    local thumbFrame = Widgets.Panel(page, "popup", 0, 0, 0, 0, 1, 1, 1)
    thumbFrame:SetPoint("TOPRIGHT", -80, -64)
    thumbFrame:SetSize(168, 168)
    local thumbnail = thumbFrame:CreateTexture(nil, "ARTWORK")
    thumbnail:SetPoint("CENTER")
    thumbnail:SetSize(154, 154)
    page.levelImage = thumbnail

    page.levelList = ns.Menu.CreateLevelPicker(page, updateDisplay, { thumbnail = thumbnail })

    local bestFrame = scoreBox()
    page.best = Widgets.Caption(bestFrame, L["PERSONAL_BEST"], 20, 1, 0.82, 0, true)
    page.best:SetPoint("CENTER", 0, 12)
    page.points = Widgets.Caption(bestFrame, "", 20, 1, 1, 1, true)
    page.points:SetPoint("CENTER", 0, -10)
    page.beatLevel = Widgets.Caption(bestFrame, L["NO_SCORE"], 20, 0, 1, 0, true)
    page.beatLevel:SetPoint("CENTER")
    page.beatLevel:SetWidth(220)

    local recentFrame = scoreBox(bestFrame)
    page.mostRecentFrame = recentFrame
    page.mostRecent = Widgets.Caption(recentFrame, L["MOST_RECENT"], 20, 1, 0.82, 0, true)
    page.mostRecent:SetPoint("CENTER", 0, 12)
    page.mostRecentPoints = Widgets.Caption(recentFrame, "", 20, 1, 1, 1, true)
    page.mostRecentPoints:SetPoint("CENTER", 0, -10)

    -- Captions sit on the best-score box, as in the original, so they draw above the page.
    page.talent1 = banner("bannerSmall1", 56, L["BEAT_THIS_LEVEL1"], L["BEAT_THIS_LEVEL3"], bestFrame)
    page.talent2 = banner("bannerSmall2", 10, L["BEAT_THIS_LEVEL2"], L["BEAT_THIS_LEVEL4"], bestFrame)

    local go = Widgets.ArtButton(page, "buttonGo", 64, function()
        ns.Game.Start(page.levelList:GetLevel(), { mode = "quick" })
    end)
    go:SetPoint("TOP", bestFrame, "BOTTOM", 0, -71)
    page.go = go

    page:SetScript("OnShow", updateDisplay)
    ns.Menu.AddTab("quick", 1, "tabQuickPlay", page)
end

ns.RegisterBuilder("QuickPlay", build)

ns.RegisterEnabler("QuickPlay", function()
    events:RegisterMessage("PEGGLE_PROGRESS_CHANGED", function()
        if page:IsVisible() then
            updateDisplay()
        end
    end)
end)
