local _, ns = ...
local C = ns.C
local game = ns.game
local Util = ns.Util

-- Ball collisions with pegs, bricks and the bucket, ported from the original engine.
-- "simulate" calls (the aim preview, the bucket) bounce the ball but leave the board alone.

local Physics = {}
ns.Physics = Physics

local sqrt, abs, cos, sin, rad, fmod, floor = math.sqrt, math.abs, math.cos, math.sin, math.rad, math.fmod, math.floor
local atan2 = Util.Atan2
local RESTITUTION = C.RESTITUTION
local BALL_RADIUS = C.BALL_RADIUS

-- Closest contact found while scanning bricks; resolved once per scan.
local hit = { bestDist = 100 }
Physics.hit = hit

-- World-space outline of a brick (or the bucket with a custom polygon). Returns coordinate count.
local polygon = {}
Physics.polygon = polygon
local scaledPolygons = {}
for shape, points in ipairs(C.BRICK_POLYGONS) do
    scaledPolygons[shape] = {}
    for i, value in ipairs(points) do
        scaledPolygons[shape][i] = value * C.BRICK_POLYGON_SCALE
    end
end

function Physics.BuildPolygon(obj, points)
    points = points or scaledPolygons[C.CURVED_BRICK[obj.radius]]
    local angle = rad(obj.rotation - 135)
    local c, s = cos(angle), sin(angle)
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        polygon[i] = c * x - s * y + obj.x
        polygon[i + 1] = s * x + c * y + obj.y
    end
    polygon[#points + 1] = nil
    return #points
end

-- First contact with a peg or brick: score it and light it up.
local function firstHit(ball, obj)
    obj.hit = true
    if obj == game.lastPeg then
        ns.Board.ResetTrail(ball)
    end
    ns.Scoring.OnObjectHit(obj)
    ns.Board.SetObjectArt(obj, true)
end

local function removeObject(obj)
    ns.Level.GridRemove(obj)
    ns.Board.HideObject(obj)
end

-- Ball against a circle (a peg, or a brick corner with radius 1). Returns collided, removed.
function Physics.CollideCircle(bx, by, ballRadius, cx, cy, radius, ball, obj, forceRemove, simulate)
    local reach = ballRadius + radius
    local distSq = (cx - bx) ^ 2 + (cy - by) ^ 2
    if distSq > reach * reach then
        return false
    end
    local dist = sqrt(distSq)
    local angle = atan2(cy - by, cx - bx)
    local push = (reach - dist) * C.PUSH_OUT
    local away = rad(angle + 180)
    ball.x = ball.x + push * cos(away)
    ball.y = ball.y + push * sin(away)
    local nx, ny = cos(rad(angle)), sin(rad(angle))
    local impulse = (1 + RESTITUTION) * (ball.xVel * nx + ball.yVel * ny) / 2
    ball.xVel = ball.xVel - impulse * 2 * nx
    ball.yVel = ball.yVel - impulse * 2 * ny
    -- Damps the small upward hops of a ball resting on a peg.
    if abs(ball.xVel) < 80 and ball.yVel >= 0 and ball.yVel < 40 then
        ball.yVel = 0
    end
    local removed
    if not simulate then
        game.slideCount = 0
        if not obj.hit then
            firstHit(ball, obj)
        end
        obj.hitCount = obj.hitCount + 1
        if obj.hitCount > C.PEG_MAX_CONTACTS then
            forceRemove = true
        end
        game.lastTouched = obj
        if forceRemove then
            removeObject(obj)
            removed = true
        end
    end
    return true, removed
end

local function setHit(obj, cornerX, cornerY, pDistX, pDistY, dxSeg, dySeg, hitAngle, ballAngle, dist, seg, count)
    hit.bestObj = obj
    hit.bestCenterX, hit.bestCenterY = cornerX, cornerY
    hit.centerX, hit.centerY = cornerX, cornerY
    hit.pDistX, hit.pDistY = pDistX, pDistY
    hit.dxSeg, hit.dySeg = dxSeg, dySeg
    hit.hitAngle = hitAngle
    hit.ballAngle = ballAngle
    hit.bestDist = dist
    hit.hitSeg = seg
    hit.maxPoly = count
end

-- Ball against a brick outline: records the closest edge (or corner) in Physics.hit.
-- As in the original, a lone corner contact is dropped unless a second corner competes with it.
function Physics.CollectBrickHit(bx, by, ballRadius, ox, oy, brickRadius, ball, brick)
    local reach = ballRadius + brickRadius
    if (ox - bx) ^ 2 + (oy - by) ^ 2 > reach * reach then
        return
    end
    local count = Physics.BuildPolygon(brick)
    local caps = C.BRICK_CAP_EDGES[C.CURVED_BRICK[brick.radius]]
    local contactSq = (ballRadius - 1) ^ 2
    local corners = 0
    local first
    local x2, y2 = polygon[count - 1], polygon[count]
    for m = 1, count, 2 do
        local x1, y1 = x2, y2
        x2, y2 = polygon[m], polygon[m + 1]
        local dx, dy = x2 - x1, y2 - y1
        local t = ((bx - x1) * dx + (by - y1) * dy) / (dx * dx + dy * dy)
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end
        local px, py = (1 - t) * x1 + t * x2, (1 - t) * y1 + t * y2
        local distX, distY = (bx - px) ^ 2, (by - py) ^ 2
        local distSq = distX + distY
        if distSq < contactSq then
            local cornerDX, cornerDY
            if caps[floor((m + 1) / 2)] then
                local length = sqrt(dx * dx + dy * dy)
                local ux, uy = dx / length, dy / length
                if (bx - x1) * ux + (by - y1) * uy < 0 then
                    cornerDX, cornerDY, px, py = bx - x1, by - y1, x1, y1
                elseif (bx - x2) * ux + (by - y2) * uy > 0 then
                    cornerDX, cornerDY, px, py = bx - x2, by - y2, x2, y2
                end
            end
            if cornerDX then
                local cdx, cdy = (bx - px + 1) ^ 2, (by - py + 1) ^ 2
                local hitAngle = fmod(atan2(cornerDY, cornerDX) + 360, 360) + 90
                local ballAngle = fmod(atan2(ball.yVel, ball.xVel) + 360, 360)
                if corners == 0 then
                    corners = 1
                    first = { brick, px, py, cdx, cdy, dx, dy, hitAngle, ballAngle, cdx + cdy, m, count }
                else
                    if cdx + cdy <= first[10] then
                        setHit(brick, px, py, cdx, cdy, dx, dy, hitAngle, ballAngle, cdx + cdy, m, count)
                    else
                        setHit(unpack(first))
                    end
                    ball.gravMultiplier = 0
                    break
                end
            elseif distSq <= hit.bestDist then
                setHit(
                    brick,
                    px,
                    py,
                    distX,
                    distY,
                    dx,
                    dy,
                    fmod(atan2(dy, dx) + 360, 360),
                    fmod(atan2(ball.yVel, ball.xVel) + 360, 360),
                    distSq,
                    m,
                    count
                )
            end
        end
    end
end

-- Bounces the ball off the contact in Physics.hit. A glancing hit (deflection under twice
-- C.SLIDE_ANGLE) turns into a slide along the surface instead.
function Physics.ResolveSegmentHit(ball, forceRemove, simulate)
    local cx, cy = hit.bestCenterX, hit.bestCenterY
    local obj = hit.bestObj
    local ballAngle = hit.ballAngle
    local normal = hit.hitAngle - 90
    local gx, gy = cos(rad(normal)), sin(rad(normal))
    local along = -ball.xVel * gx - ball.yVel * gy
    local vx = ball.xVel + (1 + RESTITUTION) * gx * along
    local vy = ball.yVel + (1 + RESTITUTION) * gy * along
    local newAngle = fmod(atan2(vy, vx) + 360, 360)
    local slideAngle
    if ballAngle > newAngle then
        if ballAngle > 330 then
            if abs(newAngle + 360 - ballAngle) / 2 < C.SLIDE_ANGLE then
                slideAngle = normal - 90
            end
        elseif abs(newAngle - ballAngle) / 2 < C.SLIDE_ANGLE then
            slideAngle = normal + 90
        end
    elseif abs(newAngle - ballAngle) / 2 < C.SLIDE_ANGLE then
        slideAngle = normal - 90
    end
    if slideAngle then
        local speed = sqrt(ball.xVel * ball.xVel + ball.yVel * ball.yVel) * C.SLIDE_SPEED
        ball.xVel = speed * cos(rad(slideAngle))
        ball.yVel = speed * sin(rad(slideAngle))
    else
        game.slideCount = 0
        ball.xVel, ball.yVel = vx, vy
    end
    ball.x = cx + cos(rad(normal)) * (BALL_RADIUS + 0.1)
    ball.y = cy + sin(rad(normal)) * (BALL_RADIUS + 0.1)
    if not simulate then
        if slideAngle and game.slideCount >= 2 then
            -- The sparks fly along the bounce angle the slide replaced, as in the original.
            local Effects = ns.Effects
            Effects.SpawnParticle(cx + 1, cy, 0.2, newAngle + 180, 10, -1, "spark")
            Effects.SpawnParticle(cx, cy - 1, 0.2, newAngle + 181, 8, -1, "spark")
            Effects.SpawnParticle(cx - 1, cy, 0.2, newAngle + 182, 6, -1, "spark")
            Effects.SpawnParticle(cx, cy + 1, 0.2, newAngle + 183, 9, -1, "spark")
            Effects.SpawnParticle(cx, cy, 0.2, newAngle + 184, 7, -1, "spark")
        end
        if not obj.hit then
            if slideAngle then
                game.slideCount = game.slideCount + 1
                ns.Scoring.AwardStyleShot(C.STYLE_SLIDE, obj.x, obj.y)
            end
            firstHit(ball, obj)
        end
        obj.hitCount = obj.hitCount + 1
        if obj.hitCount > C.BRICK_MAX_CONTACTS then
            forceRemove = true
        end
        game.lastTouched = obj
        if forceRemove then
            removeObject(obj)
        end
    end
    hit.bestObj = nil
end

-- Bucket (catcher) outline: a near-vertex contact becomes a corner (bestDist -1).
-- Returns true when the ball touched it; the caller resolves the bounce.
function Physics.CollideCatcher(ball, catcher)
    local count = Physics.BuildPolygon(catcher, C.CATCHER_POLYGON)
    hit.bestDist = 1000
    local found = false
    local bx, by = ball.x, ball.y
    local radiusSq = BALL_RADIUS * BALL_RADIUS
    local x2, y2 = polygon[count - 1], polygon[count]
    for m = 1, count, 2 do
        local x1, y1 = x2, y2
        x2, y2 = polygon[m], polygon[m + 1]
        local dx, dy = x2 - x1, y2 - y1
        local t = ((bx - x1) * dx + (by - y1) * dy) / (dx * dx + dy * dy)
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end
        -- Same arithmetic as the original: at a shared corner two edges tie, and rounding picks one.
        local px, py = (1 - t) * x1 + t * x2, (1 - t) * y1 + t * y2
        local distSq = (bx - px) ^ 2 + (by - py) ^ 2
        if distSq < radiusSq and distSq < hit.bestDist then
            found = true
            if (x1 - bx) ^ 2 + (y1 - by) ^ 2 < 25 then
                hit.bestDist = -1
                hit.centerX, hit.centerY = x1, y1
            elseif (x2 - bx) ^ 2 + (y2 - by) ^ 2 < 25 then
                hit.bestDist = -1
                hit.centerX, hit.centerY = x2, y2
            else
                hit.bestDist = distSq
                hit.hitSeg = m
                hit.hitAngle = fmod(atan2(dy, dx) + 360, 360)
                hit.ballAngle = fmod(atan2(ball.yVel, ball.xVel) + 360, 360)
                hit.bestCenterX, hit.bestCenterY = px, py
                hit.centerX, hit.centerY = px, py
                hit.dxSeg, hit.dySeg = dx, dy
                hit.pDistX, hit.pDistY = bx - px, by - py
                hit.maxPoly = count
            end
        end
    end
    return found
end

-- Elastic collision between two balls of equal mass, rewound to the moment of contact.
-- Written as the original computed it, so rounding matches too.
function Physics.CollideBalls(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local dist = sqrt(dx ^ 2 + dy ^ 2)
    if dist > BALL_RADIUS * 2 or dist == 0 then
        return
    end
    local aN = a.xVel * dx / dist + a.yVel * dy / dist
    local bN = b.xVel * dx / dist + b.yVel * dy / dist
    if aN == bN then
        return
    end
    local back = (BALL_RADIUS + BALL_RADIUS - dist) / (aN - bN)
    a.x, a.y = a.x - a.xVel * back, a.y - a.yVel * back
    b.x, b.y = b.x - b.xVel * back, b.y - b.yVel * back
    dx, dy = b.x - a.x, b.y - a.y
    dist = sqrt(dx ^ 2 + dy ^ 2)
    if dist == 0 then
        return
    end
    local nx, ny = dx / dist, dy / dist
    aN = a.xVel * nx + a.yVel * ny
    local aT = -a.xVel * ny + a.yVel * nx
    bN = b.xVel * nx + b.yVel * ny
    local bT = -b.xVel * ny + b.yVel * nx
    local aN2 = aN + (1 + RESTITUTION) * (bN - aN) / 2
    local bN2 = bN + (1 + RESTITUTION) * (aN - bN) / 2
    a.xVel, a.yVel = aN2 * nx - aT * ny, aN2 * ny + aT * nx
    b.xVel, b.yVel = bN2 * nx - bT * ny, bN2 * ny + bT * nx
    a.x, a.y = a.x + a.xVel * back, a.y + a.yVel * back
    b.x, b.y = b.x + b.xVel * back, b.y + b.yVel * back
end
