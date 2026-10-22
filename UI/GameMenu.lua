local _, ns = ...
local L = ns.L
local game = ns.game

-- The in-round menu: abandon, restart (Quick Play only) or return to the game. The board
-- pauses while it is open.

local GameMenu = {}
ns.GameMenu = GameMenu

local frame

function GameMenu.Show()
    if not ns.Game.IsInProgress() then
        return
    end
    frame.restart:SetArtEnabled(game.mode == "quick")
    frame:Show()
end

function GameMenu.Hide()
    if frame then
        frame:Hide()
    end
end

function GameMenu.Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        GameMenu.Show()
    end
end

function GameMenu.IsShown()
    return frame ~= nil and frame:IsShown()
end

ns.RegisterBuilder("GameMenu", function()
    local artBorder = ns.addon.window.artBorder
    frame = ns.Widgets.Popup(artBorder, 240, 214)
    frame:SetPoint("CENTER", ns.Board.frame, "CENTER", 0, -20)
    frame:SetFrameLevel(artBorder:GetFrameLevel() + 4)
    frame:Hide()

    local title = ns.Widgets.Caption(frame, L["MENU"], 25, 1, 0.82, 0, true)
    title:SetPoint("TOP", 0, -20)

    local abandon = ns.Widgets.ArtButton(frame, "buttonAbandonGame", 40, function()
        frame:Hide()
        ns.Game.Abandon()
    end, true)
    abandon:SetPoint("TOP", 0, -56)

    local restart = ns.Widgets.ArtButton(frame, "buttonRestartLevel", 40, function()
        frame:Hide()
        ns.Game.Restart()
    end)
    restart:SetPoint("TOP", 0, -106)
    frame.restart = restart

    local back = ns.Widgets.ArtButton(frame, "buttonReturnToGame", 40, function()
        frame:Hide()
    end)
    back:SetPoint("TOP", 0, -156)
end)
