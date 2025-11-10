-- @description jtp gen: Melody Generator (Simple Dialog)
-- @author James
-- @version 1.3
-- @about
--   # jtp gen: Melody Generator (Simple Dialog)
--   Generates a MIDI melody with a simple built-in REAPER dialog (no ImGui required).
--   Lets you set a few key parameters quickly and create a melody on the selected track.
--
--   Auto-detection mode (enabled by default) - automatically detects root note and
--   scale from the name of the region containing the selected item or edit cursor.
--   When a region is detected, note/octave/scale dialogs are skipped!
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
    num_voices = tonumber(get_ext('num_voices', 1)), -- Number of melodic voices (1-16)
    auto_detect = get_ext('auto_detect', '1') == '1' -- Auto-detect from region name (default enabled)
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

local scale_keys = {}
for k in pairs(scales) do scale_keys[#scale_keys+1] = k end

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
-- Auto-detection from region name
-- =============================

local auto_detected_note_class = nil
local auto_detected_scale = nil
local auto_detected_octave = nil
local region_name = nil

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
-- Dialog - Step 0: Auto-detect Mode Toggle
-- =============================

local auto_detect_items = {"Auto-detect from region (ON)", "Manual selection (OFF)"}
local default_auto_detect_idx = defaults.auto_detect and 1 or 2

-- If auto-detect found something, add option to override
if auto_detected_note_class and auto_detected_scale then
    table.insert(auto_detect_items, 2, "Override auto-detected values")
    -- Adjust default if needed - item 2 is now override, item 3 is manual off
    if not defaults.auto_detect then
        default_auto_detect_idx = 3 -- Point to "Manual selection (OFF)"
    end
end

local auto_detect_choice = show_popup_menu(auto_detect_items, default_auto_detect_idx)
if auto_detect_choice == 0 then return end -- User cancelled

-- Determine mode based on choice
local auto_detect_enabled
local force_manual = false

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
-- Dialog - Step 1: Root Note Selection
-- =============================

local root_note
local scale_name

-- If auto-detect is enabled and successful, skip the dialogs (unless user chose to override)
if auto_detect_enabled and auto_detected_note_class ~= nil and auto_detected_scale and not force_manual then
    -- Use auto-detected values
    local target_octave = auto_detected_octave or 4
    root_note = (target_octave + 1) * 12 + auto_detected_note_class
    -- Clamp to valid MIDI range
    if root_note < 0 then root_note = 0 end
    if root_note > 127 then root_note = 127 end
    scale_name = auto_detected_scale

    -- Show confirmation message
    local root_name = note_names[(root_note % 12) + 1]
    local octave = math.floor(root_note / 12) - 1
    reaper.MB(
        string.format('Region detected: "%s"\n\nUsing: %s%d %s',
            region_name, root_name, octave, scale_name),
        'Auto-detect Active',
        0
    )
else
    -- Manual selection mode
    -- If we have auto-detected values but user chose to override, use those as defaults
    local default_root_note = defaults.root_note
    if auto_detected_note_class and auto_detected_octave then
        local target_octave = auto_detected_octave or 4
        default_root_note = (target_octave + 1) * 12 + auto_detected_note_class
        if default_root_note < 0 then default_root_note = 0 end
        if default_root_note > 127 then default_root_note = 127 end
    end

    local default_note_name = note_names[(default_root_note % 12) + 1]
    local default_octave = math.floor(default_root_note / 12) - 1

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

    -- Show scale selection menu (with random option)
    local scale_menu_items = {"random"}
    for _, name in ipairs(scale_keys) do
        table.insert(scale_menu_items, name)
    end

    -- Use auto-detected scale as default if overriding, otherwise use saved preference
    local default_scale_name = auto_detected_scale or defaults.scale_name
    local default_scale_idx = 1
    if default_scale_name ~= "random" then
        for i, name in ipairs(scale_menu_items) do
            if name == default_scale_name then
                default_scale_idx = i
                break
            end
        end
    end

    local scale_choice = show_popup_menu(scale_menu_items, default_scale_idx)
    if scale_choice == 0 then return end -- User cancelled

    -- Process selections from menus
    local input_note_name = note_names[note_choice]
    local input_octave = tonumber(octaves[octave_choice])
    scale_name = scale_menu_items[scale_choice]
    root_note = note_name_to_pitch(input_note_name, input_octave)
end

-- =============================
-- Dialog - Step 2: Generation Parameters
-- =============================

local captions = table.concat({
    'Measures',
    'Min Notes',
    'Max Notes',
    'Min Keep',
    'Max Keep',
    'Number of Voices (1-16)'
}, ',')

local defaults_csv = table.concat({
    tostring(defaults.measures),
    tostring(defaults.min_notes),
    tostring(defaults.max_notes),
    tostring(defaults.min_keep),
    tostring(defaults.max_keep),
    tostring(defaults.num_voices)
}, ',')

local ok, ret = reaper.GetUserInputs('jtp gen: Melody Generator - Parameters', 6, captions, defaults_csv)
if not ok then return end

local fields = {}
for s in string.gmatch(ret .. ',', '([^,]*),') do fields[#fields+1] = s end

local measures = tonumber(fields[1]) or defaults.measures
local min_notes = tonumber(fields[2]) or defaults.min_notes
local max_notes = tonumber(fields[3]) or defaults.max_notes
local min_keep = tonumber(fields[4]) or defaults.min_keep
local max_keep = tonumber(fields[5]) or defaults.max_keep
local num_voices = tonumber(fields[6]) or defaults.num_voices

-- Sanity checks
measures = clamp(math.floor(measures + 0.5), 1, 128)
min_notes = clamp(math.floor(min_notes + 0.5), 1, 128)
max_notes = clamp(math.floor(max_notes + 0.5), min_notes, 256)
min_keep = clamp(math.floor(min_keep + 0.5), 0, 1000)
max_keep = clamp(math.floor(max_keep + 0.5), min_keep, 2000)
root_note = clamp(math.floor(root_note + 0.5), 0, 127)
num_voices = clamp(math.floor(num_voices + 0.5), 1, 16)

-- Resolve scale
local chosen_scale_key
if scale_name == 'random' or not scales[scale_name] then
    chosen_scale_key = choose_random(scale_keys)
else
    chosen_scale_key = scale_name
end
local chosen_scale = scales[chosen_scale_key]

-- Persist for next run
set_ext('measures', measures)
set_ext('min_notes', min_notes)
set_ext('max_notes', max_notes)
set_ext('min_keep', min_keep)
set_ext('max_keep', max_keep)
set_ext('root_note', root_note)
set_ext('scale_name', chosen_scale_key)
set_ext('num_voices', num_voices)

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
local dur_weights = {
    [sixteenth_note] = 0,   -- 16th
    [eighth_note] = 30,     -- 8th
    [quarter_note] = 20,    -- quarter
    [half_note] = 15,       -- half
    [whole_note] = 7,       -- whole (full measure)
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
local MAX_REPEATED = 0
local NOTE_VARIETY = 0.99
local BIG_JUMP_CHANCE = 0.1
local BIG_JUMP_INTERVAL = 4

-- Generate a single voice of melody
local function generate_voice(channel)
    local repeated = 0
    local direction = (math.random(2) == 1) and 1 or -1

    local function next_note(prev_note, prev_dur)
        local move = 0
        if repeated >= MAX_REPEATED or math.random() < NOTE_VARIETY then
            move = direction
            if math.random() > 0.7 then move = -move end
            repeated = 0
        else
            if math.random() < BIG_JUMP_CHANCE then
                move = (math.random(2) == 1 and -1 or 1) * math.random(1, BIG_JUMP_INTERVAL)
                repeated = 0
            end
        end
        local idx = find_index(scale_notes, prev_note)
        local new_idx = clamp(idx + move, 1, #scale_notes)
        local vel = vel_for_dur(prev_dur)
        return scale_notes[new_idx], vel
    end

    -- Note count and pruning for this voice
    local NUM_NOTES = math.random(min_notes, max_notes)
    local notes_to_keep = math.random(min_keep, max_keep)

    -- Insert first note
    local prev_note = scale_notes[math.random(1, #scale_notes)]
    local prev_dur = pick_duration(quarter_note)
    local note_start = start_time
    reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_start + prev_dur), channel, prev_note, math.random(60,100), false)

    local note_end = note_start + prev_dur
    for i = 2, NUM_NOTES do
        prev_note, vel = next_note(prev_note, prev_dur)
        prev_dur = pick_duration(prev_dur)
        note_start = note_end
        note_end = note_start + prev_dur
        reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_end), channel, prev_note, vel, false)
    end

    -- Optionally prune notes for this voice
    -- We need to count notes on this channel only
    local voice_note_count = 0
    local _, total_cnt = reaper.MIDI_CountEvts(take)
    for i = 0, total_cnt - 1 do
        local _, _, _, _, _, chan = reaper.MIDI_GetNote(take, i)
        if chan == channel then voice_note_count = voice_note_count + 1 end
    end

    -- Delete excess notes on this channel (from end)
    if voice_note_count > notes_to_keep then
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

-- Initialize random seed
math.randomseed(reaper.time_precise())
for _ = 1,10 do math.random() end

reaper.Undo_BeginBlock()

-- Generate all voices
for voice = 0, num_voices - 1 do
    generate_voice(voice)
end

-- Name the take
local root_name = note_names[(root_note % 12) + 1]
local octave = math.floor(root_note / 12) - 1
local take_name = string.format('%s%d %s', root_name, octave, chosen_scale_key)
reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)

reaper.Undo_EndBlock('jtp gen: Melody Generator (Dialog)', -1)
reaper.UpdateArrange()
