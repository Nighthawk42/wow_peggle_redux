local _, ns = ...

-- Regions cut from the shared atlases, as { left, right, top, bottom } texture coordinates.
-- ns.Art.Size(key) gives a region's pixel size in its atlas; ns.Art.Apply sets file and coords.
local CUTS = {
    leftBorder = { 0 / 512, 60 / 512, 0 / 512, 512 / 512 },
    rightBorder1 = { 0 / 256, 152 / 256, 0 / 512, 140 / 512 },
    rightBorder2 = { 85 / 256, 152 / 256, 140 / 512, 488 / 512 },
    rightBorder3 = { 0 / 256, 152 / 256, 488 / 512, 512 / 512 },
    topBorder = { 60 / 512, 512 / 512, 0 / 512, 140 / 512 },
    bottomBorder = { 60 / 512, 512 / 512, 488 / 512, 512 / 512 },
    powerLabel = { 324 / 512, 506 / 512, 179 / 512, 203 / 512 },
    catcher = { 100 / 512, 237 / 512, 413 / 512, 439 / 512 },
    catcherBack = { 100 / 512, 237 / 512, 460 / 512, 486 / 512 },
    extraBallBarTop = { 99 / 512, 110 / 512, 331 / 512, 347 / 512 },
    extraBallBar = { 99 / 512, 110 / 512, 347 / 512, 363 / 512 },
    extraBallBarBot = { 99 / 512, 110 / 512, 363 / 512, 379 / 512 },
    extraBallBottomCover = { 99 / 512, 163 / 512, 383 / 512, 399 / 512 },
    extraBallTopCover = { 167 / 512, 199 / 512, 373 / 512, 399 / 512 },
    ballLoader = { 112 / 512, 135 / 512, 260 / 512, 379 / 512 },
    buttonInstantReplay = { 144 / 512, 189 / 512, 260 / 512, 305 / 512 },
    glow = { 139 / 512, 202 / 512, 258 / 512, 322 / 512 },
    catcherGlow = { 255 / 512, 377 / 512, 429 / 512, 481 / 512 },
    feverBottomCover = { 64 / 512, 98 / 512, 384 / 512, 399 / 512 },
    feverTopCover = { 64 / 512, 98 / 512, 366 / 512, 381 / 512 },
    feverBar = { 64 / 512, 95 / 512, 352 / 512, 364 / 512 },
    feverBarHighlight = { 64 / 512, 95 / 512, 339 / 512, 351 / 512 },
    fever2x = { 202 / 512, 248 / 512, 349 / 512, 370 / 512 },
    fever2xHighlight = { 252 / 512, 298 / 512, 349 / 512, 370 / 512 },
    fever3x = { 202 / 512, 248 / 512, 324 / 512, 345 / 512 },
    fever3xHighlight = { 252 / 512, 298 / 512, 324 / 512, 345 / 512 },
    fever5x = { 202 / 512, 248 / 512, 299 / 512, 320 / 512 },
    fever5xHighlight = { 252 / 512, 298 / 512, 299 / 512, 320 / 512 },
    fever10x = { 202 / 512, 248 / 512, 274 / 512, 295 / 512 },
    fever10xHighlight = { 252 / 512, 298 / 512, 274 / 512, 295 / 512 },
    feverBonus10 = { 200 / 512, 313 / 512, 208 / 512, 258 / 512 },
    feverBonus50 = { 313 / 512, 423 / 512, 208 / 512, 258 / 512 },
    feverBonus100 = { 201 / 512, 313 / 512, 148 / 512, 205 / 512 },
    fever1 = { 0 / 512, 512 / 512, 92 / 256, 256 / 256 },
    fever2 = { 0 / 512, 512 / 512, 13 / 256, 92 / 256 },
    feverScore = { 171 / 256, 256 / 256, 0 / 512, 268 / 512 },
    feverRay = { 394 / 512, 452 / 512, 287 / 512, 481 / 512 },
    logoArt = { 305 / 512, 390 / 512, 261 / 512, 426 / 512 },
    tabQuickPlay = { 0 / 512, 118 / 512, 0 / 256, 64 / 256 },
    tabDuel = { 118 / 512, 203 / 512, 0 / 256, 64 / 256 },
    tabChallenge = { 203 / 512, 319 / 512, 0 / 256, 64 / 256 },
    tabTalents = { 319 / 512, 416 / 512, 0 / 256, 64 / 256 },
    tabHowToPlay = { 0 / 512, 141 / 512, 192 / 256, 256 / 256 },
    tabOptions = { 416 / 512, 512 / 512, 0 / 256, 64 / 256 },
    buttonOkay = { 0 / 256, 158 / 256, 0 / 256, 54 / 256 },
    buttonGo = { 0 / 256, 158 / 256, 54 / 256, 108 / 256 },
    buttonResetTalents = { 175 / 256, 219 / 256, 25 / 256, 182 / 256 },
    buttonNewChallenge = { 0 / 256, 125 / 256, 109 / 256, 141 / 256 },
    buttonChallenge = { 0 / 256, 175 / 256, 142 / 256, 183 / 256 },
    buttonRestartLevel = { 0 / 256, 185 / 256, 184 / 256, 220 / 256 },
    buttonReturnToGame = { 0 / 256, 185 / 256, 220 / 256, 256 / 256 },
    buttonAbandonGame = { 220 / 256, 256 / 256, 70 / 256, 256 / 256 },
    buttonSound = { 162 / 256, 182 / 256, 0 / 256, 20 / 256 },
    buttonMenu = { 202 / 256, 256 / 256, 0 / 256, 20 / 256 },
    buttonClose = { 235 / 256, 255 / 256, 19 / 256, 39 / 256 },
    buttonView = { 191 / 256, 215 / 256, 186 / 256, 256 / 256 },
    buttonBack = { 186 / 256, 256 / 256, 319 / 512, 343 / 512 },
    buttonAbout = { 0 / 256, 44 / 256, 141 / 512, 298 / 512 },
    buttonCredits = { 0 / 256, 44 / 256, 298 / 512, 457 / 512 },
    buttonPublish = { 155 / 256, 199 / 256, 354 / 512, 480 / 512 },
    buttonDecline = { 202 / 256, 256 / 256, 355 / 512, 512 / 512 },
    bannerBig1 = { 128 / 256, 256 / 256, 0 / 256, 183 / 256 },
    bannerBig2 = { 0 / 256, 128 / 256, 0 / 256, 183 / 256 },
    bannerSmall1 = { 0 / 512, 36 / 512, 467 / 512, 512 / 512 },
    bannerSmall2 = { 0 / 512, 36 / 512, 422 / 512, 467 / 512 },
    bannerSmall3 = { 0 / 512, 36 / 512, 377 / 512, 422 / 512 },
    howToPlay1 = { 0 / 512, 195 / 512, 0 / 512, 155 / 512 },
    howToPlay2 = { 197 / 512, 392 / 512, 0 / 512, 155 / 512 },
    howToPlay3 = { 0 / 512, 195 / 512, 155 / 512, 310 / 512 },
    howToPlay4 = { 197 / 512, 392 / 512, 155 / 512, 310 / 512 },
    howToPlay5 = { 0 / 512, 195 / 512, 311 / 512, 404 / 512 },
    howToPlay6 = { 194 / 512, 391 / 512, 311 / 512, 367 / 512 },
    howToPlay7 = { 194 / 512, 391 / 512, 405 / 512, 443 / 512 },
    howToPlay8 = { 0 / 512, 382 / 512, 444 / 512, 481 / 512 },
    popCap = { 117 / 512, 187 / 512, 181 / 512, 251 / 512 },
    peggleBringer = { 453 / 512, 512 / 512, 207 / 512, 487 / 512 },
    splashBringer = { 60 / 512, 512 / 512, 368 / 512, 512 / 512 },
    exhibitA = { 439 / 512, 512 / 512, 0 / 512, 373 / 512 },
    exhibitA2 = { 448 / 512, 512 / 512, 389 / 512, 453 / 512 },
}

-- Atlas file and pixel size per region. Regions not listed come from board1 (512x512).
local ATLAS = {
    board1 = { "board1", 512, 512 },
    board2 = { "board2", 256, 512 },
    buttons = { "buttons", 256, 256 },
    tabs = { "tabs", 512, 256 },
    howtoplay = { "howtoplay", 512, 512 },
    extremeFever = { "extremeFever", 512, 256 },
    banner2 = { "banner2", 512, 512 },
}
local REGION_ATLAS = {
    rightBorder1 = "board2",
    rightBorder2 = "board2",
    rightBorder3 = "board2",
    feverScore = "board2",
    buttonBack = "board2",
    buttonAbout = "board2",
    buttonCredits = "board2",
    buttonPublish = "board2",
    buttonDecline = "board2",
    peggleBringer = "board1",
    tabQuickPlay = "tabs",
    tabDuel = "tabs",
    tabChallenge = "tabs",
    tabTalents = "tabs",
    tabHowToPlay = "tabs",
    tabOptions = "tabs",
    buttonOkay = "buttons",
    buttonGo = "buttons",
    buttonResetTalents = "buttons",
    buttonNewChallenge = "buttons",
    buttonChallenge = "buttons",
    buttonRestartLevel = "buttons",
    buttonReturnToGame = "buttons",
    buttonAbandonGame = "buttons",
    buttonSound = "buttons",
    buttonMenu = "buttons",
    buttonClose = "buttons",
    buttonView = "buttons",
    bannerBig1 = "banner2",
    bannerBig2 = "banner2",
    splashBringer = "banner2",
    bannerSmall1 = "banner2",
    bannerSmall2 = "banner2",
    bannerSmall3 = "banner2",
    howToPlay1 = "howtoplay",
    howToPlay2 = "howtoplay",
    howToPlay3 = "howtoplay",
    howToPlay4 = "howtoplay",
    howToPlay5 = "howtoplay",
    howToPlay6 = "howtoplay",
    howToPlay7 = "howtoplay",
    howToPlay8 = "howtoplay",
    exhibitA = "howtoplay",
    exhibitA2 = "howtoplay",
    fever1 = "extremeFever",
    fever2 = "extremeFever",
}

local Art = {}
ns.Art = Art

local ART_PATH = ns.C.ART_PATH

function Art.Path(file)
    return ART_PATH .. file
end

-- Texture coordinates of a region: left, right, top, bottom.
function Art.Coords(key)
    return unpack(CUTS[key])
end

function Art.Cut(key)
    return CUTS[key]
end

function Art.Atlas(key)
    return ATLAS[REGION_ATLAS[key] or "board1"]
end

-- Pixel size of a region in its atlas (rounded, as the original sized its textures).
function Art.Size(key)
    local cut, atlas = CUTS[key], Art.Atlas(key)
    return math.floor((cut[2] - cut[1]) * atlas[2] + 0.5), math.floor((cut[4] - cut[3]) * atlas[3] + 0.5)
end

-- Sets a texture to a region. rotated draws the region turned 90 degrees.
function Art.Apply(texture, key, rotated)
    local cut = CUTS[key]
    texture:SetTexture(ART_PATH .. Art.Atlas(key)[1])
    if rotated then
        texture:SetTexCoord(cut[2], cut[3], cut[1], cut[3], cut[2], cut[4], cut[1], cut[4])
    else
        texture:SetTexCoord(cut[1], cut[2], cut[3], cut[4])
    end
end
