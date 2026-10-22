-- Same driver as compare_original.lua, on Peggle Redux.
local ns = H.ns
local game = ns.game
ns.addon.window:Show()
ns.Game.Start(LEVEL, { mode = "duel", layout = LAYOUT })
ns.CharacterSelect.Hide()
ns.Engine.Reset()
math.randomseed(SEED)

local shot, t, waiting, lastHits, lastCount = 0, 0, false, "", 0
local function hits()
    local out = {}
    for _, p in ipairs(game.hitStack) do
        out[#out + 1] = string.format("%.1f,%.1f", p.x, p.y)
    end
    return table.concat(out, ";")
end
while shot <= #ANGLES and t < 900 do
    H.step(0.02)
    t = t + 0.02
    if #game.hitStack > lastCount then
        lastHits, lastCount = hits(), #game.hitStack
    end
    local onGrid = math.fmod(math.floor(t * 50 + 0.5), 150) == 0
    if game.readyToShoot and onGrid and #game.balls == 0 and not game.reclaim then
        if waiting then
            print(string.format("SHOT %d t=%.2f balls=%d orange=%d score=%d hits=%s", shot, t, game.ballsLeft,
                game.orangeHit, game.score, lastHits))
            lastHits, lastCount, waiting = "", 0, false
        end
        shot = shot + 1
        if shot > #ANGLES then
            break
        end
        ns.Aim.SetAngle(ANGLES[shot])
        ns.Engine.Reset()
        ns.Aim.Shoot()
        waiting = true
    end
end
