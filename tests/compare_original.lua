-- Plays LEVEL with LAYOUT (object indices) on the original, firing ANGLES on a fixed 3 s grid.
-- Prints one "SHOT" line per shot: balls left, orange pegs hit, score and the pegs hit in order.
local O = __ORIG

local function upvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then
            return nil
        end
        if n == name then
            return i, v
        end
        i = i + 1
    end
end

local layout = ""
for _, index in ipairs(LAYOUT) do
    layout = layout .. O.h(index, 2)
end
O.Ae(O.ie[LEVEL], nil, layout)
-- The original's callers show the board and then clear the ready flag until the ball loads.
O.R(true)
debug.setupvalue(O.Et, (upvalue(O.Et, "Q")), false)
O.t.charScreen:Hide()
O.d.elapsed = 0
math.randomseed(SEED)

local shot, t, waiting, lastHits, lastCount = 0, 0, false, "", 0
local function hits()
    local out = {}
    for _, p in ipairs(O.d.hitPegStack) do
        out[#out + 1] = string.format("%.1f,%.1f", p.x, p.y)
    end
    return table.concat(out, ";")
end
while shot <= #ANGLES and t < 900 do
    H.step(0.02)
    t = t + 0.02
    if #O.d.hitPegStack > lastCount then
        lastHits, lastCount = hits(), #O.d.hitPegStack
    end
    local _, ready = upvalue(O.Et, "Q")
    local onGrid = math.fmod(math.floor(t * 50 + 0.5), 150) == 0
    if ready and onGrid and #O.d.activeBallStack == 0 and not O.d.reclaim and not O.d.coin:IsShown() then
        if waiting then
            local _, score = upvalue(O.it, "w")
            local _, orange = upvalue(O.Et, "G")
            local _, balls = upvalue(O.Et, "te")
            print(string.format("SHOT %d t=%.2f balls=%d orange=%d score=%d hits=%s", shot, t, balls, orange, score, lastHits))
            lastHits, lastCount, waiting = "", 0, false
        end
        shot = shot + 1
        if shot > #ANGLES then
            break
        end
        debug.setupvalue(O.Et, (upvalue(O.Et, "N")), ANGLES[shot])
        O.d.elapsed = 0
        O.Et(nil, "LeftButton")
        waiting = true
    end
end
