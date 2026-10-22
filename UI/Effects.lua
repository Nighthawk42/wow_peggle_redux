local _, ns = ...
local C = ns.C
local game = ns.game

-- Pooled board effects: hit glows, particles, particle emitters and floating score text.
-- Effects.Update runs from the engine tick with time-scaled elapsed seconds.

local Effects = {}
ns.Effects = Effects

local random, cos, sin, rad = math.random, math.cos, math.sin, math.rad
local ART = C.ART_PATH
-- Power-up rings from the game's own art; hitGlow stands in if a client lacks the file.
-- TODO(in-game): confirm both game textures still load on Retail, Classic Era and Forever.
local RING_TEXTURES = { "Spells\\AURARUNE9.BLP", "Interface\\SpellShadow\\Spell-Shadow-Acceptable.blp" }
local RING_COLORS = { { 1, 0, 1 }, { 1, 1, 1 } }

local glows, glowPool = {}, {}
local particles, particlePool = {}, {}
local emitters, emitterPool = {}, {}
local texts, textPool = {}, {}

-- Glow behind a hit object. crit: a big yellow flash. ring: 1 Unintended Awesome, 2 Space Blast.
function Effects.SpawnGlow(obj, crit, ring)
    local glow = table.remove(glowPool)
    if not glow then
        glow = Effects.frame:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(ART .. "hitGlow")
    end
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", ns.Board.frame, "BOTTOMLEFT", obj.x, obj.y)
    glow:SetAlpha(0.5)
    glow:SetBlendMode("ADD")
    glow.elapsed = 0
    glow.ring = ring
    if ring then
        if not glow:SetTexture(RING_TEXTURES[ring]) then
            glow:SetTexture(ART .. "hitGlow")
        end
        glow:SetVertexColor(unpack(RING_COLORS[ring]))
        local size = C.PEG_RADIUS * 9 * ring
        glow:SetAlpha(0.66)
        glow.startSize, glow.growth = size, 0
    else
        glow:SetTexture(ART .. "hitGlow")
        if crit then
            glow:SetVertexColor(1, 1, 0)
            glow.startSize, glow.growth = 60, 120
        else
            glow:SetVertexColor(unpack(C.PEG_GLOW_COLORS[obj.id] or C.PEG_GLOW_COLORS[C.PEG_PURPLE]))
            glow.startSize, glow.growth = 32, 64
        end
    end
    glow:SetSize(glow.startSize, glow.startSize)
    glow:Show()
    table.insert(glows, glow)
end

function Effects.SpawnParticle(x, y, life, angle, speed, gravity, textureName, r, g, b)
    local particle = table.remove(particlePool)
    if not particle then
        particle = { texture = Effects.frame:CreateTexture(nil, "OVERLAY") }
        particle.texture:SetSize(32, 32)
    end
    local texture = particle.texture
    texture:SetTexture(ART .. textureName)
    if r then
        texture:SetVertexColor(r, g, b)
    else
        texture:SetVertexColor(unpack(C.STAR_COLORS[random(1, #C.STAR_COLORS)]))
    end
    texture:SetAlpha(1)
    particle.elapsed, particle.life = 0, life
    particle.x, particle.y = x, y
    particle.gravity = gravity
    particle.xVel = speed * cos(rad(angle))
    particle.yVel = speed * sin(rad(angle))
    particle.angle = random(0, 359)
    ns.Board.Place(particle)
    texture:Show()
    table.insert(particles, particle)
end

-- Emits one particle per tick at most, every spawnRate seconds, for life seconds.
function Effects.SpawnParticleGen(x, y, life, particleLife, spawnRate, startAngle, endAngle, minSpeed, maxSpeed, gravity, textureName, r, g, b)
    local emitter = table.remove(emitterPool) or {}
    emitter.x, emitter.y = x, y
    emitter.life, emitter.particleLife = life, particleLife
    emitter.elapsed, emitter.spawnRate, emitter.spawnElapsed = 0, spawnRate, spawnRate
    emitter.startAngle, emitter.endAngle = startAngle, endAngle
    emitter.minSpeed, emitter.maxSpeed = minSpeed, maxSpeed
    emitter.gravity, emitter.textureName = gravity, textureName
    emitter.r, emitter.g, emitter.b = r, g, b
    table.insert(emitters, emitter)
end

-- Floating text at board (x, y). With a velocity it drifts for 1 s, otherwise it holds 0.4 s;
-- either way it then fades over 0.2 s. delay holds it invisible first. crit: big orange text.
function Effects.SpawnText(text, x, y, r, g, b, xVel, yVel, delay, crit)
    local label = table.remove(textPool)
    if not label then
        label = Effects.frame:CreateFontString(nil, "OVERLAY")
    end
    if crit then
        label:SetFont(C.FONT_GAME, 24, "OUTLINE")
        label:SetTextColor(1, 0.5, 0)
    else
        label:SetFont(C.FONT_GAME, 12, "OUTLINE")
        label:SetTextColor(r or 1, g or 1, b or 0)
    end
    label:SetText(text)
    label:SetAlpha(1)
    local halfWidth = label:GetStringWidth() / 2
    if x > 250 then
        if x + halfWidth > C.BOARD_WIDTH then
            x = C.BOARD_WIDTH - halfWidth - 8
        end
    elseif x - halfWidth < 0 then
        x = halfWidth + 8
    end
    label.x, label.y = x, y
    label.elapsed = 0
    label.xVel, label.yVel = xVel, yVel
    label.xOffset, label.yOffset = 0, 0
    label.displayTime = xVel ~= nil and 1 or 0.4
    label.delayed = nil
    if delay then
        label:SetAlpha(0)
        label.elapsed = -delay
        label.delayed = true
    end
    label:ClearAllPoints()
    label:SetPoint("CENTER", ns.Board.frame, "BOTTOMLEFT", x, y)
    label:Show()
    table.insert(texts, label)
end

local function updateText(label, elapsed)
    label.elapsed = label.elapsed + elapsed
    if label.elapsed < 0 then
        return false
    end
    if label.delayed then
        label:SetAlpha(1)
        label.delayed = nil
    end
    if label.xVel then
        label.xOffset = label.xOffset + elapsed * label.xVel
        label.yOffset = label.yOffset + elapsed * label.yVel
        label:SetPoint("CENTER", ns.Board.frame, "BOTTOMLEFT", label.x + label.xOffset, label.y + label.yOffset)
    end
    if label.elapsed >= label.displayTime then
        if label.elapsed >= label.displayTime + 0.2 then
            label:Hide()
            table.insert(textPool, label)
            return true
        end
        label:SetAlpha(1 - (label.elapsed - label.displayTime) / 0.2)
    end
    return false
end

function Effects.Update(elapsed)
    local timeScale = game.timeScale
    local i = 1
    while i <= #glows do
        local glow = glows[i]
        glow.elapsed = glow.elapsed + (glow.ring and elapsed / 3 or elapsed)
        if glow.elapsed > 0.3 then
            glow:Hide()
            table.insert(glowPool, table.remove(glows, i))
        else
            local size = glow.startSize + glow.growth * glow.elapsed
            glow:SetSize(size, size)
            if glow.ring then
                if glow.elapsed > 0.2 then
                    glow:SetAlpha(1 - (glow.elapsed - 0.2) / 0.1)
                end
            else
                glow:SetAlpha(0.6 - glow.elapsed * 2)
            end
            i = i + 1
        end
    end

    i = 1
    while i <= #emitters do
        local emitter = emitters[i]
        emitter.elapsed = emitter.elapsed + elapsed
        emitter.spawnElapsed = emitter.spawnElapsed + elapsed
        if emitter.elapsed > emitter.life then
            table.insert(emitterPool, table.remove(emitters, i))
        else
            if emitter.spawnElapsed > emitter.spawnRate then
                emitter.spawnElapsed = 0
                Effects.SpawnParticle(
                    emitter.x,
                    emitter.y,
                    emitter.particleLife,
                    random(emitter.startAngle, emitter.endAngle),
                    random(emitter.minSpeed, emitter.maxSpeed),
                    emitter.gravity,
                    emitter.textureName,
                    emitter.r,
                    emitter.g,
                    emitter.b
                )
            end
            i = i + 1
        end
    end

    i = 1
    while i <= #particles do
        local particle = particles[i]
        particle.elapsed = particle.elapsed + elapsed
        if particle.elapsed > particle.life + 0.2 then
            particle.texture:Hide()
            table.insert(particlePool, table.remove(particles, i))
        else
            if particle.elapsed > particle.life then
                particle.texture:SetAlpha(1 - (particle.elapsed - particle.life) / 0.2)
            end
            -- Particle speeds are per tick, not per second, as in the original.
            particle.x = particle.x + particle.xVel * timeScale
            particle.y = particle.y + particle.yVel * timeScale
            particle.yVel = particle.yVel + particle.gravity * timeScale
            particle.angle = (particle.angle + 10) % 360
            ns.Board.RotateTexture(particle.texture, particle.angle)
            ns.Board.Place(particle)
            i = i + 1
        end
    end

    i = 1
    while i <= #texts do
        if updateText(texts[i], elapsed) then
            table.remove(texts, i)
        else
            i = i + 1
        end
    end
end

function Effects.Clear()
    for i = #glows, 1, -1 do
        glows[i]:Hide()
        table.insert(glowPool, table.remove(glows, i))
    end
    for i = #particles, 1, -1 do
        particles[i].texture:Hide()
        table.insert(particlePool, table.remove(particles, i))
    end
    for i = #emitters, 1, -1 do
        table.insert(emitterPool, table.remove(emitters, i))
    end
    for i = #texts, 1, -1 do
        texts[i]:Hide()
        table.insert(textPool, table.remove(texts, i))
    end
end

ns.RegisterBuilder("Effects", function()
    local frame = CreateFrame("Frame", nil, ns.Board.frame)
    frame:SetAllPoints()
    frame:SetFrameLevel(ns.Board.foreground:GetFrameLevel() + 1)
    Effects.frame = frame
end)
