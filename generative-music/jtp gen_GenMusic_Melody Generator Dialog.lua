-- @description jtp gen: Melody Generator (Simple Dialog)
-- @author James
-- @version 1.0
-- @about
--   # jtp gen: Melody Generator (Simple Dialog)
--   Generates a MIDI melody with a simple built-in REAPER dialog (no ImGui required).
--   Lets you set a few key parameters quickly and create a melody on the selected track.

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
    num_voices = tonumber(get_ext('num_voices', 1)) -- Number of melodic voices (1-16)
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

-- Show scale selection menu (with random option)
local scale_menu_items = {"random"}
for _, name in ipairs(scale_keys) do
    table.insert(scale_menu_items, name)
end

local default_scale_idx = 1
if defaults.scale_name ~= "random" then
    for i, name in ipairs(scale_menu_items) do
        if name == defaults.scale_name then
            default_scale_idx = i
            break
        end
    end
end

local scale_choice = show_popup_menu(scale_menu_items, default_scale_idx)
if scale_choice == 0 then return end -- User cancelled

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

-- Process selections from menus
local input_note_name = note_names[note_choice]
local input_octave = tonumber(octaves[octave_choice])
local scale_name = scale_menu_items[scale_choice]

local root_note = note_name_to_pitch(input_note_name, input_octave)

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
