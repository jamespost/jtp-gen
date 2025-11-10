-- @description jtp gen: Scale Transposer
-- @author James
-- @version 1.0
-- @about
--   # jtp gen: Scale Transposer
--   Intelligently transposes MIDI items to different scales and keys.
--   Parses the item name to detect current scale/key, shows a dialog
--   to select new scale/key, and fits notes to the new scale using
--   intelligent pitch mapping.
--
--   Compatible with jtp gen Melody Generator Dialog script.
--   Uses the same scale definitions and naming conventions.

-- Check if reaper API is available
if not reaper then return end

-- =============================
-- Scale definitions (matching Melody Generator Dialog)
-- =============================
local scales = {
    major = {0,2,4,5,7,9,11},
    natural_minor = {0,2,3,5,7,8,10},
    dorian = {0,2,3,5,7,9,10},
    phrygian = {0,1,3,5,7,8,10},
    lydian = {0,2,4,6,7,9,11},
    mixolydian = {0,2,4,5,7,9,10},
    locrian = {0,1,3,5,6,8,10},
    harmonic_minor = {0,2,3,5,7,8,11},
    melodic_minor = {0,2,3,5,7,9,11},
    major_pentatonic = {0,2,4,7,9},
    minor_pentatonic = {0,3,5,7,10},
    whole_tone = {0,2,4,6,8,10},
    blues = {0,3,5,6,7,10}
}

local scale_keys = {}
for k in pairs(scales) do scale_keys[#scale_keys+1] = k end
table.sort(scale_keys)

-- =============================
-- Note name parsing
-- =============================
local note_names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

-- Map of enharmonic equivalents
local enharmonic_map = {
    ["C"] = 0, ["B#"] = 0,
    ["C#"] = 1, ["DB"] = 1,
    ["D"] = 2,
    ["D#"] = 3, ["EB"] = 3,
    ["E"] = 4, ["FB"] = 4,
    ["F"] = 5, ["E#"] = 5,
    ["F#"] = 6, ["GB"] = 6,
    ["G"] = 7,
    ["G#"] = 8, ["AB"] = 8,
    ["A"] = 9,
    ["A#"] = 10, ["BB"] = 10,
    ["B"] = 11, ["CB"] = 11
}

local function note_name_to_pitch(name, octave)
    -- Convert note name like "C", "C#", "Db" to MIDI pitch
    -- Accept both sharps and flats
    local pitch_class = enharmonic_map[name:upper()]
    if pitch_class then
        return (octave + 1) * 12 + pitch_class
    end
    return nil
end

local function pitch_to_note_name(pitch)
    -- Convert MIDI pitch to note name and octave
    local note = note_names[(pitch % 12) + 1]
    local octave = math.floor(pitch / 12) - 1
    return note, octave
end

local function parse_item_name(name)
    -- Parse item name format: "C4 major" or "G#3 minor_pentatonic" or "Db4 blues"
    -- Returns: root_note (MIDI), scale_name, or nil if not parseable

    -- Try to match note name (with optional sharp or flat), octave, and scale
    local note_pattern = "([A-G][#bB]?)(%d+)%s+([%w_]+)"
    local note_str, octave_str, scale_str = name:match(note_pattern)

    if note_str and octave_str and scale_str then
        local octave = tonumber(octave_str)
        local root_note = note_name_to_pitch(note_str, octave)
        local scale_name = scale_str:lower()

        -- Validate scale exists
        if root_note and scales[scale_name] then
            return root_note, scale_name
        end
    end

    return nil, nil
end

-- =============================
-- Scale building and transposition
-- =============================
local function build_full_scale(root_note, scale_intervals)
    -- Build full chromatic-range scale from root and intervals
    local full_scale = {}
    for octave = 0, 10 do
        for _, interval in ipairs(scale_intervals) do
            local pitch = root_note + (octave * 12) + interval
            if pitch >= 0 and pitch <= 127 then
                full_scale[#full_scale + 1] = pitch
            end
        end
    end
    table.sort(full_scale)
    return full_scale
end

local function find_closest_note(pitch, target_scale)
    -- Find the closest note in target scale to the given pitch
    local min_dist = 128
    local closest = target_scale[1]

    for _, note in ipairs(target_scale) do
        local dist = math.abs(note - pitch)
        if dist < min_dist then
            min_dist = dist
            closest = note
        end
    end

    return closest
end

local function find_scale_degree(pitch, scale)
    -- Find which scale degree a pitch belongs to (0-based within octave)
    local pitch_class = pitch % 12
    for i, interval in ipairs(scale) do
        if interval == pitch_class then
            return i - 1
        end
    end
    return nil
end

local function transpose_intelligent(pitch, old_root, old_scale, new_root, new_scale)
    -- Intelligent transposition:
    -- 1. Determine the scale degree in old scale
    -- 2. Map to same scale degree in new scale
    -- 3. Maintain relative octave

    local old_intervals = scales[old_scale]
    local new_intervals = scales[new_scale]

    -- Calculate pitch relative to old root
    local relative_pitch = pitch - old_root
    local octaves = math.floor(relative_pitch / 12)
    local pitch_class = relative_pitch % 12

    -- Find scale degree in old scale
    local scale_degree = find_scale_degree(pitch_class, old_intervals)

    if scale_degree then
        -- Map to same scale degree in new scale (wrapping if necessary)
        local new_degree = scale_degree % #new_intervals
        local new_interval = new_intervals[new_degree + 1]
        local new_pitch = new_root + (octaves * 12) + new_interval

        -- Clamp to valid MIDI range
        return math.max(0, math.min(127, new_pitch))
    else
        -- Note not in scale - find closest note in new scale
        local new_full_scale = build_full_scale(new_root, new_intervals)
        return find_closest_note(pitch, new_full_scale)
    end
end

-- =============================
-- Main script
-- =============================
local function main()
    -- Get selected MIDI item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        reaper.ShowMessageBox('Please select a MIDI item first.', 'No Item Selected', 0)
        return
    end

    local take = reaper.GetActiveTake(item)
    if not take or not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox('Selected item must be a MIDI item.', 'Invalid Item', 0)
        return
    end

    -- Get and parse item name
    local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
    local current_root, current_scale = parse_item_name(item_name)

    -- Set defaults
    local default_root = current_root or 60  -- C4
    local default_scale = current_scale or 'major'

    local root_note_name, root_octave = pitch_to_note_name(default_root)
    local detected_text = current_root and "DETECTED" or "NOT DETECTED"

    -- Build scale list for display
    local scale_list = table.concat(scale_keys, ', ')

    -- Show dialog
    local captions = table.concat({
        'Current: ' .. item_name .. ' [' .. detected_text .. ']',
        'New Root Note (C, C#/Db, D, etc.)',
        'New Root Octave (0-9)',
        'New Scale (' .. scale_list .. ')'
    }, ',')

    local defaults_csv = table.concat({
        '',  -- Info field (non-editable placeholder)
        root_note_name,
        tostring(root_octave),
        default_scale
    }, ',')

    local ok, ret = reaper.GetUserInputs('jtp gen: Scale Transposer', 4, captions .. ',extrawidth=200', defaults_csv)
    if not ok then return end

    -- Parse dialog results
    local fields = {}
    for s in string.gmatch(ret .. ',', '([^,]*),') do fields[#fields+1] = s end

    local new_note_name = fields[2]:upper()
    local new_octave = tonumber(fields[3])
    local new_scale_name = fields[4]:lower()

    -- Validate inputs
    local new_root_note = note_name_to_pitch(new_note_name, new_octave)
    if not new_root_note then
        reaper.ShowMessageBox('Invalid note name. Use format like: C, C#, Db, D, etc.', 'Invalid Input', 0)
        return
    end

    if not scales[new_scale_name] then
        reaper.ShowMessageBox('Invalid scale name. Must be one of: ' .. scale_list, 'Invalid Scale', 0)
        return
    end

    -- If we couldn't detect the original scale, ask user to confirm
    if not current_root then
        local response = reaper.ShowMessageBox(
            'Could not detect original scale from item name.\n\n' ..
            'Assuming: ' .. root_note_name .. root_octave .. ' ' .. default_scale .. '\n\n' ..
            'Continue with transposition?',
            'Scale Not Detected',
            4  -- Yes/No
        )
        if response ~= 6 then return end  -- 6 = Yes
        current_root = default_root
        current_scale = default_scale
    end

    -- Begin transposition
    reaper.Undo_BeginBlock()

    local _, note_count = reaper.MIDI_CountEvts(take)
    local notes_transposed = 0

    -- Process each note
    for i = 0, note_count - 1 do
        local _, selected, muted, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)

        -- Transpose to new scale
        local new_pitch = transpose_intelligent(pitch, current_root, current_scale, new_root_note, new_scale_name)

        -- Update note
        reaper.MIDI_SetNote(take, i, selected, muted, start_ppq, end_ppq, chan, new_pitch, vel, true)
        notes_transposed = notes_transposed + 1
    end

    -- Update item name
    local new_name = string.format('%s%d %s', new_note_name, new_octave, new_scale_name)
    reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', new_name, true)

    reaper.Undo_EndBlock('jtp gen: Scale Transposer', -1)
    reaper.UpdateArrange()

    reaper.ShowMessageBox(
        string.format('Transposed %d notes\n\nFrom: %s%d %s\nTo: %s%d %s',
            notes_transposed,
            root_note_name, root_octave, current_scale,
            new_note_name, new_octave, new_scale_name),
        'Transposition Complete',
        0
    )
end

-- Run main function
main()
