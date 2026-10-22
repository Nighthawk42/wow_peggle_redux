local _, ns = ...
local C = ns.C
local L = ns.L
local Art = ns.Art
local Widgets = ns.Widgets

-- The category screen (original "catagoryScreen"): stone backdrop over the window's content area,
-- the tab strip above it, one page per tab. Also the shared level picker used by several tabs.

local Menu = {}
ns.Menu = Menu

local SCREEN_WIDTH, SCREEN_HEIGHT = C.WINDOW_WIDTH - 18, C.WINDOW_HEIGHT - 88
Menu.PAGE_WIDTH, Menu.PAGE_HEIGHT = SCREEN_WIDTH - 9, SCREEN_HEIGHT - 13
Menu.TITLE_COLOR = { 0.05, 0.66, 1 }
Menu.HIGHLIGHT_TEXTURE = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"

local TABS_FILE = Art.Path("tabs")
local SPARK_FILE = Art.Path("spark")
local SPARK_SIZES = { 13, 10, 7, 4 }
local SPARK_STYLES = {
    { speed = { 2, 2, 2, 2 }, timer = { 0, 0.5, 1, 1.5 } },
    { speed = { 2, 4, 6, 8 }, timer = { 0, 0, 0, 0 } },
    { speed = { 1, 2, 3, 4 }, timer = { 0, 0, 0, 0 } },
}

local screen, tabStrip, outdatedText
local tabs, tabsByKey, pages, pickers = {}, {}, {}, {}
local focusedTab

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

-- Shared page pieces

-- The 40pt blue OVERLOAD title every page carries.
function Menu.Title(parent, text, y)
    local title = Widgets.Caption(parent, text, 40, Menu.TITLE_COLOR[1], Menu.TITLE_COLOR[2], Menu.TITLE_COLOR[3], true)
    title:SetPoint("TOP", 0, y or -22)
    return title
end

-- The blue quest-log glow used for list rows; drawn on owner so it sits under the row text.
function Menu.RowHighlight(owner, row)
    local tex = owner:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(row)
    tex:SetTexture(Menu.HIGHLIGHT_TEXTURE)
    tex:SetVertexColor(0.1, 0.75, 1)
    tex:SetBlendMode("ADD")
    tex:SetAlpha(0)
    return tex
end

-- Page shell: TOPLEFT (5,-9) / BOTTOMRIGHT (-4,4) of the screen, dark panel backdrop.
function Menu.CreatePage(levelOffset)
    local page = Widgets.Panel(screen, "panel", 0, 0, 0, 0.5, 1, 1, 1)
    page:SetPoint("TOPLEFT", 5, -9)
    page:SetPoint("BOTTOMRIGHT", -4, 4)
    page:SetFrameLevel(screen:GetFrameLevel() + (levelOffset or 1))
    page:Hide()
    table.insert(pages, page)
    return page
end

function Menu.GetPages()
    return pages
end

function Menu.GetScreen()
    return screen
end

-- Tabs. State art: 0 normal, 1 hover/focused, 2 pressed; vertical tabs step down a quarter of
-- the atlas per state, the horizontal How To Play tab steps right by its own width.

local function setTabState(tab, state)
    local left, right, top, bottom = tab.left, tab.right, tab.top, tab.bottom
    if tab.horizontal then
        local shift = tab.width / 512 * state
        left, right = left + shift, right + shift
    else
        top, bottom = top + 0.25 * state, bottom + 0.25 * state
    end
    tab.tex:SetTexCoord(left, right, top, bottom)
end

local function focusTab(tab)
    for _, page in ipairs(pages) do
        page:Hide()
    end
    tab.content:Show()
    if focusedTab and focusedTab ~= tab then
        focusedTab.focus = nil
        setTabState(focusedTab, 0)
    end
    focusedTab = tab
    tab.focus = true
    setTabState(tab, 1)
end

local function tabOnMouseDown(self)
    self.down = true
    setTabState(self, 2)
end

local function tabOnMouseUp(self)
    self.down = nil
    if self.hover then
        focusTab(self)
    else
        setTabState(self, self.focus and 1 or 0)
    end
end

local function tabOnEnter(self)
    self.hover = true
    setTabState(self, self.down and 2 or 1)
end

local function tabOnLeave(self)
    self.hover = nil
    setTabState(self, self.focus and 1 or 0)
end

-- Sixteen sparkles in four groups march clockwise around the tab, each group starting on a
-- different edge (the original's e.sparkleFunc over AutoCastShineTemplate).
local function sparksOnUpdate(self, elapsed)
    local timer, speed, sparkles = self.timer, self.speed, self.sparkles
    for i = 1, 4 do
        timer[i] = timer[i] + elapsed
        if timer[i] > speed[i] * 4 then
            timer[i] = 0
        end
    end
    local width, height = self:GetSize()
    for n = 1, 4 do
        local t, s = timer[n], speed[n]
        local phase = t <= s and 0 or t <= s * 2 and 1 or t <= s * 3 and 2 or 3
        local f = (t - s * phase) / s
        local x, y = f * width, f * height
        local a, b, c, d = sparkles[n], sparkles[4 + n], sparkles[8 + n], sparkles[12 + n]
        local top, right, bottom, left
        if phase == 0 then
            top, right, bottom, left = a, c, b, d
        elseif phase == 1 then
            top, right, bottom, left = d, a, c, b
        elseif phase == 2 then
            top, right, bottom, left = b, d, a, c
        else
            top, right, bottom, left = c, b, d, a
        end
        top:SetPoint("CENTER", self, "TOPLEFT", x, 0)
        right:SetPoint("CENTER", self, "TOPRIGHT", 0, -y)
        bottom:SetPoint("CENTER", self, "BOTTOMRIGHT", -x, 0)
        left:SetPoint("CENTER", self, "BOTTOMLEFT", 0, y)
    end
end

local function createSparks(tab, style)
    local config = SPARK_STYLES[style] or SPARK_STYLES[3]
    local sparks = CreateFrame("Frame", nil, tab)
    sparks:SetPoint("TOPLEFT", 6, -6)
    sparks:SetSize(tab.width - 12, tab.height - 12)
    sparks.speed = { unpack(config.speed) }
    sparks.timer = { unpack(config.timer) }
    sparks.sparkles = {}
    for i = 1, 16 do
        local spark = sparks:CreateTexture(nil, "OVERLAY")
        local size = SPARK_SIZES[(i - 1) % 4 + 1]
        -- TODO(in-game): compare sparkle size and brightness with the old AutoCastShine sparkles.
        spark:SetSize(size * 1.5, size * 1.5)
        spark:SetTexture(SPARK_FILE)
        spark:SetBlendMode("ADD")
        spark:SetVertexColor(1, 1, 0)
        sparks.sparkles[i] = spark
    end
    sparks:SetScript("OnUpdate", sparksOnUpdate)
    sparks:Hide()
    return sparks
end

local function layoutTabs()
    table.sort(tabs, function(a, b)
        return a.order < b.order
    end)
    local x = 0
    for _, tab in ipairs(tabs) do
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", tabStrip, "TOPLEFT", x, 0)
        x = x + tab.width
    end
end

-- Original order: quick 1, duel 2, battle 3, talents 4, howto 5, options 6.
function Menu.AddTab(key, order, artKey, contentFrame, sparkStyle)
    local left, right, top, bottom = Art.Coords(artKey)
    local tab = CreateFrame("Frame", nil, tabStrip)
    tab.width = math.floor((right - left) * 512 + 0.5)
    tab.height = math.floor((bottom - top) * 256 + 0.5)
    tab:SetSize(tab.width, tab.height)
    tab.left, tab.right, tab.top, tab.bottom = left, right, top, bottom
    tab.horizontal = top >= 0.75
    tab.key, tab.order, tab.content = key, order, contentFrame
    local tex = tab:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(TABS_FILE)
    tab.tex = tex
    setTabState(tab, 0)
    tab:EnableMouse(true)
    tab:SetScript("OnMouseDown", tabOnMouseDown)
    tab:SetScript("OnMouseUp", tabOnMouseUp)
    tab:SetScript("OnEnter", tabOnEnter)
    tab:SetScript("OnLeave", tabOnLeave)
    if sparkStyle then
        tab.sparks = createSparks(tab, sparkStyle)
    end
    table.insert(tabs, tab)
    tabsByKey[key] = tab
    layoutTabs()
    return tab
end

function Menu.SelectTab(key)
    local tab = tabsByKey[key]
    if tab then
        focusTab(tab)
    end
end

function Menu.GetSelectedTab()
    return focusedTab and focusedTab.key
end

function Menu.SetTabSparkle(key, shown)
    local tab = tabsByKey[key]
    if tab and tab.sparks then
        tab.sparks:SetShown(shown and true or false)
    end
end

function Menu.Show()
    screen:Show()
end

function Menu.Hide()
    screen:Hide()
end

function Menu.IsShown()
    return screen:IsShown()
end

-- Bottom-of-screen notice that a newer version is around.
function Menu.SetOutdated(shown)
    outdatedText:SetShown(shown and true or false)
end

function Menu.GetOutdatedText()
    return outdatedText
end

-- Level picker

-- Inline bannerMenu icon (32x32 atlas): none top-left, beaten top-right, cleared bottom-left.
local MEDAL_ICON = {
    [C.MEDAL_NONE] = "0:16:0:16",
    [C.MEDAL_BEATEN] = "16:32:0:16",
    [C.MEDAL_CLEARED] = "0:16:16:32",
}

local function levelLabel(level)
    local medal = ns.Progress.GetMedal(level)
    return "|T" .. Art.Path("bannerMenu") .. ":16:16:0:0:32:32:" .. (MEDAL_ICON[medal] or MEDAL_ICON[C.MEDAL_NONE]) .. "|t "
        .. string.format(L["_LEVEL_INFO"], level, L["_LEVEL_NAME" .. level])
end

local function setThumbnail(picker)
    if picker.thumbnail then
        picker.thumbnail:SetTexture(Art.Path("bg" .. picker.level .. "_thumb"))
    end
end

local function listRefresh(self)
    for level = 1, C.NUM_LEVELS do
        local medal = ns.Progress.GetMedal(level)
        self.redFlags[level]:SetShown(medal >= C.MEDAL_BEATEN)
        self.blueFlags[level]:SetShown(medal >= C.MEDAL_CLEARED)
        self.highlights[level]:SetAlpha(level == self.level and 1 or 0)
    end
end

local function listSetLevel(self, level)
    self.highlights[self.level]:SetAlpha(0)
    self.level = level
    self.highlights[level]:SetAlpha(1)
    setThumbnail(self)
end

local function getLevel(self)
    return self.level
end

local function rowOnEnter(self)
    local picker = self.picker
    if picker.level ~= self.level then
        picker.highlights[self.level]:SetAlpha(0.5)
    end
end

local function rowOnLeave(self)
    local picker = self.picker
    if picker.level ~= self.level then
        picker.highlights[self.level]:SetAlpha(0)
    end
end

local function rowOnMouseUp(self)
    local picker = self.picker
    if picker.level ~= self.level then
        picker:SetLevel(self.level)
        if picker.onSelect then
            picker.onSelect(self.level)
        end
    end
end

-- The original's t.levelList: fills its parent page, list box on the left with medal flags.
local function createLevelList(parent, onSelect)
    local picker = CreateFrame("Frame", nil, parent)
    picker:SetAllPoints()
    picker.level, picker.onSelect = 1, onSelect
    picker.redFlags, picker.blueFlags, picker.highlights = {}, {}, {}

    local caption = Widgets.Caption(picker, L["SELECT_LEVEL"], 26, 1, 0.82, 0, true)
    caption:SetPoint("TOP", picker, "TOPLEFT", 170, -60)

    local box = Widgets.Panel(picker, "popup", 0, 0, 0, 0.5, 1, 0.8, 0.45)
    box:SetPoint("TOPLEFT", 20, -90)
    box:SetPoint("BOTTOMLEFT", 20, 100)
    box:SetWidth(300)

    for level = 1, C.NUM_LEVELS do
        local y = 10 + (level - 1) * 20
        local number = Widgets.Caption(box, level, 19, 1, 1, 1, true)
        number:SetPoint("TOPLEFT", 10, -y)
        number:SetSize(32, 14)
        number:SetJustifyH("LEFT")
        local name = Widgets.Caption(box, L["_LEVEL_NAME" .. level], 19, 1, 1, 1, true)
        name:SetPoint("TOPLEFT", 42, -y)
        name:SetSize(216, 14)
        name:SetJustifyH("LEFT")

        local red = box:CreateTexture(nil, "OVERLAY")
        red:SetSize(16, 16)
        red:SetPoint("TOPRIGHT", -26, -9 - (level - 1) * 20)
        red:SetTexture(Art.Path("bannerSmallRed"))
        picker.redFlags[level] = red
        local blue = box:CreateTexture(nil, "OVERLAY")
        blue:SetSize(16, 16)
        blue:SetPoint("TOPRIGHT", -10, -9 - (level - 1) * 20)
        blue:SetTexture(Art.Path("bannerSmallBlue"))
        picker.blueFlags[level] = blue

        local row = CreateFrame("Frame", nil, box)
        row:SetSize(284, 20)
        row:SetPoint("TOPLEFT", 10, -6 - (level - 1) * 20)
        row:EnableMouse(true)
        row.picker, row.level = picker, level
        row:SetScript("OnEnter", rowOnEnter)
        row:SetScript("OnLeave", rowOnLeave)
        row:SetScript("OnMouseUp", rowOnMouseUp)
        picker.highlights[level] = Menu.RowHighlight(box, row)
    end

    picker.SetLevel = listSetLevel
    picker.GetLevel = getLevel
    picker.Refresh = listRefresh
    picker:SetScript("OnShow", listRefresh)
    return picker
end

local function dropdownSetLevel(self, level)
    self.level = level
    setThumbnail(self)
    self:GenerateMenu()
end

local function dropdownRefresh(self)
    self:GenerateMenu()
end

-- The original's levels-mode dropdown: one entry per level with its medal icon.
local function createLevelDropdown(parent, onSelect, width)
    local picker
    -- SetupMenu builds the menu once before Widgets.Dropdown returns, while picker is still nil.
    local function isSelected(level)
        return picker ~= nil and picker.level == level
    end
    local function setSelected(level)
        picker:SetLevel(level)
        if onSelect then
            onSelect(level)
        end
    end
    picker = Widgets.Dropdown(parent, width or 240, function(_, rootDescription)
        for level = 1, C.NUM_LEVELS do
            rootDescription:CreateRadio(levelLabel(level), isSelected, setSelected, level)
        end
    end)
    picker.level = 1
    picker.SetLevel = dropdownSetLevel
    picker.GetLevel = getLevel
    picker.Refresh = dropdownRefresh
    return picker
end

-- options (all optional): dropdown = true for the compact dropdown form, width (dropdown only),
-- thumbnail = a texture that follows the selection with the level's bg<n>_thumb art.
function Menu.CreateLevelPicker(parent, onSelect, options)
    options = options or {}
    local picker
    if options.dropdown then
        picker = createLevelDropdown(parent, onSelect, options.width)
    else
        picker = createLevelList(parent, onSelect)
    end
    picker.thumbnail = options.thumbnail
    setThumbnail(picker)
    table.insert(pickers, picker)
    return picker
end

local function refreshPickers()
    for _, picker in ipairs(pickers) do
        if picker:IsVisible() then
            picker:Refresh()
        end
    end
end

-- window.content may be the area at window (8,-80) or the whole window; place the screen at
-- window (8,-80) either way.
local function anchorScreen(content)
    local offsetX, offsetY = 0, 0
    -- TODO(in-game): check the screen lines up with the window border at default size and after resizing.
    if content:GetWidth() >= C.WINDOW_WIDTH - 1 then
        offsetX, offsetY = 8, -80
    end
    screen:SetPoint("TOPLEFT", content, "TOPLEFT", offsetX, offsetY)
end

ns.RegisterBuilder("Menu", function()
    local window = ns.addon.window
    local content = window.content or window
    screen = Widgets.Panel(content, "popup", 0.43, 0.43, 0.43, 1, 1, 0.8, 0.45)
    screen:SetSize(SCREEN_WIDTH, SCREEN_HEIGHT)
    anchorScreen(content)
    screen:SetFrameLevel(window:GetFrameLevel() + 1)
    screen:Hide()
    Menu.screen = screen

    local holder = CreateFrame("Frame", nil, screen)
    holder:SetSize(20, 20)
    holder:SetPoint("BOTTOM")
    holder:SetFrameLevel(screen:GetFrameLevel() + 4)
    outdatedText = Widgets.Caption(holder, L["OUT_OF_DATE"], 11, 1, 1, 1)
    outdatedText:SetPoint("BOTTOM")
    outdatedText:Hide()

    tabStrip = CreateFrame("Frame", nil, screen)
    tabStrip:SetSize(653, 64)
    tabStrip:SetPoint("TOPLEFT", -4, 54)
    tabStrip:SetFrameLevel(window:GetFrameLevel() + 2)
end)

ns.RegisterEnabler("Menu", function()
    if not focusedTab and tabs[1] then
        focusTab(tabs[1])
    end
    events:RegisterMessage("PEGGLE_PROGRESS_CHANGED", refreshPickers)
end)
