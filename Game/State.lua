local _, ns = ...
local C = ns.C

-- Round state shared by the game modules (the original kept these as file-level locals).
-- ns.game is reset by ns.State.Reset at every level start.

local State = {}
ns.State = State

local game = {
    objects = {}, -- every peg and brick on the board (original animationStack)
    grid = {}, -- grid[row][col] = objects whose centre is in that cell
    balls = {}, -- balls in flight
    hitStack = {}, -- objects hit this shot, in order
    stats = { 0, 0, 0, 0, 0, 0, 0 },
    aimAngle = 270, -- launch angle; 270 points straight down
    cannonAngle = 270, -- drawn angle of the cannon (trajectory tangent near the muzzle)
    timeScale = 1,
    inProgress = false,
    readyToShoot = false,
    character = C.CHAR_GUIDE,
}
ns.game = game

-- Indexes into game.stats.
State.STAT_SHOTS, State.STAT_FREE_BALLS, State.STAT_PEGS_HIT = 1, 2, 3
State.STAT_TALENT, State.STAT_FEVER, State.STAT_STYLE, State.STAT_PEGS_TOTAL = 4, 5, 6, 7

for row = 1, C.GRID_SECTIONS do
    game.grid[row] = {}
    for col = 1, C.GRID_SECTIONS do
        game.grid[row][col] = {}
    end
end

function State.Reset()
    game.score = 0
    game.ballsLeft = 0
    game.orangeHit = 0
    game.orangeTotal = 0
    game.feverSegments = 0
    game.feverMultiplier = 1
    game.timeScale = 1
    game.totalHit = 0
    game.guideTurns = 0
    game.guideActive = nil
    game.guideMaxHits = 1
    game.catchStreak = 0
    game.madSkillzTier = 0
    game.lastZoomDist = nil
    game.sigh = nil
    game.lastPeg = nil
    game.readyToShoot = false
    game.speedy = nil
    game.feverUp = nil
    game.reclaim = nil
    game.freeBall = nil
    game.bannerMedal = nil
    game.levelFinished = nil
    game.freeRange = nil
    game.hasShot = false
    State.ResetShot()
    for i = 1, 6 do
        game.stats[i] = 0
    end
    wipe(game.hitStack)
end

-- Per-shot scoring accumulators (cleared after every shot's tally).
function State.ResetShot()
    game.shotPegPoints = 0 -- sum of each hit's floor(base * multiplier * crit)
    game.shotBasePoints = 0 -- same without crits (feeds the free-ball meter)
    game.shotPegTotal = 0 -- shotPegPoints * pegs hit: what the shot adds to the score
    game.shotStyleRaw = 0
    game.shotStyleTotal = 0
end

-- Talent rank, or 0 while talents are off (Peggle Loot).
function State.Talent(key)
    if game.lootActive then
        return 0
    end
    return ns.Progress.TalentRank(ns.TALENT[key])
end
