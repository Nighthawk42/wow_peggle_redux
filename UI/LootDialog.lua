local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

-- The Peggle Loot invitation: item, countdown, Go and Decline. Driven by Features/Loot.lua.

local LootDialog = {}
ns.LootDialog = LootDialog

local frame, item, remaining

function LootDialog.Show(itemText)
    if not frame then
        return
    end
    item:SetText(itemText ~= L["_THE_ITEM"] and itemText or "")
    frame:Show()
end

function LootDialog.Hide()
    if frame then
        frame:Hide()
    end
end

function LootDialog.SetRemaining(seconds)
    if frame then
        remaining:SetFormattedText(L["PEGGLELOOT_REMAINING"], seconds)
    end
end

ns.RegisterBuilder("LootDialog", function()
    frame = Widgets.Popup(UIParent, 310, 230)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    local title = Widgets.Caption(frame, L["PEGGLELOOT_TITLE"], 25, 1, 0.82, 0, true)
    title:SetPoint("TOP", 0, -20)

    local desc = Widgets.Caption(frame, L["PEGGLELOOT_DESC"], 17, 1, 1, 1, true)
    desc:SetPoint("TOP", 0, -50)
    desc:SetWidth(280)
    desc:SetJustifyV("TOP")

    item = Widgets.Caption(frame, "", 18, 1, 1, 1)
    item:SetPoint("TOP", desc, "BOTTOM", 0, -10)
    item:SetWidth(280)
    item:SetJustifyV("TOP")

    remaining = Widgets.Caption(frame, "", 18, 1, 1, 1)
    remaining:SetPoint("TOP", 0, -140)
    remaining:SetWidth(280)

    local go = Widgets.ArtButton(frame, "buttonGo", 45, function()
        ns.Loot.Play()
    end)
    go:SetPoint("BOTTOMLEFT", 14, 14)
    local decline = Widgets.ArtButton(frame, "buttonDecline", 45, function()
        ns.Loot.Pass()
    end, true)
    decline:SetPoint("BOTTOMRIGHT", -14, 14)
end)
