local _, ns = ...
local C = ns.C
local Util = ns.Util

-- Slash commands: /peggle, /peg and /pegredux, plus /peggleloot [item].

local HELP = {
    "|cFFFFFF00Peggle Redux|r commands (/peggle, /peg or /pegredux):",
    "  (none) or toggle - show/hide the game window",
    "  show / hide - show or hide the game window",
    "  options - open the Options tab",
    "  resetwindow - move the window back to the middle of the screen at its normal size",
    "  achievement - replay the Exhibit A achievement, once earned",
    "/peggleloot [item] - start a Peggle Loot challenge for the item (master looter; on Retail, the group leader or an assistant)",
}

local function resetWindow()
    local window = ns.addon.window
    window:ClearAllPoints()
    window:SetPoint("CENTER")
    window:SetSize(C.WINDOW_WIDTH, C.WINDOW_HEIGHT)
end

local commands = {
    [""] = function()
        ns.Broker.ToggleWindow()
    end,
    show = function()
        if not ns.addon.window:IsVisible() then
            ns.Broker.ToggleWindow()
        end
    end,
    hide = function()
        ns.addon.window:Hide()
    end,
    options = function()
        ns.Options.Open()
    end,
    resetwindow = resetWindow,
    achievement = function()
        if ns.Achievement.IsEarned() then
            ns.Achievement.Show()
        else
            Util.Print("You have not earned that achievement yet.")
        end
    end,
    help = function()
        for _, line in ipairs(HELP) do
            Util.Print(line)
        end
    end,
}
commands.toggle = commands[""]
commands.config = commands.options

local function handler(input)
    local command = (strtrim(input or ""):match("^(%S*)") or ""):lower()
    local func = commands[command] or commands.help
    func()
end

local function lootHandler(input)
    ns.Loot.Start(strtrim(input or ""))
end

ns.RegisterEnabler("Commands", function()
    ns.addon:RegisterChatCommand("pegredux", handler)
    ns.addon:RegisterChatCommand("peggle", handler)
    ns.addon:RegisterChatCommand("peg", handler)
    ns.addon:RegisterChatCommand("peggleloot", lootHandler)
end)
