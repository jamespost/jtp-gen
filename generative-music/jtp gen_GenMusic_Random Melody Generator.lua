-- @description jtp gen: Random Melody Generator
-- @author James
-- @version 1.0
-- @about
--   # Random Melody Generator
--
--   ## Description
--   Generates a random melodic sequence on the selected MIDI item
--   using a specified scale and range.
--
--   ## Usage
--   1. Select a MIDI item
--   2. Run this script
--   3. Choose your parameters in the dialog
--
--   ## Notes
--   - Uses common musical scales
--   - Configurable note range and rhythm

if not reaper then
    return
end

-- Musical scales (intervals from root)
local SCALES = {
    major = {0, 2, 4, 5, 7, 9, 11},
    minor = {0, 2, 3, 5, 7, 8, 10},
    pentatonic = {0, 2, 4, 7, 9},
    blues = {0, 3, 5, 6, 7, 10},
}

local function log(message)
    reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

local function getUserInput()
    local retval, user_input = reaper.GetUserInputs(
        "jtp gen: Random Melody Generator",
        4,
        "Root note (C=60):,Scale (major/minor/pentatonic/blues):,Number of notes:,Note duration (beats):",
        "60,major,16,0.25"
    )

    if not retval then
        return nil
    end

    local root, scale_name, num_notes, duration = user_input:match("([^,]+),([^,]+),([^,]+),([^,]+)")

    return {
        root = tonumber(root) or 60,
        scale = scale_name or "major",
        num_notes = tonumber(num_notes) or 16,
        duration = tonumber(duration) or 0.25
    }
end

function main()
    local params = getUserInput()
    if not params then
        return  -- User cancelled
    end

    reaper.Undo_BeginBlock()

    -- Get selected MIDI item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        reaper.ShowMessageBox("Please select a MIDI item first.", "jtp gen: Melody Generator", 0)
        return
    end

    local take = reaper.GetActiveTake(item)
    if not take or not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox("Selected item is not a MIDI item.", "jtp gen: Melody Generator", 0)
        return
    end

    -- Get scale intervals
    local scale = SCALES[params.scale] or SCALES.major

    -- Generate random melody
    log("jtp gen: Generating " .. params.num_notes .. " notes in " .. params.scale .. " scale")

    math.randomseed(os.time())

    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjTime(take, 1.0)
    local note_length_ppq = ppq_per_beat * params.duration

    for i = 0, params.num_notes - 1 do
        local scale_degree = math.random(1, #scale)
        local pitch = params.root + scale[scale_degree]
        local start_ppq = i * note_length_ppq
        local end_ppq = start_ppq + note_length_ppq
        local velocity = 80 + math.random(-20, 20)

        reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, 0, pitch, velocity, false)
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()

    log("Melody generated successfully!")

    reaper.Undo_EndBlock("jtp gen: Random Melody Generator", -1)
end

main()
