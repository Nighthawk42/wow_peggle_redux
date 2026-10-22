local _, ns = ...

-- Automatic open/close of the game window: open at login, on death and at flight start; close on
-- a ready check, entering combat and landing. Flights are detected as in Bejeweled Redux: the
-- TakeTaxiNode hook arms a UNIT_FLAGS check for takeoff, and landing is PLAYER_CONTROL_GAINED once
-- UnitOnTaxi turns false (it can lag the event briefly, so a short poll follows it).
-- Duel and Peggle Loot triggers live with those features.

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local flying, landingPoll

local function window()
    return ns.addon.window
end

local function openWindow()
    if not window():IsVisible() then
        ns.Broker.ToggleWindow()
    end
end

local function startFlight()
    flying = true
    events:RegisterEvent("PLAYER_CONTROL_GAINED")
    if ns.db.profile.openFlightStart then
        openWindow()
    end
end

local function checkLanding()
    if UnitOnTaxi("player") then
        return
    end
    flying = nil
    events:UnregisterEvent("PLAYER_CONTROL_GAINED")
    if landingPoll then
        ns.addon:CancelTimer(landingPoll)
        landingPoll = nil
    end
    if ns.db.profile.closeFlightEnd then
        window():Hide()
    end
end

local function onTakeTaxiNode()
    events:RegisterEvent("UNIT_FLAGS")
end

function events:UNIT_FLAGS(_, unit)
    if unit ~= "player" or not UnitOnTaxi("player") then
        return
    end
    self:UnregisterEvent("UNIT_FLAGS")
    if not flying then
        startFlight()
    end
end

function events:PLAYER_CONTROL_GAINED()
    if not flying or landingPoll then
        return
    end
    checkLanding()
    if flying then
        landingPoll = ns.addon:ScheduleRepeatingTimer(checkLanding, 0.5)
    end
end

function events:PLAYER_DEAD()
    if ns.db.profile.openOnDeath then
        openWindow()
    end
end

function events:READY_CHECK()
    if ns.db.profile.closeReadyCheck then
        window():Hide()
    end
end

function events:PLAYER_REGEN_DISABLED()
    if ns.db.profile.closeCombat then
        window():Hide()
    end
end

ns.RegisterEnabler("Triggers", function()
    local profile = ns.db.profile
    -- The original hid the window at login unless one of these asked for it.
    if UnitOnTaxi("player") then
        flying = true
        events:RegisterEvent("PLAYER_CONTROL_GAINED")
    end
    if profile.openLogin or (flying and profile.openFlightStart) then
        openWindow()
    else
        window():Hide()
    end
    hooksecurefunc("TakeTaxiNode", onTakeTaxiNode)
    events:RegisterEvent("PLAYER_DEAD")
    events:RegisterEvent("READY_CHECK")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
end)
