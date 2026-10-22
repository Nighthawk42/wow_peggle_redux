local _, ns = ...
local C = ns.C
local L = ns.L
local Util = ns.Util
local Widgets = ns.Widgets
local Art = ns.Art

-- The Battle tab: the battle list and details (content1) and the New Battle form (content2).
-- Records and sync live in Features/Battle.lua.

local TITLE_R, TITLE_G, TITLE_B = 0.05, 0.66, 1
local LIST_ROWS = 13
local NAME_ROWS = 15
local CHANNEL_PREFIX = "|cFF4CB2FF" -- invite list entries starting with this are custom channels
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"

local page, content1, content2
local list = { state = "list" } -- content1 widgets; state "list" or "details"; selected = battle id
local form = { source = 1, duration = 1, invites = {}, entries = {} } -- content2 widgets and state

local function caption(parent, text, size, r, g, b, gameFont, flags)
    return Widgets.Caption(parent, text, size, r, g, b, gameFont, flags)
end

local function at(region, x, y)
    region:SetPoint("TOPLEFT", x, -y)
    return region
end

local function box(parent, r, g, b, a)
    return Widgets.Panel(parent, "popup", r, g, b, a or 1, 1, 1, 1)
end

local function offsetOf(bar)
    return math.floor(bar:GetValue() + 0.5)
end

local function scrollBar(parent, onChange)
    local bar = CreateFrame("Slider", nil, parent, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -21)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 23)
    -- The template's OnValueChanged scrolls its parent as a ScrollFrame, and onChange needs the bar
    -- stored by the caller, so set the starting value with no handler attached.
    bar:SetScript("OnValueChanged", nil)
    bar:SetValueStep(1)
    bar.scrollStep = 1
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", onChange)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT")
    background:SetPoint("BOTTOMRIGHT", -1, 0)
    background:SetColorTexture(0, 0, 0, 0.35)
    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(bar:GetValue() - delta * 3)
    end)
    return bar
end

local function setRange(bar, rows, visible)
    local top = math.max(0, rows - visible)
    bar:SetMinMaxValues(0, top)
    if bar:GetValue() > top then
        bar:SetValue(top)
    end
end

local function timeColor(status, remaining)
    if status ~= "active" then
        return 0.5, 0.5, 0.5
    elseif remaining < 2 * 3600 then
        return 1, 0, 0
    elseif remaining < 8 * 3600 then
        return 1, 1, 0
    end
    return 0, 1, 0
end

local function timeText(rec)
    local Battle = ns.Battle
    local status, remaining = Battle.Status(rec)
    if status == "expired" then
        return L["_EXPIRED"], 0.5, 0.5, 0.5
    end
    return ns.Multiplayer.HoursMinutes(remaining), timeColor(status, remaining)
end

-- content1: list and details

local function updateList()
    local Battle = ns.Battle
    local records = Battle.List()
    setRange(list.slider, #records, LIST_ROWS)
    list.newChallenge:SetArtEnabled(Battle.CanCreate())
    local offset = offsetOf(list.slider)
    for i = 1, LIST_ROWS do
        local row = list.rows[i]
        local rec = records[i + offset]
        row.rec = rec
        row.highlight:SetAlpha(rec and rec.id == list.selected and 1 or 0)
        row.newIcon:Hide()
        row.played:Hide()
        if rec then
            row.name:SetText(rec.creator)
            local text, r, g, b = timeText(rec)
            row.time:SetText(text)
            row.time:SetTextColor(r, g, b)
            if Battle.HasPlayed(rec) then
                rec.new = nil
                row.played:Show()
            elseif rec.new then
                row.newIcon:Show()
            end
        else
            row.name:SetText("")
            row.time:SetText("")
        end
    end
end

local function updateStandings(rec)
    local rows = ns.Battle.Standings(rec)
    setRange(list.nameSlider, #rows, LIST_ROWS)
    local offset = offsetOf(list.nameSlider)
    for i = 1, LIST_ROWS do
        local line = list.names[i]
        local index = i + offset
        local row = rows[index]
        local played = row and row.score ~= nil
        line.name:SetText(row and row.name or "")
        line.rank:SetText(played and index or "")
        line.score:SetText(row and Util.CommaNumber(row.score or 0) or "")
        local shade = played and 1 or 0.5
        line.name:SetTextColor(shade, shade, shade)
        line.score:SetTextColor(shade, shade, shade)
        line.power:SetShown(played)
        line.red:SetShown(played)
        line.blue:SetShown(played)
        line.redCount:SetText(played and row.beaten > 0 and row.beaten or "")
        line.blueCount:SetText(played and row.cleared > 0 and row.cleared or "")
        if played then
            line.power:SetTexture(Art.Path("char" .. (row.character + 1) .. "Power"))
        end
    end
end

local function updateDetails()
    local Battle = ns.Battle
    local rec = list.selected and Battle.Get(list.selected)
    if not rec then
        list.state, list.selected = "list", nil
        return
    end
    local d = list.details
    d.from:SetText(rec.creator)
    local text, r, g, b = timeText(rec)
    d.time:SetText(text)
    d.time:SetTextColor(r, g, b)
    d.shots:SetText(rec.shots)
    d.note:SetText(rec.note ~= "" and rec.note or NONE)
    d.levelImage:SetTexture(Art.Path("bg" .. rec.level .. "_thumb"))
    local rank, played = Battle.Rank(rec)
    if rank then
        d.standing:SetFormattedText(L["CHALLENGE_RANK"], rank, played)
    else
        d.standing:SetText(L["NOT_PLAYED"])
    end
    list.start:SetArtEnabled(Battle.CanPlay(rec))
    updateStandings(rec)
end

local function refreshContent1()
    if not content1:IsShown() then
        return
    end
    if list.state == "details" then
        updateDetails()
    end
    local details = list.state == "details"
    list.newChallenge:SetShown(not details)
    list.noneSelected:SetShown(not details)
    list.detailsTitle:SetShown(details)
    list.detailFrame:SetShown(details)
    list.nameList:SetShown(details)
    updateList()
end

local function showList()
    list.state, list.selected = "list", nil
    if ns.Menu.SetTabSparkle then
        ns.Menu.SetTabSparkle("battle", false)
    end
    refreshContent1()
end

local function showDetails(id)
    list.state, list.selected = "details", id
    ns.Battle.MarkSeen(id)
    list.nameSlider:SetValue(0)
    refreshContent1()
end

local function onRowEnter(row)
    if row.rec and row.rec.id ~= list.selected then
        row.highlight:SetAlpha(0.5)
    end
end

local function onRowLeave(row)
    if not row.rec or row.rec.id ~= list.selected then
        row.highlight:SetAlpha(0)
    end
end

local function onRowClick(row)
    if row.rec and row.rec.id ~= list.selected then
        showDetails(row.rec.id)
    end
end

local function buildListPanel()
    local panel = box(content1, 0.4, 0.4, 0.4)
    panel:SetPoint("TOPLEFT", 10, -58)
    panel:SetPoint("BOTTOMLEFT", 10, 10)
    panel:SetWidth(200)

    local category = caption(panel, L["CHALLENGE_LIST"], 16, 1, 1, 0, true)
    category:SetPoint("TOP", 0, -10)
    category:SetWidth(180)

    local inner = box(panel, 0.2, 0.2, 0.2)
    inner:SetPoint("TOPLEFT", 6, -30)
    inner:SetPoint("BOTTOMRIGHT", -6, 72)
    list.slider = scrollBar(inner, updateList)

    list.rows = {}
    for i = 1, LIST_ROWS do
        local y = (i - 1) * 20
        local row = CreateFrame("Frame", nil, inner)
        row:SetSize(156, 20)
        at(row, 10, 8 + y)
        row:EnableMouse(true)
        row:SetScript("OnEnter", onRowEnter)
        row:SetScript("OnLeave", onRowLeave)
        row:SetScript("OnMouseUp", onRowClick)
        local highlight = inner:CreateTexture(nil, "ARTWORK")
        highlight:SetAllPoints(row)
        highlight:SetTexture(HIGHLIGHT)
        highlight:SetVertexColor(0.1, 0.75, 1)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0)
        row.highlight = highlight
        row.name = at(caption(inner, "", 11, 1, 1, 1), 10, 10 + y)
        row.name:SetSize(100, 14)
        row.name:SetJustifyH("LEFT")
        row.time = caption(inner, "", 11, 1, 1, 1)
        row.time:SetPoint("TOPRIGHT", -22, -10 - y)
        row.time:SetSize(90, 14)
        row.time:SetJustifyH("RIGHT")
        row.newIcon = inner:CreateTexture(nil, "ARTWORK")
        row.newIcon:SetSize(32, 16)
        row.newIcon:SetPoint("TOPLEFT", -14, -9 - y)
        row.newIcon:SetTexture(Art.Path("new"))
        row.played = inner:CreateTexture(nil, "ARTWORK")
        row.played:SetSize(16, 16)
        row.played:SetPoint("TOPLEFT", -8, -9 - y)
        row.played:SetTexture(Art.Path("checkmark"))
        list.rows[i] = row
    end

    list.newChallenge = Widgets.ArtButton(panel, "buttonNewChallenge", 36, function()
        if ns.Battle.CanCreate() then
            form.Open()
        end
    end)
    list.newChallenge:SetPoint("BOTTOM", 0, 34)
    local limit = caption(panel, L["CHALLENGE_LIMIT"], 10, 1, 1, 1)
    limit:SetPoint("BOTTOM", 0, 10)
    limit:SetWidth(180)
end

local function buildStandings(panel)
    local nameList = box(panel, 0.2, 0.2, 0.2)
    nameList:SetPoint("TOPRIGHT", -6, -30)
    nameList:SetPoint("BOTTOMRIGHT", -6, 72)
    nameList:SetWidth(270)
    list.nameList = nameList
    list.nameSlider = scrollBar(nameList, function()
        local rec = list.selected and ns.Battle.Get(list.selected)
        if rec then
            updateStandings(rec)
        end
    end)
    list.names = {}
    for i = 1, LIST_ROWS do
        local y = (i - 1) * 20
        local line = {}
        line.rank = at(caption(nameList, "", 11, 1, 1, 1), 12, 10 + y)
        line.rank:SetSize(24, 14)
        line.rank:SetJustifyH("LEFT")
        line.name = at(caption(nameList, "", 11, 1, 1, 1), 32, 10 + y)
        line.name:SetSize(100, 14)
        line.name:SetJustifyH("LEFT")
        line.score = caption(nameList, "", 11, 1, 1, 1)
        line.score:SetPoint("TOPRIGHT", -24, -10 - y)
        line.score:SetSize(80, 14)
        line.score:SetJustifyH("RIGHT")
        local function icon(x, file)
            local texture = nameList:CreateTexture(nil, "ARTWORK")
            texture:SetSize(16, 16)
            texture:SetPoint("TOPLEFT", x, -9 - y)
            texture:SetTexture(Art.Path(file))
            return texture
        end
        line.power = icon(136, "char1Power")
        line.red = icon(152, "bannerSmallRed")
        line.blue = icon(168, "bannerSmallBlue")
        line.redCount = at(caption(nameList, "", 9, 1, 1, 1, true), 152, 10 + y)
        line.redCount:SetSize(18, 14)
        line.blueCount = at(caption(nameList, "", 9, 1, 1, 1, true), 168, 10 + y)
        line.blueCount:SetSize(18, 14)
        list.names[i] = line
    end
end

local function buildDetailsPanel()
    local panel = box(content1, 0.4, 0.4, 0.4)
    panel:SetPoint("TOPLEFT", 210, -58)
    panel:SetPoint("BOTTOMRIGHT", -10, 10)

    list.detailsTitle = caption(panel, L["CHALLENGE_DETAILS"], 16, 1, 1, 0, true)
    list.detailsTitle:SetPoint("TOP", 0, -10)
    list.detailsTitle:SetWidth(180)
    list.noneSelected = caption(panel, L["CHALLENGE_DESC"], 18, 1, 0.55, 0, true)
    list.noneSelected:SetPoint("CENTER")

    local frame = CreateFrame("Frame", nil, panel)
    frame:SetAllPoints()
    list.detailFrame = frame
    local d = {}
    list.details = d
    local function row(label, y)
        at(caption(frame, label, 12, 1, 1, 0), 12, y)
        local value = caption(frame, "", 12, 1, 1, 1)
        value:SetPoint("TOPRIGHT", panel, "TOPLEFT", 138, -y)
        value:SetJustifyH("RIGHT")
        return value
    end
    d.from = row(L["CHALLENGE_CAT1"], 30)
    d.time = row(L["CHALLENGE_CAT5"], 46)
    d.shots = row(L["CHALLENGE_CAT3"], 62)
    local thumb = at(Widgets.Panel(frame, "popup", 0, 0, 0, 0, 1, 1, 1), 10, 78)
    thumb:SetSize(128, 128)
    d.levelImage = thumb:CreateTexture(nil, "BACKGROUND")
    d.levelImage:SetPoint("CENTER")
    d.levelImage:SetSize(114, 114)
    at(caption(frame, L["CHALLENGE_CAT6"], 12, 1, 1, 0), 12, 206)
    d.note = at(caption(frame, "", 12, 1, 1, 1), 12, 222)
    d.note:SetSize(128, 52)
    d.note:SetJustifyH("LEFT")
    d.note:SetJustifyV("TOP")
    at(caption(frame, L["CHALLENGE_CAT4"], 12, 1, 1, 0), 12, 278)
    d.standing = at(caption(frame, "", 12, 1, 1, 1), 12, 294)

    list.start = Widgets.ArtButton(frame, "buttonGo", 40, function()
        if list.selected and ns.Battle.Play(list.selected) then
            list.returnTo = list.selected
        end
    end)
    list.start:SetPoint("BOTTOM", -75, 21)
    local back = Widgets.ArtButton(frame, "buttonBack", 40, showList)
    back:SetPoint("BOTTOM", 75, 21)

    buildStandings(frame)
end

-- content2: New Battle form

local function sourceNames()
    local names = {}
    if form.source == 1 then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            local name = info and Util.NormalizeName(info.name)
            if name then
                table.insert(names, { name = name, online = info.connected })
            end
        end
    elseif form.source == 2 then
        local clubId = IsInGuild() and C_Club.GetGuildClubId()
        local offlinePresence = Enum.ClubMemberPresence.Offline
        for _, memberId in ipairs(clubId and C_Club.GetClubMembers(clubId) or {}) do
            local info = C_Club.GetMemberInfo(clubId, memberId)
            local name = info and not info.isSelf and Util.NormalizeName(info.name)
            local online = info and info.presence ~= offlinePresence
            if name and (online or ns.db.profile.battleGuildOffline) then
                table.insert(names, { name = name, online = online })
            end
        end
        local byOnline = ns.db.profile.battleGuildSortOnline
        table.sort(names, function(a, b)
            if byOnline and a.online ~= b.online then
                return a.online
            end
            return a.name < b.name
        end)
    else
        local channels = { GetChannelList() }
        -- TODO(in-game): confirm player-made channels report channelType Custom and General/Trade do not.
        local custom = Enum.PermanentChatChannelType.Custom
        for i = 2, #channels, 3 do
            local channel = channels[i]
            local info = type(channel) == "string" and C_ChatInfo.GetChannelInfoFromIdentifier(channel)
            if info and info.channelType == custom then
                table.insert(names, { name = CHANNEL_PREFIX .. channel, online = true })
            end
        end
    end
    return names
end

local function updateInvited()
    local invites = form.invites
    setRange(form.inviteSlider, #invites, NAME_ROWS)
    local offset = offsetOf(form.inviteSlider)
    for i = 1, NAME_ROWS do
        form.invitedRows[i].text:SetText(invites[i + offset] or "")
    end
    form.invitedCount:SetFormattedText(L["INVITED"], #invites)
end

local function updateSource()
    local entries = form.entries
    setRange(form.sourceSlider, #entries, NAME_ROWS)
    local offset = offsetOf(form.sourceSlider)
    for i = 1, NAME_ROWS do
        local entry = entries[i + offset]
        local text = form.sourceRows[i].text
        text:SetText(entry and entry.name or "")
        local shade = (entry and not entry.online) and 0.5 or 1
        text:SetTextColor(shade, shade, shade)
    end
end

local function reloadSource()
    form.entries = sourceNames()
    updateSource()
end

local function addInvite(name)
    for _, existing in ipairs(form.invites) do
        if existing == name then
            return
        end
    end
    table.insert(form.invites, name)
    table.sort(form.invites)
    updateInvited()
end

local function setSource(id)
    form.source = id
    for i, check in ipairs(form.sourceChecks) do
        check:SetChecked(i == id)
    end
    form.customText:SetShown(id == 3)
    form.guildOption1:SetShown(id == 2)
    form.guildOption2:SetShown(id == 2)
    if id == 2 and IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    form.sourceSlider:SetValue(0)
    reloadSource()
end

local function setDuration(id)
    form.duration = id
    for i, check in ipairs(form.durationChecks) do
        check:SetChecked(i == id)
    end
end

local function nameRows(parent, onClick)
    local rows = {}
    for i = 1, NAME_ROWS do
        local y = (i - 1) * 12
        local text = at(caption(parent, "", 10, 1, 1, 1, false, ""), 14, 10 + y)
        text:SetSize(128, 12)
        text:SetJustifyH("LEFT")
        local hit = CreateFrame("Frame", nil, parent)
        hit:SetSize(126, 12)
        at(hit, 10, 11 + y)
        hit:EnableMouse(true)
        local highlight = parent:CreateTexture(nil, "ARTWORK")
        highlight:SetAllPoints(hit)
        highlight:SetColorTexture(1, 1, 0)
        highlight:SetAlpha(0)
        hit:SetScript("OnEnter", function()
            if text:GetText() and text:GetText() ~= "" then
                highlight:SetAlpha(0.25)
            end
        end)
        hit:SetScript("OnLeave", function()
            highlight:SetAlpha(0)
        end)
        hit:SetScript("OnMouseUp", function()
            local value = text:GetText()
            if value and value ~= "" then
                onClick(i, value)
            end
        end)
        rows[i] = { text = text, hit = hit }
    end
    return rows
end

local function namesBox(x, onClick)
    local frame = at(Widgets.Panel(content2, "popup", 0, 0, 0, 0, 1, 1, 1), x, 135)
    frame:SetSize(160, 204)
    local rows = nameRows(frame, onClick)
    return frame, rows
end

-- Channel members are listed with ListChannelByName; the reply arrives as CHAT_MSG_CHANNEL_LIST lines.
-- TODO(in-game): check the CHAT_MSG_CHANNEL_LIST text is a plain comma list of names (no player links) on every flavor.
local grabber = { pending = {} }

local function channelListFilter(_, _, text)
    if type(text) ~= "string" or Util.IsSecret(text) or not grabber.frame:IsShown() then
        return false
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%*", "")
    for name in text:gmatch("[^,]+") do
        name = Util.NormalizeName(strtrim(name))
        if name and not name:find("[%s%[%]:]") then
            grabber.found[name] = true
        end
    end
    grabber.elapsed = 0
    return true
end

local function finishCreate()
    local names = {}
    for _, entry in ipairs(form.invites) do
        if entry:sub(1, #CHANNEL_PREFIX) ~= CHANNEL_PREFIX then
            table.insert(names, entry)
        end
    end
    for name in pairs(grabber.found or {}) do
        table.insert(names, name)
    end
    local note = strtrim(form.note:GetText() or "")
    local rec = ns.Battle.Create(form.level, math.floor(form.shots:GetValue() + 0.5),
        ns.Battle.DURATIONS[form.duration], names, note)
    content2:Hide()
    content1:Show()
    if rec then
        form.note:SetText("")
        showDetails(rec.id)
        if ns.Battle.Play(rec.id) then
            list.returnTo = rec.id
        end
    else
        showList()
    end
end

local function grabberUpdate(frame, elapsed)
    if grabber.elapsed == -1 then
        local channel = table.remove(grabber.pending)
        grabber.elapsed = 0
        if channel then
            ListChannelByName(channel)
        end
    end
    grabber.elapsed = grabber.elapsed + elapsed
    if grabber.elapsed > 1 then
        if #grabber.pending > 0 then
            grabber.elapsed = -1
        else
            frame:Hide()
            Util.RemoveChatFilter("CHAT_MSG_CHANNEL_LIST", channelListFilter)
            finishCreate()
        end
    end
end

local function buildGrabber()
    local frame = CreateFrame("Frame", nil, ns.addon.window or page)
    frame:SetAllPoints()
    frame:SetFrameLevel(frame:GetFrameLevel() + 70)
    frame:EnableMouse(true)
    frame:Hide()
    local message = Widgets.Panel(frame, "popup", 0.7, 0.7, 0.7, 1, 1, 0.8, 0.45)
    message:SetSize(560, 64)
    message:SetPoint("CENTER")
    local text = caption(message, L["GENERATING_NAMES"], 18, 1, 0.82, 0, true)
    text:SetPoint("CENTER")
    frame:SetScript("OnUpdate", grabberUpdate)
    grabber.frame = frame
end

local function onSubmit()
    if not ns.Battle.CanCreate() then
        return
    end
    wipe(grabber.pending)
    grabber.found = {}
    for _, entry in ipairs(form.invites) do
        if entry:sub(1, #CHANNEL_PREFIX) == CHANNEL_PREFIX then
            table.insert(grabber.pending, entry:sub(#CHANNEL_PREFIX + 1))
        end
    end
    if #grabber.pending == 0 then
        finishCreate()
        return
    end
    Util.AddChatFilter("CHAT_MSG_CHANNEL_LIST", channelListFilter)
    grabber.elapsed = -1
    grabber.frame:Show()
end

local function setLevel(level)
    form.level = level
    form.levelDrop:SetLevel(level)
end

local function buildLevelSide()
    local thumb = at(Widgets.Panel(content2, "popup", 0, 0, 0, 0, 1, 1, 1), 388, 46)
    thumb:SetSize(224, 224)
    form.levelImage = thumb:CreateTexture(nil, "BACKGROUND")
    form.levelImage:SetPoint("CENTER")
    form.levelImage:SetSize(210, 210)

    form.levelDrop = ns.Menu.CreateLevelPicker(content2, function(level)
        form.level = level
    end, { dropdown = true, width = 240, thumbnail = form.levelImage })
    at(form.levelDrop, 380, 12)

    local shots = CreateFrame("Slider", nil, content2, "UISliderTemplateWithLabels")
    at(shots, 383, 288)
    shots:SetSize(200, 17)
    shots:SetMinMaxValues(1, ns.Battle.MAX_SHOTS)
    shots:SetValueStep(1)
    if shots.SetObeyStepOnDrag then
        shots:SetObeyStepOnDrag(true)
    end
    shots.Text:SetFont(C.FONT_GAME, 14, "OUTLINE")
    shots.Text:SetText(L["CHALLENGE_SHOTS"])
    shots.Text:SetTextColor(1, 1, 0)
    shots.Low:SetText("")
    shots.High:SetText("")
    local value = caption(shots, "", 14, 1, 1, 1)
    value:SetPoint("TOPLEFT", shots, "TOPRIGHT")
    shots:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        ns.db.profile.battleShots = v
        value:SetFormattedText(": %d", v)
    end)
    shots:SetValue(ns.db.profile.battleShots)
    value:SetFormattedText(": %d", ns.db.profile.battleShots)
    form.shots = shots

    at(caption(content2, L["CHALLENGE_DUR"], 14, 1, 1, 0, true), 383, 308):SetWidth(200)
    form.durationChecks = {}
    for i, label in ipairs({ "12h", "24h", "48h" }) do
        local check = Widgets.Checkbox(content2, label, function()
            return form.duration == i
        end, function()
            setDuration(i)
        end, nil, 1, 1, 1)
        at(check, 383 + (i - 1) * 70, 324)
        form.durationChecks[i] = check
    end

    at(caption(content2, L["INVITE_NOTE"] .. " " .. L["OPTIONAL"], 14, 1, 0.82, 0, true), 373, 348):SetWidth(220)
    local note = CreateFrame("EditBox", nil, content2, "InputBoxTemplate")
    note:SetSize(194, 32)
    at(note, 389, 358)
    note:SetAutoFocus(false)
    note:SetMaxLetters(ns.Multiplayer.MAX_NOTE)
    note:SetScript("OnEnterPressed", note.ClearFocus)
    note:SetScript("OnEscapePressed", note.ClearFocus)
    form.note = note

    local submit = Widgets.ArtButton(content2, "buttonChallenge", 40, onSubmit)
    submit:SetPoint("CENTER", 166, -188)
end

local function buildForm()
    at(caption(content2, L["CHALLENGE_NEW"], 30, TITLE_R, TITLE_G, TITLE_B, true), 10, 26):SetWidth(330)
    at(caption(content2, L["INVITEES"], 25, 1, 1, 0, true), 10, 60)
    at(caption(content2, L["CHALLENGE_DESC1"], 11, 1, 1, 1), 10, 90)
    form.customText = caption(content2, L["CHALLENGE_DESC2"], 11, 1, 1, 1)
    form.customText:SetPoint("BOTTOMLEFT", 10, 40)
    form.customText:SetWidth(350)
    form.customText:SetJustifyH("LEFT")
    form.customText:Hide()
    local desc3 = caption(content2, L["CHALLENGE_DESC3"], 10, 1, 1, 1)
    desc3:SetPoint("BOTTOMLEFT", 10, 10)
    desc3:SetWidth(350)
    desc3:SetJustifyH("LEFT")

    form.sourceChecks = {}
    for i, key in ipairs({ "CHALLENGE_INVITE1", "CHALLENGE_INVITE2", "CHALLENGE_INVITE3" }) do
        local check = Widgets.Checkbox(content2, L[key], function()
            return form.source == i
        end, function()
            setSource(i)
        end, 18)
        check.label:SetFont(C.FONT_GAME, 12, "OUTLINE")
        at(check, ({ 13, 75, 123 })[i], 115)
        form.sourceChecks[i] = check
    end

    local profile = ns.db.profile
    form.guildOption1 = Widgets.Checkbox(content2, L["CHALLENGE_GUILD1"], function()
        return profile.battleGuildOffline
    end, function(value)
        profile.battleGuildOffline = value
        reloadSource()
    end, 18)
    at(form.guildOption1, 14, 342)
    form.guildOption2 = Widgets.Checkbox(content2, L["CHALLENGE_GUILD2"], function()
        return profile.battleGuildSortOnline
    end, function(value)
        profile.battleGuildSortOnline = value
        reloadSource()
    end, 18)
    at(form.guildOption2, 14, 362)

    form.invitedCount = caption(content2, "", 12, 1, 1, 0, true)
    form.invitedCount:SetPoint("BOTTOM", content2, "TOPLEFT", 280, -130)
    form.invitedCount:SetWidth(150)

    local sourceBox
    sourceBox, form.sourceRows = namesBox(10, function(_, name)
        addInvite(name)
    end)
    form.sourceSlider = scrollBar(sourceBox, updateSource)
    local invitedBox
    invitedBox, form.invitedRows = namesBox(200, function(i, name)
        if Util.IsPlayer(name) then
            return
        end
        table.remove(form.invites, i + offsetOf(form.inviteSlider))
        updateInvited()
    end)
    form.inviteSlider = scrollBar(invitedBox, updateInvited)

    buildLevelSide()
end

function form.Open()
    content1:Hide()
    wipe(form.invites)
    table.insert(form.invites, Util.PlayerName())
    form.inviteSlider:SetValue(0)
    setSource(1)
    setDuration(1)
    setLevel(form.level or 1)
    updateInvited()
    content2:Show()
end

local function refreshForm()
    if content2:IsShown() then
        reloadSource()
    end
end

ns.RegisterBuilder("BattleTab", function()
    page = ns.Menu.CreatePage()
    content1 = CreateFrame("Frame", nil, page)
    content1:SetAllPoints()
    local title = caption(content1, L["CHALLENGE"], 40, TITLE_R, TITLE_G, TITLE_B, true)
    title:SetPoint("TOP", 0, -22)
    content1:SetScript("OnShow", refreshContent1)
    buildListPanel()
    buildDetailsPanel()

    content2 = CreateFrame("Frame", nil, page)
    content2:SetAllPoints()
    content2:Hide()
    buildForm()
    buildGrabber()

    page:SetScript("OnShow", function()
        content2:Hide()
        content1:Show()
        local returnTo = list.returnTo
        list.returnTo = nil
        if returnTo and ns.Battle.Get(returnTo) then
            showDetails(returnTo)
        else
            showList()
        end
        ns.Battle.Gossip()
    end)
    ns.Menu.AddTab("battle", 3, "tabChallenge", page, 3)
end)

ns.RegisterEnabler("BattleTab", function()
    local events = {}
    LibStub("AceEvent-3.0"):Embed(events)
    events:RegisterMessage("PEGGLE_BATTLE_UPDATE", refreshContent1)
    events:RegisterEvent("FRIENDLIST_UPDATE", refreshForm)
    events:RegisterEvent("GUILD_ROSTER_UPDATE", refreshForm)
    events:RegisterMessage("PEGGLE_SUMMARY_CLOSED", function(_, mode)
        if mode == "battle" and ns.Menu.IsShown() then
            ns.Menu.SelectTab("battle")
        end
    end)
end)
