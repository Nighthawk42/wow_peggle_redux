local _, ns = ...
local C = ns.C

-- Saved variables (AceDB, SavedVariables: PeggleReduxDB).
--   ns.db.profile  settings
--   ns.db.global   level progress and talents, shared by every character on the account as in
--                  the original; one-time flags
--   ns.db.char     duel history and records, battles

local defaults = {
    profile = {
        mouseOnAlpha = 1,
        mouseOffAlpha = 0.6,
        lockWindow = false,
        minimap = { hide = false },
        colorBlindMode = false,
        sound = "normal", -- "normal", "quiet" or "off"
        keybinding = nil,
        hideOutdated = false,
        defaultPublish = "GUILD",
        -- Automatic open/close. The original opened the window on login, death and flight by
        -- default; here opening is opt-in.
        openFlightStart = false,
        openOnDeath = false,
        openLogin = false,
        openDuel = true,
        closeFlightEnd = false,
        closeReadyCheck = true,
        closeCombat = true,
        closeDuelComplete = false,
        closePeggleLoot = false,
        -- How duel and battle invitations are announced.
        inviteChat = true,
        inviteRaidWarning = false,
        inviteMinimap = true,
        inviteDecline = false,
        -- New Battle form choices.
        battleShots = 10,
        battleGuildOffline = true,
        battleGuildSortOnline = false,
    },
    global = {
        progress = {
            best = {}, -- [level] best score
            recent = {}, -- [level] last score
            medal = {}, -- [level] C.MEDAL_*
            talents = {}, -- [talent id] rank
        },
        legalDisplayed = false,
        exhibitA = false,
        newerVersionSeen = nil,
    },
    char = {
        character = C.CHAR_GUIDE,
        lastDuels = {}, -- most recent opponent first, up to 10
        duelRecord = {}, -- [opponent] = { won, lost }; [level] = { won, lost } under levelRecord
        levelRecord = {},
        battles = {},
    },
}

function ns.InitDatabase()
    ns.db = LibStub("AceDB-3.0"):New("PeggleReduxDB", defaults, true)
    local progress = ns.db.global.progress
    for level = 1, C.NUM_LEVELS do
        progress.best[level] = progress.best[level] or 0
        progress.medal[level] = progress.medal[level] or C.MEDAL_NONE
    end
    for id = 1, #ns.Talents do
        progress.talents[id] = progress.talents[id] or 0
    end
end
