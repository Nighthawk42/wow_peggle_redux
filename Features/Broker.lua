local _, ns = ...
local L = ns.L
local Art = ns.Art

-- Launcher: LibDataBroker object shown as a minimap icon (LibDBIcon) and in the addon compartment.
-- Left-click shows or hides the game, right-click opens Options. The icon flashes while a duel or
-- battle invitation waits (SetNotice).

local ICON_NAME = "PeggleRedux"
local ICON = Art.Path("minimap")
local ICON_NOTICE = Art.Path("minimapNotice")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local Broker = {}
ns.Broker = Broker

local dataObject, noticeTimer

-- Opening mid-round brings up the pause menu, otherwise the category screen, as the original's
-- minimap button did. The window's own mouse-over fade takes it from there.
function Broker.ToggleWindow()
    local window = ns.addon.window
    if window:IsVisible() then
        window:Hide()
        return
    end
    window:SetAlpha(ns.db.profile.mouseOnAlpha)
    local inProgress = ns.Game.IsInProgress()
    if not (inProgress and ns.Menu.IsShown()) then
        if inProgress then
            if ns.GameMenu and ns.GameMenu.Show then
                ns.GameMenu.Show()
            end
        else
            ns.Game.ShowMenu()
        end
    end
    window:Show()
end

local function onClick(_, button)
    if button == "RightButton" then
        ns.Options.Open()
    else
        Broker.ToggleWindow()
    end
end

local function fillTooltip(tooltip)
    local key = ns.db.profile.keybinding
    tooltip:SetText("|cFFFFFFFFPeggle|r" .. (key and key ~= "" and (" (" .. key .. ")") or ""))
    for line in L["_TOOLTIP_MINIMAP2"]:gmatch("[^\n]+") do
        tooltip:AddLine(line)
    end
end

function Broker.Refresh()
    LibDBIcon:Refresh(ICON_NAME, ns.db.profile.minimap)
end

-- Swaps the icon with its "notice" art every 0.5 s while shown is true.
function Broker.SetNotice(shown)
    if shown then
        if not noticeTimer then
            noticeTimer = ns.addon:ScheduleRepeatingTimer(function()
                dataObject.icon = dataObject.icon == ICON and ICON_NOTICE or ICON
            end, 0.5)
        end
    elseif noticeTimer then
        ns.addon:CancelTimer(noticeTimer)
        noticeTimer = nil
        dataObject.icon = ICON
    end
end

ns.RegisterBuilder("Broker", function()
    dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(ICON_NAME, {
        type = "launcher",
        text = "Peggle Redux",
        icon = ICON,
        OnClick = onClick,
        OnTooltipShow = fillTooltip,
    })
    LibDBIcon:Register(ICON_NAME, dataObject, ns.db.profile.minimap)
end)

-- Addon compartment entry (declared in the TOC).
function PeggleRedux_OnAddonCompartmentClick(_, buttonName)
    onClick(nil, buttonName)
end

function PeggleRedux_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
end

function PeggleRedux_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
