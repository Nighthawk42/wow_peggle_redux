local _, ns = ...
local C = ns.C

-- Level results and talents (ns.db.global.progress). A level is beaten when every orange peg is
-- hit and fully cleared when every peg is; each earns one talent point.

local Progress = {}
ns.Progress = Progress

local function data()
    return ns.db.global.progress
end

function Progress.GetBest(level)
    return data().best[level] or 0
end

function Progress.GetRecent(level)
    return data().recent[level]
end

function Progress.GetMedal(level)
    return data().medal[level] or C.MEDAL_NONE
end

-- Stores a finished level. medal is C.MEDAL_NONE when the balls ran out first.
-- Returns the medal if it improved on the stored one, and whether the score is a new best.
function Progress.RecordResult(level, score, medal)
    local progress = data()
    progress.recent[level] = score
    local newBest = score > (progress.best[level] or 0)
    if newBest then
        progress.best[level] = score
    end
    local improved
    if medal > (progress.medal[level] or C.MEDAL_NONE) then
        progress.medal[level] = medal
        improved = medal
    end
    ns.addon:SendMessage("PEGGLE_PROGRESS_CHANGED")
    return improved, newBest
end

-- Levels beaten and fully cleared; the summary that duels and battles share with opponents.
function Progress.GetCounts()
    local beaten, cleared = 0, 0
    for level = 1, C.NUM_LEVELS do
        local medal = Progress.GetMedal(level)
        if medal >= C.MEDAL_BEATEN then
            beaten = beaten + 1
        end
        if medal >= C.MEDAL_CLEARED then
            cleared = cleared + 1
        end
    end
    return beaten, cleared
end

-- Talents

function Progress.TalentRank(id)
    return data().talents[id] or 0
end

function Progress.PointsEarned()
    local beaten, cleared = Progress.GetCounts()
    return beaten + cleared
end

function Progress.PointsSpent()
    local spent = 0
    for id = 1, #ns.Talents do
        spent = spent + Progress.TalentRank(id)
    end
    return spent
end

function Progress.PointsAvailable()
    return Progress.PointsEarned() - Progress.PointsSpent()
end

-- Why a talent can't take another point: "maxed", "prerequisite", "tier", "points"; nil if it can.
function Progress.LearnBlocker(id)
    local talent = ns.Talents[id]
    local rank = Progress.TalentRank(id)
    if rank >= talent.maxRank then
        return "maxed"
    end
    if talent.requires and Progress.TalentRank(talent.requires) < ns.TALENT_POINTS_PER_TIER then
        return "prerequisite"
    end
    if Progress.PointsSpent() < talent.tier * ns.TALENT_POINTS_PER_TIER then
        return "tier"
    end
    if Progress.PointsAvailable() <= 0 then
        return "points"
    end
end

function Progress.LearnTalent(id)
    if Progress.LearnBlocker(id) then
        return false
    end
    data().talents[id] = Progress.TalentRank(id) + 1
    ns.addon:SendMessage("PEGGLE_TALENTS_CHANGED")
    return true
end

function Progress.ResetTalents()
    local talents = data().talents
    for id = 1, #ns.Talents do
        talents[id] = 0
    end
    ns.addon:SendMessage("PEGGLE_TALENTS_CHANGED")
end
