local _, ns = ...
local C = ns.C
local L = ns.L
local game = ns.game
local State = ns.State
local Util = ns.Util

-- The game tick, ported from the original engine frame: it runs at most every C.TICK seconds,
-- scales time (slow motion near the last orange peg, fever), integrates balls in C.SUBSTEP
-- slices and tallies each shot after its last ball leaves the board.

local Engine = {}
ns.Engine = Engine

local sqrt, abs, max, floor = math.sqrt, math.abs, math.max, math.floor
local SUBSTEP = C.SUBSTEP
local GRAVITY_STEP = C.GRAVITY * SUBSTEP
local BALL_RADIUS, PEG_RADIUS, BRICK_RADIUS = C.BALL_RADIUS, C.PEG_RADIUS, C.BRICK_RADIUS
local SECTIONS = C.GRID_SECTIONS
local LEFT, RIGHT, TOP = C.BOUND_LEFT, C.BOUND_RIGHT, C.BOUND_TOP

local elapsedTotal = 0
local slideSeen, slideIdle = 0, 0
local pegDelay

-- Slow motion and zoom while the ball nears the last orange peg.
local function updateZoom(ball)
    local lastPeg = game.lastPeg
    local dist = sqrt((lastPeg.x - ball.x) ^ 2 + (lastPeg.y - ball.y) ^ 2)
    if dist <= C.ZOOM_DISTANCE then
        local vertical = lastPeg.y < C.BOARD_HEIGHT / 3 and "BOTTOM" or (lastPeg.y < 2 * C.BOARD_HEIGHT / 3 and "" or "TOP")
        local horizontal = lastPeg.x < C.BOARD_WIDTH / 3 and "LEFT" or (lastPeg.x < 2 * C.BOARD_WIDTH / 3 and "" or "RIGHT")
        if vertical == "" and horizontal == "" then
            horizontal = "CENTER"
        end
        if game.lastZoomDist == nil then
            game.lastZoomDist = dist
            ns.Sound.Play(C.SOUND_TIMPANI)
        end
        if game.lastZoomDist < dist and not game.sigh then
            ns.Sound.Play(C.SOUND_SIGH)
            game.sigh = true
        end
        game.lastZoomDist = dist
        local s = max(dist, C.ZOOM_DISTANCE / 2) / C.ZOOM_DISTANCE
        ns.Board.SetZoom(vertical .. horizontal, 1.5 - (s - 0.5))
        game.timeScale = 0.1
    elseif game.timeScale ~= 1 then
        Engine.ResetZoom()
        game.timeScale = 1
    end
end

function Engine.ResetZoom()
    game.sigh = nil
    game.lastZoomDist = nil
    ns.Board.SetZoom(nil)
end

-- Pegs and bricks around the ball, up to C.MAX_RESOLVE_PASSES brick resolutions per substep.
local function collideObjects(ball)
    local hit = ns.Physics.hit
    hit.bestDist = 100
    hit.bestObj = nil
    local again, passes = true, 0
    while again and passes < C.MAX_RESOLVE_PASSES do
        if game.lastPeg then
            updateZoom(ball)
        end
        again = false
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
                                    local _, removed = ns.Physics.CollideCircle(
                                        ball.x,
                                        ball.y,
                                        BALL_RADIUS,
                                        obj.x,
                                        obj.y,
                                        PEG_RADIUS,
                                        ball,
                                        obj
                                    )
                                    if removed then
                                        break
                                    end
                                elseif obj.isBrick then
                                    ns.Physics.CollectBrickHit(ball.x, ball.y, BALL_RADIUS, obj.x, obj.y, BRICK_RADIUS, ball, obj)
                                end
                            end
                            if hit.bestObj then
                                if hit.bestDist == -1 then
                                    ns.Physics.CollideCircle(
                                        ball.x,
                                        ball.y,
                                        BALL_RADIUS,
                                        hit.centerX,
                                        hit.centerY,
                                        1,
                                        ball,
                                        hit.bestObj
                                    )
                                    hit.bestObj = nil
                                else
                                    ns.Physics.ResolveSegmentHit(ball)
                                end
                                again = true
                                passes = passes + 1
                            end
                            -- Like the original, this only leaves the column loop; the next row is still scanned.
                            if again then
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Extreme Fever: round bumpers between the five score buckets.
local function collideBumpers(ball)
    local edges = C.FEVER_BUCKET_EDGES
    for k = 1, #edges do
        local bx, by = edges[k], -8
        local dx, dy = bx - ball.x, by - ball.y
        if sqrt(dx ^ 2 + dy ^ 2) <= BALL_RADIUS + C.BUMPER_RADIUS then
            ns.Sound.Play(C.SOUND_BUMPER)
            ball.x, ball.y = ball.x - ball.xVel * SUBSTEP, ball.y - ball.yVel * SUBSTEP
            dx, dy = bx - ball.x, by - ball.y
            local dist = sqrt(dx ^ 2 + dy ^ 2)
            local nx, ny = dx / dist, dy / dist
            local normal = ball.xVel * nx + ball.yVel * ny
            local tangent = -ball.xVel * ny + ball.yVel * nx
            -- A static bumper: the original's two-body formula with the bumper's speed mirrored.
            normal = normal + (1 + C.RESTITUTION) * (-normal - normal) / 2
            ball.xVel = normal * nx - tangent * ny
            ball.yVel = normal * ny + tangent * nx
            ball.x, ball.y = ball.x + ball.xVel * SUBSTEP, ball.y + ball.yVel * SUBSTEP
            return
        end
    end
end

-- Returns true when the bucket was hit; the original then skipped the rest of this substep
-- for this ball and every ball after it.
local function collideCatcher(ball)
    local catcher = ns.HUD.catcher
    if not ns.Physics.CollideCatcher(ball, catcher) then
        return false
    end
    local hit = ns.Physics.hit
    ns.Sound.Play(C.SOUND_BUCKET_HIT)
    if hit.bestDist == -1 then
        ns.Physics.CollideCircle(ball.x, ball.y, BALL_RADIUS, hit.centerX, hit.centerY, 1, ball, hit.bestObj, nil, true)
        hit.bestObj = nil
    else
        ns.Physics.ResolveSegmentHit(ball, nil, true)
    end
    ball.x = ball.x + ball.xVel * SUBSTEP
    ball.y = ball.y + ball.yVel * SUBSTEP
    return true
end

local function feverBucket(ball)
    local edges, values = C.FEVER_BUCKET_EDGES, C.FEVER_BUCKET_VALUES
    for k = 1, #values do
        if edges[k] < ball.x and ball.x < edges[k + 1] then
            ns.Sound.Play(C.SOUND_FIREWORKS_START)
            local cx = edges[k] + (edges[k + 1] - edges[k]) / 2
            ns.Effects.SpawnParticleGen(cx, 0, 1.5, 1.2, 0.03, 80, 100, 30, 40, -2, "star")
            ns.Effects.SpawnParticleGen(cx, 0, 1.5, 1.2, 0.015, 80, 100, 20, 40, -2, "spark")
            local bonus = 1 + 0.1 * State.Talent("onlyCure")
            local base
            if game.stats[State.STAT_PEGS_HIT] == game.stats[State.STAT_PEGS_TOTAL] then
                base = 100000
            else
                base = floor(values[k] * 10000)
            end
            local points = floor(base * bonus)
            ns.Effects.SpawnText(Util.CommaNumber(points), cx, 50, nil, nil, nil, 0, 80, 0)
            game.score = game.score + points
            game.stats[State.STAT_FEVER] = game.stats[State.STAT_FEVER] + points
            game.stats[State.STAT_TALENT] = game.stats[State.STAT_TALENT] + points - base
            ns.HUD.SetScore(game.score)
            return
        end
    end
end

-- A ball fell off the bottom of the board.
local function ballLost(ball, inCatcher)
    if game.orangeHit < game.orangeTotal then
        if inCatcher then
            ns.Sound.Play(C.SOUND_BUCKET_BALL)
            local catcher = ns.HUD.catcher
            game.stats[State.STAT_FREE_BALLS] = game.stats[State.STAT_FREE_BALLS] + 1
            if not game.lootActive then
                ns.HUD.AddBall()
                ns.HUD.StartCatcherGlow()
                ns.Effects.SpawnText(L["_FREE_BALL"], catcher.x, catcher.y + 30, nil, nil, nil, 0, 40)
                game.freeBall = true
            else
                local bonus = C.LOOT_BUCKET_BONUS * game.stats[State.STAT_FREE_BALLS]
                ns.Effects.SpawnText(
                    string.format(L["_FREE_BALL_DUEL"], Util.CommaNumber(bonus)),
                    catcher.x,
                    catcher.y + 30,
                    nil,
                    nil,
                    nil,
                    0,
                    40
                )
                game.shotStyleRaw = game.shotStyleRaw + bonus
                game.shotStyleTotal = game.shotStyleTotal + bonus
            end
            game.shotFlag = 1
        end
        local catcher = ns.HUD.catcher
        if not ns.Scoring.AwardStyleShot(C.STYLE_MAD_SKILLZ, catcher.x, catcher.y + 14) then
            ns.Scoring.AwardStyleShot(C.STYLE_FREE_BALL, catcher.x, catcher.y + 14)
        end
        game.timeScale = 1
    else
        feverBucket(ball)
        game.timeScale = 0.3
    end
    Engine.ResetZoom()
    ns.Board.ReleaseBall(ball)
    if #game.balls == 0 then
        game.roundValue = Util.CommaNumber(game.shotPegPoints)
        game.pegsHit = 0
        game.reclaim = true
        ns.HUD.FeverCommit()
    end
end

local function stepBalls(elapsed)
    local balls = game.balls
    local catcherX = ns.HUD.catcher.x
    local fever = game.orangeHit >= game.orangeTotal
    local step = 0
    while step <= elapsed do
        local index = 1
        for _ = 1, #balls do
            local ball = balls[index]
            ball.gravMultiplier = 1
            if step == 0 and ball.trailActive then
                ns.Board.ShiftTrail(ball)
            end
            ball.x = ball.x + ball.xVel * SUBSTEP
            ball.y = ball.y + ball.yVel * SUBSTEP
            for other = 1, #balls do
                if other ~= index then
                    ns.Physics.CollideBalls(ball, balls[other])
                end
            end
            collideObjects(ball)
            if ball.x < LEFT then
                ball.x = LEFT + (LEFT - ball.x)
                ball.xVel = -ball.xVel
            elseif ball.x > RIGHT then
                ball.x = RIGHT - (ball.x - RIGHT)
                ball.xVel = -ball.xVel
            end
            if fever then
                if ball.y <= 50 then
                    collideBumpers(ball)
                end
            elseif ball.y < 40 and collideCatcher(ball) then
                break
            end
            if ball.y < 0 then
                ball.y = -100
                ball.yVel = 0
            elseif ball.y > TOP then
                ball.y = TOP - (ball.y - TOP)
                ball.yVel = -ball.yVel
            end
            if ball.y < 2 * BALL_RADIUS and abs(ball.xVel) < 2 then
                ball.xVel = 0
            end
            ball.yVel = ball.yVel + GRAVITY_STEP * ball.gravMultiplier
            local inCatcher = catcherX - C.CATCHER_CATCH_HALF_WIDTH < ball.x
                and ball.x < catcherX + C.CATCHER_CATCH_HALF_WIDTH
            if ball.y > -100 then
                ns.Board.PlaceBall(ball)
            else
                table.remove(balls, index)
                index = index - 1
                ballLost(ball, inCatcher)
            end
            index = index + 1
        end
        step = step + SUBSTEP
    end
end

-- Pops one hit peg every 0.05 s, then adds up the shot.
local function reclaim(elapsed)
    if game.orangeHit == game.orangeTotal and not game.feverUp then
        game.feverUp = 0
        ns.HUD.StartRainbow()
    end
    if game.feverUp and game.feverUp ~= -1 then
        return
    end
    local hitStack = game.hitStack
    if #hitStack > 0 then
        pegDelay = (pegDelay or 0) + elapsed
        if pegDelay >= 0.05 then
            pegDelay = nil
            ns.Sound.Play(C.SOUND_PEG_POP)
            local obj = table.remove(hitStack, 1)
            ns.Board.HideObject(obj)
            game.pegsHit = game.pegsHit + 1
            ns.Sound.Play(C.SOUND_SCORECOUNTER)
            ns.Effects.SpawnGlow(obj)
            ns.HUD.ShowPegTally(game.roundValue, game.pegsHit, game.shotPegPoints * game.pegsHit, game.feverUp)
        end
        return
    end
    local stats = game.stats
    if game.pegsHit == 0 and not game.freeBall then
        ns.HUD.ShowTotalMiss()
        if not game.lootActive then
            ns.Sound.Play(C.SOUND_COIN_SPIN)
            ns.HUD.StartCoinFlip()
            game.catchStreak = 0
        end
    end
    if stats[State.STAT_FEVER] == 0 then
        stats[State.STAT_TALENT] = stats[State.STAT_TALENT]
            + game.shotPegPoints * game.pegsHit
            - game.shotBasePoints * game.pegsHit
    else
        stats[State.STAT_FEVER] = stats[State.STAT_FEVER] + game.shotBasePoints * game.pegsHit
    end
    if game.shotStyleRaw > 0 then
        ns.HUD.ShowStyleTotal(game.shotStyleTotal)
        stats[State.STAT_STYLE] = stats[State.STAT_STYLE] + game.shotStyleRaw
    end
    ns.HUD.ResetMeter()
    game.score = game.score + game.shotPegTotal + game.shotStyleTotal
    if game.feverUp then
        -- The original showed "+10,000" per unused ball but only added it to the fever stat.
        local bonus = game.ballsLeft * C.FEVER_BALL_BONUS
        stats[State.STAT_FEVER] = stats[State.STAT_FEVER] + bonus
        game.score = game.score + bonus
        ns.HUD.CashInBalls()
        ns.HUD.ShowFeverScore(stats[State.STAT_FEVER])
    end
    ns.HUD.SetScore(game.score)
    State.ResetShot()
    if not game.freeBall and game.pegsHit > 0 and game.orangeHit < game.orangeTotal then
        ns.HUD.LoadNextBall()
    end
    game.freeBall = nil
    game.reclaim = nil
    ns.Scoring.EndShotCleanup()
end

-- Brick slides only count when they follow each other closely.
local function updateSlideTimeout(elapsed)
    if slideSeen ~= game.slideCount then
        slideSeen = game.slideCount
        slideIdle = 0
    elseif slideSeen ~= 0 then
        slideIdle = slideIdle + elapsed
        if slideIdle > C.SLIDE_TIMEOUT then
            game.slideCount = 0
            slideSeen = 0
        end
    end
end

function Engine.OnUpdate(_, dt)
    elapsedTotal = elapsedTotal + dt
    if elapsedTotal < C.TICK then
        return
    end
    if not ns.addon.window:IsVisible() or ns.Game.IsPaused() then
        elapsedTotal = 0
        return
    end
    local elapsed = elapsedTotal * game.timeScale
    if game.speedy then
        elapsed = elapsed * 3
    end
    elapsedTotal = 0

    ns.HUD.Update(elapsed)
    updateSlideTimeout(elapsed)
    local objects = game.objects
    for i = 1, #objects do
        ns.Level.UpdateMover(objects[i], elapsed)
    end
    ns.HUD.UpdateRainbow(elapsed / game.timeScale)
    ns.Effects.Update(elapsed)
    if game.reclaim then
        reclaim(elapsed)
    end
    if game.readyToShoot then
        ns.Aim.UpdateGuide()
    end
    if #game.balls > 0 then
        stepBalls(elapsed)
    end
end

function Engine.Reset()
    elapsedTotal = 0
    slideSeen, slideIdle = 0, 0
    pegDelay = nil
end
