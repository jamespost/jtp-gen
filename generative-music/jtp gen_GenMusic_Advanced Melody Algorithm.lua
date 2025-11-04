-- @description jtp gen: Advanced Melody Algorithm
-- @author James
-- @version 1.0
-- @about
--   # Advanced Melody Generator
--   Generates sophisticated melodies using music theory algorithms:
--   - Interval-based melodic motion with tendency tones
--   - Rhythmic density curves with syncopation
--   - Contour shaping (arch, wave, ascending, descending)
--   - Harmonic rhythm and implied chord progressions
--   - Tension/release cycles
--   - Phrase structure with cadences

-- Check if reaper API is available
if not reaper then
    return
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local config = {
    -- Melody Parameters
    num_bars = 4,
    root_note = 60, -- Middle C

    -- Contour Settings
    contour_type = "arch", -- arch, wave, ascending, descending, random
    contour_strength = 0.7, -- 0-1, how much to follow contour

    -- Interval Logic
    max_leap = 7, -- semitones
    leap_recovery_prob = 0.8, -- probability to move opposite direction after leap
    tendency_tone_strength = 0.6, -- pull towards stable tones

    -- Rhythmic Density
    min_note_duration = 0.125, -- 32nd note
    max_note_duration = 2.0, -- half note
    density_curve = "varied", -- constant, increasing, decreasing, varied
    syncopation_prob = 0.3,

    -- Harmonic Context
    use_harmonic_rhythm = true,
    chord_change_bars = 1, -- bars per chord

    -- Phrase Structure
    phrase_length = 2, -- bars per phrase
    cadence_strength = 0.8, -- end phrases with stable notes
}

-- ============================================================================
-- PROJECT SETTINGS
-- ============================================================================

local function get_project_time_signature(position)
    -- Get time signature at project position (default to 0)
    position = position or 0

    -- Get time signature from project - this returns the global project time signature
    local num, denom = reaper.GetProjectTimeSignature2(0)

    -- If GetProjectTimeSignature2 returns invalid values, check what it actually returned
    -- Sometimes REAPER returns tempo in the denom field by mistake
    if denom and denom > 64 then
        -- Likely tempo got mixed in, use default 4/4
        num = 4
        denom = 4
    end

    -- Final safety check - use 4/4 if still invalid
    if not num or num <= 0 then num = 4 end
    if not denom or denom <= 0 then denom = 4 end

    return num, denom
end

local function get_project_tempo(position)
    -- Get tempo at project position (default to 0)
    position = position or 0
    local tempo = reaper.TimeMap_GetTimeSigAtTime(0, position)

    -- Fallback to master tempo
    if not tempo or tempo == 0 then
        tempo = reaper.Master_GetTempo()
    end

    return tempo
end

local function get_time_selection_bars()
    -- Get time selection
    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

    if start_time == end_time then
        -- No time selection
        return nil, nil, nil
    end

    -- Get time signature and tempo
    local time_sig_num, time_sig_denom = get_project_time_signature(start_time)
    local bpm = reaper.Master_GetTempo()

    -- Convert time selection to measures/bars using REAPER's time map
    local retval_start, measures_start = reaper.TimeMap2_timeToBeats(0, start_time)
    local retval_end, measures_end = reaper.TimeMap2_timeToBeats(0, end_time)

    -- Calculate number of bars from the measure difference
    local num_bars = measures_end - measures_start

    return num_bars, start_time, end_time
end

local function randomize_config()
    -- Randomize all parameters
    local contour_types = {"arch", "wave", "ascending", "descending", "random"}
    config.contour_type = contour_types[math.random(#contour_types)]
    config.contour_strength = 0.3 + math.random() * 0.7 -- 0.3 to 1.0

    config.max_leap = math.random(4, 12) -- 4 to 12 semitones
    config.leap_recovery_prob = 0.5 + math.random() * 0.5 -- 0.5 to 1.0
    config.tendency_tone_strength = math.random() -- 0 to 1.0

    local density_types = {"constant", "increasing", "decreasing", "varied"}
    config.density_curve = density_types[math.random(#density_types)]
    config.syncopation_prob = math.random() * 0.6 -- 0 to 0.6

    config.chord_change_bars = math.random(1, 4) -- 1 to 4 bars
    config.phrase_length = math.random(1, 4) -- 1 to 4 bars
    config.cadence_strength = 0.5 + math.random() * 0.5 -- 0.5 to 1.0

    -- Random root note in a reasonable range
    config.root_note = 48 + math.random(0, 24) -- C3 to C5
end

-- ============================================================================
-- MUSIC THEORY ALGORITHMS
-- ============================================================================

-- Define scale degrees and their stability (tension values 0=stable, 1=high tension)
local scale_degrees = {
    [0] = {tension = 0.0, name = "root"},
    [2] = {tension = 0.4, name = "2nd"},
    [4] = {tension = 0.2, name = "3rd"},
    [5] = {tension = 0.3, name = "4th"},
    [7] = {tension = 0.1, name = "5th"},
    [9] = {tension = 0.3, name = "6th"},
    [11] = {tension = 0.5, name = "7th"},
}

-- Common chord progressions (in scale degrees)
local chord_progressions = {
    {0, 7, 5, 7}, -- I-V-IV-V
    {0, 5, 7, 0}, -- I-IV-V-I
    {0, 9, 7, 0}, -- I-vi-V-I
    {0, 5, 9, 7}, -- I-IV-vi-V
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Initialize random seed
math.randomseed(reaper.time_precise())
for i = 1, 10 do math.random() end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function weighted_random_choice(choices, weights)
    local total = 0
    for _, w in ipairs(weights) do
        total = total + w
    end

    local rand = math.random() * total
    local sum = 0

    for i, w in ipairs(weights) do
        sum = sum + w
        if rand <= sum then
            return choices[i]
        end
    end

    return choices[#choices]
end

-- ============================================================================
-- CONTOUR GENERATION
-- ============================================================================

local function generate_contour(num_points, contour_type)
    local contour = {}

    if contour_type == "arch" then
        -- Bell curve: low -> high -> low
        for i = 1, num_points do
            local t = (i - 1) / (num_points - 1)
            contour[i] = math.sin(t * math.pi)
        end

    elseif contour_type == "wave" then
        -- Sine wave
        for i = 1, num_points do
            local t = (i - 1) / (num_points - 1)
            contour[i] = (math.sin(t * math.pi * 2) + 1) / 2
        end

    elseif contour_type == "ascending" then
        -- Gradual ascent
        for i = 1, num_points do
            contour[i] = (i - 1) / (num_points - 1)
        end

    elseif contour_type == "descending" then
        -- Gradual descent
        for i = 1, num_points do
            contour[i] = 1 - (i - 1) / (num_points - 1)
        end

    else -- random
        for i = 1, num_points do
            contour[i] = math.random()
        end
    end

    return contour
end

-- ============================================================================
-- RHYTHMIC GENERATION
-- ============================================================================

local function generate_rhythm_pattern(bar_length, density_curve, beat_length)
    local pattern = {}
    local position = 0

    -- Safety check
    if bar_length <= 0 or beat_length <= 0 then
        -- Add at least one note spanning the whole bar
        table.insert(pattern, {
            position = 0,
            duration = math.max(bar_length, 1.0)
        })
        return pattern
    end

    -- Define note durations relative to beat_length
    local eighth_note = beat_length / 2
    local sixteenth_note = beat_length / 4
    local quarter_note = beat_length
    local half_note = beat_length * 2

    -- Maximum iterations to prevent infinite loops
    local max_iterations = 100
    local iterations = 0

    while position < bar_length and iterations < max_iterations do
        iterations = iterations + 1

        -- Determine density factor based on position and curve type
        local progress = position / bar_length
        local density_factor

        if density_curve == "increasing" then
            density_factor = 0.3 + progress * 0.7
        elseif density_curve == "decreasing" then
            density_factor = 1.0 - progress * 0.7
        elseif density_curve == "varied" then
            density_factor = 0.5 + math.sin(progress * math.pi * 4) * 0.3
        else -- constant
            density_factor = 0.6
        end

        -- Generate note duration based on density
        -- Higher density = shorter notes
        local duration_weights = {}
        local durations = {}
        local weights = {}

        -- Add sixteenth notes (high density)
        if sixteenth_note <= bar_length - position then
            table.insert(durations, sixteenth_note)
            table.insert(weights, density_factor * 3)
        end

        -- Add eighth notes (medium-high density)
        if eighth_note <= bar_length - position then
            table.insert(durations, eighth_note)
            table.insert(weights, density_factor * 2)
        end

        -- Add quarter notes (medium density)
        if quarter_note <= bar_length - position then
            table.insert(durations, quarter_note)
            table.insert(weights, (1 - density_factor) * 2)
        end

        -- Add half notes (low density)
        if half_note <= bar_length - position then
            table.insert(durations, half_note)
            table.insert(weights, (1 - density_factor) * 1)
        end

        -- If no durations fit, use remaining space
        if #durations == 0 then
            table.insert(durations, bar_length - position)
            table.insert(weights, 1.0)
        end

        local duration = weighted_random_choice(durations, weights)

        -- Apply syncopation
        local is_on_beat = (position % beat_length) < 0.001
        if not is_on_beat and math.random() < config.syncopation_prob then
            -- Keep syncopated note
        elseif not is_on_beat and position > 0 then
            -- Snap to next beat
            local next_beat = math.ceil(position / beat_length) * beat_length
            if next_beat < bar_length then
                position = next_beat
            else
                break
            end
        end

        -- Add note to pattern
        table.insert(pattern, {
            position = position,
            duration = math.min(duration, bar_length - position)
        })

        position = position + duration
    end

    -- Ensure we have at least one note
    if #pattern == 0 then
        table.insert(pattern, {
            position = 0,
            duration = bar_length
        })
    end

    return pattern
end

-- ============================================================================
-- MELODIC INTERVAL LOGIC
-- ============================================================================

local function get_nearest_scale_degree(pitch, root)
    local pitch_class = (pitch - root) % 12
    local nearest = nil
    local min_distance = 999

    for degree, info in pairs(scale_degrees) do
        local distance = math.abs(pitch_class - (degree % 12))
        if distance < min_distance then
            min_distance = distance
            nearest = degree
        end
    end

    return nearest
end

local function get_tension(pitch, root)
    local degree = get_nearest_scale_degree(pitch, root)
    return scale_degrees[degree].tension
end

local function generate_next_pitch(current_pitch, prev_interval, target_contour, current_chord_root, is_cadence)
    local root = current_chord_root or config.root_note

    -- Determine target range based on contour
    local contour_target = config.root_note + math.floor(target_contour * 24 - 12)

    -- Calculate interval choices with weights
    local interval_choices = {}
    local interval_weights = {}

    for interval = -config.max_leap, config.max_leap do
        if interval ~= 0 then
            local new_pitch = current_pitch + interval
            local weight = 1.0

            -- Favor movement towards contour target
            local distance_to_target = math.abs(new_pitch - contour_target)
            local contour_weight = 1 / (1 + distance_to_target * config.contour_strength)
            weight = weight * (1 + contour_weight)

            -- Leap recovery: prefer opposite direction after large leap
            if prev_interval then
                local is_leap = math.abs(prev_interval) > 3
                local is_opposite_direction = (prev_interval > 0 and interval < 0) or (prev_interval < 0 and interval > 0)

                if is_leap and is_opposite_direction and math.random() < config.leap_recovery_prob then
                    weight = weight * 3
                end
            end

            -- Favor smaller intervals (stepwise motion)
            local interval_size = math.abs(interval)
            if interval_size <= 2 then
                weight = weight * 2.5
            elseif interval_size <= 4 then
                weight = weight * 1.5
            end

            -- Favor stable tones (low tension)
            local tension = get_tension(new_pitch, root)
            local stability = 1 - tension
            weight = weight * (1 + stability * config.tendency_tone_strength)

            -- At cadence points, strongly favor stable tones
            if is_cadence then
                weight = weight * (1 + stability * config.cadence_strength * 5)
            end

            table.insert(interval_choices, interval)
            table.insert(interval_weights, weight)
        end
    end

    -- Choose interval based on weights
    local interval = weighted_random_choice(interval_choices, interval_weights)
    return current_pitch + interval, interval
end

-- ============================================================================
-- HARMONIC PROGRESSION
-- ============================================================================

local function generate_harmonic_progression(num_chords)
    local progression = chord_progressions[math.random(#chord_progressions)]
    local result = {}

    for i = 1, num_chords do
        local chord_degree = progression[((i - 1) % #progression) + 1]
        table.insert(result, config.root_note + chord_degree)
    end

    return result
end

-- ============================================================================
-- MAIN MELODY GENERATION
-- ============================================================================

local function generate_melody(time_sig_num, time_sig_denom)
    local melody = {}

    -- Validate time signature values
    if not time_sig_num or time_sig_num <= 0 then time_sig_num = 4 end
    if not time_sig_denom or time_sig_denom <= 0 then time_sig_denom = 4 end

    -- Calculate total parameters
    local beats_per_bar = time_sig_num
    -- Normalize beat length to quarter note equivalents
    local bar_length = beats_per_bar * (4.0 / time_sig_denom)
    local total_beats = bar_length * config.num_bars

    -- Beat length for rhythm generation (quarter note = 1.0)
    local beat_length = 4.0 / time_sig_denom

    -- Generate harmonic progression
    local chord_changes = {}
    if config.use_harmonic_rhythm then
        local num_chords = math.ceil(config.num_bars / config.chord_change_bars)
        chord_changes = generate_harmonic_progression(num_chords)
    else
        chord_changes = {config.root_note}
    end

    -- Generate contour for entire melody
    local contour_points = math.max(4, math.ceil(config.num_bars * 4)) -- resolution
    local contour = generate_contour(contour_points, config.contour_type)

    -- Generate rhythm pattern for all bars
    local all_notes = {}

    -- Handle fractional bars - generate at least one pattern
    local num_patterns = math.max(1, math.ceil(config.num_bars))

    for bar = 1, num_patterns do
        local bar_pattern = generate_rhythm_pattern(bar_length, config.density_curve, beat_length)
        for _, note in ipairs(bar_pattern) do
            local note_position = (bar - 1) * bar_length + note.position
            -- Only include notes that fit within the total length
            if note_position < total_beats then
                table.insert(all_notes, {
                    position = note_position,
                    duration = math.min(note.duration, total_beats - note_position),
                    bar = bar
                })
            end
        end
    end

    -- Generate pitches for each note
    local current_pitch = config.root_note
    local prev_interval = nil

    for i, note in ipairs(all_notes) do
        -- Determine current chord
        local chord_idx = math.floor((note.bar - 1) / config.chord_change_bars) + 1
        chord_idx = math.min(chord_idx, #chord_changes)
        local current_chord = chord_changes[chord_idx]

        -- Determine if this is a cadence point (end of phrase)
        local is_phrase_end = (note.bar % config.phrase_length) == 0 and i == #all_notes or
                               (i < #all_notes and all_notes[i + 1].bar % config.phrase_length == 1 and all_notes[i + 1].bar > note.bar)

        -- Get contour value for this position
        local contour_idx = math.floor((note.position / total_beats) * (#contour - 1)) + 1
        contour_idx = clamp(contour_idx, 1, #contour)
        local target_contour = contour[contour_idx]

        -- Generate pitch
        current_pitch, prev_interval = generate_next_pitch(
            current_pitch,
            prev_interval,
            target_contour,
            current_chord,
            is_phrase_end
        )

        -- Store note
        table.insert(melody, {
            position = note.position,
            duration = note.duration,
            pitch = current_pitch,
            velocity = 80 + math.random(-10, 20) -- slight velocity variation
        })
    end

    return melody
end

-- ============================================================================
-- REAPER INTEGRATION
-- ============================================================================

local function create_midi_items(melody, time_sig_num, time_sig_denom, bpm, start_position, end_position)
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first.", "No Track Selected", 0)
        return false
    end

    -- Use the actual time selection length
    local item_length = end_position - start_position

    -- Create MIDI item at the time selection start position with exact selection length
    local item = reaper.CreateNewMIDIItemInProj(track, start_position, item_length)
    if not item then
        return false
    end

    local take = reaper.GetActiveTake(item)
    if not take then
        return false
    end

    -- Calculate time conversion (quarter note = 1.0)
    local beat_length = 60.0 / bpm -- seconds per quarter note

    -- Count how many notes actually get inserted
    local notes_inserted = 0

    -- Add notes to MIDI take
    for _, note in ipairs(melody) do
        -- Position and duration are in quarter note units
        -- Convert to absolute project time
        local note_start_time = start_position + (note.position * beat_length)
        local note_end_time = note_start_time + (note.duration * beat_length)

        -- Make sure note is within the item bounds
        if note_start_time >= start_position and note_start_time < end_position then
            -- Clamp end time to item boundary
            if note_end_time > end_position then
                note_end_time = end_position
            end

            -- Convert to PPQ (MIDI ticks)
            local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, note_start_time)
            local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, note_end_time)

            -- Only insert if we have valid PPQ positions and duration
            if start_ppq and end_ppq and end_ppq > start_ppq then
                local success = reaper.MIDI_InsertNote(
                    take,
                    false, -- selected
                    false, -- muted
                    start_ppq,
                    end_ppq,
                    0, -- channel
                    note.pitch,
                    note.velocity,
                    true -- no sort
                )
                if success then
                    notes_inserted = notes_inserted + 1
                end
            end
        end
    end

    -- Sort and update MIDI
    reaper.MIDI_Sort(take)
    reaper.UpdateItemInProject(item)

    return true, notes_inserted
end

-- ============================================================================
-- USER INTERFACE
-- ============================================================================

local function format_config_summary()
    -- Create a readable summary of the randomized settings
    return string.format(
        "Contour: %s (%.2f)\n" ..
        "Max Leap: %d semitones\n" ..
        "Leap Recovery: %.2f\n" ..
        "Tendency Tone: %.2f\n" ..
        "Density: %s\n" ..
        "Syncopation: %.2f\n" ..
        "Chord Change: %d bars\n" ..
        "Phrase Length: %d bars\n" ..
        "Cadence: %.2f\n" ..
        "Root Note: %d",
        config.contour_type,
        config.contour_strength,
        config.max_leap,
        config.leap_recovery_prob,
        config.tendency_tone_strength,
        config.density_curve,
        config.syncopation_prob,
        config.chord_change_bars,
        config.phrase_length,
        config.cadence_strength,
        config.root_note
    )
end

-- ============================================================================
-- MAIN FUNCTION
-- ============================================================================

function main()
    -- Get time selection
    local num_bars, start_time, end_time = get_time_selection_bars()

    if not num_bars or num_bars <= 0 then
        reaper.ShowMessageBox(
            "Please make a time selection first.\n\n" ..
            "The script will generate a melody that fills the selected time range.",
            "No Time Selection",
            0
        )
        return
    end

    -- Ensure minimum bar length
    if num_bars < 0.25 then
        num_bars = 0.25
    end

    -- Update config with the time selection length
    config.num_bars = num_bars

    -- Randomize all other parameters
    randomize_config()

    -- Get project settings
    local time_sig_num, time_sig_denom = get_project_time_signature(start_time)
    local bpm = reaper.Master_GetTempo()

    reaper.Undo_BeginBlock()

    -- Generate melody with project time signature
    local melody = generate_melody(time_sig_num, time_sig_denom)

    -- Create MIDI items in REAPER with exact time selection boundaries
    local success, notes_inserted = create_midi_items(melody, time_sig_num, time_sig_denom, bpm, start_time, end_time)

    if success then
        reaper.Undo_EndBlock("jtp gen: Generate Advanced Melody", -1)
        reaper.ShowMessageBox(
            "Generated " .. #melody .. " notes (" .. (notes_inserted or 0) .. " inserted)\n" ..
            "Length: " .. string.format("%.2f", num_bars) .. " bars\n" ..
            "Time Selection: " .. string.format("%.2f", start_time) .. "s to " .. string.format("%.2f", end_time) .. "s\n" ..
            "Time Signature: " .. time_sig_num .. "/" .. time_sig_denom .. "\n" ..
            "Tempo: " .. math.floor(bpm + 0.5) .. " BPM\n\n" ..
            "Randomized Parameters:\n" ..
            format_config_summary(),
            "Success",
            0
        )
    else
        reaper.Undo_EndBlock("jtp gen: Generate Advanced Melody (Failed)", -1)
    end
end

-- Run main function
main()
