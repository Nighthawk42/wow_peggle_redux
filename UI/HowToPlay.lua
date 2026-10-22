local _, ns = ...
local L = ns.L
local Art = ns.Art
local Widgets = ns.Widgets

-- How To Play tab: four pages (Basic Gameplay, Duel Mode, Battle Mode, Peggle Loot) picked from a
-- list on the left. Page widths are fixed numbers because anchored frames have no size at build.

local NAV_WIDTH = 180
local CONTENT_WIDTH = ns.Menu.PAGE_WIDTH - 10 - NAV_WIDTH - 10
local TEXT_WIDTH = CONTENT_WIDTH - 20
local PAGES = {
    { "HOW_TO_PLAY2a", "howToPlay5", "HOW_TO_PLAY2b", "howToPlay6" },
    { "HOW_TO_PLAY3a", "howToPlay7", "HOW_TO_PLAY3b" },
    { "HOW_TO_PLAY4a", "howToPlay8", "HOW_TO_PLAY4b" },
}
-- Page 1 shows the four screenshots in the corners.
local CORNERS = {
    { "howToPlay1", "TOPLEFT", 10, -70 },
    { "howToPlay2", "TOPRIGHT", -10, -70 },
    { "howToPlay3", "BOTTOMLEFT", 10, 20 },
    { "howToPlay4", "BOTTOMRIGHT", -10, 20 },
}

local page

local function image(parent, artKey, scale)
    local left, right, top, bottom = Art.Coords(artKey)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(math.floor((right - left) * scale + 0.5), math.floor((bottom - top) * scale + 0.5))
    Art.Apply(tex, artKey)
    return tex
end

local function updateDisplay()
    for i = 1, 4 do
        local selected = page.showID == i
        page.highlights[i]:SetAlpha(selected and 1 or 0)
        page.contents[i]:SetShown(selected)
    end
end

local function rowOnEnter(self)
    if page.showID ~= self:GetID() then
        page.highlights[self:GetID()]:SetAlpha(0.5)
    end
end

local function rowOnLeave(self)
    if page.showID ~= self:GetID() then
        page.highlights[self:GetID()]:SetAlpha(0)
    end
end

local function rowOnMouseUp(self)
    if page.showID ~= self:GetID() then
        page.showID = self:GetID()
        updateDisplay()
    end
end

local function createContent(nav, index)
    local content = CreateFrame("Frame", nil, page)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT")
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    content:Hide()
    local title = Widgets.Caption(content, L["HOW_TO_PLAY" .. index], 40, 0.05, 0.66, 1, true)
    title:SetPoint("TOP", 0, -22)
    page.contents[index] = content
    return content
end

-- Text, picture, text[, picture], chained top to bottom with 10 px gaps.
local function fillTextPage(content, items)
    local previous
    for i, item in ipairs(items) do
        local region
        if i % 2 == 1 then
            region = Widgets.Caption(content, L[item], 11, 1, 1, 1)
            region:SetWidth(TEXT_WIDTH)
        else
            region = image(content, item, 500)
        end
        if previous then
            region:SetPoint("TOP", previous, "BOTTOM", 0, -10)
        else
            region:SetPoint("TOP", 0, -64)
        end
        previous = region
    end
end

local function build()
    page = ns.Menu.CreatePage()
    page.showID = 1
    page.highlights, page.contents = {}, {}

    local nav = Widgets.Panel(page, "popup", 0, 0, 0, 0.5, 1, 0.8, 0.45)
    nav:SetPoint("TOPLEFT", 10, -10)
    nav:SetPoint("BOTTOMLEFT", 10, 10)
    nav:SetWidth(NAV_WIDTH)
    for i = 1, 4 do
        local label = Widgets.Caption(nav, L["HOW_TO_PLAY" .. i], 19, 1, 1, 1, true)
        label:SetPoint("TOPLEFT", 10, -(10 + (i - 1) * 20))
        label:SetSize(NAV_WIDTH - 16, 14)
        label:SetJustifyH("LEFT")
        local row = CreateFrame("Frame", nil, nav)
        row:SetSize(NAV_WIDTH - 16, 20)
        row:SetPoint("TOPLEFT", 10, -6 - (i - 1) * 20)
        row:EnableMouse(true)
        row:SetID(i)
        row:SetScript("OnEnter", rowOnEnter)
        row:SetScript("OnLeave", rowOnLeave)
        row:SetScript("OnMouseUp", rowOnMouseUp)
        page.highlights[i] = ns.Menu.RowHighlight(nav, row)
    end

    local basics = createContent(nav, 1)
    for _, corner in ipairs(CORNERS) do
        image(basics, corner[1], 520):SetPoint(corner[2], corner[3], corner[4])
    end
    for i, items in ipairs(PAGES) do
        fillTextPage(createContent(nav, i + 1), items)
    end

    page:SetScript("OnShow", function()
        page.showID = 1
        updateDisplay()
    end)
    ns.Menu.AddTab("howto", 5, "tabHowToPlay", page)
end

ns.RegisterBuilder("HowToPlay", build)
