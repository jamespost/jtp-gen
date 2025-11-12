-- @description jtp gen: Chord Progression Generator
-- @author James
-- @version 1.0
-- @about
--   # Chord Progression Generator
--   Generates regions with music theory-based chord progressions.
--   Creates one chord per measure with intelligent voice leading.
--   Supports all keys and modes (Major, Minor, Dorian, Phrygian, Lydian, Mixolydian, Locrian).
--
--   Features:
--   - Music theory-based chord movement (circle of 5ths, common progressions)
--   - Modal harmony support
--   - Customizable progression length
--   - Region naming with chord symbols
--   - Functional harmony (I-IV-V-I, ii-V-I, etc.)

if not reaper then return end

-- Debug flag
local DEBUG = false

-- =============================
-- Music Theory Definitions
-- =============================

-- Scale degrees (intervals from root in semitones)
local Modes = {
    Major = {0, 2, 4, 5, 7, 9, 11},          -- Ionian
    Minor = {0, 2, 3, 5, 7, 8, 10},          -- Natural Minor (Aeolian)
    Dorian = {0, 2, 3, 5, 7, 9, 10},
    Phrygian = {0, 1, 3, 5, 7, 8, 10},
    Lydian = {0, 2, 4, 6, 7, 9, 11},
    Mixolydian = {0, 2, 4, 5, 7, 9, 10},
    Locrian = {0, 1, 3, 5, 6, 8, 10},
}

-- Note names for display
local NoteNames = {
    [0] = "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
}

-- Chord quality for each scale degree (1-7) in different modes
local ChordQualities = {
    Major = {"maj", "min", "min", "maj", "maj", "min", "dim"},
    Minor = {"min", "dim", "maj", "min", "min", "maj", "maj"},
    Dorian = {"min", "min", "maj", "maj", "min", "dim", "maj"},
    Phrygian = {"min", "maj", "maj", "min", "dim", "maj", "min"},
    Lydian = {"maj", "maj", "min", "dim", "maj", "min", "min"},
    Mixolydian = {"maj", "min", "dim", "maj", "min", "min", "maj"},
    Locrian = {"dim", "maj", "min", "min", "maj", "maj", "min"},
}

-- Roman numeral notation
local RomanNumerals = {
    [1] = "I", [2] = "II", [3] = "III", [4] = "IV",
    [5] = "V", [6] = "VI", [7] = "VII"
}

-- =============================
-- Chord Progression Templates
-- =============================

-- Common progression patterns (scale degrees)
-- These are musically proven progressions
local ProgressionTemplates = {
    -- Pop/Rock progressions
    {1, 5, 6, 4},      -- I-V-vi-IV (very popular)
    {1, 4, 5, 1},      -- I-IV-V-I (classic)
    {1, 6, 4, 5},      -- I-vi-IV-V (50s progression)
    {6, 4, 1, 5},      -- vi-IV-I-V (sad to happy)

    -- Jazz progressions
    {2, 5, 1},         -- ii-V-I (jazz standard)
    {1, 6, 2, 5},      -- I-vi-ii-V (turnaround)
    {3, 6, 2, 5},      -- iii-vi-ii-V (circle progression)

    -- Modal progressions
    {1, 7, 1},         -- I-VII-I (modal vamp)
    {1, 2, 1},         -- I-II-I (Dorian feel)
    {4, 1, 4, 1},      -- IV-I vamp (Mixolydian)

    -- Extended progressions
    {1, 4, 1, 5, 1},   -- I-IV-I-V-I (gospel)
    {1, 3, 4, 4},      -- I-iii-IV-IV
    {1, 5, 6, 3, 4, 1, 4, 5}, -- Extended pop progression
}

-- =============================
-- Music Theory Logic
-- =============================

-- Get chord name from root note and quality
function get_chord_name(root_midi, quality)
    local note_name = NoteNames[root_midi % 12]
    local quality_symbol = ""

    if quality == "min" then
        quality_symbol = "m"
    elseif quality == "dim" then
        quality_symbol = "°"
    elseif quality == "maj" then
        quality_symbol = ""  -- Major is default
    end

    return note_name .. quality_symbol
end

-- Get roman numeral with quality
function get_roman_numeral(degree, quality)
    local numeral = RomanNumerals[degree]

    if quality == "min" then
        numeral = numeral:lower()
    elseif quality == "dim" then
        numeral = numeral:lower() .. "°"
    end

    return numeral
end

-- Calculate chord root note from key, mode, and scale degree
function get_chord_root(key_root, mode_intervals, degree)
    -- degree is 1-7, convert to 0-6 for array access
    local scale_position = degree - 1
    local interval = mode_intervals[scale_position + 1]
    return key_root + interval
end

-- Smart chord progression generator using music theory
function generate_smart_progression(length, mode_name)
    local progression = {}

    -- If length matches a template, use it
    for _, template in ipairs(ProgressionTemplates) do
        if #template == length then
            -- Use template with some variation chance
            if math.random() < 0.7 then  -- 70% chance to use exact template
                return template
            end
        end
    end

    -- Generate custom progression using music theory rules
    local current_degree = 1  -- Start on tonic
    table.insert(progression, current_degree)

    -- Define strong movements for each degree (most common progressions)
    local strong_movements = {
        [1] = {4, 5, 6, 2},    -- I can go to IV, V, vi, ii
        [2] = {5, 1},          -- ii wants to go to V or I
        [3] = {6, 4},          -- iii to vi or IV
        [4] = {5, 1, 2},       -- IV to V, I, or ii
        [5] = {1, 6},          -- V wants to resolve to I or go to vi (deceptive)
        [6] = {2, 4, 5},       -- vi to ii, IV, or V
        [7] = {1, 3},          -- VII to I or iii (modal)
    }

    for i = 2, length do
        local options = strong_movements[current_degree]

        -- Weighted selection (favor certain movements)
        if current_degree == 5 and i == length then
            -- Dominant wants to resolve to tonic at end
            current_degree = 1
        elseif current_degree == 2 and math.random() < 0.7 then
            -- ii strongly wants to go to V
            current_degree = 5
        elseif options then
            current_degree = options[math.random(1, #options)]
        else
            -- Fallback: random degree
            current_degree = math.random(1, 7)
        end

        table.insert(progression, current_degree)
    end

    -- Ensure progression ends on tonic if long enough
    if length >= 4 and progression[length] ~= 1 then
        progression[length] = 1
    end

    return progression
end

-- =============================
-- Region Creation
-- =============================

-- Create a region with chord name
function create_chord_region(start_time, end_time, chord_name, roman_numeral, color_index)
    -- Region name format: "I: Cmaj" or "vi: Am"
    local region_name = string.format("%s: %s", roman_numeral, chord_name)

    -- Color palette (different colors for different chord functions)
    -- Color is encoded as OS-dependent integer
    local colors = {
        0x00FF0000 | 0x1000000,  -- Red (tonic)
        0x0000FF00 | 0x1000000,  -- Green
        0x000000FF | 0x1000000,  -- Blue (dominant)
        0x00FFFF00 | 0x1000000,  -- Yellow (subdominant)
        0x00FF00FF | 0x1000000,  -- Magenta
        0x0000FFFF | 0x1000000,  -- Cyan
        0x00FFA500 | 0x1000000,  -- Orange
    }

    local color = colors[((color_index - 1) % 7) + 1]

    -- Create region
    local region_index = reaper.AddProjectMarker2(
        0,           -- project
        true,        -- isrgn (true for region)
        start_time,  -- pos
        end_time,    -- rgnend
        region_name, -- name
        -1,          -- wantidx (-1 = auto)
        color        -- color
    )

    return region_index
end

-- =============================
-- Main Generation Function
-- =============================

function generate_chord_progression(params)
    reaper.Undo_BeginBlock()

    -- Parameters
    local key_root = params.key_root or 60  -- C4 (MIDI note number 0-11 for root)
    local mode_name = params.mode or "Major"
    local progression_length = params.length or 8
    local start_time = params.start_time or reaper.GetCursorPosition()

    -- Get mode intervals
    local mode_intervals = Modes[mode_name]
    if not mode_intervals then
        reaper.ShowMessageBox("Invalid mode: " .. mode_name, "Error", 0)
        reaper.Undo_EndBlock("jtp gen: Chord Progression Generator", -1)
        return
    end

    -- Get chord qualities for this mode
    local qualities = ChordQualities[mode_name]

    -- Get time signature to calculate measure length
    local time_sig_num, time_sig_denom = reaper.TimeMap_GetTimeSigAtTime(0, start_time)
    local qn_per_measure = (4 / time_sig_denom) * time_sig_num
    local tempo = reaper.TimeMap2_GetDividedBpmAtTime(0, start_time)
    local measure_length = (60 / tempo) * qn_per_measure

    -- Generate progression using music theory
    local progression = generate_smart_progression(progression_length, mode_name)

    -- Create regions for each chord
    for i, degree in ipairs(progression) do
        local region_start = start_time + ((i - 1) * measure_length)
        local region_end = region_start + measure_length

        -- Calculate chord root note
        local chord_root = get_chord_root(key_root, mode_intervals, degree)

        -- Get chord quality
        local quality = qualities[degree]

        -- Get chord name and roman numeral
        local chord_name = get_chord_name(chord_root, quality)
        local roman_numeral = get_roman_numeral(degree, quality)

        -- Create region
        create_chord_region(region_start, region_end, chord_name, roman_numeral, degree)

        if DEBUG then
            reaper.ShowConsoleMsg(string.format(
                "Measure %d: %s (%s) at %.2fs\n",
                i, roman_numeral, chord_name, region_start
            ))
        end
    end

    reaper.UpdateTimeline()
    reaper.Undo_EndBlock("jtp gen: Chord Progression Generator", -1)

    if DEBUG then
        reaper.ShowConsoleMsg(string.format(
            "\nGenerated %d-chord progression in %s %s\n",
            progression_length, NoteNames[key_root % 12], mode_name
        ))
    end
end

-- =============================
-- User Interface
-- =============================

function show_parameter_gui()
    -- Key selection menu
    local key_menu = "C|C#|D|D#|E|F|F#|G|G#|A|A#|B"
    gfx.x, gfx.y = reaper.GetMousePosition()
    local key_choice = gfx.showmenu(key_menu)

    if key_choice == 0 then return nil end

    local key_root = (key_choice - 1) + 60  -- MIDI note (C4 = 60)

    -- Mode selection menu
    local mode_menu = "Major (Ionian)|Natural Minor (Aeolian)|Dorian|Phrygian|Lydian|Mixolydian|Locrian"
    gfx.x, gfx.y = reaper.GetMousePosition()
    local mode_choice = gfx.showmenu(mode_menu)

    if mode_choice == 0 then return nil end

    local mode_names = {"Major", "Minor", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Locrian"}
    local mode_name = mode_names[mode_choice]

    -- Get progression length
    local retval, user_input = reaper.GetUserInputs(
        "Chord Progression Length",
        1,
        "Number of measures (chords):",
        "8"
    )

    if not retval then return nil end

    local progression_length = tonumber(user_input) or 8

    -- Validate length
    if progression_length < 2 or progression_length > 32 then
        reaper.ShowMessageBox("Please enter a length between 2 and 32 measures.", "Invalid Length", 0)
        return nil
    end

    return {
        key_root = key_root,
        mode = mode_name,
        length = progression_length,
        start_time = reaper.GetCursorPosition()
    }
end

-- =============================
-- Main Entry Point
-- =============================

function main()
    -- Seed random number generator
    math.randomseed(os.time())

    -- Show GUI and get parameters
    local params = show_parameter_gui()

    if not params then
        if DEBUG then reaper.ShowConsoleMsg("Operation cancelled by user\n") end
        return
    end

    -- Generate the progression
    generate_chord_progression(params)

    -- Show success message
    local key_name = NoteNames[params.key_root % 12]
    reaper.ShowMessageBox(
        string.format(
            "Created %d-measure chord progression\nKey: %s %s\nStarting at edit cursor",
            params.length,
            key_name,
            params.mode
        ),
        "Chord Progression Generated",
        0
    )
end

-- Run the script
main()
