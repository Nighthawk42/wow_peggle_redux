local _, ns = ...

-- The eleven talents. tier: row in the tree (needs tier * 5 points spent), maxRank, requires:
-- a talent that needs 5 points first. value(rank) is the number shown in the description.
-- Points: one per level beaten and one more per full clear.
local function linear(base, perRank)
    return function(rank)
        return base + perRank * rank
    end
end

ns.Talents = {
    { key = "coin", icon = "t_coin", tier = 0, maxRank = 5, value = linear(0, 10) },
    { key = "style", icon = "t_style_for_miles", tier = 0, maxRank = 5, value = linear(0, 2) },
    { key = "stepAhead", icon = "t_a_step_ahead", tier = 1, maxRank = 2, value = linear(0, 1) },
    { key = "onlyCure", icon = "t_the_only_cure", tier = 1, maxRank = 5, value = linear(0, 10) },
    { key = "marksman", icon = "t_peg_marksmen", tier = 1, maxRank = 3, value = linear(0, 5) },
    { key = "cowbell", icon = "t_more_cowbell", tier = 2, maxRank = 5, value = linear(0, 10) },
    { key = "missionCritical", icon = "t_mission_critical", tier = 2, maxRank = 5, value = linear(150, 10) },
    { key = "unintended", icon = "t_unintended_awesome", tier = 3, maxRank = 5, value = linear(0, 10) },
    { key = "infusion", icon = "t_infusion_of_awesome", tier = 3, maxRank = 5, value = linear(0, 20) },
    { key = "ignition", icon = "t_rolling_ignition", tier = 4, maxRank = 1, requires = 8, value = linear(0, 0) },
    { key = "fission", icon = "t_double_fission", tier = 4, maxRank = 1, requires = 9, value = linear(0, 0) },
}

-- Talent ids by key, for readable lookups in game code: ns.TALENT.coin == 1.
ns.TALENT = {}
for id, talent in ipairs(ns.Talents) do
    talent.id = id
    ns.TALENT[talent.key] = id
end

ns.TALENT_POINTS_PER_TIER = 5
