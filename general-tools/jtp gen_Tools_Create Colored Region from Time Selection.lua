-- @description jtp gen: Create Colored Region from Time Selection
-- @author James
-- @version 1.0
-- @about
--   # jtp gen: Create Colored Region from Time Selection
--   Creates a region from the current time selection using dropdown dialogs.
--   The region color is based on the selected root note, matching REAPER's
--   MIDI piano roll per-note color scheme.
--
--   ## Usage
--   1. Make a time selection in the REAPER timeline
--   2. Run this script
--   3. Select root note from dropdown menu
--   4. Select octave from dropdown menu
--   5. Enter region name
--   6. A region will be created with the specified name and note-based color
--
--   ## Notes
--   - Requires a time selection to be active
--   - Colors match REAPER's piano roll per-note coloring
--   - Settings are remembered between uses via ExtState

-- Check if reaper API is available
if not reaper then return end

-- =============================
-- Defaults and persistence
-- =============================
local EXT_SECTION = 'jtp_gen_colored_region'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- Defaults
local defaults = {
    root_note = tonumber(get_ext('root_note', 60)), -- Middle C
    scale_name = get_ext('scale_name', 'major')
}

-- Scale list (same as melody generator)
local scale_names = {
    "major", "natural_minor", "dorian", "phrygian", "lydian",
    "mixolydian", "locrian", "harmonic_minor", "melodic_minor",
    "major_pentatonic", "minor_pentatonic", "whole_tone", "blues"
}

-- =============================
-- REAPER Piano Roll Colors
-- =============================
-- These colors match REAPER's MIDI editor per-note coloring
-- Based on the chromatic scale (C=0, C#=1, D=2, etc.)
local piano_roll_colors = {
    [0]  = {255, 255, 255},  -- C  - White
    [1]  = {180, 180, 180},  -- C# - Light Gray
    [2]  = {255, 200, 100},  -- D  - Orange
    [3]  = {200, 180, 100},  -- D# - Tan
    [4]  = {255, 255, 100},  -- E  - Yellow
    [5]  = {100, 255, 100},  -- F  - Light Green
    [6]  = {100, 200, 100},  -- F# - Green
    [7]  = {100, 255, 255},  -- G  - Cyan
    [8]  = {100, 200, 200},  -- G# - Teal
    [9]  = {150, 150, 255},  -- A  - Light Blue
    [10] = {120, 120, 200},  -- A# - Blue
    [11] = {255, 150, 200},  -- B  - Pink
}

local function get_color_for_note(midi_note)
    local note_class = midi_note % 12
    local rgb = piano_roll_colors[note_class]
    return reaper.ColorToNative(rgb[1], rgb[2], rgb[3]) | 0x1000000
end

-- =============================
-- Dialog helpers
-- =============================
-- Note names with enharmonic equivalents
local note_names = {"C","C#/Db","D","D#/Eb","E","F","F#/Gb","G","G#/Ab","A","A#/Bb","B"}

-- Map display names back to MIDI pitch class
local note_display_to_pitch_class = {
    ["C"] = 0,
    ["C#/Db"] = 1,
    ["D"] = 2,
    ["D#/Eb"] = 3,
    ["E"] = 4,
    ["F"] = 5,
    ["F#/Gb"] = 6,
    ["G"] = 7,
    ["G#/Ab"] = 8,
    ["A"] = 9,
    ["A#/Bb"] = 10,
    ["B"] = 11
}

local function note_name_to_pitch(name, octave)
    local pitch_class = note_display_to_pitch_class[name]
    if pitch_class then
        return (octave + 1) * 12 + pitch_class
    end
    return nil
end

local function show_popup_menu(items, default_idx)
    -- Build menu string for gfx.showmenu with checkmark on default
    local menu_str = ""
    for i, item in ipairs(items) do
        if i == default_idx then
            menu_str = menu_str .. "!" .. item .. "|"
        else
            menu_str = menu_str .. item .. "|"
        end
    end

    -- Position menu at mouse cursor
    gfx.x, gfx.y = reaper.GetMousePosition()
    local choice = gfx.showmenu(menu_str)
    return choice -- Returns 0 if cancelled, or 1-based index of selection
end

-- =============================
-- Main script logic
-- =============================
function main()
    -- Check if there's a time selection
    local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    if start_time == end_time then
        reaper.ShowMessageBox(
            "Please make a time selection first.",
            "jtp gen: No Time Selection",
            0
        )
        return
    end

    -- =============================
    -- Dialog - Step 1: Root Note Selection
    -- =============================

    -- Convert stored root_note to note name and octave for display
    local default_note_name = note_names[(defaults.root_note % 12) + 1]
    local default_octave = math.floor(defaults.root_note / 12) - 1

    -- Find default note index
    local default_note_idx = 1
    for i, name in ipairs(note_names) do
        if name == default_note_name then
            default_note_idx = i
            break
        end
    end

    -- Show note selection menu
    local note_choice = show_popup_menu(note_names, default_note_idx)
    if note_choice == 0 then return end -- User cancelled

    -- Show octave selection menu
    local octaves = {"0","1","2","3","4","5","6","7","8","9"}
    local default_octave_idx = default_octave + 1 -- Convert to 1-based index
    local octave_choice = show_popup_menu(octaves, default_octave_idx)
    if octave_choice == 0 then return end -- User cancelled

    -- Show scale selection menu
    local default_scale_idx = 1
    for i, name in ipairs(scale_names) do
        if name == defaults.scale_name then
            default_scale_idx = i
            break
        end
    end

    local scale_choice = show_popup_menu(scale_names, default_scale_idx)
    if scale_choice == 0 then return end -- User cancelled

    -- Process selections
    local input_note_name = note_names[note_choice]
    local input_octave = tonumber(octaves[octave_choice])
    local root_note = note_name_to_pitch(input_note_name, input_octave)
    local scale_name = scale_names[scale_choice]

    -- Generate region name automatically from note, octave, and scale
    local region_name = string.format('%s%d %s', input_note_name, input_octave, scale_name)

    -- Persist for next run
    set_ext('root_note', root_note)
    set_ext('scale_name', scale_name)

    -- Get color based on root note
    local region_color = get_color_for_note(root_note)

    -- Begin undo block
    reaper.Undo_BeginBlock()

    -- Create the region
    local region_index = reaper.AddProjectMarker2(
        0,              -- project
        true,           -- isrgn (true for region)
        start_time,     -- pos
        end_time,       -- rgnend
        region_name,    -- name
        -1,             -- wantidx (-1 = auto-assign)
        region_color    -- color
    )

    -- Update the arrange view
    reaper.UpdateArrange()

    -- End undo block with descriptive name
    reaper.Undo_EndBlock("jtp gen: Create Colored Region", -1)
end

-- Run the script
main()
