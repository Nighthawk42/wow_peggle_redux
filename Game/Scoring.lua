local _, ns = ...
local C = ns.C
local L = ns.L
local game = ns.game
local State = ns.State
local Util = ns.Util

-- Scoring for each peg hit, character powers, talents and style shots.
-- A shot scores (sum of each hit's points) x (pegs hit in the shot) + style points.

local Scoring = {}
ns.Scoring = Scoring

local floor, random = math.floor, math.random
local STYLE_KEYS = { "_STYLESHOT_1", "_STYLESHOT_2", "_STYLESHOT_3", "_STYLESHOT_4", "_STYLESHOT_5", "_STYLESHOT_6" }

-- Awards a style shot if its condition holds. Returns true when points were given.
function Scoring.AwardStyleShot(kind, x, y)
    local multiplier = 1 + State.Talent("style") * 0.02
    local key = STYLE_KEYS[kind]
    local points
    local hits = #game.hitStack
    if kind == C.STYLE_FREE_BALL then
        if (game.shotFlag == 1 and hits == 1) or game.shotFlag == 2 then
            points = C.STYLE_POINTS[kind]
        end
    elseif kind == C.STYLE_LONG or kind == C.STYLE_SUPER_LONG then
        points = C.STYLE_POINTS[kind]
    elseif kind == C.STYLE_MAD_SKILLZ then
        if game.shotFlag == 1 and hits > 0 then
            game.catchStreak = game.catchStreak + 1
            if game.catchStreak == 5 and game.madSkillzTier == 0 then
                game.madSkillzTier = 1
                points = C.STYLE_POINTS[kind]
            elseif game.catchStreak == 10 and game.madSkillzTier == 1 then
                game.madSkillzTier = 2
                points = C.CRAZY_MAD_SKILLZ_POINTS
                key = "_STYLESHOT_4a"
            end
            if points and hits == 1 then
                y = y + 10 -- clears the "FREE BALL SKILLS!" text drawn at the same spot
            end
        else
            game.catchStreak = 0
        end
    elseif kind == C.STYLE_SLIDE then
        if game.slideCount >= C.SLIDE_STYLE_COUNT then
            points = C.STYLE_POINTS[kind]
            game.slideCount = 0
        end
    elseif kind == C.STYLE_ORANGE_ATTACK then
        if game.orangeAttack >= 0 then
            points = C.STYLE_POINTS[kind]
            game.orangeAttack = -C.ORANGE_ATTACK_DEFAULT
        end
    end
    if not points then
        return
    end
    local awarded = floor(points * multiplier)
    game.shotStyleTotal = game.shotStyleTotal + awarded
    game.shotStyleRaw = game.shotStyleRaw + floor(points)
    ns.Effects.SpawnText(L[key] .. Util.CommaNumber(awarded), x, y, 0.4, 1, 1, 0, 0)
    return true
end

-- Every object within radius of (x, y) that isn't hit yet is hit by an explosion.
local function explode(x, y, radius, critChance)
    local radiusSq = radius * radius
    local objects = game.objects
    for i = 1, #objects do
        local obj = objects[i]
        if not obj.hit and (x - obj.x) ^ 2 + (y - obj.y) ^ 2 <= radiusSq then
            obj.hit = true
            Scoring.OnObjectHit(obj, nil, critChance)
            ns.Board.SetObjectArt(obj, true)
        end
    end
end

local function greenPower(obj)
    -- The original rolled "< rank * 10" here and for More Cowbell, one percent under the tooltip.
    local unintended = not game.lootActive and random(1, 100) <= State.Talent("unintended") * 10
    if game.character == C.CHAR_GUIDE then
        ns.Sound.Play(C.SOUND_POWERUP_GUIDE)
        game.guideTurns = game.guideTurns + C.GUIDE_TURNS
        ns.Effects.SpawnText(
            game.powerName .. "\n" .. L["_NEXT"] .. game.guideTurns .. L["_TURNS"],
            obj.x,
            obj.y,
            0.5,
            1,
            0.5,
            0,
            40,
            0.35
        )
        ns.HUD.ShowPowerLabel(L["_SPECIAL_NAME1"] .. " " .. game.guideTurns)
        game.guideMaxHits = 2
        game.guideActive = true
    else
        ns.Effects.SpawnText(game.powerName, obj.x, obj.y, 0.5, 1, 0.5, 0, 40, 0.35)
        ns.Effects.SpawnGlow(obj, nil, 2)
        ns.Sound.Play(C.SOUND_POWERUP_BLAST)
        -- The original spawned this glow twice; the two copies overlap exactly.
        ns.Effects.SpawnGlow(obj, nil, 2)
        explode(obj.x, obj.y, C.SPACE_BLAST_RADIUS, State.Talent("infusion") * 20)
    end
    if unintended then
        ns.Sound.Play(C.SOUND_POWERUP_BLAST)
        local purple
        for _, other in ipairs(game.objects) do
            if other.id == C.PEG_PURPLE then
                purple = other
                break
            end
        end
        if purple then
            ns.Effects.SpawnGlow(purple, nil, 1)
            explode(purple.x, purple.y, C.SMALL_BLAST_RADIUS, 0)
        end
    end
end

local function updateBonusBuckets()
    if game.stats[State.STAT_PEGS_HIT] == game.stats[State.STAT_PEGS_TOTAL] then
        ns.HUD.SetFeverBuckets(true)
    else
        ns.HUD.SetFeverBuckets(false)
    end
end

-- Scores an object on its first hit. echo: Double Fission re-scoring an earlier hit.
-- critOverride: crit chance forced by a blast (Infusion of Awesome) or 0 for no crit.
function Scoring.OnObjectHit(obj, echo, critOverride)
    local base = 0
    local multiplier = game.feverMultiplier
    local crit = 1
    if not game.lootActive then
        local critChance = State.Talent("marksman") * 5
        if critOverride and critOverride > 0 then
            critChance = critOverride
        end
        if game.character == C.CHAR_GUIDE and game.shotFlag == true and #game.hitStack < 2 then
            critChance = State.Talent("infusion") * 20
        end
        if not echo and random(1, 100) <= critChance then
            crit = C.CRIT_MULTIPLIER + State.Talent("missionCritical") * 0.1
            ns.Effects.SpawnGlow(obj, true)
        end
    end
    if game.orangeHit >= game.orangeTotal then
        multiplier = C.FEVER_MULTIPLIER
    end

    local last = game.lastTouched
    if last and last.id ~= C.PEG_BLUE and obj.id ~= C.PEG_BLUE then
        local distance = math.sqrt((last.x - obj.x) ^ 2 + (last.y - obj.y) ^ 2)
        if distance >= C.SUPER_LONG_SHOT then
            Scoring.AwardStyleShot(C.STYLE_SUPER_LONG, obj.x, obj.y)
        elseif distance >= C.LONG_SHOT then
            Scoring.AwardStyleShot(C.STYLE_LONG, obj.x, obj.y)
        end
        game.lastTouched = obj
    end

    if obj.id == C.PEG_ORANGE then
        base = C.POINTS[C.PEG_ORANGE]
        if not echo then
            game.orangeHit = game.orangeHit + 1
            ns.HUD.FeverAddSegment()
        end
        game.orangeAttack = game.orangeAttack + 1
        Scoring.AwardStyleShot(C.STYLE_ORANGE_ATTACK, obj.x, obj.y)
        if game.orangeHit == game.orangeTotal - 1 then
            for _, other in ipairs(game.objects) do
                if other.id == C.PEG_ORANGE and not other.hit then
                    game.lastPeg = other
                    break
                end
            end
        end
    elseif obj.id == C.PEG_PURPLE then
        ns.Sound.Play(C.SOUND_POWERUP)
        base = game.orangeHit >= game.orangeTotal and C.PURPLE_FEVER_POINTS or C.POINTS[C.PEG_PURPLE]
        local text = (critOverride and critOverride ~= 0) and L["_TALENT8_NAME"] or L["_POINT_BOOST"]
        ns.Effects.SpawnText(text, obj.x, obj.y, 1, 0.5, 1, 0, 40, 0.35)
        if not game.lootActive then
            local cowbell = State.Talent("cowbell")
            if cowbell > 0 and random(1, 100) <= cowbell * 10 then
                ns.HUD.FeverAddSegment()
            end
            if State.Talent("fission") > 0 then
                for i = 1, #game.hitStack do
                    Scoring.OnObjectHit(game.hitStack[i], true)
                end
            end
        end
    elseif obj.id == C.PEG_GREEN then
        base = C.POINTS[C.PEG_GREEN]
        if not echo then
            greenPower(obj)
        end
    else
        base = C.POINTS[C.PEG_BLUE]
    end

    if not echo then
        ns.Effects.SpawnGlow(obj)
        game.totalHit = game.totalHit + 1
        table.insert(game.hitStack, obj)
        game.stats[State.STAT_PEGS_HIT] = game.stats[State.STAT_PEGS_HIT] + 1
        updateBonusBuckets()
        ns.Sound.PegHit(#game.hitStack, game.freeRange)
    end

    local hits = #game.hitStack
    game.shotBasePoints = game.shotBasePoints + base * multiplier
    local points = floor(base * multiplier * crit)
    game.shotPegPoints = game.shotPegPoints + points
    game.shotPegTotal = game.shotPegPoints * hits
    if echo then
        ns.Effects.SpawnText(points, obj.x + 3, obj.y + 3, nil, nil, nil, nil, nil, 0.1, crit ~= 1)
    else
        ns.Effects.SpawnText(points, obj.x, obj.y - 15, nil, nil, nil, nil, nil, nil, crit ~= 1)
    end
    ns.HUD.SetMeter(game.shotBasePoints * hits)
end

-- After each shot: recolour the purple peg (and Rolling Ignition greens), drop hit objects and
-- check whether every orange peg is gone.
function Scoring.EndShotCleanup()
    local objects = game.objects
    local purples, ignitions = 0, 0
    local i = 1
    for _ = 1, #objects do
        local obj = objects[i]
        if obj.id == C.PEG_PURPLE then
            purples = purples + 1
            Scoring.SetColorKeepHit(obj, C.PEG_BLUE)
        end
        if obj.hit then
            if game.shotFlag == 1 and obj.id == C.PEG_GREEN and State.Talent("ignition") == 1 then
                ignitions = ignitions + 1
            end
            ns.Level.GridRemove(obj)
            ns.Board.ReleaseObject(table.remove(objects, i))
        else
            i = i + 1
        end
    end
    local finished = true
    for _, obj in ipairs(objects) do
        if obj.required then
            if game.orangeHit == game.orangeTotal - 1 then
                game.lastPeg = obj
            end
            finished = false
        end
    end
    local blues = {}
    for row = 1, C.GRID_SECTIONS do
        for col = 1, C.GRID_SECTIONS do
            for _, obj in ipairs(game.grid[row][col]) do
                if obj.id == C.PEG_BLUE then
                    table.insert(blues, obj)
                end
            end
        end
    end
    for n = 1, purples + ignitions do
        if #blues > 0 then
            local obj = table.remove(blues, random(1, #blues))
            ns.Level.SetColor(obj, n <= ignitions and C.PEG_GREEN or C.PEG_PURPLE)
        end
    end
    if finished and game.inProgress then
        ns.Game.FinishLevel()
    end
end

-- Recolours without touching the lit state (used on hit objects that are about to go).
function Scoring.SetColorKeepHit(obj, id)
    obj.id = id
    ns.Board.SetObjectArt(obj, obj.hit)
end
