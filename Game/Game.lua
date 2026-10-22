local _, ns = ...
local Peggle = ns.addon
local C = ns.C
local L = ns.L
local game = ns.game
local State = ns.State

-- Round flow: starting a level, the end of a level, and switching between board and menu.
-- Fires "PEGGLE_LEVEL_END" (result), "PEGGLE_LEVEL_ABANDONED" (mode) and
-- "PEGGLE_SUMMARY_CLOSED" (mode). result = { level, mode, score, character, medal (C.MEDAL_*
-- earned this round), beaten, cleared (level counts after saving), stats = { shots, freeBalls,
-- pegsHit, talentScore, feverScore, styleScore, pegsTotal } }.

local Game = {}
ns.Game = Game

local currentOptions
local onBoard = false

function Game.IsInProgress()
    return game.inProgress
end

function Game.GetMode()
    return game.mode
end

function Game.GetLevel()
    return game.level
end

function Game.GetScore()
    return game.score or 0
end

function Game.GetCharacter()
    return game.character
end

function Game.HasShot()
    return game.hasShot
end

function Game.IsShotInFlight()
    return #game.balls > 0 or game.reclaim
end

-- The board stops while the menu or the game menu covers it.
function Game.IsPaused()
    return not onBoard or ns.GameMenu.IsShown()
end

-- Overlays that block aiming and shooting.
function Game.IsOverlayShown()
    return ns.CharacterSelect.IsShown() or ns.Summary.IsShown() or ns.GameMenu.IsShown()
end

function Game.ShowMenu()
    onBoard = false
    ns.GameMenu.Hide()
    ns.Summary.Hide()
    ns.Board.container:Hide()
    Peggle.window.artBorder:Hide()
    ns.HUD.SetRoundShown(false)
    ns.Menu.Show()
    game.readyToShoot = false
    ns.MainWindow.SetMenuButtonEnabled(game.inProgress)
end

function Game.ShowBoard()
    onBoard = true
    ns.GameMenu.Hide()
    ns.Menu.Hide()
    ns.Board.container:Show()
    Peggle.window.artBorder:Show()
    ns.HUD.SetRoundShown(true)
    ns.MainWindow.SetMenuButtonEnabled(true)
end

local function clearBoard()
    ns.Engine.Reset()
    ns.Engine.ResetZoom()
    ns.Effects.Clear()
    ns.Board.ReleaseAll()
    ns.Level.ClearGrid()
    ns.HUD.ResetRound()
    ns.HUD.ResetTube(true)
end

local function applyLayout(objects, layout)
    game.orangeTotal = 0
    for slot, index in ipairs(layout) do
        local obj = objects[index]
        if slot <= C.ORANGE_COUNT then
            ns.Level.SetColor(obj, C.PEG_ORANGE)
            game.orangeTotal = game.orangeTotal + 1
        elseif slot <= C.ORANGE_COUNT + C.GREEN_COUNT then
            ns.Level.SetColor(obj, C.PEG_GREEN)
        else
            ns.Level.SetColor(obj, C.PEG_PURPLE)
        end
    end
end

-- options: mode ("quick", "duel", "battle", "loot"), layout (28 object indices), balls.
function Game.Start(level, options)
    options = options or {}
    local mode = options.mode or "quick"
    local layout = options.layout
    if not layout or not ns.Level.IsValidLayout(level, layout) then
        layout = ns.Level.RandomLayout(level)
    end
    currentOptions = { mode = mode, layout = layout, balls = options.balls }

    clearBoard()
    State.Reset()
    game.level = level
    game.mode = mode
    game.lootActive = mode == "loot" or nil
    game.inProgress = true
    game.aimAngle = 270

    ns.Board.SetBackground(level)
    local objects = ns.Level.Build(level)
    applyLayout(objects, layout)
    game.stats[State.STAT_PEGS_TOTAL] = #game.objects

    ns.HUD.SetScore(0)
    ns.HUD.SetBest(ns.Progress.GetBest(level))
    if mode == "loot" then
        ns.HUD.SetTimerCaption(string.format(L["SCORE_TIME_LEFT"] .. " sec", 30))
    elseif mode == "duel" then
        ns.HUD.SetTimerCaption(string.format(L["SCORE_TIME_LEFT"], "4m 59s"))
    else
        ns.HUD.SetTimerCaption(nil)
    end
    ns.HUD.FeverReset()
    ns.HUD.ResetMeter()
    ns.HUD.ResetCatcher()

    local balls = mode == "loot" and 1 or options.balls or C.BALLS_PER_LEVEL
    for _ = 1, balls do
        ns.HUD.AddBall()
    end
    ns.HUD.LoadNextBall()

    if mode == "loot" then
        Game.SetCharacter(C.CHAR_BLAST)
        ns.CharacterSelect.Hide()
    else
        Game.SetCharacter(ns.db.char.character or C.CHAR_GUIDE)
        ns.CharacterSelect.Show()
    end
    for _ = 1, State.Talent("stepAhead") do
        ns.HUD.FeverAddSegment()
    end
    ns.HUD.FeverCommit(5)
    Game.ShowBoard()
    game.readyToShoot = false
end

function Game.SetCharacter(character)
    game.character = character
    game.guideTurns = 0
    game.powerName = character == C.CHAR_GUIDE and L["_SPECIAL_NAME1"] or L["_SPECIAL_NAME2"]
    ns.HUD.SetCharacterFace(character)
end

-- Restart with the same layout (Quick Play only; the game menu disables it elsewhere).
function Game.Restart()
    if currentOptions then
        Game.Start(game.level, currentOptions)
    end
end

-- The loaded ball reached the cannon.
function Game.BallLoaded()
    game.readyToShoot = true
    ns.HUD.ShowLoadedBall()
end

local function buildResult(medal)
    local stats = game.stats
    local beaten, cleared = ns.Progress.GetCounts()
    return {
        level = game.level,
        mode = game.mode,
        score = game.score,
        character = game.character,
        medal = medal,
        beaten = beaten,
        cleared = cleared,
        stats = {
            shots = stats[State.STAT_SHOTS],
            freeBalls = stats[State.STAT_FREE_BALLS],
            pegsHit = stats[State.STAT_PEGS_HIT],
            talentScore = stats[State.STAT_TALENT],
            feverScore = stats[State.STAT_FEVER],
            styleScore = stats[State.STAT_STYLE],
            pegsTotal = stats[State.STAT_PEGS_TOTAL],
        },
    }
end

-- Every orange peg is gone. The summary follows the tally fade (and the banner if the level's
-- medal improved).
function Game.FinishLevel()
    game.inProgress = false
    ns.HUD.SetScore(game.score)
    local stats = game.stats
    local medal = stats[State.STAT_PEGS_HIT] == stats[State.STAT_PEGS_TOTAL] and C.MEDAL_CLEARED or C.MEDAL_BEATEN
    game.bannerMedal = ns.Progress.RecordResult(game.level, game.score, medal)
    game.levelFinished = true
    game.result = buildResult(medal)
    Peggle:SendMessage("PEGGLE_LEVEL_END", game.result)
end

-- The tube is empty and the shot is over.
function Game.OutOfBalls()
    if not game.inProgress then
        return
    end
    game.inProgress = false
    ns.Progress.RecordResult(game.level, game.score, C.MEDAL_NONE)
    game.result = buildResult(C.MEDAL_NONE)
    Peggle:SendMessage("PEGGLE_LEVEL_END", game.result)
    ns.Summary.Show()
end

function Game.Abandon()
    local mode = game.mode
    local wasInProgress = game.inProgress
    game.inProgress = false
    for i = #game.balls, 1, -1 do
        ns.Board.ReleaseBall(table.remove(game.balls, i))
    end
    game.reclaim = nil
    Game.ShowMenu()
    if wasInProgress then
        Peggle:SendMessage("PEGGLE_LEVEL_ABANDONED", mode)
    end
end

-- Peggle Loot time-out: balls in flight drop out so the shot (and the score) finishes now.
function Game.ForceEndShot()
    for _, ball in ipairs(game.balls) do
        ball.x, ball.y = 0, -100
        ball.xVel, ball.yVel = 0, 0
    end
end

-- The summary's OK button.
function Game.SummaryClosed()
    local mode = game.mode
    Game.ShowMenu()
    Peggle:SendMessage("PEGGLE_SUMMARY_CLOSED", mode)
end

-- Created after every other frame so the tubes update before the engine within a frame, as in
-- the original (it keeps ball loading on the same frame timing).
ns.RegisterEnabler("Engine", function()
    local engine = CreateFrame("Frame", nil, UIParent)
    engine:SetScript("OnUpdate", ns.Engine.OnUpdate)
    Game.engineFrame = engine
end)
