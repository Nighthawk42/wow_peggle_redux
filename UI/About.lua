local _, ns = ...
local L = ns.L
local Art = ns.Art
local Widgets = ns.Widgets

-- About and Credits panels, opened from the Options tab; Okay returns to Options.

local About = {}
ns.About = About

local WIDTH = ns.Menu.PAGE_WIDTH
local GOLD = { 1, 0.85, 0.1 }

local aboutPanel, creditsPanel

local function backToOptions()
    ns.Menu.SelectTab("options")
end

local function okayButton(panel, y)
    local button = Widgets.ArtButton(panel, "buttonOkay", 40, backToOptions)
    button:SetPoint("BOTTOM", 0, y)
end

local function caption(panel, text, size, r, g, b, x, y)
    local fontString = Widgets.Caption(panel, text, size, r, g, b)
    if x then
        fontString:SetPoint("TOPLEFT", x, -y)
        fontString:SetJustifyH("LEFT")
    end
    return fontString
end

local function buildAbout()
    local panel = ns.Menu.CreatePage(2)
    ns.Menu.Title(panel, L["ABOUT"], -20)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    local width, height = Art.Size("popCap")
    logo:SetSize(math.floor(width * 1.5 + 0.5), math.floor(height * 1.5 + 0.5))
    Art.Apply(logo, "popCap")
    logo:SetPoint("BOTTOM", 0, 114)

    local text = caption(panel, L["ABOUT_TEXT1"], 14, GOLD[1], GOLD[2], GOLD[3])
    text:SetPoint("TOP", 0, -60)
    text:SetWidth(WIDTH - 60)
    caption(panel, L["ABOUT_TEXT4"] .. ns.addon.version, 14, 1, 1, 1):SetPoint("TOPRIGHT", -20, -20)
    text = caption(panel, L["ABOUT_TEXT3"], 9, 1, 1, 0)
    text:SetPoint("BOTTOM", 0, 10)
    text:SetWidth(WIDTH - 60)
    text = caption(panel, L["ABOUT_TEXT2"], 15, GOLD[1], GOLD[2], GOLD[3])
    text:SetPoint("BOTTOM", 0, 80)
    text:SetWidth(WIDTH - 60)
    okayButton(panel, 30)
    return panel
end

-- Credit headings (16pt yellow) with their names (14pt gold) indented below.
local function creditBlock(panel, key, x, y)
    caption(panel, L[key], 16, 1, 1, 0, x, y)
    caption(panel, L[key .. "a"], 14, GOLD[1], GOLD[2], GOLD[3], x + 20, y + 20)
end

local function buildCredits()
    local panel = ns.Menu.CreatePage(2)
    ns.Menu.Title(panel, L["CREDITS"], -20)

    -- Two Peggle bringers turned on their side, the right one mirrored.
    local left, right, top, bottom = Art.Coords("peggleBringer")
    local width = math.floor((bottom - top) * 384 + 0.5)
    local height = math.floor((right - left) * 384 + 0.5)
    for side = -1, 1, 2 do
        local tex = panel:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOP", side * (WIDTH / 4 + 20), -10)
        tex:SetSize(width, height)
        tex:SetTexture(Art.Path("board1"))
        if side < 0 then
            tex:SetTexCoord(right, top, left, top, right, bottom, left, bottom)
        else
            tex:SetTexCoord(right, bottom, left, bottom, right, top, left, top)
        end
    end

    local y = 60
    for i, step in ipairs({ 40, 40, 55, 40, 55, 0 }) do
        creditBlock(panel, "CREDITS" .. i, 20, y)
        y = y + step
    end
    creditBlock(panel, "CREDITS7", WIDTH / 2 + 10, 60)
    y = 60 + 25 + 15 * 6 + 20
    caption(panel, L["CREDITS8"], 16, 1, 1, 0, WIDTH / 2 + 10, y)
    caption(panel, L["CREDITS8a"], 12, GOLD[1], GOLD[2], GOLD[3], WIDTH / 3, y + 16)
    caption(panel, L["CREDITS8b"], 12, GOLD[1], GOLD[2], GOLD[3], WIDTH / 3 + 200, y + 16)
    okayButton(panel, 14)
    return panel
end

function About.ShowAbout()
    for _, page in ipairs(ns.Menu.GetPages()) do
        page:Hide()
    end
    aboutPanel:Show()
end

function About.ShowCredits()
    for _, page in ipairs(ns.Menu.GetPages()) do
        page:Hide()
    end
    creditsPanel:Show()
end

ns.RegisterBuilder("About", function()
    aboutPanel = buildAbout()
    creditsPanel = buildCredits()
end)
