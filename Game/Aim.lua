local _, ns = ...
local C = ns.C
local L = ns.L
local game = ns.game
local State = ns.State
local Util = ns.Util

-- Aiming, the trajectory preview and firing.

local Aim = {}
ns.Aim = Aim

local sqrt, abs, cos, sin, rad, fmod, floor = math.sqrt, math.abs, math.cos, math.sin, math.rad, math.fmod, math.floor
local atan2 = Util.Atan2
local SUBSTEP = C.SUBSTEP
local GRAVITY, SPEED = C.GRAVITY, C.SHOT_SPEED
local GRAVITY_STEP = GRAVITY * SUBSTEP
local BALL_RADIUS, PEG_RADIUS, BRICK_RADIUS = C.BALL_RADIUS, C.PEG_RADIUS, C.BRICK_RADIUS
local SECTIONS = C.GRID_SECTIONS
local MUZZLE_X, MUZZLE_Y = C.BOARD_WIDTH / 2, C.BOARD_HEIGHT - 36

local guideBall = { x = 0, y = 0, xVel = 0, yVel = 0 }
local lastX, lastY

-- Launch angle whose arc passes through the cursor; nil when the point is out of reach.
local function solveAngle(x, y)
    local dx = x - MUZZLE_X
    local dy = MUZZLE_Y - y
    local disc = SPEED ^ 4 - GRAVITY * (GRAVITY * dx * dx + 2 * dy * SPEED * SPEED)
    if disc <= 0 or dx == 0 then
        return nil
    end
    local angle = -math.deg(math.atan((SPEED * SPEED - sqrt(disc)) / (GRAVITY * dx)))
    if dx < 0 then
        angle = angle - 180
    end
    return fmod(angle + 360, 360)
end

function Aim.SetAngle(angle)
    if angle > C.AIM_MIN and angle < C.AIM_MAX then
        angle = angle < 90 and C.AIM_MIN or C.AIM_MAX
    end
    game.aimAngle = angle
    -- The cannon follows the arc's direction a short way out of the muzzle.
    local vx, vy = SPEED * cos(rad(angle)), SPEED * sin(rad(angle))
    local t = 3 / 10 / 1.85
    local px = MUZZLE_X + vx * t
    local py = MUZZLE_Y + vy * t + 0.5 * GRAVITY * t * t
    game.cannonAngle = fmod(atan2(MUZZLE_Y - py + 4, MUZZLE_X - px) + 180, 360)
    ns.HUD.SetCannonAngle(game.cannonAngle)
end

-- Board-local cursor position changed (called by the board's OnUpdate).
function Aim.OnCursor(x, y, force)
    if x == lastX and y == lastY and not force then
        return
    end
    lastX, lastY = x, y
    local angle = force and game.aimAngle or solveAngle(x, y)
    if angle then
        Aim.SetAngle(angle)
    end
end

-- Mouse wheel nudges the angle; the board ignores the cursor until it moves 5 pixels.
function Aim.Nudge(delta)
    Aim.SetAngle(game.aimAngle + delta * 0.1)
end

-- The aim preview: dotted path to the first contact, or with Super Guide a line through two.
function Aim.UpdateGuide()
    local Board = ns.Board
    Board.HideGuide()
    local hit = ns.Physics.hit
    local ball = guideBall
    ball.x, ball.y = C.MUZZLE_X, C.MUZZLE_Y
    ball.xVel = cos(rad(game.aimAngle)) * SPEED
    ball.yVel = sin(rad(game.aimAngle)) * SPEED
    hit.bestDist = 100
    local cannon = game.cannonAngle
    local dotTimer = -0.2 - abs(270 - cannon) / 110 * 0.15
    if cannon < 90 then
        dotTimer = -0.2 - abs(cannon - 90) / 110 * 0.15
    end
    local guide = game.guideActive
    local maxHits = game.guideMaxHits
    local simTime, hits, prevHits = 0, 0, 0
    while simTime < 10 and ball.y > 0 and hits < maxHits do
        local px, py = ball.x, ball.y
        ball.x = ball.x + ball.xVel * SUBSTEP
        ball.y = ball.y + ball.yVel * SUBSTEP
        simTime = simTime + SUBSTEP
        hit.bestDist = 100
        local col, row = ns.Level.Cell(ball.x, ball.y)
        if col then
            for r = row - 1, row + 1 do
                if r > 0 and r <= SECTIONS then
                    for c = col - 1, col + 1 do
                        if c > 0 and c <= SECTIONS then
                            local cell = game.grid[r][c]
                            for i = 1, #cell do
                                local obj = cell[i]
                                if obj.isPeg then
                                    local touched =
                                        ns.Physics.CollideCircle(ball.x, ball.y, BALL_RADIUS, obj.x, obj.y, PEG_RADIUS, ball, obj, nil, true)
                                    if touched then
                                        if guide then
                                            Board.GuideLine(px, py, ball.x, ball.y)
                                        end
                                        hits = hits + 1
                                    end
                                elseif obj.isBrick then
                                    ns.Physics.CollectBrickHit(ball.x, ball.y, BALL_RADIUS, obj.x, obj.y, BRICK_RADIUS, ball, obj)
                                end
                            end
                        end
                    end
                end
            end
            if hit.bestObj then
                hits = hits + 1
                if hit.bestDist == -1 then
                    ns.Physics.CollideCircle(ball.x, ball.y, BALL_RADIUS, hit.centerX, hit.centerY, 1, ball, hit.bestObj, nil, true)
                    hit.bestObj = nil
                else
                    ns.Physics.ResolveSegmentHit(ball, nil, true)
                end
                if guide then
                    Board.GuideLine(px, py, ball.x, ball.y)
                end
            end
        end
        if guide and prevHits == hits then
            Board.GuideLine(px, py, ball.x, ball.y)
        end
        dotTimer = dotTimer + SUBSTEP
        if dotTimer > 0.04 or prevHits ~= hits then
            dotTimer = 0
            local angle = floor(atan2(ball.yVel, ball.xVel)) + 135
            if hits ~= prevHits then
                Board.PathPiece(ball.x, ball.y, angle, "Circle")
            elseif not guide then
                local pieces = Board.PathPieceCount()
                Board.PathPiece(px, py, angle, pieces == 9 and "Edge" or "Square")
                if pieces + 1 > 9 and maxHits <= 2 then
                    simTime = 11
                end
            end
        end
        prevHits = hits
        if Board.GuideLineCount() > 240 and maxHits <= 2 then
            simTime = 11
        end
        if ball.x < C.BOUND_LEFT then
            ball.x = C.BOUND_LEFT + (C.BOUND_LEFT - ball.x)
            ball.xVel = -ball.xVel
        elseif ball.x > C.BOUND_RIGHT then
            ball.x = C.BOUND_RIGHT - (ball.x - C.BOUND_RIGHT)
            ball.xVel = -ball.xVel
        end
        if ball.y < 0 then
            ball.y = -100
            ball.yVel = 0
        elseif ball.y > C.BOUND_TOP then
            ball.y = C.BOUND_TOP - (ball.y - C.BOUND_TOP)
            ball.yVel = -ball.yVel
        end
        if ball.y < BALL_RADIUS * 2 and abs(ball.xVel) < 2 then
            ball.xVel = 0
        end
        ball.yVel = ball.yVel + GRAVITY_STEP
    end
end

-- Board click. Right button held fast-forwards while the ball is in flight or during fever.
function Aim.OnMouseDown(button)
    if button == "RightButton" and (game.readyToShoot or game.orangeHit >= game.orangeTotal) then
        game.speedy = true
        return
    end
    if not game.readyToShoot or ns.Game.IsOverlayShown() then
        return
    end
    Aim.Shoot()
end

function Aim.OnMouseUp()
    game.speedy = nil
end

function Aim.Shoot()
    ns.HUD.SkipBallsLeftIntro()
    game.speedy = nil
    game.readyToShoot = false
    game.hasShot = true
    game.ballsLeft = game.ballsLeft - 1
    ns.HUD.SetBallCount(game.ballsLeft)
    ns.Sound.Play(C.SOUND_SHOT)
    ns.Board.SpawnBall(C.MUZZLE_X, C.MUZZLE_Y, game.aimAngle, SPEED)
    ns.Effects.SpawnParticleGen(
        C.MUZZLE_X,
        C.MUZZLE_Y + 4,
        0.2,
        0.3,
        0.005,
        game.cannonAngle - 1,
        game.cannonAngle + 1,
        10,
        13,
        0,
        "spark",
        1,
        1,
        0.8
    )
    game.stats[State.STAT_SHOTS] = game.stats[State.STAT_SHOTS] + 1
    ns.HUD.HideLoadedBall()
    ns.Board.HideGuide()

    game.shotFlag = nil
    if game.guideTurns > 0 then
        game.shotFlag = true
        game.guideTurns = game.guideTurns - 1
        if game.guideTurns == 0 then
            game.guideMaxHits = 1
            ns.HUD.HidePowerLabel()
        end
    end
    game.guideActive = nil
    if game.guideTurns > 0 and game.character == C.CHAR_GUIDE then
        game.guideActive = true
        ns.HUD.ShowPowerLabel(L["_SPECIAL_NAME1"] .. " " .. game.guideTurns)
    end
    -- Orange Attack needs a number of oranges in one shot that depends on how many are left.
    local left = game.orangeTotal - game.orangeHit
    game.orangeAttack = -C.ORANGE_ATTACK_DEFAULT
    local ranks = C.ORANGE_ATTACK_RANKS
    for i = 1, #ranks, 2 do
        if left >= ranks[i] then
            game.orangeAttack = -ranks[i + 1]
        end
    end
    game.slideCount = 0
    game.lastTouched = nil
end
