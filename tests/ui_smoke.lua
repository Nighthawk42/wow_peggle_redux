-- Fires every frame's mouse, click, show and update handlers in each screen, reporting Lua errors.
dofile(HARNESS)
H.boot()
H.step(0.5)
local ns = H.ns
ns.addon.window:Show()
local function poke(label)
    for _, f in ipairs(H.created) do
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnShow" }) do
            local fn = f._scripts[script]
            if fn and f:IsVisible() then
                local ok, err = pcall(fn, f, "LeftButton")
                if not ok then H.report("UI " .. label .. " " .. script, err) end
            end
        end
    end
end
local function clickAll(label)
    for _, f in ipairs(H.created) do
        local fn = f._scripts.OnClick
        if fn and f:IsVisible() and f ~= ns.addon.window.toggleButton then
            local ok, err = pcall(fn, f, "LeftButton", true)
            if not ok then H.report("UI " .. label .. " OnClick", err) end
            H.step(0.05)
            ns.addon.window:Show()
        end
    end
end
for _, tab in ipairs({ "quick", "duel", "battle", "talents", "howto", "options" }) do
    ns.Game.ShowMenu()
    ns.Menu.SelectTab(tab)
    H.step(0.1)
    poke(tab)
    clickAll(tab)
end
ns.Game.Start(5, { mode = "quick" })
H.step(1)
poke("board")
ns.GameMenu.Show()
poke("gamemenu")
ns.GameMenu.Hide()
for _ = 1, 200 do H.step(0.05) end
ns.Summary.Show()
poke("summary")
clickAll("summary")
print("ui smoke done")
