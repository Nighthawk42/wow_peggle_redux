local _, ns = ...
local C = ns.C
local L = ns.L
local game = ns.game
local State = ns.State
local Util = ns.Util

-- End-of-level summary and the brag channel picker.

local Summary = {}
ns.Summary = Summary
local Brag = {}
ns.Brag = Brag

local NO_PUBLISH_HEIGHT, PUBLISH_HEIGHT = 260, 304
local frame, bragFrame, bragDropdown
local bragText

local function summaryTitleKey()
    local key = 0
    if #game.objects == 0 then
        key = 2
    elseif game.orangeHit >= game.orangeTotal then
        key = 1
    end
    if game.mode == "duel" then
        key = 3
    elseif game.mode == "battle" then
        key = 4
    elseif game.mode == "loot" then
        key = 5
    end
    return "_SUMMARY_TITLE" .. key
end

function Summary.Show()
    ns.HUD.ResetRound()
    local stats = game.stats
    local publish = game.mode ~= "duel"
    frame.publish:SetShown(publish)
    frame:SetHeight(publish and PUBLISH_HEIGHT or NO_PUBLISH_HEIGHT)
    frame.title:SetText(L[summaryTitleKey()])
    frame.best:SetFormattedText(L["SUMMARY_SCORE_BEST"], Util.CommaNumber(ns.Progress.GetBest(game.level)))
    frame.current:SetFormattedText(L["SUMMARY_SCORE_YOURS"], Util.CommaNumber(game.score))
    local total = stats[State.STAT_PEGS_TOTAL]
    frame.stat1:SetText(stats[State.STAT_SHOTS])
    frame.stat2:SetText(stats[State.STAT_FREE_BALLS])
    frame.stat3:SetFormattedText("%d%%", total > 0 and math.floor(stats[State.STAT_PEGS_HIT] / total * 100) or 0)
    frame.stat4:SetText(Util.CommaNumber(stats[State.STAT_TALENT]))
    frame.stat5:SetText(Util.CommaNumber(stats[State.STAT_FEVER]))
    frame.stat6:SetText(Util.CommaNumber(stats[State.STAT_STYLE]))
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", ns.Board.frame, "CENTER", 0, -20)
    frame:Show()
end

function Summary.Hide()
    frame:Hide()
    bragFrame:Hide()
end

function Summary.IsShown()
    return frame:IsShown()
end

-- Custom chat channels the player is in (no zone or community channels).
local function customChannels()
    local names = {}
    for id = 1, MAX_WOW_CHAT_CHANNELS or 20 do
        local _, name = GetChannelName(id)
        local info = name and C_ChatInfo.GetChannelInfoFromIdentifier(name)
        if info and info.zoneChannelID == 0 and info.channelType ~= Enum.PermanentChatChannelType.Communities then
            table.insert(names, info.name)
        end
    end
    return names
end

local function channelLabel(channel)
    for i, chatType in ipairs(C.CHAT_CHANNELS) do
        if chatType == channel then
            return L["_PUBLISH_" .. i]
        end
    end
    return channel
end

local function buildChannelMenu(_, root)
    local function isSelected(value)
        return ns.db.profile.defaultPublish == value
    end
    local function select(value)
        ns.db.profile.defaultPublish = value
    end
    for _, chatType in ipairs(C.CHAT_CHANNELS) do
        root:CreateRadio(channelLabel(chatType), isSelected, select, chatType)
    end
    for _, name in ipairs(customChannels()) do
        root:CreateRadio(name, isSelected, select, name)
    end
end

local function sendBrag()
    local channel = ns.db.profile.defaultPublish
    local id = GetChannelName(channel)
    if id and id > 0 then
        ns.Comm.Chat(bragText, "CHANNEL", id)
    elseif channel == "GUILD" or channel == "PARTY" or channel == "RAID" then
        ns.Comm.Chat(bragText, channel)
    else
        Util.Print(string.format(ns.L["BRAG_NO_CHANNEL"], channel))
    end
end

-- Opens the channel picker over parent (default: the summary); text is sent as written.
function Brag.Open(text, parent, onSent)
    bragText = text
    bragFrame.onSent = onSent
    parent = parent or frame
    bragFrame:SetParent(parent)
    bragFrame:ClearAllPoints()
    bragFrame:SetPoint("BOTTOM", parent, "BOTTOM", 0, 10)
    bragFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    -- A channel saved earlier may since have been left.
    local profile = ns.db.profile
    local valid = profile.defaultPublish == "GUILD" or profile.defaultPublish == "PARTY" or profile.defaultPublish == "RAID"
    for _, name in ipairs(customChannels()) do
        valid = valid or name:lower() == tostring(profile.defaultPublish):lower()
    end
    if not valid then
        profile.defaultPublish = "GUILD"
    end
    bragDropdown:GenerateMenu()
    bragFrame:Show()
end

local function caption(parent, text, size, r, g, b, gameFont)
    return ns.Widgets.Caption(parent, text, size, r, g, b, gameFont)
end

local function statRow(label, labelX, valueX, y)
    local labelText = caption(frame, label, 17, 1, 0.82, 0)
    labelText:SetPoint("TOPLEFT", labelX, -y)
    local value = caption(frame, "", 17, 1, 1, 1)
    value:SetPoint("TOPRIGHT", frame, "TOPLEFT", valueX, -y)
    return value
end

ns.RegisterBuilder("Summary", function()
    local artBorder = ns.addon.window.artBorder
    frame = ns.Widgets.Panel(artBorder, "window", 0.7, 0.7, 0.7, 1)
    frame:SetSize(380, NO_PUBLISH_HEIGHT)
    frame:EnableMouse(true)
    frame:SetFrameLevel(artBorder:GetFrameLevel() + 3)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not ns.db.profile.lockWindow then
            ns.addon.window:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        ns.addon.window:StopMovingOrSizing()
    end)
    frame:Hide()

    frame.title = caption(frame, "", 25, 1, 0.82, 0, true)
    frame.title:SetPoint("TOP", 0, -36)
    frame.current = caption(frame, "", 23, 1, 0.82, 0, true)
    frame.current:SetPoint("TOP", 0, -72)
    local y, step = 104, 18
    frame.stat1 = statRow(L["SUMMARY_STAT1"], 20, 164, y)
    frame.stat2 = statRow(L["SUMMARY_STAT2"], 20, 164, y + step)
    frame.stat3 = statRow(L["SUMMARY_STAT3"], 20, 164, y + step * 2)
    frame.stat5 = statRow(L["SUMMARY_STAT5"], 170, 360, y)
    frame.stat6 = statRow(L["SUMMARY_STAT6"], 170, 360, y + step)
    frame.stat4 = statRow(L["SUMMARY_STAT4"], 170, 360, y + step * 2)
    frame.best = caption(frame, "", 17, 1, 0.82, 0)
    frame.best:SetPoint("TOP", 0, -(y + 66))

    local publish = ns.Widgets.ArtButton(frame, "buttonPublish", 40, function()
        local levelName = L["_LEVEL_NAME" .. game.level]
        Brag.Open(string.format(L["_PUBLISH_SCORE"], Util.PlayerName(), Util.CommaNumber(game.score), levelName), frame, function()
            frame.publish:Hide()
            frame:SetHeight(NO_PUBLISH_HEIGHT)
        end)
    end, true)
    publish:SetPoint("BOTTOM", -1, 60)
    frame.publish = publish

    local okay = ns.Widgets.ArtButton(frame, "buttonOkay", 40, function()
        Summary.Hide()
        ns.Game.SummaryClosed()
        if game.mode == "loot" and ns.db.profile.closePeggleLoot then
            ns.addon.window:Hide()
        end
    end)
    okay:SetPoint("BOTTOM", 0, 16)

    bragFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    ns.Util.SetBackdrop(bragFrame, "window", 0.7, 0.7, 0.7, 1)
    bragFrame:SetSize(340, 200)
    bragFrame:EnableMouse(true)
    bragFrame:Hide()
    local prompt = caption(bragFrame, L["BRAG"], 17, 1, 0.82, 0)
    prompt:SetPoint("TOP", 0, -36)
    prompt:SetWidth(290)
    bragDropdown = ns.Widgets.Dropdown(bragFrame, 240, buildChannelMenu)
    bragDropdown:SetPoint("TOP", 0, -88)
    local send = ns.Widgets.ArtButton(bragFrame, "buttonPublish", 40, function()
        sendBrag()
        bragFrame:Hide()
        if bragFrame.onSent then
            bragFrame.onSent()
        end
    end, true)
    send:SetPoint("BOTTOMLEFT", 16, 16)
    local back = ns.Widgets.ArtButton(bragFrame, "buttonBack", 40, function()
        bragFrame:Hide()
    end)
    back:SetPoint("BOTTOMRIGHT", -16, 16)
end)
