local _, ns = ...
local C = ns.C

-- Game sounds. Play takes a C.SOUND_* number or a file name in sounds/; the Quiet setting
-- swaps in the "q_" copies of the same files.

local Sound = {}
ns.Sound = Sound

function Sound.Play(sound)
    local setting = ns.db.profile.sound
    if setting == "off" then
        return
    end
    local file = type(sound) == "number" and C.SOUND_FILES[sound] or sound
    if not file or file == "" then
        return
    end
    local prefix = setting == "quiet" and "q_" or ""
    PlaySoundFile(C.SOUND_PATH .. prefix .. file, "Master")
end

-- Peg hit sound. The pitch climbs with the number of pegs hit this shot; after the second and
-- third free-ball thresholds (range 1, 2) it switches to the higher "plus" sets.
function Sound.PegHit(count, range)
    local file
    if range == 1 then
        local step = math.min(count - 12, 9)
        if step < -7 then
            return -- the original asked for files below -7, which don't exist
        end
        file = step < 0 and ("peghit_plus4b" .. step .. ".ogg") or ("peghit_plus4b+" .. step .. ".ogg")
    elseif range == 2 then
        file = "peghit_plus_mega9.ogg"
    else
        file = "peghitx" .. math.min(count, 18) .. ".ogg"
    end
    Sound.Play(file)
end
