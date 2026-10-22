local _, ns = ...
local C = ns.C
local game = ns.game

-- Board objects: building a level, colouring pegs, the spatial grid and moving pegs.

local Level = {}
ns.Level = Level

local floor, fmod, cos, sin, rad, random, pi = math.floor, math.fmod, math.cos, math.sin, math.rad, math.random, math.pi
local SECTIONS = C.GRID_SECTIONS

-- Grid cell of a board position, or nil outside the board.
function Level.Cell(x, y)
    local col = floor(x / C.SECTION_WIDTH) + 1
    local row = floor(y / C.SECTION_HEIGHT) + 1
    if col < 1 or col > SECTIONS or row < 1 or row > SECTIONS then
        return nil
    end
    return col, row
end

function Level.GridInsert(obj, col, row)
    if not col then
        col, row = Level.Cell(obj.x, obj.y)
        if not col then
            return
        end
    end
    local cell = game.grid[row][col]
    for i = 1, #cell do
        if cell[i] == obj then
            return
        end
    end
    table.insert(cell, obj)
end

function Level.GridRemove(obj, col, row)
    if not col then
        col, row = Level.Cell(obj.x, obj.y)
        if not col then
            return
        end
    end
    local cell = game.grid[row][col]
    for i = 1, #cell do
        if cell[i] == obj then
            table.remove(cell, i)
            return
        end
    end
end

function Level.ClearGrid()
    for row = 1, SECTIONS do
        for col = 1, SECTIONS do
            wipe(game.grid[row][col])
        end
    end
end

-- Movement along a line: value4 > 0 gives a distance along angle value3, otherwise the end
-- point is (value1, value2). Reversing movers ease back and forth on a cosine.
local function moveLine(obj)
    local t
    if obj.reverser then
        t = 1 - (cos(2 * pi * obj.elapsed / obj.loopTime) + 1) / 2
    else
        t = obj.elapsed / obj.loopTime
    end
    local dx, dy
    if obj.value4 and obj.value4 > 0 then
        dx = obj.value4 * -cos(rad(obj.value3))
        dy = obj.value4 * -sin(rad(obj.value3))
    else
        dx = obj.startX - obj.value1
        dy = obj.startY - obj.value2
    end
    obj.x = obj.startX - t * dx
    obj.y = obj.startY - t * dy
end
Level.MoveLine = moveLine

local function moveCircle(obj)
    local angle = rad(360 * obj.elapsed / obj.loopTime)
    obj.x = obj.startX + cos(angle) * (obj.value1 + 8.5) * 0.85
    obj.y = obj.startY + sin(angle) * (obj.value2 + 8.5) * 0.85
end

local function rotate(obj)
    if obj.isBrick then
        obj.rotation = fmod(obj.elapsed / obj.loopTime * 360 + 135, 360)
        ns.Board.RotateTexture(obj.texture, floor(obj.rotation))
    end
end

-- Advances a moving peg or brick and keeps its grid cell current.
function Level.UpdateMover(obj, elapsed)
    local moveType = obj.moveType
    if moveType <= 0 then
        return
    end
    obj.elapsed = obj.elapsed + elapsed
    if obj.elapsed > obj.loopTime then
        obj.elapsed = fmod(obj.elapsed, obj.loopTime)
    end
    local oldCol, oldRow = Level.Cell(obj.x, obj.y)
    if moveType == C.MOVE_LINE then
        moveLine(obj)
    elseif moveType == C.MOVE_CIRCLE then
        moveCircle(obj)
    elseif moveType == C.MOVE_ROTATE then
        rotate(obj)
    elseif moveType == C.MOVE_LINE_ROTATE then
        moveLine(obj)
        rotate(obj)
    elseif moveType == C.MOVE_CIRCLE_ROTATE then
        moveCircle(obj)
        rotate(obj)
    end
    local col, row = Level.Cell(obj.x, obj.y)
    if col ~= oldCol or row ~= oldRow then
        if oldCol then
            Level.GridRemove(obj, oldCol, oldRow)
        end
        Level.GridInsert(obj, col, row)
    end
    ns.Board.Place(obj)
    if obj.inactive then
        obj.moveType = 0
        obj.inactive = nil
    end
end

-- Builds every object of a level, all blue. Returns the object list in level-data order.
function Level.Build(level)
    local objects = {}
    for index, data in ipairs(ns.Levels[level].objects) do
        local kind = data[1]
        local obj
        if kind == C.KIND_PEG then
            obj = ns.Board.AcquirePeg()
        else
            obj = ns.Board.AcquireBrick()
            obj.radius = kind == C.KIND_STRAIGHT_BRICK and 0 or data.r
        end
        obj.index = index
        obj.x, obj.y = data[2], data[3]
        obj.xVel, obj.yVel = 0, 0
        obj.radius = obj.radius or 0
        obj.rotation = fmod((data.rot or 0) + 135, 360)
        obj.hit = nil
        obj.hitCount = 0
        obj.required = nil
        local anim = data.anim
        if anim then
            obj.moveType = anim[1]
            obj.loopTime = anim[2]
            obj.elapsed = anim[2] * (anim[3] / 100)
            obj.reverser = anim[4]
            obj.inactive = not anim[5] or nil
            obj.startX, obj.startY = obj.x, obj.y
            obj.value1, obj.value2, obj.value3, obj.value4 = anim[6], anim[7], anim[8], anim[9]
        else
            obj.moveType = C.MOVE_NONE
            obj.reverser = true
            obj.inactive = nil
            obj.loopTime, obj.elapsed = nil, nil
        end
        Level.SetColor(obj, C.PEG_BLUE)
        if obj.isBrick then
            ns.Board.RotateTexture(obj.texture, obj.rotation)
        end
        ns.Board.Place(obj)
        Level.UpdateMover(obj, 0)
        Level.GridInsert(obj)
        objects[index] = obj
        table.insert(game.objects, obj)
    end
    return objects
end

function Level.SetColor(obj, id)
    obj.id = id
    obj.required = id == C.PEG_ORANGE or nil
    ns.Board.SetObjectArt(obj, false)
end

local function distanceSq(a, b)
    return (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2
end

-- 28 distinct object indices: 25 orange, 2 green at least C.GREEN_MIN_DISTANCE apart, 1 purple.
-- The original compared the second green against a stale pool slot; this compares against the
-- first green itself, and gives up on the spacing rule if no candidate qualifies.
function Level.RandomLayout(level)
    local objects = ns.Levels[level].objects
    local pool = {}
    for i = 1, #objects do
        pool[i] = i
    end
    local layout = {}
    for _ = 1, C.ORANGE_COUNT do
        table.insert(layout, table.remove(pool, random(1, #pool)))
    end
    local minDistanceSq = C.GREEN_MIN_DISTANCE ^ 2
    local firstGreen
    for _ = 1, C.GREEN_COUNT do
        local pick = random(1, #pool)
        if firstGreen then
            local candidates = {}
            for i, index in ipairs(pool) do
                if distanceSq(objects[index], objects[firstGreen]) >= minDistanceSq then
                    table.insert(candidates, i)
                end
            end
            if #candidates > 0 then
                pick = candidates[random(1, #candidates)]
            end
        end
        local index = table.remove(pool, pick)
        firstGreen = firstGreen or index
        table.insert(layout, index)
    end
    table.insert(layout, table.remove(pool, random(1, #pool)))
    return layout
end

-- True if layout is 28 distinct indices of objects in the level.
function Level.IsValidLayout(level, layout)
    local count = ns.Levels[level] and #ns.Levels[level].objects
    if not count or type(layout) ~= "table" or #layout ~= C.LAYOUT_SIZE then
        return false
    end
    local seen = {}
    for _, index in ipairs(layout) do
        if type(index) ~= "number" or index ~= floor(index) or index < 1 or index > count or seen[index] then
            return false
        end
        seen[index] = true
    end
    return true
end

ns.Levels.RandomLayout = Level.RandomLayout
ns.Levels.IsValidLayout = Level.IsValidLayout
