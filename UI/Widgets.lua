local _, ns = ...
local C = ns.C
local Art = ns.Art
local Util = ns.Util

-- Widget factories shared by every screen. Callers anchor the returned widget themselves.

local Widgets = {}
ns.Widgets = Widgets

-- gameFont: the original's OVERLOAD.ttf; otherwise the client's standard font.
function Widgets.Caption(parent, text, size, r, g, b, gameFont, flags)
    local fontString = parent:CreateFontString(nil, "OVERLAY")
    fontString:SetFont(gameFont and C.FONT_GAME or STANDARD_TEXT_FONT, size or 10, flags or "OUTLINE")
    fontString:SetTextColor(r or 1, g or 1, b or 1)
    fontString:SetText(text or "")
    return fontString
end

local function artButtonOnMouseDown(self)
    self.down = true
    self.highlight:SetAlpha(0.2)
end

local function artButtonOnMouseUp(self)
    self.down = nil
    self.highlight:SetAlpha(self:IsMouseOver() and 0.1 or 0)
end

local function artButtonOnEnter(self)
    self.highlight:SetAlpha(self.down and 0.2 or 0.1)
end

local function artButtonOnLeave(self)
    self.highlight:SetAlpha(0)
end

local function artButtonSetEnabled(self, enabled)
    self:EnableMouse(enabled)
    self.background:SetDesaturated(not enabled)
    if not enabled then
        self.highlight:SetAlpha(0)
    end
end

-- A button drawn from an atlas region (Data/Art.lua), scaled to the given height. rotated
-- draws the region turned 90 degrees, as the original did for its vertical button art.
function Widgets.ArtButton(parent, artKey, height, onClick, rotated)
    local width, artHeight = Art.Size(artKey)
    if rotated then
        width, artHeight = artHeight, width
    end
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width * height / artHeight, height)
    button:RegisterForClicks("AnyUp")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    Art.Apply(background, artKey, rotated)
    button.background = background

    local highlight = button:CreateTexture(nil, "ARTWORK")
    highlight:SetPoint("CENTER")
    highlight:SetSize(button:GetSize())
    highlight:SetTexture(C.ART_PATH .. "buttonHighlight")
    highlight:SetTexCoord(0, 93 / 128, 0, 1)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0)
    button.highlight = highlight

    button:SetScript("OnMouseDown", artButtonOnMouseDown)
    button:SetScript("OnMouseUp", artButtonOnMouseUp)
    button:SetScript("OnEnter", artButtonOnEnter)
    button:SetScript("OnLeave", artButtonOnLeave)
    button:SetScript("OnClick", onClick)
    button.SetArtEnabled = artButtonSetEnabled
    return button
end

-- A frame with one of the backdrop styles from Core/Util.lua ("window", "popup", "panel", "tooltip").
function Widgets.Panel(parent, style, r, g, b, a, borderR, borderG, borderB)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Util.SetBackdrop(frame, style, r, g, b, a, borderR, borderG, borderB)
    return frame
end

-- The gold-bordered stone popup used by the game menu, character select and dialogs.
function Widgets.Popup(parent, width, height)
    local frame = Widgets.Panel(parent, "popup", 0.7, 0.7, 0.7, 1, 1, 0.8, 0.45)
    frame:SetSize(width, height)
    frame:EnableMouse(true)
    return frame
end

-- Check box with a label to its right. getter/setter read and write the setting.
function Widgets.Checkbox(parent, label, getter, setter, size, r, g, b)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(size or 21, size or 21)
    local text = Widgets.Caption(check, label, 14, r or 1, g or 0.82, b or 0, false, "")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label = text
    check:SetHitRectInsets(0, -text:GetStringWidth() - 4, 0, 0)
    check.Refresh = function(self)
        self:SetChecked(getter() and true or false)
    end
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    check:Refresh()
    return check
end

-- Dropdown (WowStyle1DropdownTemplate). buildMenu(dropdown, rootDescription) fills the menu.
function Widgets.Dropdown(parent, width, buildMenu)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    dropdown:SetupMenu(buildMenu)
    return dropdown
end

-- A line between two points on a frame, for the aim guide and talent branches.
function Widgets.Line(parent, layer, texture, thickness)
    local line = parent:CreateLine(nil, layer or "OVERLAY")
    line:SetTexture(texture)
    line:SetThickness(thickness or 2)
    return line
end
