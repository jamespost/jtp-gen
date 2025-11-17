-- @description jtp gen: Chord-Based Solo Generator
-- @author James
-- @version 1.0
-- @about
--   # Chord-Based Solo Generator
--   Takes existing MIDI chord progressions and generates melodic solos over them.
--
--   Detects "chords" as any overlapping notes at a given time, then generates
--   solo lines using only the notes available in each chord (plus octave extensions).
--
--   **THREE GENERATION MODES:**
--   1. SAFE MODE (Conservative): Uses only chord tones + octave transpositions
--   2. EXTENDED MODE (More Colorful): Adds chromatic approach notes
--   3. INTERPOLATED MODE (Most Musical): Stepwise motion between chord tones
--
--   **Features:**
--   - Intelligent chord change detection throughout time
--   - Jazzy phrasing with swing and syncopation
--   - Phrase-based structure (not just random notes)
--   - Velocity and timing humanization
--   - Respects harmonic changes in the source material
--
--   **Usage:**
--   Select a MIDI item with a chord progression, run the script, choose your mode!

-- Check if reaper API is available
if not reaper then return end

local DEBUG = true

local function log(...)
    if not DEBUG then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    reaper.ShowConsoleMsg(table.concat(parts, '') .. '\n')
end

if DEBUG then reaper.ClearConsole() end

-- =============================
-- ExtState Persistence
-- =============================

local EXT_SECTION = 'jtp_gen_chord_solo'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- =============================
-- Configuration & Constants
-- =============================

local GENERATION_MODES = {
    SAFE = 1,           -- Chord tones + octaves only
    EXTENDED = 2,       -- + chromatic approach notes
    INTERPOLATED = 3,   -- + stepwise motion between chord tones
}

local config = {
    min_chord_length = 1/16,      -- Minimum note length to consider part of chord
    overlap_tolerance = 0.01,     -- Time tolerance for note overlap (QN)
    humanization_time = 0.015,    -- ±15ms timing variation
    humanization_velocity = 12,   -- ±12 velocity variation
    swing_amount = 0.15,          -- Swing/jazz feel (0-0.5)
    note_density = 0.7,           -- How many notes to generate (0-1)
    phrase_length_min = 3,        -- Min notes per phrase
    phrase_length_max = 8,        -- Max notes per phrase
    rest_probability = 0.25,      -- Chance of rest between phrases
    octave_range = {-1, 2},       -- Octave transposition range
}

-- Jazz phrasing rhythms (in quarter notes)
local JAZZ_RHYTHMS = {
    {0.25, 50},    -- 16th note (weight: 50)
    {0.33, 60},    -- Triplet 8th
    {0.5, 100},    -- 8th note (most common)
    {0.67, 40},    -- Dotted 8th
    {0.75, 30},    -- Dotted 8th + 16th
    {1.0, 80},     -- Quarter note
    {1.5, 20},     -- Dotted quarter
    {2.0, 10}      -- Half note (occasional)
}

-- =============================
-- Helper Functions
-- =============================

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function choose_weighted(options)
    local total_weight = 0
    for _, opt in ipairs(options) do
        total_weight = total_weight + opt[2]
    end

    local r = math.random() * total_weight
    local cumulative = 0

    for _, opt in ipairs(options) do
        cumulative = cumulative + opt[2]
        if r <= cumulative then
            return opt[1]
        end
    end

    return options[1][1]
end

local function apply_swing(base_time, beat_position, swing_amt)
    -- Apply swing to off-beats
    local beat_fraction = beat_position % 1.0

    -- If this is an off-beat 8th note (0.5 beat position)
    if math.abs(beat_fraction - 0.5) < 0.1 then
        return base_time + (swing_amt * 0.25)  -- Push it later
    end

    return base_time
end

local function humanize(base_time, base_velocity)
    local time_offset = (math.random() - 0.5) * 2 * config.humanization_time
    local vel_offset = (math.random() - 0.5) * 2 * config.humanization_velocity

    return base_time + time_offset, clamp(base_velocity + vel_offset, 1, 127)
end

-- =============================
-- Chord Detection Engine
-- =============================

-- Find all notes overlapping at a specific time
local function findNotesAtTime(notes, time_qn)
    local active_notes = {}

    for _, note in ipairs(notes) do
        if note.start_qn <= time_qn + config.overlap_tolerance and
           note.end_qn >= time_qn - config.overlap_tolerance then
            table.insert(active_notes, note)
        end
    end

    -- Sort by pitch
    table.sort(active_notes, function(a, b) return a.pitch < b.pitch end)

    return active_notes
end

-- Build a timeline of chord changes
local function buildChordTimeline(notes)
    if #notes == 0 then return {} end

    -- Collect all unique time points where chords might change
    local time_points = {}

    for _, note in ipairs(notes) do
        if note.end_qn - note.start_qn >= config.min_chord_length then
            time_points[note.start_qn] = true
            time_points[note.end_qn] = true
        end
    end

    -- Convert to sorted list
    local sorted_times = {}
    for time, _ in pairs(time_points) do
        table.insert(sorted_times, time)
    end
    table.sort(sorted_times)

    -- Build chord segments
    local chord_timeline = {}

    for i = 1, #sorted_times - 1 do
        local start_time = sorted_times[i]
        local end_time = sorted_times[i + 1]
        local mid_time = (start_time + end_time) / 2

        -- Sample notes at midpoint of segment
        local active = findNotesAtTime(notes, mid_time)

        if #active > 0 then
            -- Extract unique pitches
            local pitches = {}
            local pitch_set = {}

            for _, note in ipairs(active) do
                if not pitch_set[note.pitch] then
                    pitch_set[note.pitch] = true
                    table.insert(pitches, note.pitch)
                end
            end

            table.sort(pitches)

            table.insert(chord_timeline, {
                start_qn = start_time,
                end_qn = end_time,
                duration = end_time - start_time,
                pitches = pitches,
                root = pitches[1],  -- Lowest note assumed as root
            })
        end
    end

    log('Built chord timeline with ', #chord_timeline, ' segments')
    return chord_timeline
end

-- =============================
-- Note Pool Builders (by Mode)
-- =============================

-- Mode 1: SAFE - Only chord tones + octaves
local function buildSafeNotePool(chord_segment)
    local pool = {}

    for _, pitch in ipairs(chord_segment.pitches) do
        -- Add original note
        table.insert(pool, pitch)

        -- Add octave transpositions
        for octave = config.octave_range[1], config.octave_range[2] do
            if octave ~= 0 then
                local transposed = pitch + (octave * 12)
                if transposed >= 36 and transposed <= 96 then
                    table.insert(pool, transposed)
                end
            end
        end
    end

    -- Remove duplicates and sort
    local unique = {}
    for _, p in ipairs(pool) do
        unique[p] = true
    end

    local result = {}
    for p, _ in pairs(unique) do
        table.insert(result, p)
    end
    table.sort(result)

    return result
end

-- Mode 2: EXTENDED - Safe pool + chromatic approach notes
local function buildExtendedNotePool(chord_segment)
    local pool = buildSafeNotePool(chord_segment)
    local extended = {}

    -- Copy safe pool
    for _, p in ipairs(pool) do
        extended[p] = true
    end

    -- Add chromatic approach notes (half-step below each chord tone)
    for _, pitch in ipairs(chord_segment.pitches) do
        local approach = pitch - 1
        if approach >= 36 and approach <= 96 then
            extended[approach] = true
        end
    end

    -- Convert to sorted array
    local result = {}
    for p, _ in pairs(extended) do
        table.insert(result, p)
    end
    table.sort(result)

    return result
end

-- Mode 3: INTERPOLATED - Extended pool + passing tones
local function buildInterpolatedNotePool(chord_segment)
    local pool = buildExtendedNotePool(chord_segment)

    -- Add all chromatic notes between lowest and highest chord tones
    local min_pitch = chord_segment.pitches[1]
    local max_pitch = chord_segment.pitches[#chord_segment.pitches]

    -- Extend range slightly
    min_pitch = min_pitch + (config.octave_range[1] * 12)
    max_pitch = max_pitch + (config.octave_range[2] * 12)

    local interpolated = {}

    -- Add all notes in extended range
    for pitch = math.max(36, min_pitch), math.min(96, max_pitch) do
        interpolated[pitch] = true
    end

    -- Convert to sorted array
    local result = {}
    for p, _ in pairs(interpolated) do
        table.insert(result, p)
    end
    table.sort(result)

    return result
end

-- =============================
-- Solo Generation Engine
-- =============================

-- Generate a melodic phrase within a chord segment
local function generatePhrase(chord_segment, mode, start_time, max_duration)
    local note_pool

    -- Build note pool based on mode
    if mode == GENERATION_MODES.SAFE then
        note_pool = buildSafeNotePool(chord_segment)
    elseif mode == GENERATION_MODES.EXTENDED then
        note_pool = buildExtendedNotePool(chord_segment)
    else
        note_pool = buildInterpolatedNotePool(chord_segment)
    end

    if #note_pool == 0 then return {} end

    local phrase = {}
    local phrase_length = math.random(config.phrase_length_min, config.phrase_length_max)
    local current_time = start_time
    local last_pitch = nil

    -- Start phrase on a chord tone
    local start_pitch = chord_segment.pitches[math.random(1, #chord_segment.pitches)]
    start_pitch = start_pitch + (math.random(config.octave_range[1], config.octave_range[2]) * 12)
    start_pitch = clamp(start_pitch, 36, 96)

    for i = 1, phrase_length do
        if current_time >= start_time + max_duration then
            break
        end

        -- Pick rhythm
        local duration = choose_weighted(JAZZ_RHYTHMS)

        -- Don't exceed segment boundary
        if current_time + duration > start_time + max_duration then
            duration = (start_time + max_duration) - current_time
        end

        -- Pick pitch based on mode and melodic logic
        local pitch

        if i == 1 then
            pitch = start_pitch
        elseif mode == GENERATION_MODES.INTERPOLATED and last_pitch then
            -- Stepwise motion preferred
            local step = math.random(-3, 3)
            pitch = last_pitch + step

            -- Clamp to pool range
            pitch = clamp(pitch, note_pool[1], note_pool[#note_pool])

            -- Find closest note in pool
            local closest = note_pool[1]
            local closest_dist = math.abs(pitch - closest)
            for _, p in ipairs(note_pool) do
                local dist = math.abs(pitch - p)
                if dist < closest_dist then
                    closest = p
                    closest_dist = dist
                end
            end
            pitch = closest
        elseif mode == GENERATION_MODES.EXTENDED and last_pitch then
            -- Prefer chord tones, occasional approaches
            if math.random() < 0.7 then
                -- Chord tone
                pitch = chord_segment.pitches[math.random(1, #chord_segment.pitches)]
                pitch = pitch + (math.random(config.octave_range[1], config.octave_range[2]) * 12)
                pitch = clamp(pitch, 36, 96)
            else
                -- Approach note leading to next
                pitch = note_pool[math.random(1, #note_pool)]
            end
        else
            -- Safe mode or no context: random from pool
            pitch = note_pool[math.random(1, #note_pool)]
        end

        -- Base velocity with dynamics
        local velocity = 70 + math.random(-15, 25)

        -- Accent longer notes
        if duration >= 1.0 then
            velocity = velocity + 15
        end

        -- Apply swing and humanization
        local beat_position = (current_time - start_time) / 1.0  -- Relative to phrase start
        local actual_time = apply_swing(current_time, beat_position, config.swing_amount)
        actual_time, velocity = humanize(actual_time, velocity)

        table.insert(phrase, {
            start_qn = actual_time,
            end_qn = actual_time + (duration * 0.85),  -- Slight separation
            pitch = pitch,
            velocity = velocity,
        })

        current_time = current_time + duration
        last_pitch = pitch
    end

    return phrase
end

-- Generate complete solo over chord timeline
local function generateSolo(chord_timeline, mode)
    local solo_notes = {}

    for _, chord_segment in ipairs(chord_timeline) do
        local segment_duration = chord_segment.duration
        local current_time = chord_segment.start_qn

        -- Generate phrases until segment is filled
        while current_time < chord_segment.end_qn do
            -- Occasionally insert rests
            if math.random() < config.rest_probability then
                local rest_duration = choose_weighted({{0.5, 70}, {1.0, 30}})
                current_time = current_time + rest_duration
            else
                -- Generate phrase
                local remaining_time = chord_segment.end_qn - current_time
                local phrase_max_duration = math.min(remaining_time, 4.0)  -- Max 4 beats per phrase

                local phrase = generatePhrase(chord_segment, mode, current_time, phrase_max_duration)

                if #phrase > 0 then
                    for _, note in ipairs(phrase) do
                        table.insert(solo_notes, note)
                    end

                    -- Advance time to end of phrase
                    current_time = phrase[#phrase].end_qn
                else
                    break
                end
            end
        end
    end

    log('Generated ', #solo_notes, ' solo notes')
    return solo_notes
end

-- =============================
-- MIDI Processing
-- =============================

local function readMIDINotes(take)
    local _, note_count = reaper.MIDI_CountEvts(take)
    local notes = {}

    for i = 0, note_count - 1 do
        local retval, selected, muted, start_ppq, end_ppq, chan, pitch, vel =
            reaper.MIDI_GetNote(take, i)

        if retval then
            local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, start_ppq)
            local end_qn = reaper.MIDI_GetProjQNFromPPQPos(take, end_ppq)

            table.insert(notes, {
                index = i,
                start_qn = start_qn,
                end_qn = end_qn,
                pitch = pitch,
                velocity = vel,
                channel = chan,
                selected = selected,
                muted = muted,
            })
        end
    end

    -- Sort by start time
    table.sort(notes, function(a, b) return a.start_qn < b.start_qn end)

    return notes
end

local function insertSoloNotes(take, solo_notes)
    for _, note in ipairs(solo_notes) do
        local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.start_qn)
        local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.end_qn)

        reaper.MIDI_InsertNote(
            take,
            false,  -- selected
            false,  -- muted
            start_ppq,
            end_ppq,
            0,      -- channel 0 (different from chords)
            note.pitch,
            math.floor(note.velocity),
            true    -- no sort yet
        )
    end

    reaper.MIDI_Sort(take)
end

-- =============================
-- User Interface
-- =============================

local function showModeDialog()
    -- Get saved mode preference
    local saved_mode = tonumber(get_ext('mode', 1))

    local mode_options = {
        "Auto (use last settings)",
        "SAFE - Chord tones + octaves only",
        "EXTENDED - Adds chromatic approach notes",
        "INTERPOLATED - Stepwise motion between tones"
    }

    local menu_str = ""
    for i, option in ipairs(mode_options) do
        if i == 1 then
            menu_str = menu_str .. "!" .. option .. "|"  -- Checkmark on Auto
        else
            menu_str = menu_str .. option .. "|"
        end
    end

    gfx.x, gfx.y = reaper.GetMousePosition()
    local choice = gfx.showmenu(menu_str)

    if choice == 0 then return nil end

    -- Handle Auto mode
    if choice == 1 then
        return saved_mode
    end

    -- Return and save the chosen mode (2->1, 3->2, 4->3)
    local mode = choice - 1
    set_ext('mode', mode)
    return mode
end

-- =============================
-- Main Function
-- =============================

function main()
    -- Check for selected items
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then
        reaper.ShowMessageBox(
            "Please select a MIDI item containing a chord progression.",
            "jtp gen: No Selection",
            0
        )
        return
    end

    -- Get first selected item
    local item = reaper.GetSelectedMediaItem(0, 0)
    local take = reaper.GetActiveTake(item)

    if not take or not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox(
            "Selected item is not a MIDI item.",
            "jtp gen: Invalid Item",
            0
        )
        return
    end

    -- Show mode selection dialog
    local mode = showModeDialog()
    if not mode then return end

    -- Initialize random seed
    math.randomseed(reaper.time_precise())
    for i = 1, 10 do math.random() end

    reaper.Undo_BeginBlock()

    -- Read existing MIDI notes
    local notes = readMIDINotes(take)

    if #notes == 0 then
        reaper.ShowMessageBox(
            "No MIDI notes found in selected item.",
            "jtp gen: Empty Item",
            0
        )
        return
    end

    log('Read ', #notes, ' MIDI notes')

    -- Build chord timeline
    local chord_timeline = buildChordTimeline(notes)

    if #chord_timeline == 0 then
        reaper.ShowMessageBox(
            "Could not detect chord changes in the MIDI.\n\nMake sure you have overlapping notes.",
            "jtp gen: No Chords",
            0
        )
        return
    end

    log('Detected ', #chord_timeline, ' chord segments')

    -- Generate solo
    local solo_notes = generateSolo(chord_timeline, mode)

    if #solo_notes == 0 then
        reaper.ShowMessageBox(
            "Failed to generate solo notes.",
            "jtp gen: Generation Failed",
            0
        )
        return
    end

    -- Insert solo notes into MIDI
    insertSoloNotes(take, solo_notes)

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("jtp gen: Chord-Based Solo Generation", -1)

    local mode_names = {"SAFE", "EXTENDED", "INTERPOLATED"}
    reaper.ShowMessageBox(
        string.format(
            "Successfully generated %d solo notes!\n\nMode: %s\nChord segments: %d",
            #solo_notes,
            mode_names[mode],
            #chord_timeline
        ),
        "jtp gen: Solo Generated!",
        0
    )
end

-- Run main function
main()
