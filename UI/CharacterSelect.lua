local _, ns = ...
local C = ns.C
local L = ns.L

-- Character select at the start of a round: Super Guide (left) or Space Blast (right).
-- The panel dims to 25% while the cursor is away so the board stays visible.

local CharacterSelect = {}
ns.CharacterSelect = CharacterSelect

local frame
local portraits = {}

local function setFocus(portrait)
    for _, other in ipairs(portraits) do
        other.texture:SetVertexColor(other == portrait and 1 or 0.5, other == portrait and 1 or 0.5, other == portrait and 1 or 0.5)
    end
    frame.focus = portrait
    ns.Game.SetCharacter(portrait.character)
end

function CharacterSelect.Show()
    setFocus(portraits[(ns.db.char.character or C.CHAR_GUIDE) + 1])
    frame:SetAlpha(1)
    frame:Show()
end

function CharacterSelect.Hide()
    if frame then
        frame:Hide()
    end
end

function CharacterSelect.IsShown()
    return frame ~= nil and frame:IsShown()
end

local function dimUnlessHovered()
    if not frame:IsMouseOver() then
        frame:SetAlpha(0.25)
    end
end

local function createPortrait(character, x)
    local portrait = CreateFrame("Button", nil, frame, "BackdropTemplate")
    portrait:SetSize(140, 140)
    portrait:SetPoint("CENTER", x, 0)
    portrait:SetBackdrop({
        edgeFile = C.ART_PATH .. "CharSelectBorder",
        edgeSize = 32,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    portrait:SetBackdropBorderColor(0.1, 0.6, 0.6)
    portrait.character = character
    local texture = portrait:CreateTexture(nil, "BACKGROUND")
    texture:SetSize(128, 128)
    texture:SetPoint("CENTER", 0, 1)
    texture:SetTexture(C.ART_PATH .. "char" .. (character + 1))
    portrait.texture = texture
    portrait:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 1, 0.4)
        frame:SetAlpha(1)
    end)
    portrait:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.1, 0.6, 0.6)
        dimUnlessHovered()
    end)
    portrait:SetScript("OnClick", function(self)
        if frame.focus ~= self then
            ns.Sound.Play(C.SOUND_POWERUP_GUIDE + self.character)
        end
        setFocus(self)
    end)
    portraits[character + 1] = portrait
end

ns.RegisterBuilder("CharacterSelect", function()
    local artBorder = ns.addon.window.artBorder
    frame = ns.Widgets.Popup(artBorder, 340, 260)
    frame:SetPoint("CENTER", ns.Board.frame, "CENTER", 0, -20)
    frame:SetFrameLevel(artBorder:GetFrameLevel() + 4)
    frame:Hide()
    frame:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
    end)
    frame:SetScript("OnLeave", dimUnlessHovered)

    local title = ns.Widgets.Caption(frame, L["CHAR_SELECT"], 25, 1, 0.82, 0, true)
    title:SetPoint("TOP", 0, -20)

    createPortrait(C.CHAR_GUIDE, -80)
    createPortrait(C.CHAR_BLAST, 80)

    local okay = ns.Widgets.ArtButton(frame, "buttonOkay", 40, function()
        ns.db.char.character = frame.focus.character
        ns.Game.SetCharacter(frame.focus.character)
        frame:Hide()
    end)
    okay:SetPoint("BOTTOM", 0, 16)
    okay:HookScript("OnEnter", function()
        frame:SetAlpha(1)
    end)
    okay:HookScript("OnLeave", dimUnlessHovered)
end)
