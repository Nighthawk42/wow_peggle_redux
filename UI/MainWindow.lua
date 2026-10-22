local _, ns = ...
local Peggle = ns.addon
local C = ns.C
local Art = ns.Art

-- The game window: title bar with close, sound and menu buttons, the board's art frame and
-- score captions, the resize grip and the mouse-off fade.

local WIDTH, HEIGHT = C.WINDOW_WIDTH, C.WINDOW_HEIGHT
local ART = C.ART_PATH

local MainWindow = {}
ns.MainWindow = MainWindow

-- Width of the tiled title texture in texture repeats.
local function tileCoord(width)
    return math.fmod(width, 128) / 128 + math.floor(width / 128)
end

local function onSizeChanged(window)
    local scale = window:GetWidth() / WIDTH
    for _, frame in ipairs(window.scaledFrames) do
        frame:SetScale(scale)
    end
    window:SetHeight(HEIGHT * scale)
    window.coverUp:SetHeight(26.5 * scale)
    local cover = window.topCover
    cover:SetWidth(window:GetWidth() - 92)
    cover:SetTexCoord(0, tileCoord(cover:GetWidth()), 0, 1)
end

-- Sound button: mutes, or restores the volume setting that was active before muting.
local function soundButtonOnClick(button)
    local profile = ns.db.profile
    if profile.sound == "off" then
        profile.sound = button.previous or "normal"
    else
        button.previous = profile.sound
        profile.sound = "off"
    end
    MainWindow.RefreshSoundButton()
    Peggle:SendMessage("PEGGLE_SETTING_CHANGED")
end

function MainWindow.RefreshSoundButton()
    local button = Peggle.window.soundButton
    local left, right, top, bottom = Art.Coords("buttonSound")
    local shift = ns.db.profile.sound == "off" and 20 / 256 or 0
    button.background:SetTexCoord(left + shift, right + shift, top, bottom)
end

local function menuButtonOnClick()
    if ns.Menu.IsShown() and ns.Game.IsInProgress() then
        ns.Game.ShowBoard()
    elseif ns.Game.IsInProgress() then
        ns.GameMenu.Toggle()
    else
        ns.Game.ShowMenu()
    end
end

function MainWindow.SetMenuButtonEnabled(enabled)
    Peggle.window.menuButton:SetArtEnabled(enabled)
end

-- Fades the window to the mouse-off alpha half a second after the cursor leaves it; an overlay
-- then catches the cursor's return.
local function setupFade(window)
    local sentry = CreateFrame("Frame", nil, window)
    sentry:SetPoint("TOPLEFT", 0, 30)
    sentry:SetPoint("BOTTOMRIGHT")
    sentry:EnableMouse(false)
    sentry:SetFrameLevel(window:GetFrameLevel() + 80)
    sentry.elapsed = 0
    sentry.mouseOver = true
    sentry:SetScript("OnUpdate", function(self, elapsed)
        if not self.mouseOver and not self.fading then
            return
        end
        local profile = ns.db.profile
        self.elapsed = self.elapsed + elapsed
        if self.fading and self.elapsed < 0.5 then
            local on, off = profile.mouseOnAlpha, profile.mouseOffAlpha
            window:SetAlpha(on - (on - off) * (self.elapsed / 0.5))
        end
        if self.elapsed > 0.5 then
            self.elapsed = 0
            if self.fading then
                window:SetAlpha(profile.mouseOffAlpha)
                self.fading = nil
            elseif not window:IsMouseOver() and not window.resizing then
                self:EnableMouse(true)
                self.mouseOver = nil
                self.fading = true
            end
        end
    end)
    sentry:SetScript("OnEnter", function(self)
        window:SetAlpha(ns.db.profile.mouseOnAlpha)
        self.mouseOver = true
        self.fading = nil
        self.elapsed = 0
        self:EnableMouse(false)
    end)
    window.mouseOverScreen = sentry
end

-- Shows the window at full alpha, or faded if the cursor isn't over it.
function MainWindow.ShowFaded()
    local window = Peggle.window
    local sentry = window.mouseOverScreen
    window:SetAlpha(ns.db.profile.mouseOnAlpha)
    if window:IsMouseOver() then
        sentry:EnableMouse(false)
        sentry.mouseOver = true
    else
        sentry:EnableMouse(true)
        sentry.mouseOver = nil
    end
    sentry.fading = nil
    window:Show()
end

function MainWindow.ResetPosition()
    local window = Peggle.window
    window:ClearAllPoints()
    window:SetPoint("CENTER")
    window:SetSize(WIDTH, HEIGHT)
end

local function createBorder(artBorder, key, width, height)
    local texture = artBorder:CreateTexture(nil, "ARTWORK")
    texture:SetSize(width, height)
    Art.Apply(texture, key)
    return texture
end

local function scoreCaption(parent, text, point, x)
    local caption = ns.Widgets.Caption(parent, text, 15, 0.55, 0.85, 1, true)
    caption:SetPoint(point, parent, "TOPLEFT", x, -47)
    return caption
end

ns.RegisterBuilder("MainWindow", function()
    local window = CreateFrame("Frame", "PeggleReduxWindow", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:EnableMouse(true)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetHitRectInsets(0, 0, -14, 0)
    window:Hide()
    window.scaledFrames = {}
    Peggle.window = window
    tinsert(UISpecialFrames, "PeggleReduxWindow")
    ns.Util.SetBackdrop(window, "window", 0.7, 0.7, 0.7, 1)

    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        if not ns.db.profile.lockWindow then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local coverUp = window:CreateTexture(nil, "ARTWORK")
    coverUp:SetPoint("TOPLEFT", 2, 0)
    coverUp:SetPoint("TOPRIGHT", -8, 0)
    coverUp:SetHeight(26)
    coverUp:SetColorTexture(0, 0, 0)
    window.coverUp = coverUp

    local titleBar = CreateFrame("Frame", nil, window)
    titleBar:SetHeight(128)
    titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 32, 32)
    titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 32)
    local coverLeft = titleBar:CreateTexture(nil, "OVERLAY")
    coverLeft:SetPoint("TOPRIGHT", titleBar, "TOPLEFT", 16, 0)
    coverLeft:SetSize(64, 64)
    coverLeft:SetTexture(ART .. "windowCoverLeft")
    local coverRight = titleBar:CreateTexture(nil, "OVERLAY")
    coverRight:SetPoint("TOPLEFT", titleBar, "TOPRIGHT", -44, 0)
    coverRight:SetSize(64, 64)
    coverRight:SetTexture(ART .. "windowCoverRight")
    local topCover = titleBar:CreateTexture(nil, "ARTWORK")
    topCover:SetPoint("TOPLEFT", 16, 0)
    topCover:SetSize(WIDTH - 92, 64)
    topCover:SetTexture(ART .. "windowCoverCenter", "REPEAT", "CLAMP")
    topCover:SetTexCoord(0, tileCoord(WIDTH - 92), 0, 1)
    window.topCover = topCover

    local closeButton = ns.Widgets.ArtButton(titleBar, "buttonClose", 20, function()
        window:Hide()
    end)
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", 2, 9)
    closeButton.highlight:SetSize(12, 12)

    local soundButton = ns.Widgets.ArtButton(titleBar, "buttonSound", 20, soundButtonOnClick)
    soundButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT")
    soundButton.highlight:SetSize(12, 12)
    window.soundButton = soundButton

    local menuButton = ns.Widgets.ArtButton(titleBar, "buttonMenu", 20, menuButtonOnClick)
    menuButton:SetPoint("TOPRIGHT", soundButton, "TOPLEFT")
    menuButton.highlight:SetSize(menuButton:GetWidth() - 6, menuButton:GetHeight() - 8)
    window.menuButton = menuButton

    -- Frames below are WIDTH x HEIGHT in their own coordinates and scale with the window.
    local content = CreateFrame("Frame", nil, window)
    content:SetSize(WIDTH, HEIGHT)
    content:SetPoint("TOPLEFT")
    content:SetFrameLevel(window:GetFrameLevel() + 1)
    window.content = content
    table.insert(window.scaledFrames, content)

    local artBorder = CreateFrame("Frame", nil, window)
    artBorder:SetSize(WIDTH, HEIGHT)
    artBorder:SetPoint("TOPLEFT")
    artBorder:SetFrameLevel(window:GetFrameLevel() + 3)
    window.artBorder = artBorder
    table.insert(window.scaledFrames, artBorder)

    local leftBorder = createBorder(artBorder, "leftBorder", 60, 512)
    leftBorder:SetPoint("TOPLEFT", 9, -27)
    local topBorder = createBorder(artBorder, "topBorder", 446, 140)
    topBorder:SetPoint("TOPLEFT", leftBorder, "TOPRIGHT")
    local bottomBorder = createBorder(artBorder, "bottomBorder", 446, 24)
    bottomBorder:SetPoint("BOTTOMLEFT", leftBorder, "BOTTOMRIGHT")
    local rightBorder1 = createBorder(artBorder, "rightBorder1", 152, 140)
    rightBorder1:SetPoint("TOPLEFT", topBorder, "TOPRIGHT")
    local rightBorder2 = createBorder(artBorder, "rightBorder2", 152 - 85, 512 - 140 - 24)
    rightBorder2:SetPoint("TOPLEFT", topBorder, "TOPRIGHT", 85, -140)
    local rightBorder3 = createBorder(artBorder, "rightBorder3", 152, 24)
    rightBorder3:SetPoint("TOPLEFT", topBorder, "TOPRIGHT", 0, -488)
    window.leftBorder, window.rightBorder1, window.rightBorder3 = leftBorder, rightBorder1, rightBorder3

    window.scoreText = scoreCaption(artBorder, "0", "TOPRIGHT", 234)
    scoreCaption(artBorder, ns.L["SCORE"], "TOPLEFT", 112)
    window.bestScore = scoreCaption(artBorder, "0", "TOPRIGHT", 546)
    window.bestScoreCaption = scoreCaption(artBorder, ns.L["SCORE_BEST"], "TOPLEFT", 546 - 124)

    local logoWidth, logoHeight = Art.Size("logoArt")
    logoWidth, logoHeight = logoHeight, logoWidth
    local logoFrame = CreateFrame("Frame", nil, window)
    logoFrame:SetPoint("TOP", 12, 12)
    logoFrame:SetSize(logoWidth, logoHeight)
    logoFrame:SetFrameLevel(window:GetFrameLevel() + 4)
    table.insert(window.scaledFrames, logoFrame)
    local logo = logoFrame:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOP", -14, 32)
    logo:SetSize(logoWidth, logoHeight)
    Art.Apply(logo, "logoArt", true)

    -- Bottom-right grip: drag to resize (height follows width), right-click to reset.
    local grip = CreateFrame("Frame", nil, window)
    grip:SetPoint("BOTTOMRIGHT")
    grip:SetSize(32, 32)
    grip:SetFrameLevel(window:GetFrameLevel() + 7)
    grip:EnableMouse(true)
    local gripTexture = grip:CreateTexture(nil, "ARTWORK")
    gripTexture:SetAllPoints()
    gripTexture:SetTexture(ART .. "resize")
    grip:SetScript("OnMouseDown", function(_, button)
        if ns.db.profile.lockWindow then
            return
        end
        if button == "RightButton" then
            window:SetSize(WIDTH, HEIGHT)
        else
            window.resizing = true
            window:StartSizing("RIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        window.resizing = nil
        window:StopMovingOrSizing()
    end)
    window:SetResizable(true)
    window:SetResizeBounds(WIDTH / 2, HEIGHT / 2, WIDTH * 1.5, HEIGHT * 1.5)
    window:SetScript("OnSizeChanged", onSizeChanged)

    -- Named click target for the show/hide key binding (SetOverrideBindingClick).
    local toggleButton = CreateFrame("Button", "PeggleReduxToggleButton", UIParent)
    toggleButton:SetSize(1, 1)
    toggleButton:SetPoint("BOTTOMRIGHT")
    toggleButton:SetScript("OnClick", function()
        if window:IsShown() then
            window:Hide()
        else
            MainWindow.ShowFaded()
        end
    end)
    window.toggleButton = toggleButton

    setupFade(window)
end)

ns.RegisterEnabler("MainWindow", function()
    MainWindow.RefreshSoundButton()
    Peggle:RegisterMessage("PEGGLE_SETTING_CHANGED", MainWindow.RefreshSoundButton)
end)
