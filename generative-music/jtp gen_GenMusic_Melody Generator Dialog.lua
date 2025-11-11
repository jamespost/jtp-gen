-- @description jtp gen: Melody Generator (Simple Dialog)
-- @author James
-- @version 1.8
-- @about
--   # jtp gen: Melody Generator (Simple Dialog)
--   Generates a MIDI melody with a simple built-in REAPER dialog (no ImGui required).
--   Lets you set a few key parameters quickly and create a melody on the selected track.
--
--   NEW in v1.8: Melodic Memory and Motif Repetition!
--   - Phrase memory buffer stores last 3-5 phrases
--   - Motif repetition chance parameter (30-50% default)
--   - Retrieves and varies previous phrases with transposition
--   - Creates recognizable melodic themes and development
--   - Augmentation/diminution for rhythmic variation
--
--   v1.7: Phrase-Based Structure!
--   - Replaced note-by-note generation with phrase-based system
--   - Each phrase has 4-8 notes with coherent contour shapes
--   - Five contour types: arch, ascending, descending, valley, wave
--   - Intelligent variation: next phrase contrasts with previous
--   - Creates more musical, structured melodies with clear phrases
--
--   v1.6: Rhythmic Guitar Mode!
--   - Adapted from adaptive drum generator
--   - Uses drum-style rhythm/articulation patterns with guitar note choices
--   - Features: bursts, double hits, focused riffs, rhythmic complexity
--   - Combines physical constraint modeling with melodic note selection
--   - Disabled by default - toggle in parameters dialog
--
--   NEW in v1.5: Auto Mode - One-Click Generation!
--   - First dialog: Choose "Auto" to instantly generate with last settings, or "Manual" to configure
--   - Auto mode = zero-click generation with your preferred settings
--   - Perfect for rapid iteration and workflow speed
--
--   Auto-detection mode (enabled by default) - automatically detects root note and
--   scale from the name of the region containing the selected item or edit cursor.
--   When a region is detected, note/octave/scale dialogs are skipped!
--
--   Advanced Polyphony with Music Theory (v1.4)
--   - Three polyphony modes: Free (creative), Harmonic (chords), Voice Leading (counterpoint)
--   - Theory Weight parameter (0-1) blends between free/creative and strict music theory
--   - Proper voice leading rules: contrary motion, smooth voice movement, consonance
--   - Avoids parallel perfect intervals, voice crossing, and other theory violations
--   - Weight 0 = original creative behavior, Weight 1 = strict theory adherence
--
--   Supported region name formats:
--   - "C Major", "Dm", "G# minor", "Ab Dorian" (defaults to octave 4)
--   - "C4 major", "D#2 minor", "Gb5 Lydian" (explicit octave 0-9)
--   - Supports sharps (#), flats (b), and various scale names
--
--   Dialog options:
--   - Auto-detect from region (ON) - Skip dialogs when region detected
--   - Override auto-detected values - Use detected values as defaults but allow changes
--   - Manual selection (OFF) - Always show all dialogs

-- Check if reaper API is available
if not reaper then return end

local DEBUG = false

local function log(...)
    if not DEBUG then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    reaper.ShowConsoleMsg(table.concat(parts, '') .. '\n')
end

if DEBUG then reaper.ClearConsole() end

-- =============================
-- Defaults and persistence
-- =============================
local EXT_SECTION = 'jtp_gen_melody_dialog'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- Reasonable defaults
local defaults = {
    measures = tonumber(get_ext('measures', 2)),
    min_notes = tonumber(get_ext('min_notes', 3)),
    max_notes = tonumber(get_ext('max_notes', 7)),
    min_keep = tonumber(get_ext('min_keep', 12)),
    max_keep = tonumber(get_ext('max_keep', 24)),
    root_note = tonumber(get_ext('root_note', 60)), -- Middle C
    scale_name = get_ext('scale_name', 'random'), -- type a name from list below or 'random'
    num_voices = tonumber(get_ext('num_voices', 4)), -- Number of melodic voices (1-16)
    auto_detect = get_ext('auto_detect', '1') == '1', -- Auto-detect from region name (default enabled)
    ca_mode = get_ext('ca_mode', '0') == '1', -- Cellular Automata mode (default disabled)
    poly_mode = get_ext('poly_mode', 'free'), -- Polyphony mode: 'free', 'harmonic', 'voice_leading'
    theory_weight = tonumber(get_ext('theory_weight', 0.5)), -- 0.0 = free, 1.0 = strict theory
    rhythmic_guitar_mode = get_ext('rhythmic_guitar_mode', '0') == '1', -- Rhythmic guitar mode (default disabled)
    motif_mode = get_ext('motif_mode', 'melodic'), -- 'melodic' or 'rhythmic'
    repetition_allowance = tonumber(get_ext('repetition_allowance', 3)), -- 2-4 allowed repeats
    motif_repeat_chance = tonumber(get_ext('motif_repeat_chance', 40)), -- 0-100% chance of repeating a previous phrase
}

-- Small curated scale list (intervals from root)
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

-- Build sorted scale list for consistent menu ordering
local scale_keys = {}
for k in pairs(scales) do scale_keys[#scale_keys+1] = k end
table.sort(scale_keys)

-- =============================
-- Helpers
-- =============================
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function choose_random(t)
    return t[math.random(1, #t)]
end

local function table_contains(t, x)
    for i = 1, #t do if t[i] == x then return true end end
    return false
end

-- =============================
-- Region name parsing
-- =============================

-- Parse region name to extract root note and scale
-- Supports formats like: "C Major", "Dm", "G# minor", "Ab Dorian", "C4 major", etc.
local function parse_region_name(region_name)
    if not region_name or region_name == "" then return nil, nil, nil end

    -- Normalize the string
    local name = region_name:lower():gsub("^%s*(.-)%s*$", "%1") -- trim whitespace

    -- Define note patterns with their pitch classes
    local note_patterns = {
        {"c#", 1}, {"c♯", 1}, {"db", 1}, {"d♭", 1}, {"c sharp", 1}, {"d flat", 1},
        {"c", 0},
        {"d#", 3}, {"d♯", 3}, {"eb", 3}, {"e♭", 3}, {"d sharp", 3}, {"e flat", 3},
        {"d", 2},
        {"e", 4},
        {"f#", 6}, {"f♯", 6}, {"gb", 6}, {"g♭", 6}, {"f sharp", 6}, {"g flat", 6},
        {"f", 5},
        {"g#", 8}, {"g♯", 8}, {"ab", 8}, {"a♭", 8}, {"g sharp", 8}, {"a flat", 8},
        {"g", 7},
        {"a#", 10}, {"a♯", 10}, {"bb", 10}, {"b♭", 10}, {"a sharp", 10}, {"b flat", 10},
        {"a", 9},
        {"b", 11}
    }

    -- Try to find note at start of name
    local found_note_class = nil
    local remaining_text = name

    for _, pattern_data in ipairs(note_patterns) do
        local pattern = pattern_data[1]
        local pitch_class = pattern_data[2]

        -- Try to match at start with word boundary
        if name:match("^" .. pattern .. "[%s_%-]") or name:match("^" .. pattern .. "$") then
            found_note_class = pitch_class
            remaining_text = name:gsub("^" .. pattern, ""):gsub("^[%s_%-]+", "")
            break
        end
    end

    if not found_note_class then return nil, nil, nil end

    -- Try to extract octave number (0-9) if present
    local found_octave = nil
    local octave_match = remaining_text:match("^(%d)")
    if octave_match then
        found_octave = tonumber(octave_match)
        -- Remove the octave from remaining text
        remaining_text = remaining_text:gsub("^%d+", ""):gsub("^[%s_%-]+", "")
    end

    -- Now try to find scale in remaining text
    local scale_patterns = {
        {"maj", "major"},
        {"major", "major"},
        {"m", "natural_minor"},
        {"min", "natural_minor"},
        {"minor", "natural_minor"},
        {"dor", "dorian"},
        {"dorian", "dorian"},
        {"phryg", "phrygian"},
        {"phrygian", "phrygian"},
        {"lyd", "lydian"},
        {"lydian", "lydian"},
        {"mix", "mixolydian"},
        {"mixolydian", "mixolydian"},
        {"loc", "locrian"},
        {"locrian", "locrian"},
        {"harm", "harmonic_minor"},
        {"harmonic", "harmonic_minor"},
        {"mel", "melodic_minor"},
        {"melodic", "melodic_minor"},
        {"pent", "major_pentatonic"},
        {"pentatonic", "major_pentatonic"},
        {"whole", "whole_tone"},
        {"blues", "blues"}
    }

    local found_scale = nil
    for _, scale_data in ipairs(scale_patterns) do
        local pattern = scale_data[1]
        local scale_name = scale_data[2]

        if remaining_text:match(pattern) then
            found_scale = scale_name
            break
        end
    end

    -- If no scale found, try to infer from minor indicator
    if not found_scale then
        -- Default to major
        found_scale = "major"
    end

    return found_note_class, found_scale, found_octave
end

-- Get region(s) at current position (selected item or edit cursor)
local function get_region_at_position()
    local pos = nil

    -- First, try to get position from selected item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    else
        -- No item selected, use edit cursor
        pos = reaper.GetCursorPosition()
    end

    if not pos then return nil end

    -- Find region at this position
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, is_region, region_start, region_end, name, idx = reaper.EnumProjectMarkers(i)

        if is_region and pos >= region_start and pos < region_end then
            log('Found region: "', name, '" at position ', pos)
            return name
        end
    end

    log('No region found at position ', pos)
    return nil
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
-- Dialog - Step 0: Mode Selection (Auto vs Manual)
-- =============================

-- Declare ALL variables at top level BEFORE any goto statements to avoid scope issues
local auto_detected_note_class = nil
local auto_detected_scale = nil
local auto_detected_octave = nil
local region_name = nil
local auto_detect_enabled
local force_manual = false
local root_note
local scale_name
local measures
local min_notes
local max_notes
local min_keep
local max_keep
local num_voices
local ca_mode
local ca_growth_rate
local ca_time_bias
local poly_mode
local theory_weight
local chosen_scale_key
local chosen_scale
local auto_detect_items
local default_auto_detect_idx
local auto_detect_choice
local default_root_note
local target_octave
local default_note_name
local default_octave
local default_note_idx
local note_choice
local octaves
local default_octave_idx
local octave_choice
local scale_menu_items
local default_scale_name
local default_scale_idx
local scale_choice
local input_note_name
local input_octave
local poly_modes
local default_poly_idx
local poly_choice
local captions
local defaults_csv
local ok
local ret
local fields
local rhythmic_guitar_mode
local motif_repeat_chance

local mode_items = {"Auto (use last settings)", "Manual (configure all settings)"}
local mode_choice = show_popup_menu(mode_items, 1)
if mode_choice == 0 then return end -- User cancelled

local use_auto_mode = (mode_choice == 1)

-- =============================
-- AUTO MODE - Skip all dialogs and use saved settings
-- =============================

if use_auto_mode then
    log('Auto mode selected - using last saved settings')
    -- Jump directly to melody generation
    goto GENERATE_MELODY
end

-- =============================
-- MANUAL MODE - Show all dialogs
-- =============================

-- =============================
-- Auto-detection from region name
-- =============================

if defaults.auto_detect then
    region_name = get_region_at_position()
    if region_name then
        auto_detected_note_class, auto_detected_scale, auto_detected_octave = parse_region_name(region_name)
        if auto_detected_note_class then
            log('Auto-detected from region "', region_name, '": note class ', auto_detected_note_class, ', scale ', auto_detected_scale or 'none', ', octave ', auto_detected_octave or 'default')
        end
    end
end

-- =============================
-- Dialog - Step 1a: Auto-detect Mode Toggle
-- =============================

auto_detect_items = {"Auto-detect from region (ON)", "Manual selection (OFF)"}
default_auto_detect_idx = defaults.auto_detect and 1 or 2

-- If auto-detect found something, add option to override
if auto_detected_note_class and auto_detected_scale then
    table.insert(auto_detect_items, 2, "Override auto-detected values")
    -- Adjust default if needed - item 2 is now override, item 3 is manual off
    if not defaults.auto_detect then
        default_auto_detect_idx = 3 -- Point to "Manual selection (OFF)"
    end
end

auto_detect_choice = show_popup_menu(auto_detect_items, default_auto_detect_idx)
if auto_detect_choice == 0 then return end -- User cancelled

-- Determine mode based on choice
if auto_detected_note_class and auto_detected_scale then
    -- Three-option menu
    if auto_detect_choice == 1 then
        auto_detect_enabled = true
        force_manual = false
    elseif auto_detect_choice == 2 then
        auto_detect_enabled = true
        force_manual = true -- Use auto-detect but allow override
    else -- choice == 3
        auto_detect_enabled = false
        force_manual = true
    end
else
    -- Two-option menu
    auto_detect_enabled = (auto_detect_choice == 1)
    force_manual = not auto_detect_enabled
end

set_ext('auto_detect', auto_detect_enabled and '1' or '0')

-- If user just turned on auto-detect, try to detect now
if auto_detect_enabled and not auto_detected_note_class then
    region_name = get_region_at_position()
    if region_name then
        auto_detected_note_class, auto_detected_scale, auto_detected_octave = parse_region_name(region_name)
    end
end

-- =============================
-- Dialog - Step 1b: Root Note Selection
-- =============================

-- If auto-detect is enabled and successful, skip the dialogs (unless user chose to override)
if auto_detect_enabled and auto_detected_note_class ~= nil and auto_detected_scale and not force_manual then
    -- Use auto-detected values
    target_octave = auto_detected_octave or 4
    root_note = (target_octave + 1) * 12 + auto_detected_note_class
    -- Clamp to valid MIDI range
    if root_note < 0 then root_note = 0 end
    if root_note > 127 then root_note = 127 end
    scale_name = auto_detected_scale

    -- Show confirmation message
    local root_name = note_names[(root_note % 12) + 1]  -- This is OK, only used in this block
    local octave = math.floor(root_note / 12) - 1  -- This is OK, only used in this block
    reaper.MB(
        string.format('Region detected: "%s"\n\nUsing: %s%d %s',
            region_name, root_name, octave, scale_name),
        'Auto-detect Active',
        0
    )
else
    -- Manual selection mode
    -- If we have auto-detected values but user chose to override, use those as defaults
    default_root_note = defaults.root_note
    if auto_detected_note_class and auto_detected_octave then
        target_octave = auto_detected_octave or 4
        default_root_note = (target_octave + 1) * 12 + auto_detected_note_class
        if default_root_note < 0 then default_root_note = 0 end
        if default_root_note > 127 then default_root_note = 127 end
    end

    default_note_name = note_names[(default_root_note % 12) + 1]
    default_octave = math.floor(default_root_note / 12) - 1

    -- Find default note index
    default_note_idx = 1
    for i, name in ipairs(note_names) do
        if name == default_note_name then
            default_note_idx = i
            break
        end
    end

    -- Show note selection menu
    note_choice = show_popup_menu(note_names, default_note_idx)
    if note_choice == 0 then return end -- User cancelled

    -- Show octave selection menu
    octaves = {"0","1","2","3","4","5","6","7","8","9"}
    default_octave_idx = default_octave + 1 -- Convert to 1-based index
    octave_choice = show_popup_menu(octaves, default_octave_idx)
    if octave_choice == 0 then return end -- User cancelled

    -- Show scale selection menu (with random option)
    scale_menu_items = {"random"}
    for _, name in ipairs(scale_keys) do
        table.insert(scale_menu_items, name)
    end

    -- Use auto-detected scale as default if overriding, otherwise use saved preference
    default_scale_name = auto_detected_scale or defaults.scale_name
    default_scale_idx = 1
    if default_scale_name ~= "random" then
        for i, name in ipairs(scale_menu_items) do
            if name == default_scale_name then
                default_scale_idx = i
                break
            end
        end
    end

    scale_choice = show_popup_menu(scale_menu_items, default_scale_idx)
    if scale_choice == 0 then return end -- User cancelled

    -- Process selections from menus
    input_note_name = note_names[note_choice]
    input_octave = tonumber(octaves[octave_choice])
    scale_name = scale_menu_items[scale_choice]
    root_note = note_name_to_pitch(input_note_name, input_octave)
end

-- =============================
-- Dialog - Step 2: Generation Parameters
-- =============================

-- Show polyphony mode selection menu (only if multiple voices)
poly_mode = 'free'
theory_weight = defaults.theory_weight

if defaults.num_voices > 1 then
    poly_modes = {"Free (Creative)", "Harmonic (Chords)", "Voice Leading (Counterpoint)"}
    default_poly_idx = 1
    if defaults.poly_mode == 'harmonic' then default_poly_idx = 2
    elseif defaults.poly_mode == 'voice_leading' then default_poly_idx = 3
    end

    poly_choice = show_popup_menu(poly_modes, default_poly_idx)
    if poly_choice == 0 then return end

    if poly_choice == 1 then poly_mode = 'free'
    elseif poly_choice == 2 then poly_mode = 'harmonic'
    elseif poly_choice == 3 then poly_mode = 'voice_leading'
    end
end

captions = table.concat({
    'Measures',
    'Min Notes',
    'Max Notes',
    'Min Keep',
    'Max Keep',
    'Number of Voices (1-16)',
    'CA Mode (0=off 1=on)',
    'CA: Growth Rate (0.1-1.0)',
    'CA: Time Bias (0-1, 0.5=equal)',
    'Theory Weight (0=free 1=strict)',
    'Rhythmic Guitar Mode (0=off 1=on)',
    'Motif Repeat Chance (0-100%)'
}, ',')

defaults_csv = table.concat({
    tostring(defaults.measures),
    tostring(defaults.min_notes),
    tostring(defaults.max_notes),
    tostring(defaults.min_keep),
    tostring(defaults.max_keep),
    tostring(defaults.num_voices),
    defaults.ca_mode and '1' or '0',
    '0.4',  -- Default growth rate
    '0.6',  -- Default time bias (prefers horizontal)
    tostring(theory_weight),
    defaults.rhythmic_guitar_mode and '1' or '0',
    tostring(defaults.motif_repeat_chance)
}, ',')

ok, ret = reaper.GetUserInputs('jtp gen: Melody Generator - Parameters', 12, captions, defaults_csv)
if not ok then return end

fields = {}
for s in string.gmatch(ret .. ',', '([^,]*),') do fields[#fields+1] = s end

measures = tonumber(fields[1]) or defaults.measures
min_notes = tonumber(fields[2]) or defaults.min_notes
max_notes = tonumber(fields[3]) or defaults.max_notes
min_keep = tonumber(fields[4]) or defaults.min_keep
max_keep = tonumber(fields[5]) or defaults.max_keep
num_voices = tonumber(fields[6]) or defaults.num_voices
ca_mode = (tonumber(fields[7]) or 0) == 1
ca_growth_rate = tonumber(fields[8]) or 0.4
ca_time_bias = tonumber(fields[9]) or 0.6
theory_weight = tonumber(fields[10]) or theory_weight
rhythmic_guitar_mode = (tonumber(fields[11]) or 0) == 1
motif_repeat_chance = tonumber(fields[12]) or defaults.motif_repeat_chance

-- Sanity checks
measures = clamp(math.floor(measures + 0.5), 1, 128)
min_notes = clamp(math.floor(min_notes + 0.5), 1, 128)
max_notes = clamp(math.floor(max_notes + 0.5), min_notes, 256)
min_keep = clamp(math.floor(min_keep + 0.5), 0, 1000)
max_keep = clamp(math.floor(max_keep + 0.5), min_keep, 2000)
root_note = clamp(math.floor(root_note + 0.5), 0, 127)
num_voices = clamp(math.floor(num_voices + 0.5), 1, 16)
ca_growth_rate = clamp(ca_growth_rate, 0.1, 1.0)
ca_time_bias = clamp(ca_time_bias, 0.0, 1.0)
theory_weight = clamp(theory_weight, 0.0, 1.0)
motif_repeat_chance = clamp(motif_repeat_chance, 0, 100)

-- Resolve scale
if scale_name == 'random' or not scales[scale_name] then
    chosen_scale_key = choose_random(scale_keys)
else
    chosen_scale_key = scale_name
end
chosen_scale = scales[chosen_scale_key]

-- Persist for next run
set_ext('measures', measures)
set_ext('min_notes', min_notes)
set_ext('max_notes', max_notes)
set_ext('min_keep', min_keep)
set_ext('max_keep', max_keep)
set_ext('root_note', root_note)
set_ext('scale_name', chosen_scale_key)
set_ext('num_voices', num_voices)
set_ext('ca_mode', ca_mode and '1' or '0')
set_ext('poly_mode', poly_mode)
set_ext('theory_weight', theory_weight)
set_ext('rhythmic_guitar_mode', rhythmic_guitar_mode and '1' or '0')
set_ext('motif_repeat_chance', motif_repeat_chance)

-- =============================
-- GENERATE_MELODY label for auto mode
-- =============================

::GENERATE_MELODY::

-- If we jumped here from auto mode, we need to declare the variables
-- Otherwise they were set by the manual dialogs
if use_auto_mode then
    measures = defaults.measures
    min_notes = defaults.min_notes
    max_notes = defaults.max_notes
    min_keep = defaults.min_keep
    max_keep = defaults.max_keep
    root_note = defaults.root_note
    num_voices = defaults.num_voices
    ca_mode = defaults.ca_mode
    ca_growth_rate = 0.4
    ca_time_bias = 0.6
    poly_mode = defaults.poly_mode
    theory_weight = defaults.theory_weight
    rhythmic_guitar_mode = defaults.rhythmic_guitar_mode
    motif_repeat_chance = defaults.motif_repeat_chance

    -- Resolve scale
    if defaults.scale_name == 'random' or not scales[defaults.scale_name] then
        chosen_scale_key = choose_random(scale_keys)
    else
        chosen_scale_key = defaults.scale_name
    end
    chosen_scale = scales[chosen_scale_key]
end

-- =============================
-- Music Theory & Voice Leading Engine
-- =============================

-- Interval qualities for consonance/dissonance assessment
local INTERVAL_QUALITIES = {
    [0] = {type = 'perfect', consonance = 1.0, name = 'unison'},
    [1] = {type = 'dissonant', consonance = 0.2, name = 'minor 2nd'},
    [2] = {type = 'dissonant', consonance = 0.4, name = 'major 2nd'},
    [3] = {type = 'imperfect', consonance = 0.7, name = 'minor 3rd'},
    [4] = {type = 'imperfect', consonance = 0.8, name = 'major 3rd'},
    [5] = {type = 'perfect', consonance = 0.9, name = 'perfect 4th'},
    [6] = {type = 'dissonant', consonance = 0.1, name = 'tritone'},
    [7] = {type = 'perfect', consonance = 1.0, name = 'perfect 5th'},
    [8] = {type = 'imperfect', consonance = 0.7, name = 'minor 6th'},
    [9] = {type = 'imperfect', consonance = 0.8, name = 'major 6th'},
    [10] = {type = 'dissonant', consonance = 0.4, name = 'minor 7th'},
    [11] = {type = 'dissonant', consonance = 0.5, name = 'major 7th'},
    [12] = {type = 'perfect', consonance = 1.0, name = 'octave'}
}

-- Calculate interval between two pitches (0-12 semitones)
local function get_interval(pitch1, pitch2)
    local diff = math.abs(pitch1 - pitch2) % 12
    return diff
end

-- Get consonance rating for an interval (0.0 = very dissonant, 1.0 = perfect consonance)
local function get_consonance(pitch1, pitch2)
    local interval = get_interval(pitch1, pitch2)
    return INTERVAL_QUALITIES[interval].consonance
end

-- Check if motion between two voice pairs is parallel (forbidden in strict voice leading)
local function is_parallel_motion(voice1_from, voice1_to, voice2_from, voice2_to)
    local interval1 = get_interval(voice1_from, voice2_from)
    local interval2 = get_interval(voice1_to, voice2_to)
    local dir1 = voice1_to - voice1_from
    local dir2 = voice2_to - voice2_from

    -- Parallel if same interval type and same direction
    if interval1 == interval2 and dir1 * dir2 > 0 then
        -- Parallel perfect intervals (unison, 5th, octave) are forbidden
        if interval1 == 0 or interval1 == 7 or interval1 == 12 then
            return true, 'parallel_perfect'
        end
        return true, 'parallel_imperfect'
    end
    return false, nil
end

-- Check if motion is contrary (opposite directions - good!)
local function is_contrary_motion(voice1_from, voice1_to, voice2_from, voice2_to)
    local dir1 = voice1_to - voice1_from
    local dir2 = voice2_to - voice2_from
    return (dir1 * dir2 < 0) and (dir1 ~= 0 and dir2 ~= 0)
end

-- Check if motion is oblique (one voice stays, other moves - acceptable)
local function is_oblique_motion(voice1_from, voice1_to, voice2_from, voice2_to)
    local dir1 = voice1_to - voice1_from
    local dir2 = voice2_to - voice2_from
    return (dir1 == 0 and dir2 ~= 0) or (dir1 ~= 0 and dir2 == 0)
end

-- Build chord from scale degrees (triads and 7th chords)
local function build_chord(scale_notes, root_scale_idx, chord_type, octave_range)
    octave_range = octave_range or {-1, 1}

    local chord = {}
    local intervals

    if chord_type == 'triad' then
        -- Root, 3rd, 5th
        intervals = {0, 2, 4}
    elseif chord_type == 'seventh' then
        -- Root, 3rd, 5th, 7th
        intervals = {0, 2, 4, 6}
    elseif chord_type == 'sus4' then
        -- Root, 4th, 5th
        intervals = {0, 3, 4}
    else
        intervals = {0, 2, 4}  -- default triad
    end

    for _, interval in ipairs(intervals) do
        local scale_idx = ((root_scale_idx - 1 + interval) % #scale_notes) + 1
        local base_pitch = scale_notes[scale_idx]

        -- Add octave variations
        for oct = octave_range[1], octave_range[2] do
            table.insert(chord, base_pitch + (oct * 12))
        end
    end

    return chord
end

-- Voice leading: find smoothest voice movement (minimize total motion)
local function find_best_voice_leading(prev_pitches, target_chord, theory_weight)
    if #prev_pitches == 0 then
        -- First chord, just pick from target
        local result = {}
        for i = 1, math.min(#target_chord, 4) do
            table.insert(result, target_chord[i])
        end
        return result
    end

    -- Calculate all possible voice assignments
    local num_voices = #prev_pitches
    local best_assignment = nil
    local best_score = -math.huge

    -- Generate permutations (simplified for up to 4 voices)
    local function score_assignment(assignment)
        local total_motion = 0
        local contrary_bonus = 0
        local consonance_score = 0
        local parallel_penalty = 0

        -- Calculate total voice motion
        for i = 1, num_voices do
            total_motion = total_motion + math.abs(assignment[i] - prev_pitches[i])
        end

        -- Check voice leading quality
        for i = 1, num_voices - 1 do
            for j = i + 1, num_voices do
                -- Reward contrary motion
                if is_contrary_motion(prev_pitches[i], assignment[i], prev_pitches[j], assignment[j]) then
                    contrary_bonus = contrary_bonus + 5
                end

                -- Penalize parallel motion
                local is_parallel, parallel_type = is_parallel_motion(
                    prev_pitches[i], assignment[i],
                    prev_pitches[j], assignment[j]
                )
                if is_parallel then
                    if parallel_type == 'parallel_perfect' then
                        parallel_penalty = parallel_penalty + 20
                    else
                        parallel_penalty = parallel_penalty + 5
                    end
                end

                -- Reward consonant intervals
                consonance_score = consonance_score + get_consonance(assignment[i], assignment[j]) * 3
            end
        end

        -- Blend between smooth motion (low total_motion) and theory rules
        -- theory_weight = 0: prefer minimal motion (creative/free)
        -- theory_weight = 1: prefer theory rules (contrary motion, consonance, avoid parallels)
        local smooth_score = -total_motion
        local theory_score = contrary_bonus + consonance_score - parallel_penalty

        return (1 - theory_weight) * smooth_score + theory_weight * theory_score
    end

    -- Try different combinations from target_chord
    -- For simplicity, we'll try sorted ascending, descending, and closest matches
    local candidates = {}

    -- Candidate 1: Closest pitches
    local closest = {}
    local used = {}
    for i = 1, num_voices do
        local best_pitch = nil
        local best_dist = math.huge
        for _, pitch in ipairs(target_chord) do
            if not used[pitch] then
                local dist = math.abs(pitch - prev_pitches[i])
                if dist < best_dist then
                    best_dist = dist
                    best_pitch = pitch
                end
            end
        end
        if best_pitch then
            closest[i] = best_pitch
            used[best_pitch] = true
        else
            closest[i] = prev_pitches[i]  -- fallback
        end
    end
    table.insert(candidates, closest)

    -- Candidate 2: Ascending order
    local sorted_asc = {}
    for _, p in ipairs(target_chord) do table.insert(sorted_asc, p) end
    table.sort(sorted_asc)
    if #sorted_asc >= num_voices then
        table.insert(candidates, {table.unpack(sorted_asc, 1, num_voices)})
    end

    -- Candidate 3: Middle range
    local mid_start = math.max(1, math.floor(#sorted_asc / 2) - math.floor(num_voices / 2))
    if mid_start + num_voices - 1 <= #sorted_asc then
        table.insert(candidates, {table.unpack(sorted_asc, mid_start, mid_start + num_voices - 1)})
    end

    -- Score all candidates
    for _, candidate in ipairs(candidates) do
        local score = score_assignment(candidate)
        if score > best_score then
            best_score = score
            best_assignment = candidate
        end
    end

    return best_assignment or closest
end

-- =============================
-- 2D Cellular Automata Engine - "Growing Mold"
-- =============================

-- Cell structure: {time_step, scale_idx, age, voice_id}
-- Grid is stored as grid[time_step][scale_idx] = cell or nil

-- Configuration for CA growth
local CA_CONFIG = {
    spawn_prob = ca_mode and ca_growth_rate or 0.4,           -- Probability of spawning a neighbor
    horizontal_bias = ca_mode and ca_time_bias or 0.6,        -- 0.5 = equal, >0.5 = prefers time direction
    max_age = 8,                                              -- Cells die after this many generations
    initial_seeds = 2,                                        -- Number of starting cells
    max_poly_per_slice = nil,                                 -- Set dynamically based on num_voices
}

-- Create empty 2D grid
local function create_grid(time_steps, scale_size)
    local grid = {}
    for t = 1, time_steps do
        grid[t] = {}
        for s = 1, scale_size do
            grid[t][s] = nil
        end
    end
    return grid
end

-- Count living cells at a specific time slice (for polyphony limiting)
local function count_cells_at_time(grid, time_step)
    local count = 0
    for scale_idx, cell in pairs(grid[time_step] or {}) do
        if cell then count = count + 1 end
    end
    return count
end

-- Check if position is valid and empty
local function is_valid_position(grid, time_step, scale_idx, time_steps, scale_size)
    if time_step < 1 or time_step > time_steps then return false end
    if scale_idx < 1 or scale_idx > scale_size then return false end
    if grid[time_step][scale_idx] ~= nil then return false end
    return true
end

-- Try to spawn a new cell from parent
local function try_spawn(grid, parent_cell, direction, time_steps, scale_size, max_poly)
    local new_time = parent_cell.time_step
    local new_scale = parent_cell.scale_idx

    -- Apply direction: 1=up, 2=down, 3=left, 4=right
    if direction == 1 then new_scale = new_scale + 1      -- up (higher pitch)
    elseif direction == 2 then new_scale = new_scale - 1  -- down (lower pitch)
    elseif direction == 3 then new_time = new_time - 1    -- left (earlier time)
    elseif direction == 4 then new_time = new_time + 1    -- right (later time)
    end

    -- Check validity
    if not is_valid_position(grid, new_time, new_scale, time_steps, scale_size) then
        return false
    end

    -- Check polyphony constraint
    if count_cells_at_time(grid, new_time) >= max_poly then
        return false
    end

    -- Check spawn probability
    if math.random() > CA_CONFIG.spawn_prob then
        return false
    end

    -- Spawn the cell
    grid[new_time][new_scale] = {
        time_step = new_time,
        scale_idx = new_scale,
        age = 0,
        voice_id = parent_cell.voice_id
    }

    return true
end

-- Evolve the 2D CA grid for one generation
local function evolve_2d_ca(grid, time_steps, scale_size, max_poly)
    local all_cells = {}

    -- Collect all living cells
    for t = 1, time_steps do
        for s = 1, scale_size do
            if grid[t][s] then
                table.insert(all_cells, grid[t][s])
            end
        end
    end

    -- Age all cells and mark for death
    local cells_to_remove = {}
    for _, cell in ipairs(all_cells) do
        cell.age = cell.age + 1
        if cell.age >= CA_CONFIG.max_age then
            table.insert(cells_to_remove, cell)
        end
    end

    -- Remove dead cells
    for _, cell in ipairs(cells_to_remove) do
        grid[cell.time_step][cell.scale_idx] = nil
    end

    -- Try to spawn new cells from living cells
    -- Shuffle to randomize growth order
    for i = #all_cells, 2, -1 do
        local j = math.random(i)
        all_cells[i], all_cells[j] = all_cells[j], all_cells[i]
    end

    for _, cell in ipairs(all_cells) do
        if grid[cell.time_step] and grid[cell.time_step][cell.scale_idx] then
            -- Cell still alive, try to spawn

            -- Determine which directions to try based on bias
            local directions = {}
            if math.random() < CA_CONFIG.horizontal_bias then
                -- Prefer horizontal (time) first
                directions = {4, 3, 1, 2}  -- right, left, up, down
            else
                -- Prefer vertical (pitch) first
                directions = {1, 2, 4, 3}  -- up, down, right, left
            end

            -- Try one random direction
            local dir = directions[math.random(1, #directions)]
            try_spawn(grid, cell, dir, time_steps, scale_size, max_poly)
        end
    end
end

-- Generate 2D CA grid and return as note list
local function generate_2d_ca_notes(time_steps, scale_size, num_voices)
    CA_CONFIG.max_poly_per_slice = num_voices

    local grid = create_grid(time_steps, scale_size)

    -- Plant initial seeds at random positions
    for seed = 1, CA_CONFIG.initial_seeds do
        local rand_time = math.random(1, math.ceil(time_steps / 2))
        local rand_scale = math.random(1, scale_size)

        -- Make sure it's empty
        local attempts = 0
        while grid[rand_time][rand_scale] ~= nil and attempts < 20 do
            rand_time = math.random(1, time_steps)
            rand_scale = math.random(1, scale_size)
            attempts = attempts + 1
        end

        grid[rand_time][rand_scale] = {
            time_step = rand_time,
            scale_idx = rand_scale,
            age = 0,
            voice_id = seed - 1  -- 0-indexed for MIDI channel
        }
    end

    -- Evolve for multiple generations
    local generations = math.max(10, time_steps / 2)
    for gen = 1, generations do
        evolve_2d_ca(grid, time_steps, scale_size, CA_CONFIG.max_poly_per_slice)
    end

    -- Convert grid to note list
    local notes = {}
    for t = 1, time_steps do
        for s = 1, scale_size do
            if grid[t][s] then
                table.insert(notes, {
                    time_step = t,
                    scale_idx = s,
                    voice_id = grid[t][s].voice_id,
                    age = grid[t][s].age  -- Can use for velocity/duration
                })
            end
        end
    end

    log('Generated ', #notes, ' notes from 2D CA')
    return notes
end

-- =============================
-- Melody generation
-- =============================

-- Project / selection info
local bpm = reaper.Master_GetTempo()
local start_time = reaper.GetCursorPosition()

-- Get time signature - just get the numerator, ignore the weird denominator value
local _, time_sig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, start_time)
local beats_per_measure = time_sig_num
-- Calculate one beat's duration: BPM is always in quarter notes per minute
local quarter_note_duration = 60 / bpm

-- Simple, direct calculation: measures × beats per measure × quarter note duration
-- This works because BPM is always quarter notes per minute in REAPER
local measure_duration = quarter_note_duration * beats_per_measure
local end_time = start_time + (measure_duration * measures)

log('--- Melody Generator Debug ---')
log('BPM: ', bpm)
log('Time signature numerator (beats per measure): ', time_sig_num)
log('Measures requested: ', measures)
log('Quarter note duration: ', quarter_note_duration)
log('Measure duration (s): ', measure_duration)
log('Start time: ', start_time)
log('Computed end time: ', end_time)
log('Expected item length: ', end_time - start_time)

local track = reaper.GetSelectedTrack(0, 0)
if not track then
    reaper.ShowMessageBox('Please select a track first.', 'No Track', 0)
    return
end

-- Create MIDI item
local item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
local take = reaper.GetTake(item, 0)
if not take then return end

local actual_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
log('Actual created item length: ', actual_len)

local function timeToPPQ(t)
    return reaper.MIDI_GetPPQPosFromProjTime(take, t)
end

-- Velocity ranges based on duration buckets
local VELOCITY_16 = {40, 60}
local VELOCITY_8 = {50, 70}
local VELOCITY_4 = {60, 90}
local VELOCITY_2PLUS = {80, 100}

-- Calculate note durations - always based on quarter notes regardless of time signature
-- This keeps the note duration choices consistent
local sixteenth_note = quarter_note_duration / 4
local eighth_note = quarter_note_duration / 2
local quarter_note = quarter_note_duration
local half_note = quarter_note_duration * 2
local whole_note = measure_duration -- full measure duration

local function vel_for_dur(dur)
    if dur <= sixteenth_note then return math.random(VELOCITY_16[1], VELOCITY_16[2])
    elseif dur <= eighth_note then return math.random(VELOCITY_8[1], VELOCITY_8[2])
    elseif dur <= quarter_note then return math.random(VELOCITY_4[1], VELOCITY_4[2])
    else return math.random(VELOCITY_2PLUS[1], VELOCITY_2PLUS[2]) end
end

-- Duration choices with weights (in seconds)
-- Higher weight = more frequent. Adjust these to taste!
local dur_weights = {
    [sixteenth_note] = 5,   -- 16th (occasional fast notes)
    [eighth_note] = 5,     -- 8th (reduced from 30)
    [quarter_note] = 30,    -- quarter (now most common)
    [half_note] = 40,       -- half (increased)
    [whole_note] = 10,      -- whole (increased)
}

local function pick_duration(prev)
    local total = 0
    for _, w in pairs(dur_weights) do total = total + w end
    local r = math.random() * total
    local c = 0
    for d, w in pairs(dur_weights) do
        c = c + w
        if r <= c then return d end
    end
    return prev
end

-- Build note pitch set from chosen scale
local scale_notes = {}
for _, iv in ipairs(chosen_scale) do
    scale_notes[#scale_notes+1] = root_note + iv
end

local function find_index(t, v)
    for i = 1, #t do if t[i] == v then return i end end
    return 1
end

-- Simple motion logic constants
-- Motif development: dynamic repetition constraints
local motif_mode = defaults.motif_mode -- 'melodic' or 'rhythmic'
local repetition_allowance = clamp(defaults.repetition_allowance or 3, 2, 4)
local MAX_REPEATED = repetition_allowance
local NOTE_VARIETY = (motif_mode == 'rhythmic') and 0.85 or 0.99
local BIG_JUMP_CHANCE = 0.1
local BIG_JUMP_INTERVAL = 4

-- Initialize random seed
math.randomseed(reaper.time_precise())
for _ = 1,10 do math.random() end

reaper.Undo_BeginBlock()

-- =============================
-- RHYTHMIC GUITAR MODE (Drum-Style Rhythmic Generation)
-- =============================
if rhythmic_guitar_mode then
    log('Using Rhythmic Guitar mode - drum-style rhythm with melodic notes')

    -- Configuration constants adapted from drum script
    local PPQ = 960
    local SUBDIVS_MIN = 1
    local SUBDIVS_MAX = 2
    local BURST_NOTES = 8
    local HUMANIZE_MS = 7
    local VEL_MIN = 7
    local VEL_MAX = 110
    local SUSTAIN_MODE = true
    local SUSTAIN_FACTOR = 0.9

    -- Rhythmic pattern probabilities (adapted from drum script)
    local BURST_CHANCE = 0.250
    local DOUBLE_STROKE_CHANCE = 0.250
    local PARADIDDLE_CHANCE = 0.250
    local FOCUSED_RIFF_CHANCE = 0.300
    local ANCHOR_DOWNBEAT_CHANCE = 0.300
    local RANDOM_BEAT_ACCENT_CHANCE = 0.600

    -- Guitar string simulation (replace drum limbs with string tracking)
    local string_state = {
        S1 = {last_note_time = nil, last_pitch = nil},
        S2 = {last_note_time = nil, last_pitch = nil},
        S3 = {last_note_time = nil, last_pitch = nil},
        S4 = {last_note_time = nil, last_pitch = nil},
        S5 = {last_note_time = nil, last_pitch = nil},
        S6 = {last_note_time = nil, last_pitch = nil}
    }

    local MIN_STRING_INTERVAL_SECS = 0.01

    -- Helper: Choose a note from the scale
    local function choose_note()
        return scale_notes[math.random(1, #scale_notes)]
    end

    -- Helper: Pick a string for this note
    local function pick_string()
        local strings = {"S1", "S2", "S3", "S4", "S5", "S6"}
        return strings[math.random(1, #strings)]
    end

    -- Helper: Check if string can play at this time
    local function can_string_play(string_id, requested_time)
        local st = string_state[string_id]
        if not st.last_note_time then return true end
        local dt = requested_time - st.last_note_time
        return dt >= MIN_STRING_INTERVAL_SECS
    end

    -- Helper: Dynamic velocity with accent influence
    local function get_dynamic_velocity(note_ppq, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local on_quarter = ((note_ppq % PPQ) == 0)
        if on_quarter then return math.random(VEL_MIN, VEL_MAX) end

        local accent_factor = 0
        if accent_ppqs and measure_start_ppq then
            local accent_window = PPQ / 4
            for _, accent_ppq in ipairs(accent_ppqs) do
                local diff = math.abs(note_ppq - accent_ppq)
                local candidate = (accent_window - diff) / accent_window
                if candidate > accent_factor then accent_factor = candidate end
            end
        end

        local base_min, base_max = 50, 90
        local bonus = math.floor(accent_factor * 20)
        local final_min = math.min(VEL_MAX, base_min + bonus)
        local final_max = math.min(VEL_MAX, base_max + bonus)
        return math.random(final_min, final_max)
    end

    -- Helper: Insert note with humanization
    local function insert_guitar_note(take, ppq_pos, pitch, override_vel_min, override_vel_max, note_duration_ticks, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local note_time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq_pos)
        local humanize_offset_sec = (math.random() * 2 - 1) * (HUMANIZE_MS / 1000)
        local final_time = note_time + humanize_offset_sec

        local string_id = pick_string()
        if not can_string_play(string_id, final_time) then return end

        local note_velocity
        if override_vel_min and override_vel_max then
            note_velocity = math.random(override_vel_min, override_vel_max)
        else
            note_velocity = get_dynamic_velocity(ppq_pos, accent_ppqs, measure_start_ppq, measure_len_ppq)
        end

        local ppq_with_offset = reaper.MIDI_GetPPQPosFromProjTime(take, final_time)
        local note_off_ppq = note_duration_ticks and (ppq_with_offset + note_duration_ticks) or (ppq_with_offset + 1)

        reaper.MIDI_InsertNote(take, false, false, ppq_with_offset, note_off_ppq, 0, pitch, note_velocity, false)

        string_state[string_id].last_note_time = final_time
        string_state[string_id].last_pitch = pitch
    end

    -- Pattern: Double stroke
    local function insert_double_stroke(take, base_ppq, spacing_ticks, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local pitch = choose_note()
        local duration = SUSTAIN_MODE and math.floor(spacing_ticks * SUSTAIN_FACTOR) or nil
        insert_guitar_note(take, base_ppq, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
        insert_guitar_note(take, base_ppq + spacing_ticks, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
    end

    -- Pattern: Paradiddle (8-note pattern)
    local function insert_paradiddle(take, start_ppq, spacing_ticks, kit_focus, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local function pick_note()
            if kit_focus and #kit_focus > 0 then
                return kit_focus[math.random(1, #kit_focus)]
            else
                return choose_note()
            end
        end

        local strokes = {}
        for i = 1, 8 do
            strokes[i] = pick_note()
        end

        local duration = SUSTAIN_MODE and math.floor(spacing_ticks * SUSTAIN_FACTOR) or nil
        for i, pitch in ipairs(strokes) do
            local stroke_ppq = start_ppq + (i - 1) * spacing_ticks
            insert_guitar_note(take, stroke_ppq, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
        end
    end

    -- Pattern: Focused riff (repetitive pattern on subset of notes)
    local function choose_note_subset(size)
        local subset = {}
        local pool = {}
        for _, note in ipairs(scale_notes) do
            table.insert(pool, note)
        end

        for i = 1, math.min(size, #pool) do
            local idx = math.random(1, #pool)
            table.insert(subset, pool[idx])
            table.remove(pool, idx)
        end
        return subset
    end

    local function insert_focused_riff(take, start_ppq, measure_end_ppq, note_focus, accent_ppqs, measure_start_ppq, measure_len_ppq)
        if not note_focus or #note_focus < 1 then
            note_focus = choose_note_subset(math.random(2, 4))
        end

        local pattern_length = math.random(3, 5)
        local total_space = measure_end_ppq - start_ppq
        local spacing = math.floor(total_space / (pattern_length * 2))
        local duration = SUSTAIN_MODE and math.floor(spacing * SUSTAIN_FACTOR) or nil

        local pos = start_ppq
        while pos < measure_end_ppq do
            for p = 1, pattern_length do
                local pitch = note_focus[math.random(1, #note_focus)]
                local insert_pos = pos + (p - 1) * spacing
                if insert_pos >= measure_end_ppq then break end
                insert_guitar_note(take, insert_pos, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
            end
            pos = pos + (pattern_length * spacing)
        end
    end

    -- Pattern: Insert accent (strong beat with emphasis)
    local function insert_accent(take, beat_ppq, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local duration = SUSTAIN_MODE and math.floor(PPQ * SUSTAIN_FACTOR) or nil
        local pitch = choose_note()
        insert_guitar_note(take, beat_ppq, pitch, 80, 110, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
        if accent_ppqs then table.insert(accent_ppqs, beat_ppq) end
    end

    -- Main generation loop
    local start_ppq = timeToPPQ(start_time)
    local end_ppq = timeToPPQ(end_time)
    local total_ppq = end_ppq - start_ppq

    local time_sig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, start_time)
    local measure_len_ppq = time_sig_num * PPQ

    local num_measures = math.floor(total_ppq / measure_len_ppq)
    local leftover_ppq = total_ppq % measure_len_ppq
    local measure_start_ppq = start_ppq

    for m = 1, num_measures do
        local current_measure_accents = {}
        local measure_end = measure_start_ppq + measure_len_ppq

        -- Anchor downbeat
        if math.random() < ANCHOR_DOWNBEAT_CHANCE then
            local duration = SUSTAIN_MODE and math.floor(PPQ * SUSTAIN_FACTOR) or nil
            insert_guitar_note(take, measure_start_ppq, choose_note(), nil, nil, duration, current_measure_accents, measure_start_ppq, measure_len_ppq)
        end

        -- Random beat accent
        if math.random() < RANDOM_BEAT_ACCENT_CHANCE then
            local random_beat_idx = math.random(1, time_sig_num)
            local random_beat_ppq = measure_start_ppq + (random_beat_idx - 1) * PPQ
            insert_accent(take, random_beat_ppq, current_measure_accents, measure_start_ppq, measure_len_ppq)
        end

        -- Focused riff mode for entire measure
        if math.random() < FOCUSED_RIFF_CHANCE then
            local note_focus = choose_note_subset(math.random(2, 4))
            insert_focused_riff(take, measure_start_ppq + PPQ, measure_end, note_focus, current_measure_accents, measure_start_ppq, measure_len_ppq)
        else
            -- Beat-by-beat generation
            for beat_idx = 1, time_sig_num do
                local beat_ppq = measure_start_ppq + (beat_idx - 1) * PPQ

                local subdivs = math.random(SUBDIVS_MIN, SUBDIVS_MAX)
                local ticks_per_sub = math.floor(PPQ / subdivs)

                for s = 1, subdivs do
                    local sub_tick = beat_ppq + (s - 1) * ticks_per_sub
                    if sub_tick >= measure_end then break end

                    if math.random() < BURST_CHANCE then
                        -- Burst pattern
                        for i = 0, BURST_NOTES - 1 do
                            local flurry_tick = sub_tick + i * math.floor(ticks_per_sub / (BURST_NOTES + 1))
                            if flurry_tick >= measure_end then break end
                            local duration = SUSTAIN_MODE and math.floor((ticks_per_sub / (BURST_NOTES + 1)) * SUSTAIN_FACTOR) or nil
                            insert_guitar_note(take, flurry_tick, choose_note(), nil, nil, duration, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        end
                    else
                        local do_double = (math.random() < DOUBLE_STROKE_CHANCE)
                        local do_para = (not do_double and math.random() < PARADIDDLE_CHANCE)

                        if do_double then
                            local stroke_spacing = math.floor(ticks_per_sub * 0.25)
                            insert_double_stroke(take, sub_tick, stroke_spacing, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        elseif do_para then
                            local stroke_spacing = math.floor(ticks_per_sub * 0.25)
                            insert_paradiddle(take, sub_tick, stroke_spacing, nil, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        else
                            local duration = SUSTAIN_MODE and math.floor(ticks_per_sub * SUSTAIN_FACTOR) or nil
                            insert_guitar_note(take, sub_tick, choose_note(), nil, nil, duration, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        end
                    end
                end
            end
        end

        measure_start_ppq = measure_end
    end

    -- Handle leftover beats
    if leftover_ppq > 0 then
        local leftover_start = measure_start_ppq
        local leftover_end = leftover_start + leftover_ppq
        local current_measure_accents = {}

        if math.random() < ANCHOR_DOWNBEAT_CHANCE then
            local duration = SUSTAIN_MODE and math.floor(PPQ * SUSTAIN_FACTOR) or nil
            insert_guitar_note(take, leftover_start, choose_note(), nil, nil, duration, current_measure_accents, leftover_start, leftover_ppq)
        end

        local leftover_beats = leftover_ppq / PPQ
        local cur_tick = 0
        while cur_tick < leftover_ppq do
            local subdivs = math.random(SUBDIVS_MIN, SUBDIVS_MAX)
            local ticks_per_sub = math.floor(PPQ / subdivs)

            for s = 1, subdivs do
                local sub_tick = cur_tick + (s - 1) * ticks_per_sub
                if sub_tick >= leftover_ppq then break end
                local actual_tick = leftover_start + sub_tick

                if math.random() < BURST_CHANCE then
                    for i = 0, BURST_NOTES - 1 do
                        local flurry_tick = actual_tick + i * math.floor(ticks_per_sub / (BURST_NOTES + 1))
                        if flurry_tick >= leftover_end then break end
                        local duration = SUSTAIN_MODE and math.floor((ticks_per_sub / (BURST_NOTES + 1)) * SUSTAIN_FACTOR) or nil
                        insert_guitar_note(take, flurry_tick, choose_note(), nil, nil, duration, current_measure_accents, leftover_start, leftover_ppq)
                    end
                else
                    local duration = SUSTAIN_MODE and math.floor(ticks_per_sub * SUSTAIN_FACTOR) or nil
                    insert_guitar_note(take, actual_tick, choose_note(), nil, nil, duration, current_measure_accents, leftover_start, leftover_ppq)
                end
            end
            cur_tick = cur_tick + PPQ
        end
    end

    reaper.MIDI_Sort(take)

-- =============================
-- CELLULAR AUTOMATA MODE
-- =============================
elseif ca_mode then
    log('Using 2D CA mode - growing mold algorithm')

    -- Calculate time grid resolution
    local time_resolution = eighth_note  -- Each step is an 8th note
    local total_duration = end_time - start_time
    local time_steps = math.floor(total_duration / time_resolution)

    log('Time steps: ', time_steps, ', Scale size: ', #scale_notes)

    -- Generate 2D CA notes
    local ca_notes = generate_2d_ca_notes(time_steps, #scale_notes, num_voices)

    -- Insert notes from CA grid into MIDI
    for _, note_data in ipairs(ca_notes) do
        local note_time = start_time + ((note_data.time_step - 1) * time_resolution)
        local note_pitch = scale_notes[note_data.scale_idx]
        local note_duration = time_resolution  -- Could vary based on age
        local note_velocity = math.random(60, 100)  -- Could use age for velocity
        local note_channel = note_data.voice_id

        reaper.MIDI_InsertNote(
            take, false, false,
            timeToPPQ(note_time),
            timeToPPQ(note_time + note_duration),
            note_channel,
            note_pitch,
            note_velocity,
            false
        )
    end

-- =============================
-- STANDARD MODE with Polyphony Modes
-- =============================
else
    log('Using standard mode with polyphony: ', poly_mode, ', theory weight: ', theory_weight)

    -- Simple motion logic constants
    local MAX_REPEATED = 0
    local NOTE_VARIETY = 0.99
    local BIG_JUMP_CHANCE = 0.1
    local BIG_JUMP_INTERVAL = 4

    -- =============================
    -- Mode 1: FREE - Independent voice generation (original behavior)
    -- =============================
    if poly_mode == 'free' or num_voices == 1 then
        log('Free polyphony mode - independent voices')

        -- =============================
        -- Phrase-Based Generation System (Step 2)
        -- =============================

        -- Phrase structure: {pitches, durations, contour_type, tension_level}
        -- contour_type: 'arch', 'ascending', 'descending', 'valley', 'wave'
        -- tension_level: 'low', 'medium', 'high'

        -- Generate a phrase with a specific contour type
        local function generate_phrase(start_pitch, contour_type, phrase_length)
            phrase_length = phrase_length or math.random(4, 8)
            local pitches = {}
            local durations = {}

            -- Starting pitch
            local current_idx = find_index(scale_notes, start_pitch)
            table.insert(pitches, scale_notes[current_idx])

            -- Generate contour based on type
            if contour_type == 'arch' then
                -- Ascend for first half, descend for second half
                local peak_point = math.floor(phrase_length / 2)
                for i = 2, phrase_length do
                    if i <= peak_point then
                        -- Ascending
                        local step = math.random(1, 2)
                        current_idx = clamp(current_idx + step, 1, #scale_notes)
                    else
                        -- Descending
                        local step = math.random(1, 2)
                        current_idx = clamp(current_idx - step, 1, #scale_notes)
                    end
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'ascending' then
                -- Gradual climb
                for i = 2, phrase_length do
                    local step = math.random(1, 2)
                    if math.random() < 0.2 then step = -1 end -- occasional drop for interest
                    current_idx = clamp(current_idx + step, 1, #scale_notes)
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'descending' then
                -- Gradual descent
                for i = 2, phrase_length do
                    local step = math.random(1, 2)
                    if math.random() < 0.2 then step = -1 end -- occasional rise for interest
                    current_idx = clamp(current_idx - step, 1, #scale_notes)
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'valley' then
                -- Descend first, then ascend (inverse arch)
                local valley_point = math.floor(phrase_length / 2)
                for i = 2, phrase_length do
                    if i <= valley_point then
                        -- Descending
                        local step = math.random(1, 2)
                        current_idx = clamp(current_idx - step, 1, #scale_notes)
                    else
                        -- Ascending
                        local step = math.random(1, 2)
                        current_idx = clamp(current_idx + step, 1, #scale_notes)
                    end
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'wave' then
                -- Oscillating up and down
                local direction = 1
                for i = 2, phrase_length do
                    local step = math.random(1, 2) * direction
                    current_idx = clamp(current_idx + step, 1, #scale_notes)
                    table.insert(pitches, scale_notes[current_idx])
                    -- Change direction occasionally
                    if math.random() < 0.4 then
                        direction = -direction
                    end
                end
            end

            -- Generate durations for the phrase
            for i = 1, phrase_length do
                local dur = pick_duration(quarter_note)
                table.insert(durations, dur)
            end

            return {
                pitches = pitches,
                durations = durations,
                contour_type = contour_type,
                tension_level = 'medium', -- Default, can be adjusted
                length = #pitches
            }
        end

        -- Determine contour variation based on previous phrase
        local function get_next_contour_type(prev_contour)
            local contour_types = {'arch', 'ascending', 'descending', 'valley', 'wave'}

            if not prev_contour then
                -- First phrase, choose randomly
                return contour_types[math.random(1, #contour_types)]
            end

            -- Create contrast: if previous was ascending, prefer descending or arch
            local contrast_map = {
                ascending = {'descending', 'arch', 'valley'},
                descending = {'ascending', 'arch', 'valley'},
                arch = {'valley', 'wave', 'ascending'},
                valley = {'arch', 'wave', 'descending'},
                wave = {'arch', 'ascending', 'descending'}
            }

            local candidates = contrast_map[prev_contour] or contour_types
            return candidates[math.random(1, #candidates)]
        end

        -- Transpose a phrase by a number of scale degrees
        local function transpose_phrase(phrase, scale_degrees)
            local transposed = {
                pitches = {},
                durations = {},
                contour_type = phrase.contour_type,
                tension_level = phrase.tension_level,
                length = phrase.length
            }

            -- Copy durations unchanged
            for i = 1, #phrase.durations do
                transposed.durations[i] = phrase.durations[i]
            end

            -- Transpose pitches by scale degrees
            for i = 1, #phrase.pitches do
                local original_pitch = phrase.pitches[i]
                local original_idx = find_index(scale_notes, original_pitch)
                local new_idx = clamp(original_idx + scale_degrees, 1, #scale_notes)
                transposed.pitches[i] = scale_notes[new_idx]
            end

            return transposed
        end

        -- Apply rhythmic augmentation (longer durations) or diminution (shorter)
        local function vary_rhythm(phrase, factor)
            local varied = {
                pitches = {},
                durations = {},
                contour_type = phrase.contour_type,
                tension_level = phrase.tension_level,
                length = phrase.length
            }

            -- Copy pitches unchanged
            for i = 1, #phrase.pitches do
                varied.pitches[i] = phrase.pitches[i]
            end

            -- Scale durations by factor (0.5 = diminution, 2.0 = augmentation)
            for i = 1, #phrase.durations do
                varied.durations[i] = phrase.durations[i] * factor
            end

            return varied
        end

        -- Retrieve and vary a phrase from memory
        local function retrieve_motif(phrase_memory)
            if #phrase_memory == 0 then return nil end

            -- Choose a random phrase from memory
            local source_phrase = phrase_memory[math.random(1, #phrase_memory)]

            -- Decide variation type
            local variation_type = math.random(1, 3)

            if variation_type == 1 then
                -- Transpose by 2-5 scale degrees (up or down)
                local transpose_amount = math.random(2, 5) * (math.random(2) == 1 and 1 or -1)
                log('  Retrieving motif with transposition: ', transpose_amount, ' degrees')
                return transpose_phrase(source_phrase, transpose_amount)
            elseif variation_type == 2 then
                -- Rhythmic augmentation (longer notes)
                log('  Retrieving motif with augmentation')
                return vary_rhythm(source_phrase, 1.5)
            else
                -- Rhythmic diminution (shorter notes)
                log('  Retrieving motif with diminution')
                return vary_rhythm(source_phrase, 0.75)
            end
        end

        -- Generate a single voice of melody using phrases
        local function generate_voice(channel)
            -- Phrase count and pruning for this voice
            local NUM_PHRASES = math.random(tonumber(min_notes) or 2, tonumber(max_notes) or 5)
            local notes_to_keep = math.random(tonumber(min_keep) or 12, tonumber(max_keep) or 24)

            -- Phrase memory buffer (stores last 3-5 phrases)
            local phrase_memory = {}
            local max_memory_size = math.random(3, 5)

            -- Track phrase memory for variation
            local prev_contour = nil
            local note_start = start_time

            log('Generating ', NUM_PHRASES, ' phrases for channel ', channel, ' (motif repeat chance: ', motif_repeat_chance, '%)')

            -- Generate phrases one by one
            for phrase_num = 1, NUM_PHRASES do
                local phrase = nil

                -- Check if we should repeat a motif from memory
                if #phrase_memory > 0 and math.random(100) <= motif_repeat_chance then
                    -- Retrieve and vary a previous phrase
                    phrase = retrieve_motif(phrase_memory)
                    log('  Phrase ', phrase_num, ': MOTIF REPETITION (varied from memory)')
                end

                -- If no motif repetition, generate new phrase
                if not phrase then
                    -- Determine contour type based on previous phrase
                    local contour_type = get_next_contour_type(prev_contour)

                    -- Choose starting pitch
                    local start_pitch
                    if phrase_num == 1 then
                        -- First phrase: random starting note
                        start_pitch = scale_notes[math.random(1, #scale_notes)]
                    else
                        -- Subsequent phrases: end near where we left off
                        -- Get last inserted note for this channel
                        local last_pitch = scale_notes[math.random(1, #scale_notes)] -- fallback
                        local _, note_count = reaper.MIDI_CountEvts(take)
                        for i = note_count - 1, 0, -1 do
                            local _, _, _, _, _, chan, pitch = reaper.MIDI_GetNote(take, i)
                            if chan == channel then
                                last_pitch = pitch
                                break
                            end
                        end
                        start_pitch = last_pitch
                    end

                    -- Generate the phrase
                    local phrase_length = math.random(4, 8)
                    phrase = generate_phrase(start_pitch, contour_type, phrase_length)

                    log('  Phrase ', phrase_num, ': ', contour_type, ', length=', phrase.length)
                end

                -- Insert all notes from the phrase
                for i = 1, phrase.length do
                    local pitch = phrase.pitches[i]
                    local duration = phrase.durations[i]
                    local velocity = vel_for_dur(duration)
                    local note_end = note_start + duration

                    reaper.MIDI_InsertNote(
                        take, false, false,
                        timeToPPQ(note_start),
                        timeToPPQ(note_end),
                        channel,
                        pitch,
                        velocity,
                        false
                    )

                    note_start = note_end
                end

                -- Add phrase to memory buffer
                table.insert(phrase_memory, phrase)
                -- Keep memory buffer size limited
                if #phrase_memory > max_memory_size then
                    table.remove(phrase_memory, 1) -- Remove oldest phrase
                end

                -- Store this phrase's characteristics for next iteration
                prev_contour = phrase.contour_type
            end

            -- Prune excess notes for this voice if needed
            local voice_note_count = 0
            local _, total_cnt = reaper.MIDI_CountEvts(take)
            for i = 0, total_cnt - 1 do
                local _, _, _, _, _, chan = reaper.MIDI_GetNote(take, i)
                if chan == channel then voice_note_count = voice_note_count + 1 end
            end

            if voice_note_count > notes_to_keep then
                log('  Pruning from ', voice_note_count, ' to ', notes_to_keep, ' notes')
                local deleted = 0
                for i = total_cnt - 1, 0, -1 do
                    if deleted >= (voice_note_count - notes_to_keep) then break end
                    local _, _, _, _, _, chan = reaper.MIDI_GetNote(take, i)
                    if chan == channel then
                        reaper.MIDI_DeleteNote(take, i)
                        deleted = deleted + 1
                    end
                end
            end
        end

        -- Generate all voices independently
        for voice = 0, num_voices - 1 do
            generate_voice(voice)
        end

    -- =============================
    -- Mode 2: HARMONIC - Chord-based generation
    -- =============================
    elseif poly_mode == 'harmonic' then
        log('Harmonic polyphony mode - chord progression')

    local NUM_CHORDS = math.random(tonumber(min_notes) or 3, tonumber(max_notes) or 7)
        local chord_types = {'triad', 'seventh', 'sus4'}

        local prev_chord_pitches = {}
        local note_start = start_time

        for i = 1, NUM_CHORDS do
            -- Pick a random root from scale
            local root_idx = math.random(1, #scale_notes)
            local chord_type = choose_random(chord_types)

            -- Build chord pool
            local chord_pool = build_chord(scale_notes, root_idx, chord_type, {-1, 1})

            -- Use voice leading to choose pitches
            local chord_pitches = find_best_voice_leading(prev_chord_pitches, chord_pool, theory_weight)

            -- Pick duration for this chord
            local chord_dur = pick_duration(quarter_note)
            local note_end = note_start + chord_dur

            -- Insert all voices for this chord
            for voice = 0, math.min(num_voices - 1, #chord_pitches - 1) do
                local pitch = chord_pitches[voice + 1]
                local vel = vel_for_dur(chord_dur)
                reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_end), voice, pitch, vel, false)
            end

            prev_chord_pitches = chord_pitches
            note_start = note_end
        end

    -- =============================
    -- Mode 3: VOICE LEADING - Counterpoint with proper voice leading
    -- =============================
    elseif poly_mode == 'voice_leading' then
        log('Voice leading polyphony mode - counterpoint with theory weight: ', theory_weight)

    local NUM_NOTES = math.random(tonumber(min_notes) or 3, tonumber(max_notes) or 7)

        -- Track state for all voices
        local voice_states = {}
        for v = 0, num_voices - 1 do
            voice_states[v] = {
                pitch = scale_notes[math.random(1, #scale_notes)],
                direction = (math.random(2) == 1) and 1 or -1,
                repeated = 0
            }
        end

        -- Function to generate next note for a voice with voice leading awareness
        local function next_note_vl(voice_id, prev_note, all_current_pitches)
            local state = voice_states[voice_id]
            local move = 0

            -- Decide movement based on blend of free and theory-guided
            if math.random() < (1 - theory_weight) then
                -- Free/creative movement
                if state.repeated >= MAX_REPEATED or math.random() < NOTE_VARIETY then
                    move = state.direction
                    if math.random() > 0.7 then move = -move end
                    state.repeated = 0
                else
                    if math.random() < BIG_JUMP_CHANCE then
                        move = (math.random(2) == 1 and -1 or 1) * math.random(1, BIG_JUMP_INTERVAL)
                        state.repeated = 0
                    end
                end
            else
                -- Theory-guided movement
                -- Prefer stepwise motion (small intervals)
                if math.random() < 0.7 then
                    move = (math.random(2) == 1 and 1 or -1)
                else
                    move = (math.random(2) == 1 and 1 or -1) * 2
                end

                -- Check for contrary motion opportunity
                local other_directions = {}
                for v = 0, num_voices - 1 do
                    if v ~= voice_id then
                        table.insert(other_directions, voice_states[v].direction)
                    end
                end

                -- Encourage contrary motion at higher theory weights
                if #other_directions > 0 and math.random() < (theory_weight * 0.7) then
                    local avg_dir = 0
                    for _, d in ipairs(other_directions) do avg_dir = avg_dir + d end
                    avg_dir = avg_dir / #other_directions
                    -- Move opposite to average
                    if avg_dir > 0 then move = -math.abs(move)
                    else move = math.abs(move) end
                end
            end

            local idx = find_index(scale_notes, prev_note)
            local new_idx = clamp(idx + move, 1, #scale_notes)
            local new_pitch = scale_notes[new_idx]

            -- Update state
            state.direction = (new_pitch > prev_note) and 1 or ((new_pitch < prev_note) and -1 or 0)
            state.pitch = new_pitch

            return new_pitch
        end

        -- Generate first chord
        local note_start = start_time
        local prev_dur = pick_duration(quarter_note)
        local all_current = {}

        for voice = 0, num_voices - 1 do
            local pitch = voice_states[voice].pitch
            all_current[voice] = pitch
            reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_start + prev_dur), voice, pitch, vel_for_dur(prev_dur), false)
        end

        -- Generate subsequent notes with voice leading
        local note_end = note_start + prev_dur
        for i = 2, NUM_NOTES do
            local new_all_current = {}

            -- Move all voices
            for voice = 0, num_voices - 1 do
                local new_pitch = next_note_vl(voice, all_current[voice], all_current)
                new_all_current[voice] = new_pitch
            end

            -- Check voice leading quality and possibly adjust
            if theory_weight > 0.5 then
                -- Avoid voice crossing for adjacent voices
                for voice = 0, num_voices - 2 do
                    if new_all_current[voice] < new_all_current[voice + 1] then
                        -- Swap if needed
                        new_all_current[voice], new_all_current[voice + 1] = new_all_current[voice + 1], new_all_current[voice]
                    end
                end
            end

            prev_dur = pick_duration(prev_dur)
            note_start = note_end
            note_end = note_start + prev_dur

            -- Insert all voices
            for voice = 0, num_voices - 1 do
                reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_end), voice, new_all_current[voice], vel_for_dur(prev_dur), false)
            end

            all_current = new_all_current
        end

        -- Prune if needed
    local notes_to_keep = math.random(tonumber(min_keep) or 12, tonumber(max_keep) or 24)
        local _, total_cnt = reaper.MIDI_CountEvts(take)
        if total_cnt > notes_to_keep then
            local deleted = 0
            for i = total_cnt - 1, 0, -1 do
                if deleted >= (total_cnt - notes_to_keep) then break end
                reaper.MIDI_DeleteNote(take, i)
                deleted = deleted + 1
            end
        end
    end
end

-- Name the take
local root_name = note_names[(root_note % 12) + 1]
local octave = math.floor(root_note / 12) - 1
local take_name = string.format('%s%d %s', root_name, octave, chosen_scale_key)
reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)

reaper.Undo_EndBlock('jtp gen: Melody Generator (Dialog)', -1)
reaper.UpdateArrange()
