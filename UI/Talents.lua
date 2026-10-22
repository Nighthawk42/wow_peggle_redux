local _, ns = ...
local L = ns.L
local Art = ns.Art
local Widgets = ns.Widgets
local Progress = ns.Progress

-- Talents tab: the eleven-node tree on the left, the description box on the right, points left
-- and Reset. Nodes are drawn here (icon, slot border, rank badge, branch and arrow) because the
-- old TalentButtonTemplate is gone from Retail.

local POINTS_PER_TIER = ns.TALENT_POINTS_PER_TIER
local BRANCH_FILE = "Interface\\TalentFrame\\UI-TalentBranches"
local ARROW_FILE = "Interface\\TalentFrame\\UI-TalentArrows"
-- TALENT_BRANCH_TEXTURECOORDS.down and TALENT_ARROW_TEXTURECOORDS.top, lit and unlit.
local BRANCH_LIT, BRANCH_DIM = { 0, 0.125, 0, 0.484375 }, { 0, 0.125, 0.515625, 1 }
local ARROW_LIT, ARROW_DIM = { 0, 0.5, 0, 0.5 }, { 0, 0.5, 0.5, 1 }

-- Tree columns and rows from the original layout.
local COL_2 = { 91, 171 }
local COL_3 = { 51, 131, 211 }
local ROWS = { { 1, 2 }, { 3, 4, 5 }, { 6, 7 }, { 8, 9 }, { 10, 11 } }

local page, info
local nodes = {}

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function talentName(id)
    return L["_TALENT" .. id .. "_NAME"]
end

local function talentDesc(id, rank)
    return string.format(L["_TALENT" .. id .. "_DESC"], ns.Talents[id].value(rank))
end

local function refresh()
    local spent, available = Progress.PointsSpent(), Progress.PointsAvailable()
    page.pointsLeft:SetText(L["_POINTS_LEFT"] .. ": |cFFFFFFFF" .. available)
    ns.Menu.SetTabSparkle("talents", available > 0)
    for id, node in ipairs(nodes) do
        local talent = ns.Talents[id]
        local rank = Progress.TalentRank(id)
        local r, g, b
        if rank == talent.maxRank then
            r, g, b = 1, 0.82, 0
        elseif spent >= talent.tier * POINTS_PER_TIER then
            r, g, b = 0, 1, 0
        else
            r, g, b = 0.5, 0.5, 0.5
        end
        if talent.requires then
            local prereq = nodes[talent.requires]
            local open = Progress.TalentRank(talent.requires) >= POINTS_PER_TIER
                and ((spent >= talent.tier * POINTS_PER_TIER and available > 0) or rank > 0)
            if open then
                prereq.branch:SetTexCoord(unpack(BRANCH_LIT))
                node.arrow:SetTexCoord(unpack(ARROW_LIT))
            else
                r, g, b = 0.5, 0.5, 0.5
                prereq.branch:SetTexCoord(unpack(BRANCH_DIM))
                node.arrow:SetTexCoord(unpack(ARROW_DIM))
            end
        end
        if available == 0 and rank == 0 then
            r, g, b = 0.5, 0.5, 0.5
        end
        node.rank:SetText(rank)
        node.border:SetVertexColor(r, g, b)
        local dimmed = r == 0.5
        node.icon:SetDesaturated(dimmed)
        node.rankBorder:SetShown(not dimmed)
        node.rank:SetShown(not dimmed)
        node.rank:SetTextColor(r, g, b)
    end
end

local function nodeOnEnter(self)
    local id = self:GetID()
    local talent = ns.Talents[id]
    local rank = Progress.TalentRank(id)
    info.mouseOver:Hide()
    info.name:SetText(talentName(id))
    info.rank:SetFormattedText(L["_RANK"], rank, talent.maxRank)
    info.icon:SetTexture(Art.Path(talent.icon))
    info.icon:Show()

    local requirements = ""
    if talent.requires and Progress.TalentRank(talent.requires) < POINTS_PER_TIER then
        requirements = requirements .. string.format(L["_REQUIRES_5"], talentName(talent.requires))
    end
    if Progress.PointsSpent() < talent.tier * POINTS_PER_TIER then
        requirements = requirements .. string.format(L["_REQUIRES_X"], talent.tier * POINTS_PER_TIER)
    end
    local nextRank = " "
    if rank > 0 and rank < talent.maxRank then
        nextRank = "|cFFFFFFFF" .. L["_TALENT_NEXT_RANK"] .. "|r\n" .. talentDesc(id, rank + 1)
    end
    info.desc:SetText(requirements .. "|r" .. talentDesc(id, math.max(rank, 1)) .. "\n\n" .. nextRank)
    info.name:Show()
    info.rank:Show()
    info.desc:Show()
    info.learn:SetShown(Progress.PointsAvailable() > 0 and not Progress.LearnBlocker(id))
end

local function nodeOnLeave()
    info.mouseOver:Show()
    info.name:Hide()
    info.rank:Hide()
    info.desc:Hide()
    info.learn:Hide()
    info.icon:Hide()
end

local function nodeOnClick(self)
    if Progress.LearnTalent(self:GetID()) then
        nodeOnEnter(self)
    end
end

-- 37x37 node as TalentButtonTemplate drew it: icon, 64x64 slot ring, rank badge at the corner.
local function createNode(tree, id, x, y)
    local node = CreateFrame("Button", nil, tree)
    node:SetSize(37, 37)
    node:SetPoint("TOPLEFT", x, y)
    node:SetID(id)
    node:RegisterForClicks("LeftButtonUp")

    local icon = node:CreateTexture(nil, "BORDER")
    icon:SetAllPoints()
    icon:SetTexture(Art.Path(ns.Talents[id].icon))
    node.icon = icon

    local border = node:CreateTexture(nil, "BACKGROUND")
    border:SetSize(64, 64)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
    node.border = border

    -- TODO(in-game): check the branch and arrow art lines up between rows 4 and 5 on Retail and Classic Era.
    -- TalentFrame-RankBorder is missing from Retail, so the badge is a dark plate instead.
    local rankBorder = node:CreateTexture(nil, "OVERLAY")
    rankBorder:SetSize(18, 14)
    rankBorder:SetPoint("CENTER", node, "BOTTOMRIGHT", 0, 0)
    rankBorder:SetColorTexture(0, 0, 0, 0.8)
    node.rankBorder = rankBorder
    local rank = node:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetPoint("CENTER", rankBorder, "CENTER", 0, 0)
    rank:SetDrawLayer("OVERLAY", 1)
    node.rank = rank

    node:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    node:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    node:SetScript("OnClick", nodeOnClick)
    node:SetScript("OnEnter", nodeOnEnter)
    node:SetScript("OnLeave", nodeOnLeave)
    return node
end

local function buildTree()
    local tree = Widgets.Panel(page, "panel", 0.43, 0.43, 0.43, 0, 1, 1, 1)
    tree:SetPoint("TOPRIGHT", page, "TOPLEFT", 8, 0)
    tree:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", 8, 0)
    tree:SetWidth(300)
    local background = tree:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetTexture(Art.Path("bg7"))
    background:SetPoint("TOPLEFT", 4, -4)
    background:SetSize(294, ns.Menu.PAGE_HEIGHT - 12)
    background:SetTexCoord(0.3, 0.8, 0.2, 0.9)
    background:SetVertexColor(0.3, 0.3, 0.3)

    local y = -81
    for _, row in ipairs(ROWS) do
        local columns = #row == 3 and COL_3 or COL_2
        for i, id in ipairs(row) do
            nodes[id] = createNode(tree, id, columns[i], y)
        end
        y = y - 61
    end
    for id, talent in ipairs(ns.Talents) do
        if talent.requires then
            local prereq = nodes[talent.requires]
            local branch = prereq:CreateTexture(nil, "BACKGROUND")
            branch:SetSize(32, 32)
            branch:SetTexture(BRANCH_FILE)
            branch:SetPoint("TOPLEFT", prereq, "BOTTOMLEFT", 2, -1)
            branch:SetTexCoord(unpack(BRANCH_DIM))
            prereq.branch = branch
            local arrow = nodes[id]:CreateTexture(nil, "OVERLAY")
            arrow:SetSize(32, 32)
            arrow:SetTexture(ARROW_FILE)
            arrow:SetPoint("TOPLEFT", 2, 17)
            arrow:SetTexCoord(unpack(ARROW_DIM))
            nodes[id].arrow = arrow
        end
    end
end

local function infoCaption(text, size, r, g, b, gameFont, flags)
    local caption = Widgets.Caption(info, text, size, r, g, b, gameFont, flags)
    caption:Hide()
    return caption
end

local function build()
    page = ns.Menu.CreatePage()
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", 297, -9)
    page:SetPoint("BOTTOMRIGHT", -4, 4)
    local width = ns.Menu.PAGE_WIDTH - 292

    ns.Menu.Title(page, L["TALENTS"], -20)
    local desc = Widgets.Caption(page, L["TALENTS_DESC"], 18, 1, 0.55, 0)
    desc:SetPoint("TOP", 0, -62)
    desc:SetWidth(width - 20)

    info = Widgets.Panel(page, "panel", 0, 0, 0, 0.5, 1, 1, 1)
    info:SetPoint("TOP", 0, -114)
    info:SetSize(width - 40, 230)
    info.icon = info:CreateTexture(nil, "ARTWORK")
    info.icon:SetSize(64, 64)
    info.icon:SetPoint("TOPLEFT", -10, 10)
    info.icon:Hide()
    info.name = infoCaption("", 22, 1, 1, 1, true)
    info.name:SetPoint("TOP", 22, -10)
    info.name:SetWidth(width - 60)
    info.rank = infoCaption("", 16, 1, 1, 1, false, "")
    info.rank:SetPoint("TOP", 22, -30)
    info.rank:SetWidth(width - 60)
    info.desc = infoCaption("", 14, 1, 0.82, 0, false, "")
    info.desc:SetPoint("TOP", 0, -54)
    info.desc:SetJustifyH("LEFT")
    info.desc:SetWidth(width - 80)
    info.learn = infoCaption(L["_TALENT_LEARN"], 14, 0, 1, 0, false, "")
    info.learn:SetPoint("BOTTOM", 0, 16)
    info.learn:SetJustifyH("LEFT")
    info.learn:SetWidth(width - 80)
    info.mouseOver = Widgets.Caption(info, L["MOUSE_OVER"], 14, 0, 1, 0, false, "")
    info.mouseOver:SetPoint("CENTER")
    info.mouseOver:SetWidth(width - 160)

    page.pointsLeft = Widgets.Caption(page, "", 18, 1, 0.82, 0)
    page.pointsLeft:SetPoint("TOP", 0, -350)
    page.pointsLeft:SetWidth(width - 20)

    local reset = Widgets.ArtButton(page, "buttonResetTalents", 50, function()
        Progress.ResetTalents()
    end, true)
    reset:SetPoint("BOTTOM", 0, 18)

    buildTree()
    page:SetScript("OnShow", refresh)
    ns.Menu.AddTab("talents", 4, "tabTalents", page, 3)
end

ns.RegisterBuilder("Talents", build)

ns.RegisterEnabler("Talents", function()
    events:RegisterMessage("PEGGLE_TALENTS_CHANGED", refresh)
    events:RegisterMessage("PEGGLE_PROGRESS_CHANGED", refresh)
    refresh()
end)
