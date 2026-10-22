local ADDON_NAME, ns = ...

-- Shared constants. Each file pulls what it needs into locals:
--   local C = ns.C
-- Values and names follow the original addon (Peggle 1.02); coordinates are board pixels with
-- the origin at the board's bottom-left corner, angles in degrees.
local C = {}
ns.C = C

C.ADDON_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"
C.ART_PATH = C.ADDON_PATH .. "images\\"
C.SOUND_PATH = C.ADDON_PATH .. "sounds\\"
C.FONT_GAME = C.ART_PATH .. "OVERLOAD.ttf"
C.FONT_TITLE = C.ART_PATH .. "Contb___.ttf"

C.COMM_PREFIX = "PeggleRedux1"
C.PROTOCOL_VERSION = 1

-- Window and board
C.WINDOW_WIDTH, C.WINDOW_HEIGHT = 662, 548
C.BOARD_WIDTH, C.BOARD_HEIGHT = 554, 464
C.BOARD_LEFT, C.BOARD_TOP = 53, -70 -- board position inside the window
C.GRID_SECTIONS = 10
C.SECTION_WIDTH = math.floor(C.BOARD_WIDTH / C.GRID_SECTIONS + 0.9) -- 56
C.SECTION_HEIGHT = math.floor(C.BOARD_HEIGHT / C.GRID_SECTIONS + 0.9) -- 47
C.BOUND_LEFT, C.BOUND_RIGHT = 10, C.BOARD_WIDTH - 2
C.BOUND_BOTTOM, C.BOUND_TOP = 10, C.BOARD_HEIGHT - 2
C.MUZZLE_X, C.MUZZLE_Y = C.BOARD_WIDTH / 2 + 1, C.BOARD_HEIGHT - 16 - 20

-- Sprite sizes
C.BALL_SIZE = 12
C.PEG_SIZE = 28 * 0.85
C.BRICK_SIZE = 34 * 0.85
C.CATCHER_WIDTH, C.CATCHER_HEIGHT = 138, 27

-- Physics. The engine ticks at most every TICK seconds and integrates in SUBSTEP slices.
C.TICK = 0.025
C.SUBSTEP = 0.01
C.GRAVITY = -248
C.SHOT_SPEED = 260
C.RESTITUTION = 0.68
C.BALL_RADIUS = 6
C.PEG_RADIUS = 8.5
C.BRICK_RADIUS = 18.3 -- broad-phase radius
C.PUSH_OUT = 1.01
C.MAX_RESOLVE_PASSES = 5
C.PEG_MAX_CONTACTS = 90 -- a peg touched more often than this is removed (stuck ball)
C.BRICK_MAX_CONTACTS = 9
C.SLIDE_ANGLE = 25 -- half the deflection below which a brick hit becomes a slide
C.SLIDE_SPEED = 0.98
C.SLIDE_TIMEOUT = 0.05
C.AIM_MIN, C.AIM_MAX = 25, 155 -- angles in this range (pointing up) are blocked
C.CATCHER_LOOP_TIME = 6
C.CATCHER_START_X, C.CATCHER_Y = 60, 9
C.CATCHER_CATCH_HALF_WIDTH = 50
C.CATCHER_ROTATION = 315
C.ZOOM_DISTANCE = 48
C.BUMPER_RADIUS = 32
-- Fever buckets: x edges of the five buckets, then each bucket's value in 10,000s.
C.FEVER_BUCKET_EDGES = { 0, 114, 224, 330, 438, 550 }
C.FEVER_BUCKET_VALUES = { 1, 5, 10, 5, 1 }

-- Peg colors (object.id)
C.PEG_BLUE, C.PEG_ORANGE, C.PEG_PURPLE, C.PEG_GREEN = 1, 2, 3, 4
C.BRICK_TEXTURES = { "blue", "red", "purple", "green" }
C.PEG_GLOW_COLORS = { { 0.4, 0.4, 1 }, { 1, 0.4, 0.4 }, { 1, 0.4, 1 }, { 0.4, 1, 0.4 } }

-- Object kinds in level data
C.KIND_PEG, C.KIND_BRICK, C.KIND_STRAIGHT_BRICK = 0, 1, 2

-- Motion types (object.moveType)
C.MOVE_NONE, C.MOVE_LINE, C.MOVE_CIRCLE, C.MOVE_ROTATE, C.MOVE_LINE_ROTATE, C.MOVE_CIRCLE_ROTATE = 0, 1, 2, 3, 4, 5

-- Characters
C.CHAR_GUIDE, C.CHAR_BLAST = 0, 1
C.GUIDE_TURNS = 3
C.SMALL_BLAST_RADIUS = C.PEG_RADIUS * 5 -- 42.5
C.SPACE_BLAST_RADIUS = C.PEG_RADIUS * 10 -- 85
C.GREEN_MIN_DISTANCE = C.PEG_RADIUS * 9 -- 76.5

-- Scoring
C.ORANGE_COUNT, C.GREEN_COUNT, C.PURPLE_COUNT = 25, 2, 1
C.LAYOUT_SIZE = C.ORANGE_COUNT + C.GREEN_COUNT + C.PURPLE_COUNT
C.POINTS = { [1] = 10, [2] = 100, [3] = 500, [4] = 10 }
C.PURPLE_FEVER_POINTS = 100
C.FEVER_MULTIPLIER = 100
C.FEVER_SEGMENTS = 25
C.FEVER_STEPS = { [10] = 1, [15] = 2, [19] = 3, [22] = 4 } -- lit segments -> badge index
C.FEVER_BADGE_MULTIPLIERS = { 2, 3, 5, 10 }
C.FEVER_BALL_BONUS = 10000
C.CRIT_MULTIPLIER = 1.5
C.FREE_BALL_FIRST = 25000
C.FREE_BALL_STEP = 50000
C.LOOT_BUCKET_BONUS = 2500
C.BALLS_PER_LEVEL = 10
C.LONG_SHOT = 0.33 * C.BOARD_WIDTH
C.SUPER_LONG_SHOT = 0.66 * C.BOARD_WIDTH
C.SLIDE_STYLE_COUNT = 12
-- Style shots: points and locale key per kind.
C.STYLE_FREE_BALL, C.STYLE_LONG, C.STYLE_SUPER_LONG, C.STYLE_MAD_SKILLZ, C.STYLE_SLIDE, C.STYLE_ORANGE_ATTACK =
    1, 2, 3, 4, 5, 6
C.STYLE_POINTS = { 5000, 25000, 50000, 25000, 50000, 50000 }
C.CRAZY_MAD_SKILLZ_POINTS = 100000
-- Orange Attack: { oranges left at shot time, oranges needed in one shot }, best match wins.
C.ORANGE_ATTACK_RANKS = { 5, 4, 6, 5, 8, 6, 9, 7, 10, 8, 16, 9, 20, 10 }
C.ORANGE_ATTACK_DEFAULT = 30

-- Free-ball meter (left tube)
C.TUBE_TOP = C.BOARD_HEIGHT - 170
C.TUBE_LOAD_SPEED, C.TUBE_ADD_SPEED, C.TUBE_FAST_ADD_SPEED, C.TUBE_SPRING_SPEED = 900, 900, 2250, 450
C.METER_HEIGHT = 300

-- Peg glows, particles
C.STAR_COLORS = {
    { 1, 0.3, 0.3 },
    { 0.3, 1, 0.3 },
    { 0.3, 0.3, 1 },
    { 1, 1, 0.3 },
    { 1, 0.3, 1 },
    { 0.3, 1, 1 },
    { 1, 1, 1 },
}

-- Brick shapes. CURVED_BRICK maps the level's curve value to a shape and texture number.
C.CURVED_BRICK = {
    [0] = 12,
    [10] = 1,
    [20] = 2,
    [30] = 3,
    [40] = 4,
    [60] = 5,
    [80] = 6,
    [100] = 7,
    [120] = 8,
    [140] = 9,
    [160] = 10,
    [180] = 11,
}
-- Collision outline of each brick shape (x, y pairs, unscaled; Game/Physics scales by BRICK_POLYGON_SCALE).
C.BRICK_POLYGON_SCALE = 0.85
C.BRICK_POLYGONS = {
    { 7, -11, 9, -4, 9, 3, 7, 10, -10, 3, -10, -4 },
    { 7, -15, 10, -1, 7, 14, -10, 7, -9, 0, -10, -8 },
    { 7, -13, 9, -6, 9, 5, 7, 12, -10, 7, -10, -8 },
    { 8, -12, 9, -4, 9, 3, 8, 12, -9, 9, -8, 0, -9, -9 },
    { 9, -14, 10, -6, 10, 5, 9, 14, -10, 11, -10, -11 },
    { 8, -13, 9, -8, 9, 6, 8, 12, -10, 10, -10, -11 },
    { 8, -15, 9, -7, 9, 6, 8, 15, -10, 13, -10, -13 },
    { 8, -15, 9, -9, 9, 7, 8, 14, -9, 12, -9, 6, -9, -8, -9, -13 },
    { 8, -15, 9, -6, 9, 5, 8, 13, -10, 11, -10, 6, -10, -7, -10, -13 },
    { 8, -15, 9, -8, 9, 7, 8, 14, -10, 13, -10, -14 },
    { 8, -15, 9, -8, 9, 7, 8, 15, -10, 14, -10, -14 },
    { 9, -15, 9, 14, -9, 14, -9, -15 },
}
-- Edges of each shape that are end caps; a ball beyond the end of a cap edge hits its corner.
C.BRICK_CAP_EDGES = {}
do
    local a, b, c, d, e = { 1, 4, 5, 6 }, { 1, 3, 4, 6 }, { 1, 4, 5, 7 }, { 1, 4, 5, 8 }, { 1, 2, 3, 4 }
    local caps = { a, b, a, c, a, a, a, d, d, a, a, e }
    for shape, list in ipairs(caps) do
        C.BRICK_CAP_EDGES[shape] = {}
        for _, edge in ipairs(list) do
            C.BRICK_CAP_EDGES[shape][edge] = true
        end
    end
end
C.CATCHER_POLYGON = { 49, -7, 51, -9, 73, 8, 51, 32, -51, 32, -74, 8, -51, -9, -49, -7, -49, 31, 49, 31 }

-- Sounds, by the original's numbering; "peghit" is a prefix the hit code completes.
C.SOUND_FILES = {
    "applause.ogg",
    "",
    "ball_add.ogg",
    "",
    "cannonshot.ogg",
    "coin_spin.ogg",
    "coin_freeball_denied.ogg",
    "extraball.ogg",
    "extraball2.ogg",
    "extraball3.ogg",
    "extremefever2.ogg",
    "feverhit.ogg",
    "",
    "fireworks2.ogg",
    "gapbonus1.ogg",
    "gong.ogg",
    "odetojoy.ogg",
    "peghit",
    "pegpop.ogg",
    "",
    "aah.ogg",
    "powerup_guide.ogg",
    "powerup_spaceblast.ogg",
    "rainbow.ogg",
    "scorecounter.ogg",
    "sigh.ogg",
    "timpaniroll.ogg",
    "xbump_mod2.ogg",
    "aah.ogg",
}
C.SOUND_APPLAUSE = 1
C.SOUND_BALL_ADD = 3
C.SOUND_BUCKET_HIT = 4
C.SOUND_SHOT = 5
C.SOUND_COIN_SPIN = 6
C.SOUND_COIN_DENIED = 7
C.SOUND_EXTRABALL1 = 8
C.SOUND_EXTRABALL2 = 9
C.SOUND_EXTRABALL3 = 10
C.SOUND_FEVER = 11
C.SOUND_FEVER_HIT = 12
C.SOUND_FIREWORKS_START = 14
C.SOUND_GAP_BONUS = 15
C.SOUND_GONG = 16
C.SOUND_ODETOJOY = 17
C.SOUND_PEG_HIT = 18
C.SOUND_PEG_POP = 19
C.SOUND_POWERUP = 21
C.SOUND_POWERUP_GUIDE = 22
C.SOUND_POWERUP_BLAST = 23
C.SOUND_RAINBOW = 24
C.SOUND_SCORECOUNTER = 25
C.SOUND_SIGH = 26
C.SOUND_TIMPANI = 27
C.SOUND_BUMPER = 28
C.SOUND_BUCKET_BALL = 29

C.NUM_LEVELS = 12
-- Level select medals: 0 never beaten, 1 beaten, 2 full clear (stored per level).
C.MEDAL_NONE, C.MEDAL_BEATEN, C.MEDAL_CLEARED = 0, 1, 2

C.CHAT_CHANNELS = { "GUILD", "PARTY", "RAID" }
