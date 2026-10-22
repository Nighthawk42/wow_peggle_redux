-- One simulated player for the multiplayer tests: boots the addon and plays any round it is in
-- with random aim. Globals in: HARNESS, ROOT, SEED, PLAYER_NAME.
dofile(HARNESS)
math.randomseed(SEED)
H.boot()
H.step(0.1)
local ns = H.ns
local game = ns.game
H.mouseOver = true
ns.addon.window:Show()

-- Advances dt seconds and returns the addon messages sent meanwhile.
function client_tick(dt)
    H.step(dt)
    if ns.Game.IsInProgress() then
        if ns.CharacterSelect.IsShown() then
            ns.CharacterSelect.Hide()
        end
        if game.readyToShoot and not ns.Game.IsOverlayShown() and #game.balls == 0 then
            ns.Aim.SetAngle(math.random(160, 380) % 360)
            ns.Aim.Shoot()
        end
    end
    if ns.Summary.IsShown() then
        ns.Summary.Hide()
        ns.Game.SummaryClosed()
    end
    local out = H.comm
    H.comm = {}
    return out
end

function client_receive(prefix, text, distribution, sender)
    local handler = H.commHandlers and H.commHandlers[prefix]
    if handler then
        local ok, err = pcall(handler[2], prefix, text, distribution, sender)
        if not ok then
            H.report("RECEIVE", err)
        end
    end
end

function client_errors()
    local count = 0
    for key in pairs(H.errors) do
        if not key:find("GLOBAL WRITE") then
            count = count + 1
        end
    end
    return count
end
