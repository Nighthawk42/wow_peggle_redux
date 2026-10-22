local _, ns = ...
local C = ns.C
local game = ns.game

-- The play area: board frame (inside a clipping scroll frame so the zoom stays in bounds),
-- pooled sprites for pegs, bricks and balls, and the aim preview pieces.

local Board = {}
ns.Board = Board

local sin, cos, rad, min = math.sin, math.cos, math.rad, math.min
local ART = C.ART_PATH
local TRAIL_LENGTH = 30

local pegPool, brickPool, ballPool = {}, {}, {}
local guideLines, pathPieces = {}, {}
local guideLineCount, pathPieceCount = 0, 0

-- Rotates a square texture's coordinates about its centre; 135 degrees draws it upright.
function Board.RotateTexture(texture, angle)
    local s = sin(rad(angle)) * 0.71
    local c = cos(rad(angle)) * 0.71
    texture:SetTexCoord(0.5 - s, 0.5 + c, 0.5 + c, 0.5 + s, 0.5 - c, 0.5 - s, 0.5 + s, 0.5 - c)
end

-- Positions a sprite at board coordinates.
function Board.Place(obj)
    local texture = obj.texture
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", Board.frame, "BOTTOMLEFT", obj.x, obj.y)
end

local function newSprite(size, layer)
    local texture = Board.foreground:CreateTexture(nil, layer)
    texture:SetSize(size, size)
    return texture
end

function Board.AcquirePeg()
    local obj = table.remove(pegPool)
    if not obj then
        obj = { isPeg = true, texture = newSprite(C.PEG_SIZE, "BACKGROUND") }
    end
    obj.texture:Show()
    obj.texture:SetAlpha(1)
    return obj
end

function Board.AcquireBrick()
    local obj = table.remove(brickPool)
    if not obj then
        obj = { isBrick = true, texture = newSprite(C.BRICK_SIZE, "BACKGROUND") }
    end
    obj.radius = nil
    obj.texture:Show()
    obj.texture:SetAlpha(1)
    return obj
end

-- Unlit or lit art for a peg or brick in its current colour.
function Board.SetObjectArt(obj, lit)
    local colorBlind = ns.db.profile.colorBlindMode
    local id = obj.id
    if obj.isPeg then
        obj.texture:SetTexture(ART .. (colorBlind and "pegs_" or "pegs"))
        obj.texture:SetTexCoord((id - 1) * 0.25, id * 0.25, lit and 0.5 or 0, lit and 1 or 0.5)
    else
        -- Orange has no colour-blind variant, and neither do lit blue bricks.
        local suffix = ""
        if colorBlind and ((lit and id > C.PEG_ORANGE) or (not lit and id ~= C.PEG_ORANGE)) then
            suffix = "_"
        end
        local file = C.BRICK_TEXTURES[id] .. "Brick" .. C.CURVED_BRICK[obj.radius] .. (lit and "a" or "") .. suffix
        obj.texture:SetTexture(ART .. file)
        Board.RotateTexture(obj.texture, obj.rotation)
    end
end

function Board.HideObject(obj)
    obj.texture:Hide()
end

function Board.ReleaseObject(obj)
    obj.texture:Hide()
    obj.hit = nil
    table.insert(obj.isPeg and pegPool or brickPool, obj)
end

-- Balls carry a 30-segment trail coloured red, green, blue along its length. The trail only
-- shows after the ball hits the last orange peg.
local function newBall()
    local ball = { isBall = true, texture = newSprite(C.BALL_SIZE, "OVERLAY"), trail = {} }
    ball.texture:SetTexture(ART .. "ball")
    local r, g, b = 1, 0, 0
    local dr, dg, db = -0.1, 0.1, 0
    for i = 1, TRAIL_LENGTH do
        local segment = newSprite(C.BALL_SIZE, "ARTWORK")
        segment:SetTexture(ART .. "ballTrail")
        segment:SetVertexColor(r, g, b)
        segment:SetAlpha(min((35 - i) / 30, 1))
        r, g, b = r + dr, g + dg, b + db
        if i == 10 then
            dr, dg, db = 0, 0, 0.1
        elseif i == 20 then
            dr, dg, db = 0.1, -0.1, 0
        end
        segment:Hide()
        ball.trail[i] = { texture = segment, x = -1000, y = -1000 }
    end
    return ball
end

function Board.SpawnBall(x, y, angle, speed)
    local ball = table.remove(ballPool) or newBall()
    ball.x, ball.y = x, y
    ball.xVel = cos(rad(angle)) * speed
    ball.yVel = sin(rad(angle)) * speed
    ball.gravMultiplier = 1
    ball.trailActive = nil
    for _, segment in ipairs(ball.trail) do
        segment.x, segment.y = -1000, -1000
        segment.texture:Hide()
    end
    Board.Place(ball)
    ball.texture:SetAlpha(1)
    ball.texture:Show()
    table.insert(game.balls, ball)
    return ball
end

function Board.ResetTrail(ball)
    for _, segment in ipairs(ball.trail) do
        segment.x, segment.y = -100, -100
        segment.texture:Hide()
    end
    ball.trailActive = true
end

function Board.ShiftTrail(ball)
    local trail = ball.trail
    for k = TRAIL_LENGTH, 2, -1 do
        trail[k].x, trail[k].y = trail[k - 1].x, trail[k - 1].y
    end
    trail[1].x, trail[1].y = ball.x, ball.y
end

function Board.PlaceBall(ball)
    if ball.trailActive then
        for _, segment in ipairs(ball.trail) do
            if segment.x > -100 then
                segment.texture:ClearAllPoints()
                segment.texture:SetPoint("CENTER", Board.frame, "BOTTOMLEFT", segment.x, segment.y)
                segment.texture:Show()
            end
        end
    end
    Board.Place(ball)
end

function Board.ReleaseBall(ball)
    ball.texture:Hide()
    for _, segment in ipairs(ball.trail) do
        segment.texture:Hide()
    end
    table.insert(ballPool, ball)
end

-- Aim preview

function Board.HideGuide()
    for i = 1, guideLineCount do
        guideLines[i]:Hide()
    end
    for i = 1, pathPieceCount do
        pathPieces[i]:Hide()
    end
    guideLineCount, pathPieceCount = 0, 0
end

function Board.GuideLineCount()
    return guideLineCount
end

function Board.PathPieceCount()
    return pathPieceCount
end

-- Super Guide line segment, in board coordinates.
function Board.GuideLine(x1, y1, x2, y2)
    guideLineCount = guideLineCount + 1
    local line = guideLines[guideLineCount]
    if not line then
        line = Board.foreground:CreateLine(nil, "OVERLAY")
        line:SetTexture(ART .. "pathLine")
        line:SetVertexColor(0.3, 0.7, 1)
        line:SetAlpha(0.8)
        line:SetThickness(32)
        guideLines[guideLineCount] = line
    end
    line:SetStartPoint("BOTTOMLEFT", Board.frame, x1, y1)
    line:SetEndPoint("BOTTOMLEFT", Board.frame, x2, y2)
    line:Show()
end

-- Trajectory dot: kind is "Square", "Edge" (the last, fading dot) or "Circle" (a bounce).
function Board.PathPiece(x, y, angle, kind)
    pathPieceCount = pathPieceCount + 1
    local piece = pathPieces[pathPieceCount]
    if not piece then
        piece = Board.foreground:CreateTexture(nil, "OVERLAY")
        piece:SetSize(16, 16)
        pathPieces[pathPieceCount] = piece
    end
    piece:SetTexture(ART .. "path" .. kind)
    piece:ClearAllPoints()
    piece:SetPoint("CENTER", Board.frame, "BOTTOMLEFT", x, y)
    Board.RotateTexture(piece, angle)
    piece:Show()
end

-- Zoom toward a board region ("TOPLEFT", "BOTTOM", "CENTER", ...); nil restores the normal view.
function Board.SetZoom(anchor, scale)
    local frame = Board.frame
    frame:ClearAllPoints()
    if anchor then
        frame:SetPoint(anchor)
        frame:SetScale(scale)
        ns.HUD.SetCatcherAlpha(0)
    else
        frame:SetPoint("CENTER")
        frame:SetScale(1)
        ns.HUD.SetCatcherAlpha(1)
    end
end

-- Extreme Fever eases the last-peg zoom back out, 0.01 scale per tick.
function Board.ZoomOutStep()
    local scale = Board.frame:GetScale()
    if scale > 1.001 then
        scale = scale - 0.01
        if scale < 1 then
            Board.SetZoom(nil)
            return
        end
        Board.frame:SetScale(scale)
    end
end

function Board.ReleaseAll()
    for i = #game.objects, 1, -1 do
        Board.ReleaseObject(table.remove(game.objects, i))
    end
    for i = #game.balls, 1, -1 do
        Board.ReleaseBall(table.remove(game.balls, i))
    end
    Board.HideGuide()
end

ns.RegisterBuilder("Board", function()
    local window = ns.addon.window
    local container = CreateFrame("ScrollFrame", nil, window)
    container:SetSize(C.BOARD_WIDTH, C.BOARD_HEIGHT)
    container:SetPoint("TOPLEFT", C.BOARD_LEFT, C.BOARD_TOP)
    container:SetFrameLevel(window:GetFrameLevel() + 2)
    Board.container = container
    table.insert(window.scaledFrames, container)

    local frame = CreateFrame("Frame", nil, container)
    frame:SetSize(C.BOARD_WIDTH, C.BOARD_HEIGHT)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    container:SetScrollChild(frame)
    Board.frame = frame

    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetSize(C.BOARD_WIDTH, C.BOARD_WIDTH)
    background:SetPoint("CENTER", 0, -2)
    Board.background = background

    local foreground = CreateFrame("Frame", nil, frame)
    foreground:SetAllPoints()
    foreground:SetFrameLevel(frame:GetFrameLevel() + 1)
    Board.foreground = foreground

    local fineX, fineY
    frame:SetScript("OnMouseDown", function(_, button)
        ns.Aim.OnMouseDown(button)
    end)
    frame:SetScript("OnMouseUp", function()
        ns.Aim.OnMouseUp()
    end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        ns.Aim.Nudge(delta)
        fineX, fineY = GetCursorPosition()
    end)
    frame:SetScript("OnUpdate", function(self)
        if ns.Game.IsOverlayShown() or ns.Game.IsPaused() then
            return
        end
        local cx, cy = GetCursorPosition()
        if fineX then
            if math.abs(fineX - cx) < 5 and math.abs(fineY - cy) < 5 then
                return
            end
            fineX, fineY = nil, nil
        end
        local left, bottom, width, height = self:GetRect()
        if not left then
            return
        end
        local scale = self:GetEffectiveScale()
        local x, y = cx / scale - left, cy / scale - bottom
        if x >= 0 and x <= width and y >= 0 and y <= height then
            ns.Aim.OnCursor(x, y)
        end
    end)
end)

function Board.SetBackground(level)
    Board.background:SetTexture(ART .. "bg" .. level)
end

