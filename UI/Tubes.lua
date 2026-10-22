local _, ns = ...
local C = ns.C
local Art = ns.Art
local game = ns.game
local State = ns.State
local Util = ns.Util

-- The two tubes beside the board. Left: the balls waiting to be fired, the spring that loads
-- them into the cannon and the free-ball meter. Right: the 25-segment fever meter and its
-- 2x/3x/5x/10x multiplier badges.

local HUD = ns.HUD
local fmod, min, max = math.fmod, math.min, math.max
local ART = C.ART_PATH

local tube, fever

local function atlasTexture(parent, layer, key, mirrored)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetSize(Art.Size(key))
    texture:SetTexture(ART .. "board1")
    local left, right, top, bottom = Art.Coords(key)
    if mirrored then
        texture:SetTexCoord(right, left, top, bottom)
    else
        texture:SetTexCoord(left, right, top, bottom)
    end
    return texture
end

local function placeTubeBall(ball)
    ball:SetPoint("TOPLEFT", tube, "BOTTOMLEFT", 22, ball.y)
end

local function restack()
    local count = #tube.ballStack
    for i, ball in ipairs(tube.ballStack) do
        ball.y = 74 - count * 3 + i * 18
        placeTubeBall(ball)
    end
end

-- Meter colours: the fill (bar1) and the band behind it (bar2) per free ball earned this shot.
local METER_COLORS = {
    [0] = { { 0, 0, 0, 0 }, { 0, 1, 0.7, 1 } },
    { { 0, 1, 0.7, 1 }, { 1, 0, 1, 1 } },
    { { 1, 0, 1, 1 }, { 1, 1, 0, 1 } },
    { { 1, 1, 0, 1 }, { 1, 1, 0, 1 } },
}

local function colorMeter(level)
    local colors = METER_COLORS[min(level, 3)]
    for _, part in ipairs(tube.bar2) do
        part:SetVertexColor(unpack(colors[1]))
    end
    for _, part in ipairs(tube.bar1) do
        part:SetVertexColor(unpack(colors[2]))
    end
end

local function runAction(action, value)
    if action <= 2 and tube.active then
        table.insert(tube.actionQueue, action)
        return
    end
    local recalc
    if action == 1 then
        if tube.ballStack[1] then
            tube.active = true
            local count = #tube.ballStack
            if count < 4 then
                HUD.ShowBallsLeft(count)
            else
                HUD.HideBallsLeft()
            end
            tube.spring.newY = 76 - count * 3
            tube.spring.y = 76 - (count + 1) * 3
            tube.springMove = -1
            tube.ballDisplay:SetText(game.ballsLeft)
        else
            ns.Game.OutOfBalls()
        end
    elseif action == 2 then
        local ball = table.remove(tube.ballPool)
        if not ball then
            ball = tube:CreateTexture(nil, "ARTWORK")
            ball:SetSize(18, 18)
            ball:SetTexture(ART .. "ball")
        end
        ball:Show()
        table.insert(tube.ballStack, ball)
        game.ballsLeft = game.ballsLeft + 1
        tube.ballDisplay:SetText(game.ballsLeft)
        ball.y = C.TUBE_TOP
        ball.newY = 74 - game.ballsLeft * 3 + game.ballsLeft * 18
        ball.adding = true
        tube.ball = ball
        tube.active = true
        placeTubeBall(ball)
    elseif action == 3 then
        tube.nextValue = C.FREE_BALL_FIRST
        tube.currentValue = 0
        tube.valueStart = 0
        tube.extraLevel = 0
        game.freeRange = nil
        colorMeter(0)
        recalc = true
    elseif action == 4 then
        tube.currentValue = value
        recalc = true
    end
    if not recalc then
        return
    end
    local fill = (tube.currentValue - tube.valueStart) / tube.nextValue
    if fill >= 1 then
        if tube.extraLevel == 1 then
            ns.Sound.Play(C.SOUND_EXTRABALL1)
            game.freeRange = 1
        elseif tube.extraLevel == 2 then
            ns.Sound.Play(C.SOUND_EXTRABALL2)
            game.freeRange = 2
        else
            ns.Sound.Play(C.SOUND_EXTRABALL3)
        end
        game.stats[State.STAT_FREE_BALLS] = game.stats[State.STAT_FREE_BALLS] + 1
        fill = 0
        tube.freeDisplay2:SetText(Util.CommaNumber(tube.nextValue))
        tube.valueStart = tube.nextValue
        tube.nextValue = tube.nextValue + C.FREE_BALL_STEP
        tube.freeState, tube.freeElapsed = 0, 0
        tube.extraLevel = tube.extraLevel + 1
        colorMeter(tube.extraLevel)
        tube.ballDisplay:Hide()
        tube.freeDisplay1:SetAlpha(1)
        tube.freeDisplay1:Show()
        tube.freeDisplayGlow:SetAlpha(1)
        tube.freeDisplayGlow:Show()
        if game.lootActive then
            -- Peggle Loot has one ball: the meter pays style points instead.
            local flag = game.shotFlag
            game.shotFlag = 2
            ns.Scoring.AwardStyleShot(C.STYLE_FREE_BALL, 8, C.BOARD_HEIGHT - 40)
            game.shotFlag = flag
        else
            runAction(2)
        end
    end
    local height = fill * C.METER_HEIGHT
    tube.leftbar1Bottom:SetShown(height >= 32)
    tube.rightbar1Bottom:SetShown(height >= 32)
    tube.leftbar1Top:SetPoint("TOPLEFT", tube, "BOTTOMLEFT", 12, 12 + height)
end

-- Ball movement in the tube runs on real time, not the game's time scale.
local function tubeOnUpdate(self, elapsed)
    if not self.active or ns.Game.IsPaused() then
        return
    end
    local ball = self.ball
    if ball then
        if ball.loading then
            ball.y = ball.y + elapsed * C.TUBE_LOAD_SPEED
            placeTubeBall(ball)
            if ball.y > C.TUBE_TOP then
                ball:Hide()
                table.insert(self.ballPool, ball)
                ball.loading = nil
                self.ball = nil
                self.active = nil
                ns.Game.BallLoaded()
            end
        elseif ball.adding then
            ball.y = ball.y - elapsed * (self.fastAdd and C.TUBE_FAST_ADD_SPEED or C.TUBE_ADD_SPEED)
            placeTubeBall(ball)
            if ball.y <= ball.newY then
                ns.Sound.Play(C.SOUND_BALL_ADD)
                ball.y = ball.newY
                placeTubeBall(ball)
                ball.adding = nil
                self.ball = nil
                self.active = nil
                self.spring:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 18, 76 - game.ballsLeft * 3)
                restack()
                if self.actionQueue[1] then
                    runAction(table.remove(self.actionQueue, 1))
                else
                    self.fastAdd = nil
                end
            end
        end
    elseif self.springMove then
        local spring = self.spring
        spring.y = spring.y + self.springMove * elapsed * C.TUBE_SPRING_SPEED
        if spring.y < 0 then
            spring.y = 0
            self.springMove = 1
        elseif spring.y >= spring.newY then
            self.springMove = nil
            local top = table.remove(self.ballStack)
            top.loading = true
            self.ball = top
            spring.y = 76 - #self.ballStack * 3
            restack()
        end
        spring:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 18, spring.y)
    end
end

-- "FREE BALL" and the amount reached blink in turn for 3.5 s after the meter pays out.
local function updateFreeBlink(elapsed)
    if not tube.freeElapsed then
        return
    end
    tube.freeElapsed = tube.freeElapsed + elapsed
    if tube.freeElapsed >= 0.5 then
        tube.freeState = tube.freeState + 1
        tube.freeElapsed = 0
        if tube.freeState == 7 then
            tube.freeDisplay1:Hide()
            tube.freeDisplay2:Hide()
            tube.freeDisplayGlow:Hide()
            tube.ballDisplay:Show()
            tube.freeElapsed = nil
            tube.freeState = 0
        elseif tube.freeState < 5 then
            local first = fmod(tube.freeState, 2) == 0
            tube.freeDisplay1:SetShown(first)
            tube.freeDisplay2:SetShown(not first)
        end
    elseif tube.freeState == 6 then
        local alpha = (0.5 - tube.freeElapsed) / 0.5
        tube.freeDisplay1:SetAlpha(alpha)
        tube.freeDisplayGlow:SetAlpha(alpha)
    end
end

function HUD.LoadNextBall()
    runAction(1)
end

function HUD.AddBall()
    runAction(2)
end

function HUD.ResetMeter()
    runAction(3)
end

function HUD.SetMeter(value)
    runAction(4, value)
end

function HUD.SetBallCount(count)
    tube.ballDisplay:SetText(count)
end

-- Extreme Fever cashes in the balls left in the tube.
function HUD.CashInBalls()
    for _, ball in ipairs(tube.ballStack) do
        ns.Effects.SpawnText(ns.L["_BALL_SCORE"], 0, ball.y + 40, 0.4, 1, 1, 0, 40, 0)
        ball:Hide()
    end
end

function HUD.ResetTube(fastAdd)
    for _, ball in ipairs(tube.ballStack) do
        ball:Hide()
        table.insert(tube.ballPool, ball)
    end
    wipe(tube.ballStack)
    if tube.ball then
        tube.ball:Hide()
        tube.ball.loading, tube.ball.adding = nil, nil
        table.insert(tube.ballPool, tube.ball)
        tube.ball = nil
    end
    tube.active = nil
    tube.springMove = nil
    tube.freeElapsed = nil
    tube.freeDisplay1:Hide()
    tube.freeDisplay2:Hide()
    tube.freeDisplayGlow:Hide()
    tube.ballDisplay:Show()
    wipe(tube.actionQueue)
    tube.fastAdd = fastAdd
end

-- Fever meter

local function setBadge(badge, lit)
    badge:SetTexCoord(Art.Coords(lit and badge.highlightKey or badge.normalKey))
end

local function setSegment(segment, lit)
    segment:SetTexCoord(Art.Coords(lit and "feverBarHighlight" or "feverBar"))
end

function HUD.FeverReset()
    game.feverSegments = 0
    game.feverMultiplier = 1
    fever.lastBar = 0
    fever.active, fever.feverElapsed, fever.glowElapsed, fever.flashing = nil, nil, nil, nil
    for i = 1, C.FEVER_SEGMENTS do
        fever.segments[i]:Hide()
        fever.segments[i].elapsed = nil
    end
    for _, badge in ipairs(fever.badges) do
        setBadge(badge, false)
        badge.elapsed = nil
    end
    fever.text:SetText(C.ORANGE_COUNT - game.orangeHit)
end

-- Starts the blink of the segments lit since the last commit (after each shot).
function HUD.FeverCommit(start)
    if game.orangeHit < game.orangeTotal then
        for i = fever.lastBar + 1, game.feverSegments do
            local segment = fever.segments[i]
            segment.elapsed = start or 0
            segment.flashCount = start or 0
            segment:Hide()
            fever.flashing = true
        end
        fever.active = true
    end
    fever.text:SetText(C.ORANGE_COUNT - game.orangeHit)
end

local function startExtremeFever()
    ns.Sound.Play(C.SOUND_ODETOJOY)
    ns.Sound.Play(C.SOUND_FEVER)
    HUD.ShowFeverBuckets()
    HUD.SetCatcherShown(false)
    local lastPeg = game.lastPeg
    if lastPeg then
        ns.Effects.SpawnParticleGen(lastPeg.x, lastPeg.y, 0.5, 0.3, 0.005, 0, 359, 1, 3, -0.05, "spark")
        ns.Effects.SpawnParticleGen(lastPeg.x, lastPeg.y, 0.5, 0.3, 0.005, 0, 359, 1, 3, -0.05, "spark")
    end
    HUD.ShowExtremeFeverText()
    local wave = 0
    for i = C.FEVER_SEGMENTS, 1, -1 do
        fever.segments[i].elapsed = wave * 0.125
        wave = (wave + 1) % 6
        fever.segments[i]:Show()
    end
    game.timeScale = 0.5
    fever.feverElapsed = true
    fever.glowElapsed = 0
    fever.active = true
    game.lastPeg = nil
end

-- One more segment (an orange peg, A Step Ahead, More Cowbell).
function HUD.FeverAddSegment()
    if game.feverSegments < C.FEVER_SEGMENTS then
        if fever.flashing then
            fever.lastBar = min(max(game.feverSegments, 1), C.FEVER_SEGMENTS)
            fever.flashing = nil
            fever.active = nil
            for i = 1, game.feverSegments do
                local segment = fever.segments[i]
                segment.flashCount, segment.elapsed = nil, nil
                segment:Show()
                setSegment(segment, false)
            end
        end
        game.feverSegments = game.feverSegments + 1
        local segment = fever.segments[game.feverSegments]
        setSegment(segment, true)
        segment:Show()
        local step = C.FEVER_STEPS[game.feverSegments]
        if step then
            local badge = fever.badges[step]
            badge.elapsed, badge.flashCount = 0, 0
            setBadge(badge, true)
            game.feverMultiplier = C.FEVER_BADGE_MULTIPLIERS[step]
            fever.active = true
        end
    end
    if game.orangeHit >= game.orangeTotal then
        startExtremeFever()
    end
    fever.text:SetText(C.ORANGE_COUNT - game.orangeHit)
end

local function updateFever(elapsed)
    if not fever.active then
        return
    end
    if fever.feverElapsed then
        elapsed = elapsed * 2
        ns.Board.ZoomOutStep()
        fever.glowElapsed = fever.glowElapsed + elapsed
        if fever.glowElapsed > 0.5 then
            fever.glowElapsed = 0
        end
        for i = 1, C.FEVER_SEGMENTS do
            local segment = fever.segments[i]
            segment.elapsed = segment.elapsed + elapsed
            if segment.elapsed > 0.8 then
                segment.elapsed = segment.elapsed - 0.8
                setSegment(segment, true)
                segment.on = true
            end
            if segment.elapsed <= 0.1 then
                segment:SetAlpha(1)
            elseif segment.elapsed <= 0.2 then
                segment:SetAlpha(0.9)
            elseif segment.elapsed <= 0.3 then
                segment:SetAlpha(0.8)
            elseif segment.on then
                segment.on = nil
                setSegment(segment, false)
                segment:SetAlpha(1)
            end
        end
        local firstHalf = fever.glowElapsed < 0.25
        setBadge(fever.badges[1], firstHalf)
        setBadge(fever.badges[4], firstHalf)
        setBadge(fever.badges[2], not firstHalf)
        setBadge(fever.badges[3], not firstHalf)
        return
    end
    local done = true
    if fever.flashing then
        local segmentsDone = true
        for i = fever.lastBar + 1, game.feverSegments do
            local segment = fever.segments[i]
            if segment.elapsed then
                segmentsDone = false
                segment.elapsed = segment.elapsed + elapsed
                if segment.elapsed > 0.2 then
                    segment.flashCount = segment.flashCount + 1
                    segment.elapsed = 0
                    if fmod(segment.flashCount, 2) == 0 then
                        if segment.flashCount >= 6 then
                            segment.flashCount, segment.elapsed = nil, nil
                            segment:Show()
                            setSegment(segment, false)
                        else
                            segment:Hide()
                        end
                    else
                        segment:Show()
                    end
                end
            end
        end
        if segmentsDone then
            fever.lastBar = min(max(game.feverSegments, 1), C.FEVER_SEGMENTS)
            fever.flashing = nil
        else
            done = false
        end
    end
    for _, badge in ipairs(fever.badges) do
        if badge.elapsed then
            done = false
            badge.elapsed = badge.elapsed + elapsed
            if badge.elapsed >= 0.2 then
                badge.flashCount = badge.flashCount + 1
                badge.elapsed = 0
                if fmod(badge.flashCount, 2) == 0 then
                    if badge.flashCount == 6 then
                        badge.flashCount, badge.elapsed = nil, nil
                        setBadge(badge, true)
                    else
                        setBadge(badge, false)
                    end
                else
                    setBadge(badge, true)
                end
            end
        end
    end
    if done then
        fever.active = nil
    end
end

function HUD.UpdateTubes(elapsed)
    updateFever(elapsed)
    updateFreeBlink(elapsed)
end

local BADGE_Y = { 512 - 336 - 62, 512 - 277 - 61, 512 - 229 - 60, 512 - 194 - 59 }
local BADGE_KEYS = { "fever2x", "fever3x", "fever5x", "fever10x" }

local function buildBallTube(window, artBorder)
    local scroll = CreateFrame("ScrollFrame", nil, artBorder)
    scroll:SetSize(64, 300)
    scroll:SetPoint("BOTTOMLEFT", window.leftBorder, "BOTTOMLEFT", -8, 56)
    tube = CreateFrame("Frame", nil, scroll)
    tube:SetSize(64, 300)
    scroll:SetScrollChild(tube)
    scroll:SetVerticalScroll(0)

    tube.ballDisplay = ns.Widgets.Caption(artBorder, "10", 25, 0, 1, 0, true)
    tube.ballDisplay:SetPoint("CENTER", window.leftBorder, "TOPLEFT", 36, -36)
    local glow = artBorder:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER", artBorder, "TOPLEFT", 43, -62)
    glow:SetSize(128, 128)
    Art.Apply(glow, "glow")
    glow:SetVertexColor(0, 1, 0)
    glow:Hide()
    tube.freeDisplayGlow = glow

    atlasTexture(tube, "OVERLAY", "extraBallBottomCover"):SetPoint("BOTTOMLEFT")
    atlasTexture(tube, "OVERLAY", "extraBallTopCover"):SetPoint("BOTTOMLEFT", 16, 346 - 56)

    -- bar2: the coloured band behind the fill (shown once a free ball is earned); bar1: the fill.
    local left2Top = atlasTexture(scroll, "ARTWORK", "extraBallBarTop")
    left2Top:SetPoint("TOPLEFT", tube, "BOTTOMLEFT", 12, 297)
    local right2Top = atlasTexture(scroll, "ARTWORK", "extraBallBarTop", true)
    right2Top:SetPoint("TOP", left2Top, "TOP")
    right2Top:SetPoint("LEFT", tube, "LEFT", 38, 0)
    local left1Top = atlasTexture(tube, "BACKGROUND", "extraBallBarTop")
    left1Top:SetPoint("TOPLEFT", tube, "BOTTOMLEFT", 12, 297)
    local right1Top = atlasTexture(tube, "BACKGROUND", "extraBallBarTop", true)
    right1Top:SetPoint("TOP", left1Top, "TOP")
    right1Top:SetPoint("LEFT", tube, "LEFT", 38, 0)

    local left2Middle = atlasTexture(scroll, "ARTWORK", "extraBallBar")
    left2Middle:SetPoint("TOPRIGHT", left2Top, "BOTTOMRIGHT")
    left2Middle:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 12, 12)
    local right2Middle = atlasTexture(scroll, "ARTWORK", "extraBallBar", true)
    right2Middle:SetPoint("TOPRIGHT", right2Top, "BOTTOMRIGHT")
    right2Middle:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 38, 12)
    local left1Middle = atlasTexture(tube, "BACKGROUND", "extraBallBar")
    left1Middle:SetPoint("TOPRIGHT", left1Top, "BOTTOMRIGHT")
    left1Middle:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 12, 12)
    local right1Middle = atlasTexture(tube, "BACKGROUND", "extraBallBar", true)
    right1Middle:SetPoint("TOP", left1Top, "BOTTOM")
    right1Middle:SetPoint("RIGHT", right1Top, "RIGHT")
    right1Middle:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 38, 12)

    local left2Bottom = atlasTexture(scroll, "ARTWORK", "extraBallBarBot")
    left2Bottom:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 12, 12)
    local right2Bottom = atlasTexture(scroll, "ARTWORK", "extraBallBarBot", true)
    right2Bottom:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 38, 12)
    local left1Bottom = atlasTexture(tube, "ARTWORK", "extraBallBarBot")
    left1Bottom:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 12, 12)
    local right1Bottom = atlasTexture(tube, "ARTWORK", "extraBallBarBot", true)
    right1Bottom:SetPoint("BOTTOMLEFT", tube, "BOTTOMLEFT", 38, 12)

    tube.leftbar1Top, tube.leftbar1Bottom, tube.rightbar1Bottom = left1Top, left1Bottom, right1Bottom
    tube.bar1 = { left1Top, right1Top, left1Middle, right1Middle, left1Bottom, right1Bottom }
    tube.bar2 = { left2Top, right2Top, left2Middle, right2Middle, left2Bottom, right2Bottom }
    colorMeter(0)

    tube.freeDisplay1 = ns.Widgets.Caption(artBorder, ns.L["FREE_BALL2"], 18, 0, 1, 0, true)
    tube.freeDisplay1:SetPoint("CENTER", artBorder, "TOPLEFT", 46, -62)
    tube.freeDisplay1:Hide()
    tube.freeDisplay2 = ns.Widgets.Caption(artBorder, "25,000", 12, 0, 1, 0, true)
    tube.freeDisplay2:SetPoint("CENTER", artBorder, "TOPLEFT", 46, -62)
    tube.freeDisplay2:Hide()

    tube.spring = atlasTexture(tube, "BACKGROUND", "ballLoader")
    tube.spring:SetPoint("TOPLEFT", tube, "BOTTOMLEFT", 17, 76)
    tube.spring.y = 76
    tube.ballPool, tube.ballStack, tube.actionQueue = {}, {}, {}
    tube.extraLevel = 0
    tube.nextValue, tube.currentValue, tube.valueStart = C.FREE_BALL_FIRST, 0, 0
    tube:SetScript("OnUpdate", tubeOnUpdate)
    HUD.tube = tube
end

local function buildFeverTube(window, artBorder)
    fever = CreateFrame("Frame", nil, artBorder)
    fever:SetSize(48, 300)
    fever:SetPoint("BOTTOMRIGHT", window.rightBorder3, "BOTTOMRIGHT", -8, 54)
    atlasTexture(fever, "OVERLAY", "feverBottomCover"):SetPoint("BOTTOMLEFT", 2, 0)
    atlasTexture(fever, "OVERLAY", "feverTopCover"):SetPoint("BOTTOMLEFT", 2, 293)
    fever.text = ns.Widgets.Caption(artBorder, "25", 25, 1, 0.69, 0, true)
    fever.text:SetPoint("CENTER", window.rightBorder1, "TOPRIGHT", -48, -36)
    fever.segments = {}
    local _, segmentHeight = Art.Size("feverBar")
    for i = 0, C.FEVER_SEGMENTS - 1 do
        local segment = atlasTexture(fever, "ARTWORK", "feverBar")
        segment:SetPoint("BOTTOMLEFT", 3, i * segmentHeight + 5)
        segment:Hide()
        fever.segments[i + 1] = segment
    end
    fever.badges = {}
    for i, key in ipairs(BADGE_KEYS) do
        local badge = atlasTexture(fever, "OVERLAY", key)
        badge:SetPoint("BOTTOMLEFT", -5, BADGE_Y[i])
        badge.normalKey, badge.highlightKey = key, key .. "Highlight"
        fever.badges[i] = badge
    end
    fever.lastBar = 0
    HUD.fever = fever
end

ns.RegisterBuilder("Tubes", function()
    local window = ns.addon.window
    buildBallTube(window, window.artBorder)
    buildFeverTube(window, window.artBorder)
end)
