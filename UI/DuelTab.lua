local _, ns = ...
local L = ns.L
local Util = ns.Util
local Widgets = ns.Widgets
local Art = ns.Art

-- The Duel tab: the invite panel (level list, opponent, note, status) and the result panel. All
-- state lives in Features/Duel.lua; this file only draws it and forwards button presses.

local TITLE_R, TITLE_G, TITLE_B = 0.05, 0.66, 1
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0

local page, info1, info2
local picker
local w = {} -- widgets by the original's names

local function caption(parent, text, size, r, g, b, gameFont, flags)
    return Widgets.Caption(parent, text, size, r, g, b, gameFont, flags)
end

local function thumbnail(parent, point, x, y)
    local frame = Widgets.Panel(parent, "panel", 0, 0, 0, 0, 1, 1, 1)
    frame:SetPoint(point, page, point, x, y)
    frame:SetSize(128, 128)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetPoint("CENTER")
    texture:SetSize(114, 114)
    return texture
end

local function editBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 32)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

local function setLocked(box, locked)
    if locked then
        box:DisableDrawLayer("BACKGROUND")
        box:SetJustifyH("CENTER")
        box:EnableMouse(false)
        box:ClearFocus()
    else
        box:EnableDrawLayer("BACKGROUND")
        box:SetJustifyH("LEFT")
        box:EnableMouse(true)
    end
end

local function selectedLevel()
    local duel = ns.Duel.GetState()
    return duel and duel.level or picker:GetLevel() or 1
end

local function updateLevel()
    local level = selectedLevel()
    local thumb = Art.Path("bg" .. level .. "_thumb")
    w.levelImage:SetTexture(thumb)
    w.levelImage2:SetTexture(thumb)
    w.winLossCount:SetFormattedText("%d - %d", ns.Duel.GetLevelRecord(level))
end

local function updateOpponentRecord()
    local name = strtrim(w.name2:GetText() or "")
    if name == "" then
        w.winLossPlayer:Hide()
        return
    end
    w.winLossPlayer:SetFormattedText(L["WIN_LOSS_PLAYER"], ns.Duel.GetRecordVs(ns.Multiplayer.Capitalize(name)))
    w.winLossPlayer:Show()
end

local function updateClock(remaining)
    remaining = remaining or ns.Duel.GetRemaining()
    w.timeRemaining:SetFormattedText(L["DUEL_TIME"], ns.Multiplayer.ClockText(remaining))
end

local function showRow(row, result, scoreFormat)
    row.waiting:Hide()
    row.forfeit:Hide()
    row.results:Hide()
    if result == nil then
        row.waiting:Show()
    elseif result == "forfeit" then
        row.forfeit:Show()
    else
        local results = row.results
        results:Show()
        results.score:SetFormattedText(scoreFormat, Util.CommaNumber(result.score))
        results.score:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
        results.talent:SetFormattedText(L["DUEL_BREAKDOWN2"], Util.CommaNumber(result.talent))
        results.style:SetFormattedText(L["DUEL_BREAKDOWN3"], Util.CommaNumber(result.style))
        results.fever:SetFormattedText(L["DUEL_BREAKDOWN4"], Util.CommaNumber(result.fever))
        results.charImage:SetTexture(Art.Path("char" .. (result.character + 1)))
        results.redCount:SetText(result.beaten)
        results.blueCount:SetText(result.cleared)
    end
end

local function refreshResults(duel)
    local Duel = ns.Duel
    showRow(w.player1, duel.mine, L["DUEL_BREAKDOWN1"])
    showRow(w.player2, duel.theirs, L["DUEL_BREAKDOWN1a"])
    local opponent = duel.opponent
    local outcome = duel.outcome
    local status = w.resultStatus
    if duel.phase ~= "done" then
        status:SetFormattedText(L["DUEL_RESULT1"], opponent)
    elseif outcome == Duel.WON then
        status:SetFormattedText(L["DUEL_RESULT2"], opponent)
    elseif outcome == Duel.LOST then
        status:SetFormattedText(L["DUEL_RESULT3"], opponent)
    elseif outcome == Duel.TIED then
        status:SetFormattedText(L["_DUEL_RESULT_TIE"], opponent)
    else
        status:SetText(L["DUEL_RESULT4"])
    end
    local win, lose = w.player1.results.score, w.player2.results.score
    if outcome == Duel.LOST then
        win, lose = lose, win
    end
    if outcome == Duel.WON or outcome == Duel.LOST then
        win:SetTextColor(0, 1, 0)
        lose:SetTextColor(1, 0, 0)
    end
    w.publish:SetShown(duel.publishInfo ~= nil)
    w.winLossDuels:SetFormattedText(L["DUEL_TOTAL_WL"], Duel.GetTotalRecord())
    w.winLossDuelsVs:SetFormattedText(L["DUEL_OPP_WL"], opponent, Duel.GetRecordVs(opponent))
    local timer = w.timeRemaining
    timer:SetParent(w.player2)
    timer:ClearAllPoints()
    timer:SetPoint("CENTER", w.player2, "CENTER", 0, -22)
    timer:SetShown(duel.phase == "playing")
end

local function refresh()
    if not page then
        return
    end
    local duel = ns.Duel.GetState()
    local phase = duel and duel.phase
    local results = phase == "playing" or phase == "done"
    info1:SetShown(not results)
    info2:SetShown(results)
    picker:SetShown(duel == nil)
    for _, key in ipairs({ "go", "decline1", "okay1", "okay2", "decline2" }) do
        w[key]:Hide()
    end
    w.winLoss:ClearAllPoints()
    w.winLoss:SetPoint("TOPLEFT", page, "BOTTOMLEFT", 20, duel and 190 or 90)
    for _, key in ipairs({ "winLoss", "winLossLevel", "winLossCount" }) do
        w[key]:SetShown(not results)
    end
    w.timeRemaining:SetParent(page)
    w.timeRemaining:ClearAllPoints()
    w.timeRemaining:SetPoint("TOP", w.winLossCount, "BOTTOM", 0, -6)
    w.timeRemaining:SetShown(phase == "sending" or phase == "waiting" or phase == "invited")
    updateClock()
    updateLevel()
    if results then
        refreshResults(duel)
        return
    end
    setLocked(w.name2, duel ~= nil)
    w.nameDrop:SetShown(duel == nil)
    w.note3:SetShown(duel ~= nil)
    w.note3Title:SetShown(duel ~= nil)
    w.note2:SetShown(duel == nil)
    w.note2a:SetShown(duel ~= nil)
    if not duel then
        w.note1:SetText(L["OPPONENT_NOTE"] .. " " .. L["OPTIONAL"])
        w.go:Show()
        updateOpponentRecord()
        return
    end
    w.name2:SetText(duel.opponent)
    w.note1:SetText(duel.challenger and L["OPPONENT_NOTE"] or L["OPPONENT_NOTE2"])
    w.note2a:SetText(duel.note ~= "" and duel.note or NONE)
    if phase == "sending" then
        w.note3:SetText(L["DUEL_STATUS1"])
        w.decline1:Show()
    elseif phase == "waiting" then
        w.note3:SetText(L["DUEL_STATUS2"])
        w.decline1:Show()
    elseif phase == "invited" then
        w.note3:SetFormattedText(L["DUEL_CHALLENGE"], duel.opponent)
        w.okay2:Show()
        w.decline2:Show()
    else
        w.note3:SetText(duel.status or "")
        w.okay1:Show()
    end
    updateOpponentRecord()
end

local function onGo()
    local name = strtrim(w.name2:GetText() or "")
    if name == "" then
        return
    end
    local note = strtrim(w.note2:GetText() or "")
    if ns.Duel.Invite(name, picker:GetLevel(), note) then
        w.note2:SetText("")
    end
end

local function openHistoryMenu(button)
    MenuUtil.CreateContextMenu(button, function(_, root)
        local history = ns.Duel.GetHistory()
        if #history == 0 then
            root:CreateTitle(L["_DUEL_NO_HISTORY"])
            return
        end
        root:CreateTitle(L["_DUEL_HISTORY"])
        for _, name in ipairs(history) do
            root:CreateButton(name, function()
                w.name2:SetText(name)
            end)
        end
    end)
end

local function buildInvitePanel()
    info1 = CreateFrame("Frame", nil, page)
    info1:SetPoint("TOPRIGHT", -35, -200)
    info1:SetSize(256, 128)

    local title = caption(info1, L["DUEL"], 40, TITLE_R, TITLE_G, TITLE_B, true)
    title:SetPoint("TOP", page, "TOP", 0, -22)

    w.levelImage = thumbnail(info1, "TOPRIGHT", -98, -60)
    local thumb = w.levelImage:GetParent()

    w.name1 = caption(info1, L["OPPONENT"], 20, GOLD_R, GOLD_G, GOLD_B, true)
    w.name1:SetPoint("TOP", thumb, "BOTTOM", 2, -10)

    local name2 = editBox(info1, 256)
    name2:SetPoint("TOP", thumb, "BOTTOM", 0, -30)
    name2:SetMaxLetters(ns.Multiplayer.MAX_NAME)
    name2:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        if userInput and text:find("^%l") then
            self:SetText(ns.Multiplayer.Capitalize(text))
        end
        updateOpponentRecord()
    end)
    w.name2 = name2

    local nameDrop = CreateFrame("Button", nil, info1)
    nameDrop:SetSize(24, 24)
    nameDrop:SetPoint("LEFT", name2, "RIGHT", 2, 0)
    nameDrop:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    nameDrop:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    nameDrop:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    nameDrop:SetScript("OnClick", openHistoryMenu)
    w.nameDrop = nameDrop

    w.winLossPlayer = caption(info1, "", 18, GOLD_R, GOLD_G, GOLD_B, true)
    w.winLossPlayer:SetPoint("TOP", thumb, "BOTTOM", 0, -62)
    w.winLossPlayer:Hide()

    w.note1 = caption(info1, "", 20, GOLD_R, GOLD_G, GOLD_B, true)
    w.note1:SetPoint("TOP", thumb, "BOTTOM", 0, -100)

    local note2 = editBox(info1, 256)
    note2:SetPoint("TOP", thumb, "BOTTOM", 0, -120)
    note2:SetMaxBytes(48)
    w.note2 = note2

    local note2a = caption(info1, "", 12, 1, 1, 1, false, "")
    note2a:SetPoint("TOP", thumb, "BOTTOM", 0, -126)
    note2a:SetSize(256, 28)
    note2a:SetJustifyV("TOP")
    note2a:Hide()
    w.note2a = note2a

    w.note3Title = caption(page, L["DUEL_STATUS"], 24, GOLD_R, GOLD_G, GOLD_B, true)
    w.note3Title:SetPoint("TOPLEFT", 170, -120)
    w.note3Title:SetWidth(256)
    w.note3 = caption(page, "", 18, 1, 1, 1, true)
    w.note3:SetPoint("TOPLEFT", 170, -180)
    w.note3:SetWidth(256)

    w.winLoss = caption(page, L["WIN_LOSS"], 20, 0, 1, 0, true)
    w.winLoss:SetWidth(300)
    w.winLossLevel = caption(page, L["WIN_LOSS_LEVEL"], 12, 0, 1, 0, true)
    w.winLossLevel:SetPoint("TOP", w.winLoss, "BOTTOM", 0, 0)
    w.winLossCount = caption(page, "0 - 0", 26, 0, 1, 0, true)
    w.winLossCount:SetPoint("TOP", w.winLossLevel, "BOTTOM", 0, -6)
    w.timeRemaining = caption(page, "", 14, GOLD_R, GOLD_G, GOLD_B, true)
    w.timeRemaining:Hide()

    local Duel = ns.Duel
    w.go = Widgets.ArtButton(info1, "buttonGo", 64, onGo)
    w.go:SetPoint("TOP", info1, "BOTTOM", 0, -28)
    w.decline1 = Widgets.ArtButton(info1, "buttonDecline", 64, Duel.Cancel, true)
    w.decline1:SetPoint("BOTTOM", page, "BOTTOM", 0, 16)
    w.okay1 = Widgets.ArtButton(info1, "buttonOkay", 64, Duel.Dismiss)
    w.okay1:SetPoint("BOTTOM", page, "BOTTOM", 0, 16)
    w.okay2 = Widgets.ArtButton(info1, "buttonGo", 64, Duel.Accept)
    w.okay2:SetPoint("BOTTOM", page, "BOTTOM", -150, 16)
    w.decline2 = Widgets.ArtButton(info1, "buttonDecline", 64, Duel.Decline, true)
    w.decline2:SetPoint("BOTTOM", page, "BOTTOM", 150, 16)
end

local function buildPlayerRow(y, forfeitText, charX, charY)
    local row = Widgets.Panel(info2, "panel", 0, 0, 0, 0.5, 1, 1, 1)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 10, y)
    row:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, y)
    row:SetHeight(88)

    row.waiting = caption(row, L["DUEL_WAITING"], 25, GOLD_R, GOLD_G, GOLD_B, true)
    row.waiting:SetAllPoints()
    row.forfeit = caption(row, forfeitText, 25, GOLD_R, GOLD_G, GOLD_B, true)
    row.forfeit:SetAllPoints()

    local results = CreateFrame("Frame", nil, row)
    results:SetAllPoints()
    results:Hide()
    row.results = results

    local charImage = results:CreateTexture(nil, "ARTWORK")
    charImage:SetPoint("TOPLEFT", charX, charY)
    charImage:SetSize(64, 64)
    results.charImage = charImage

    local function banner(file, x, key)
        local texture = results:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(Art.Path(file))
        texture:SetPoint("TOPLEFT", x, -48)
        texture:SetSize(24, 24)
        local count = caption(results, "", 12, 1, 1, 1, true)
        count:SetPoint("TOPLEFT", x + 2, -54)
        count:SetWidth(24)
        results[key] = count
    end
    banner("bannerSmallRed", 96, "redCount")
    banner("bannerSmallBlue", 120, "blueCount")

    results.score = caption(results, "", 25, GOLD_R, GOLD_G, GOLD_B, true)
    results.score:SetPoint("TOPLEFT", 8, -16)
    results.score:SetPoint("RIGHT", -8, 0)
    results.score:SetJustifyH("LEFT")
    local function stat(x, key)
        local text = caption(results, "", 18, TITLE_R, TITLE_G, TITLE_B, true)
        text:SetPoint("TOPLEFT", x, -52)
        results[key] = text
    end
    stat(159, "talent")
    stat(316, "style")
    stat(468, "fever")
    return row
end

local function buildResultPanel()
    info2 = CreateFrame("Frame", nil, page)
    info2:SetPoint("TOPRIGHT", -35, -160)
    info2:SetSize(256, 128)
    info2:Hide()

    local title = caption(info2, L["DUEL_RESULTS"], 40, TITLE_R, TITLE_G, TITLE_B, true)
    title:SetPoint("TOP", page, "TOP", 0, -22)

    w.levelImage2 = thumbnail(info2, "TOPLEFT", 98, -60)
    local thumb = w.levelImage2:GetParent()

    local status = caption(info2, "", 25, GOLD_R, GOLD_G, GOLD_B, true)
    status:SetPoint("TOPLEFT", thumb, "TOPRIGHT", 10, -10)
    status:SetPoint("BOTTOMRIGHT", page, "TOPRIGHT", -10, -125)
    status:SetJustifyV("TOP")
    w.resultStatus = status

    w.winLossDuels = caption(info2, "", 16, GOLD_R, GOLD_G, GOLD_B, true)
    w.winLossDuels:SetPoint("TOP", status, "BOTTOM", 0, -10)
    w.winLossDuels:SetWidth(400)
    w.winLossDuelsVs = caption(info2, "", 16, GOLD_R, GOLD_G, GOLD_B, true)
    w.winLossDuelsVs:SetPoint("TOP", w.winLossDuels, "BOTTOM", 0, -6)
    w.winLossDuelsVs:SetWidth(400)

    w.player1 = buildPlayerRow(-190, L["DUEL_FORFEIT1"], 16, -12)
    w.player2 = buildPlayerRow(-276, L["DUEL_FORFEIT2"], 15, -11)

    w.okay3 = Widgets.ArtButton(info2, "buttonOkay", 64, ns.Duel.Dismiss)
    w.okay3:SetPoint("BOTTOM", page, "BOTTOM", 0, 16)
    w.publish = Widgets.ArtButton(info2, "buttonPublish", 64, function()
        local duel = ns.Duel.GetState()
        if duel and duel.publishInfo then
            ns.Brag.Open(duel.publishInfo, page, function()
                duel.publishInfo = nil
                w.publish:Hide()
            end)
        end
    end, true)
    w.publish:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 16)
    w.publish:Hide()
end

ns.RegisterBuilder("DuelTab", function()
    page = ns.Menu.CreatePage()
    picker = ns.Menu.CreateLevelPicker(page, function()
        updateLevel()
    end)
    picker:SetAllPoints(page)
    buildInvitePanel()
    buildResultPanel()
    page:SetScript("OnShow", function()
        picker:Refresh()
        refresh()
    end)
    ns.Menu.AddTab("duel", 2, "tabDuel", page, 3)
end)

ns.RegisterEnabler("DuelTab", function()
    local events = {}
    LibStub("AceEvent-3.0"):Embed(events)
    events:RegisterMessage("PEGGLE_DUEL_UPDATE", refresh)
    events:RegisterMessage("PEGGLE_DUEL_TICK", function(_, remaining)
        if page:IsVisible() then
            updateClock(remaining)
        end
    end)
    refresh()
end)
