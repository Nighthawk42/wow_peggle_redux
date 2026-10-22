local _, ns = ...
local C = ns.C
local L = ns.L
local Art = ns.Art
local game = ns.game
local State = ns.State
local Util = ns.Util

-- Everything drawn around and over the board during a round except the two tubes
-- (UI/Tubes.lua): cannon, character face, power label, bucket, coin flip, round tallies,
-- Extreme Fever art and the level-clear banner.

local HUD = {}
ns.HUD = HUD

local floor, fmod, max, cos, sin, rad = math.floor, math.fmod, math.max, math.cos, math.sin, math.rad
local ART = C.ART_PATH

local window, artBorder
local shooter, loadedBall, face, powerLabel
local catcher, catcherBack, catcherGlow
local coin, rainbow, banner, bannerTexture
local roundPegs, roundPegScore, roundBonusScore, ballsLeft
local fever1, fever2, fever3, feverPegScore
local buckets = {}

-- The bucket. Physics reads catcher.x/y/rotation; it moves like a reversing line mover.
catcher = {
    x = C.CATCHER_START_X,
    y = C.CATCHER_Y,
    rotation = C.CATCHER_ROTATION,
    startX = C.CATCHER_START_X,
    startY = C.CATCHER_Y,
    value1 = C.BOARD_WIDTH - C.CATCHER_START_X,
    value2 = C.CATCHER_Y,
    reverser = true,
    loopTime = C.CATCHER_LOOP_TIME,
    elapsed = 1,
}
HUD.catcher = catcher

local function placeCatcher()
    catcher.texture:ClearAllPoints()
    catcher.texture:SetPoint("CENTER", ns.Board.frame, "BOTTOMLEFT", catcher.x, catcher.y)
    catcherBack:ClearAllPoints()
    catcherBack:SetPoint("CENTER", ns.Board.frame, "BOTTOMLEFT", catcher.x, catcher.y)
end

local function updateCatcher(elapsed)
    catcher.elapsed = catcher.elapsed + elapsed
    if catcher.elapsed > catcher.loopTime then
        catcher.elapsed = fmod(catcher.elapsed, catcher.loopTime)
    end
    ns.Level.MoveLine(catcher)
    placeCatcher()
    if catcher.glowElapsed then
        catcher.glowElapsed = catcher.glowElapsed + elapsed
        if catcher.glowElapsed > 1 then
            catcher.glowElapsed = nil
            catcherGlow:SetAlpha(0)
            HUD.LoadNextBall()
        else
            catcherGlow:SetAlpha(1 - catcher.glowElapsed)
        end
    end
end

-- The bucket starts in the middle of its sweep.
function HUD.ResetCatcher()
    catcher.elapsed = C.CATCHER_LOOP_TIME / 4
    catcher.glowElapsed = nil
    catcherGlow:SetAlpha(0)
    ns.Level.MoveLine(catcher)
    placeCatcher()
    HUD.SetCatcherShown(true)
    HUD.SetCatcherAlpha(1)
end

function HUD.StartCatcherGlow()
    catcher.glowElapsed = 0
end

function HUD.SetCatcherShown(shown)
    catcher.texture:SetShown(shown)
    catcherBack:SetShown(shown)
end

function HUD.SetCatcherAlpha(alpha)
    catcher.texture:SetAlpha(alpha)
end

-- Cannon

function HUD.SetCannonAngle(angle)
    ns.Board.RotateTexture(shooter, floor(angle) - 135)
    loadedBall:ClearAllPoints()
    loadedBall:SetPoint(
        "CENTER",
        ns.Board.frame,
        "BOTTOMLEFT",
        1 + C.BOARD_WIDTH / 2 + 1 + 65 * cos(rad(angle)),
        C.BOARD_HEIGHT - 12 - 20 + 65 * sin(rad(angle))
    )
end

function HUD.ShowLoadedBall()
    loadedBall:Show()
end

function HUD.HideLoadedBall()
    loadedBall:Hide()
end

function HUD.SetCharacterFace(character)
    face:SetTexture(ART .. "char" .. (character + 1) .. "Face")
end

function HUD.ShowPowerLabel(text)
    powerLabel.text:SetText(text)
    powerLabel:Show()
end

function HUD.HidePowerLabel()
    powerLabel:Hide()
end

-- Scores

function HUD.SetScore(score)
    window.scoreText:SetText(Util.CommaNumber(score))
end

function HUD.SetBest(score)
    window.bestScore:SetText(Util.CommaNumber(score))
end

-- Replaces the "Best" caption with a countdown (duels, Peggle Loot); nil restores it.
function HUD.SetTimerCaption(text)
    if text then
        window.bestScoreCaption:SetText(text)
        window.bestScore:Hide()
    else
        window.bestScoreCaption:SetText(L["SCORE_BEST"])
        window.bestScore:Show()
    end
end

-- Fever score buckets along the bottom; every bucket pays 100,000 once every peg is hit.
function HUD.ShowFeverBuckets()
    for _, bucket in ipairs(buckets) do
        bucket:Show()
    end
end

function HUD.SetFeverBuckets(allPegsHit)
    local keys = allPegsHit and { "feverBonus100", "feverBonus100", "feverBonus100", "feverBonus100", "feverBonus100" }
        or { "feverBonus10", "feverBonus50", "feverBonus100", "feverBonus50", "feverBonus10" }
    for i, bucket in ipairs(buckets) do
        bucket:SetTexCoord(Art.Coords(keys[i]))
        local _, height = Art.Size(keys[i])
        bucket:SetHeight(height)
    end
    if allPegsHit then
        fever2:Show()
    end
end

-- Round tallies over the board

function HUD.ShowPegTally(roundValue, pegsHit, points, inFever)
    if inFever then
        feverPegScore:SetText(Util.CommaNumber(points))
        feverPegScore:Show()
    else
        roundPegs:SetFormattedText(L["_PEGS_HIT"], roundValue, pegsHit)
        roundPegScore:SetText(Util.CommaNumber(points))
        roundPegs:Show()
        roundPegScore:Show()
    end
    roundPegs.elapsed = 0
end

function HUD.ShowTotalMiss()
    roundPegScore:SetText(L["_TOTAL_MISS"])
    roundPegScore:Show()
end

function HUD.ShowStyleTotal(points)
    roundBonusScore:SetFormattedText(L["_STYLE_COUNT"], Util.CommaNumber(points))
    roundBonusScore:Show()
end

function HUD.ShowFeverScore(points)
    feverPegScore:SetText(Util.CommaNumber(points))
    feverPegScore:Show()
    roundBonusScore:Hide()
end

-- Starts the 2 s hold and fade of the tally text (the coin flip calls this when it stops).
function HUD.StartTallyFade()
    roundPegs.elapsed = 0
end

local function updateTally(elapsed)
    if not roundPegs.elapsed then
        return
    end
    roundPegs.elapsed = roundPegs.elapsed + elapsed
    if roundPegs.elapsed >= 2 then
        roundPegs:Hide()
        fever3:Hide()
        feverPegScore:Hide()
        roundPegScore:Hide()
        roundBonusScore:Hide()
        roundPegs:SetAlpha(1)
        roundPegScore:SetAlpha(1)
        roundBonusScore:SetAlpha(1)
        roundPegs.elapsed = nil
        if game.levelFinished then
            if game.bannerMedal then
                HUD.ShowBanner(game.bannerMedal)
            else
                ns.Summary.Show()
            end
        end
    elseif roundPegs.elapsed > 1 and not game.feverUp then
        local alpha = 1 - (roundPegs.elapsed - 1)
        roundPegs:SetAlpha(alpha)
        roundPegScore:SetAlpha(alpha)
        roundBonusScore:SetAlpha(alpha)
    end
end

function HUD.ShowExtremeFeverText()
    roundPegs:SetText("")
    roundPegScore:SetText("")
    roundPegs:Show()
    roundPegScore:Show()
    fever1:Show()
end

-- "N BALLS LEFT" zooms in when three or fewer balls remain.
function HUD.ShowBallsLeft(count)
    ballsLeft:Hide()
    ballsLeft.count = count
    ballsLeft:Show()
end

function HUD.HideBallsLeft()
    ballsLeft:Hide()
end

-- Firing cuts the notice short to its fade-out.
function HUD.SkipBallsLeftIntro()
    if ballsLeft.elapsed < 3.2 then
        ballsLeft.elapsed = 3.2
    end
end

-- Extreme Fever rainbow wipe, 0.5 s of real time.
function HUD.StartRainbow()
    roundPegs:SetText("")
    roundPegScore:SetText("")
    roundBonusScore:SetText("")
    fever1:Hide()
    fever2:Hide()
    rainbow:Show()
    rainbow:SetTexCoord(1, 1, 0, 1)
    rainbow:SetWidth(1)
end

function HUD.UpdateRainbow(realElapsed)
    if not game.feverUp or game.feverUp <= -1 then
        return
    end
    game.feverUp = game.feverUp + realElapsed
    if game.feverUp >= 0.5 then
        game.feverUp = -1
        rainbow:SetWidth(C.BOARD_WIDTH)
        rainbow:SetTexCoord(0, 1, 0, 1)
        feverPegScore:Show()
        fever3:Show()
    else
        rainbow:SetWidth(max(C.BOARD_WIDTH * game.feverUp * 2, 1))
        rainbow:SetTexCoord(1 - game.feverUp * 2, 1, 0, 1)
    end
end

-- Level clear banner (medal 1 beaten, 2 fully cleared), then the summary.
function HUD.ShowBanner(medal)
    bannerTexture:SetTexCoord(Art.Coords(medal == C.MEDAL_CLEARED and "bannerBig2" or "bannerBig1"))
    bannerTexture:SetAlpha(0)
    bannerTexture:Show()
    banner.elapsed = 0
    banner:Show()
    ns.Sound.Play(C.SOUND_APPLAUSE)
end

-- Total miss: a coin flip for a free ball (50%, plus 10% per rank of Two-Sided Coin).
function HUD.StartCoinFlip()
    coin.elapsed, coin.side, coin.flips = 0, 0, 0
    coin.check, coin.stopped = nil, nil
    coin:Show()
end

local function coinOnUpdate(self, elapsed)
    if ns.Game.IsPaused() then
        return
    end
    elapsed = math.min(elapsed, 0.05)
    self.elapsed = self.elapsed + elapsed
    if self.stopped then
        if self.elapsed > 1.5 then
            self.stopped = nil
            self.side = 0
            self:Hide()
            HUD.LoadNextBall()
        end
        return
    end
    if self.elapsed > 0.2 then
        self.side = 1 - self.side
        self.flips = self.flips + 1
        self.check = nil
        self.elapsed = 0
        self.texture:SetTexCoord(self.side * 0.5, (self.side + 1) * 0.5, 0, 1)
    end
    if self.elapsed < 0.1 then
        self.texture:SetWidth(196 * (self.elapsed / 0.1 + 0.001))
    else
        self.texture:SetWidth(196 * (0.2 - self.elapsed) / 0.1)
    end
    if not self.check and self.flips == 6 and self.elapsed > 0.1 then
        self.check = true
        if math.random(1, 100) > 50 - State.Talent("coin") * 10 then
            self.texture:SetWidth(196)
            self.elapsed = 0
            self.stopped = true
            HUD.StartTallyFade()
            HUD.AddBall()
        else
            ns.Sound.Play(C.SOUND_COIN_DENIED)
        end
    end
    if self.flips == 7 and self.elapsed > 0.1 then
        self.texture:SetWidth(196)
        self.elapsed = 0
        self.stopped = true
        HUD.StartTallyFade()
        ns.Sound.Play(C.SOUND_COIN_DENIED)
    end
end

-- Per engine tick (time-scaled).
function HUD.Update(elapsed)
    updateCatcher(elapsed)
    HUD.UpdateTubes(elapsed)
    updateTally(elapsed)
end

-- Clears every round overlay for a new level.
function HUD.ResetRound()
    for _, bucket in ipairs(buckets) do
        bucket:Hide()
    end
    HUD.SetFeverBuckets(false)
    fever1:Hide()
    fever2:Hide()
    fever3:Hide()
    feverPegScore:Hide()
    rainbow:Hide()
    roundPegs.elapsed = nil
    for _, text in ipairs({ roundPegs, roundPegScore, roundBonusScore }) do
        text:Hide()
        text:SetAlpha(1)
    end
    powerLabel:Hide()
    banner:Hide()
    bannerTexture:Hide()
    coin:Hide()
    ballsLeft:Hide()
    loadedBall:Hide()
end

function HUD.SetRoundShown(shown)
    window.charPortrait:SetShown(shown)
end

local function atlasTexture(parent, layer, key)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetSize(Art.Size(key))
    Art.Apply(texture, key)
    return texture
end

local function buildCannon()
    shooter = artBorder:CreateTexture(nil, "OVERLAY")
    shooter:SetPoint("CENTER", artBorder, "TOP", 1, -101)
    shooter:SetSize(256, 256)
    shooter:SetTexture(ART .. "shooter")
    loadedBall = artBorder:CreateTexture(nil, "OVERLAY")
    loadedBall:SetSize(C.BALL_SIZE, C.BALL_SIZE)
    loadedBall:SetTexture(ART .. "ball")
    loadedBall:Hide()

    local portrait = CreateFrame("Frame", nil, window)
    portrait:SetFrameLevel(window:GetFrameLevel() + 2)
    portrait:SetSize(C.WINDOW_WIDTH, C.WINDOW_HEIGHT)
    portrait:SetPoint("TOPLEFT")
    table.insert(window.scaledFrames, portrait)
    window.charPortrait = portrait
    local back1 = portrait:CreateTexture(nil, "BACKGROUND")
    back1:SetPoint("CENTER", portrait, "TOP", 3, -101)
    back1:SetSize(72, 50)
    back1:SetColorTexture(0, 0, 0)
    local back2 = portrait:CreateTexture(nil, "BACKGROUND")
    back2:SetPoint("CENTER", portrait, "TOP", 2, -98)
    back2:SetSize(50, 74)
    back2:SetColorTexture(0, 0, 0)
    face = portrait:CreateTexture(nil, "ARTWORK")
    face:SetPoint("CENTER", portrait, "TOP", 0, -101)
    face:SetSize(64, 72)
    face:SetTexture(ART .. "char1Face")
    face:SetTexCoord(0, 1, 0, 72 / 256)

    powerLabel = CreateFrame("Frame", nil, artBorder)
    powerLabel:SetPoint("TOP", artBorder, "TOP", 0, -30)
    powerLabel:SetSize(64, 64)
    atlasTexture(powerLabel, "ARTWORK", "powerLabel"):SetPoint("TOP")
    powerLabel.text = ns.Widgets.Caption(powerLabel, L["_SPECIAL_NAME1"], 15, 0.55, 0.85, 1, true)
    powerLabel.text:SetPoint("TOP", 0, -5)
    powerLabel:Hide()
end

local function buildCatcher(board, foreground)
    catcherGlow = atlasTexture(foreground, "ARTWORK", "catcherGlow")
    catcherGlow:SetAlpha(0)
    catcherGlow:SetVertexColor(1, 1, 0.5)
    catcherBack = foreground:CreateTexture(nil, "BACKGROUND")
    catcherBack:SetSize(C.CATCHER_WIDTH, C.CATCHER_HEIGHT)
    Art.Apply(catcherBack, "catcherBack")
    local front = artBorder:CreateTexture(nil, "OVERLAY")
    front:SetSize(C.CATCHER_WIDTH, C.CATCHER_HEIGHT)
    Art.Apply(front, "catcher")
    catcher.texture = front
    catcherGlow:SetPoint("BOTTOM", front, "BOTTOM", 0, 10)
    placeCatcher()
end

local function buildOverlays(board, foreground)
    coin = CreateFrame("Frame", nil, foreground)
    coin:SetSize(196, 196)
    coin:SetPoint("CENTER", board, "CENTER", 0, -30)
    coin:Hide()
    local coinTexture = coin:CreateTexture(nil, "OVERLAY")
    coinTexture:SetSize(1, 196)
    coinTexture:SetTexture(ART .. "coin")
    coinTexture:SetTexCoord(0, 0.5, 0, 1)
    coinTexture:SetPoint("CENTER")
    coin.texture = coinTexture
    coin:SetScript("OnUpdate", coinOnUpdate)

    local offset = 0
    for i, key in ipairs({ "feverBonus10", "feverBonus50", "feverBonus100", "feverBonus50", "feverBonus10" }) do
        local bucket = atlasTexture(board, "ARTWORK", key)
        bucket:SetPoint("BOTTOMLEFT", offset, 0)
        bucket:Hide()
        offset = offset + bucket:GetWidth()
        buckets[i] = bucket
    end

    rainbow = foreground:CreateTexture(nil, "OVERLAY")
    rainbow:SetPoint("TOPRIGHT", board, "TOPRIGHT", 0, 40)
    rainbow:SetSize(C.BOARD_WIDTH, C.BOARD_WIDTH)
    rainbow:SetTexture(ART .. "rainbow2")
    rainbow:SetAlpha(0.8)
    rainbow:Hide()

    local holder = CreateFrame("Frame", nil, foreground)
    holder:SetAllPoints()
    holder:SetFrameLevel(foreground:GetFrameLevel() + 2)
    local quarter = C.BOARD_HEIGHT / 4
    roundPegs = ns.Widgets.Caption(holder, "", 16, 1, 1, 0, true)
    roundPegs:SetPoint("CENTER", board, "CENTER", 0, quarter)
    roundPegScore = ns.Widgets.Caption(holder, "", 24, 1, 1, 0, true)
    roundPegScore:SetPoint("CENTER", board, "CENTER", 0, quarter - 20)
    roundBonusScore = ns.Widgets.Caption(holder, "", 20, 0.4, 1, 1, true)
    roundBonusScore:SetPoint("CENTER", board, "CENTER", 0, quarter - 44)

    ballsLeft = CreateFrame("Frame", nil, foreground)
    ballsLeft:SetSize(200, 24)
    ballsLeft:SetPoint("CENTER", board, "CENTER", 0, quarter - 44 - 24)
    ballsLeft:SetFrameLevel(foreground:GetFrameLevel() + 3)
    ballsLeft:Hide()
    ballsLeft.elapsed = 0
    ballsLeft.text = ns.Widgets.Caption(ballsLeft, "", 25, 1, 0, 0, true)
    ballsLeft.text:SetPoint("CENTER")
    ballsLeft:SetScript("OnShow", function(self)
        self.elapsed = 0
        self:SetAlpha(1)
        if self.count == 1 then
            self.text:SetText(L["BALLS_LEFT2"])
        else
            self.text:SetFormattedText(L["BALLS_LEFT1"], self.count or 0)
        end
    end)
    ballsLeft:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.25 then
            self.text:SetTextHeight(50 - 100 * self.elapsed)
        else
            self.text:SetTextHeight(25)
        end
        if self.elapsed > 4 then
            self.elapsed = 0
            self:Hide()
            return
        end
        if self.elapsed > 3 then
            self:SetAlpha(max(4 - self.elapsed, 0))
        end
    end)

    local feverHolder = CreateFrame("Frame", nil, artBorder)
    feverHolder:SetPoint("CENTER")
    feverHolder:SetSize(20, 20)
    fever1 = feverHolder:CreateTexture(nil, "OVERLAY")
    fever1:SetSize(Art.Size("fever1"))
    fever1:SetPoint("CENTER")
    Art.Apply(fever1, "fever1")
    fever1:Hide()
    fever2 = feverHolder:CreateTexture(nil, "OVERLAY")
    fever2:SetSize(Art.Size("fever2"))
    fever2:SetPoint("BOTTOM", fever1, "TOP")
    Art.Apply(fever2, "fever2")
    fever2:Hide()
    local cut = Art.Cut("feverScore")
    fever3 = artBorder:CreateTexture(nil, "OVERLAY")
    fever3:SetPoint("CENTER", artBorder, "CENTER", 0, 42)
    fever3:SetSize(floor((cut[4] - cut[3]) * 512 * 1.4 + 0.5), floor((cut[2] - cut[1]) * 256 * 1.3 + 0.5))
    Art.Apply(fever3, "feverScore", true)
    fever3:Hide()
    feverPegScore = ns.Widgets.Caption(holder, "", 40, 0.4, 1, 1, true)
    feverPegScore:SetPoint("TOP", fever3, "BOTTOM", 0, 20)

    banner = CreateFrame("Frame", nil, artBorder)
    banner:SetSize(1, 1)
    banner:SetPoint("CENTER", board, "CENTER")
    banner:Hide()
    banner.elapsed = 0
    bannerTexture = artBorder:CreateTexture(nil, "OVERLAY")
    bannerTexture:SetSize(Art.Size("bannerBig1"))
    bannerTexture:SetPoint("CENTER", board, "CENTER", 2, -52)
    Art.Apply(bannerTexture, "bannerBig1")
    bannerTexture:Hide()
    banner:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        bannerTexture:SetAlpha(math.min(self.elapsed * 2, 1))
        if self.elapsed > 3.5 then
            self.elapsed = 0
            self:Hide()
            bannerTexture:Hide()
            ns.Summary.Show()
        end
    end)
end

ns.RegisterBuilder("HUD", function()
    window = ns.addon.window
    artBorder = window.artBorder
    local board, foreground = ns.Board.frame, ns.Board.foreground
    buildCannon()
    buildCatcher(board, foreground)
    buildOverlays(board, foreground)
    HUD.SetCannonAngle(270)
end)
