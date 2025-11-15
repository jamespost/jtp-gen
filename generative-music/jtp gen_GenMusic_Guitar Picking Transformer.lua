-- @description jtp gen: Guitar Picking Transformer
-- @author James
-- @version 1.0
-- @about
--   # Guitar Picking Transformer
--   Transforms MIDI note chords into sophisticated guitar picking patterns.
--   Treats sustained/overlapping notes as a chord voicing being held, then
--   generates realistic fingerstyle, strumming, and picking patterns.
--
--   Takes existing MIDI clips and transforms them - not interactive, fully generative.
--   More sophisticated than simple arpeggiation - uses multiple picking techniques
--   and patterns that real guitarists would use.

if not reaper then
    return
end

-- =============================
-- Configuration & Patterns
-- =============================

-- Picking style techniques (multiple can be combined in one pattern)
local PICKING_TECHNIQUES = {
    FINGERSTYLE = 1,      -- Classic fingerpicking (Travis, folk)
    HYBRID = 2,           -- Pick + fingers combination
    SWEEP = 3,            -- Rapid directional sweeps
    ECONOMY = 4,          -- Alternating pick with string skips
    TREMOLO = 5,          -- Rapid repeated notes
    CAMPANELLA = 6,       -- Overlapping/ringing notes
    RASGUEADO = 7,        -- Flamenco-style strumming
}

-- Rhythmic feel types
local RHYTHMIC_FEELS = {
    STRAIGHT = 1,         -- Even subdivisions
    SWING = 2,            -- Swing/shuffle feel
    SYNCOPATED = 3,       -- Off-beat emphasis
    RUBATO = 4,           -- Free timing variations
}

-- Configuration
local config = {
    min_chord_length = 1/8,   -- Minimum note length to consider as "held chord" (1/8 note)
    humanization = 0.015,      -- Random timing offset (±15ms)
    velocity_variation = 15,   -- Random velocity variation (±15)
    string_count = 6,          -- Simulate 6-string guitar
    min_string_interval = 0.020, -- 20ms minimum between hits on same string
}

-- =============================
-- Guitar Picking Pattern Library
-- =============================

-- Pattern definitions: each pattern is a sequence of note indices and techniques
-- Format: {index, timing_offset, velocity_mod, technique_hint}
local PATTERN_LIBRARY = {}

-- Travis Picking Patterns (alternating bass with melody)
PATTERN_LIBRARY.travis_basic = {
    {1, 0.00, 0, "bass"},      -- Bass note
    {3, 0.25, -10, "melody"},  -- High note
    {2, 0.50, -5, "mid"},      -- Mid note
    {3, 0.75, -10, "melody"},  -- High note
}

PATTERN_LIBRARY.travis_double = {
    {1, 0.00, 0, "bass"},
    {3, 0.125, -10, "melody"},
    {2, 0.25, -5, "mid"},
    {3, 0.375, -10, "melody"},
    {1, 0.50, -3, "bass"},
    {4, 0.625, -8, "melody"},
    {2, 0.75, -5, "mid"},
    {4, 0.875, -8, "melody"},
}

-- Folk/Country patterns
PATTERN_LIBRARY.folk_basic = {
    {1, 0.00, 0, "bass"},
    {3, 0.25, -8, "melody"},
    {1, 0.50, -3, "bass"},
    {4, 0.75, -10, "melody"},
}

PATTERN_LIBRARY.folk_rolling = {
    {1, 0.00, 0, "bass"},
    {2, 0.167, -5, "mid"},
    {3, 0.333, -8, "melody"},
    {4, 0.50, -10, "melody"},
    {3, 0.667, -8, "melody"},
    {2, 0.833, -5, "mid"},
}

-- Fingerstyle Jazz patterns
PATTERN_LIBRARY.jazz_walking = {
    {1, 0.00, 0, "bass"},
    {2, 0.125, -8, "mid"},
    {4, 0.25, -12, "melody"},
    {3, 0.375, -10, "melody"},
    {2, 0.50, -5, "mid"},
    {1, 0.625, -3, "bass"},
    {3, 0.75, -10, "melody"},
    {4, 0.875, -12, "melody"},
}

-- Flamenco-inspired patterns
PATTERN_LIBRARY.flamenco_rasgueado = {
    {4, 0.00, 5, "strum"},
    {3, 0.03, 3, "strum"},
    {2, 0.06, 0, "strum"},
    {1, 0.09, -3, "strum"},
    {2, 0.50, -5, "accent"},
    {4, 0.75, -8, "accent"},
}

-- Sweep picking patterns (for fast runs)
PATTERN_LIBRARY.sweep_ascending = {
    {1, 0.00, -10, "sweep"},
    {2, 0.083, -8, "sweep"},
    {3, 0.167, -6, "sweep"},
    {4, 0.25, -4, "sweep"},
    {4, 0.333, 0, "accent"},
}

PATTERN_LIBRARY.sweep_descending = {
    {4, 0.00, 0, "accent"},
    {3, 0.083, -4, "sweep"},
    {2, 0.167, -6, "sweep"},
    {1, 0.25, -8, "sweep"},
    {1, 0.333, -10, "sweep"},
}

-- Hybrid picking (pick + fingers)
PATTERN_LIBRARY.hybrid_alternating = {
    {1, 0.00, 0, "pick"},
    {3, 0.125, -8, "finger"},
    {1, 0.25, -3, "pick"},
    {4, 0.375, -10, "finger"},
    {2, 0.50, -5, "pick"},
    {3, 0.625, -8, "finger"},
    {1, 0.75, -3, "pick"},
    {4, 0.875, -10, "finger"},
}

-- Tremolo picking (rapid repetition)
PATTERN_LIBRARY.tremolo_high = {
    {4, 0.00, 0, "tremolo"},
    {4, 0.125, -5, "tremolo"},
    {4, 0.25, -3, "tremolo"},
    {4, 0.375, -5, "tremolo"},
    {4, 0.50, 0, "tremolo"},
    {4, 0.625, -5, "tremolo"},
    {4, 0.75, -3, "tremolo"},
    {4, 0.875, -5, "tremolo"},
}

-- Campanella (ringing/overlapping notes)
PATTERN_LIBRARY.campanella = {
    {1, 0.00, 0, "sustain"},
    {2, 0.25, -5, "sustain"},
    {3, 0.50, -8, "sustain"},
    {4, 0.75, -10, "sustain"},
    {3, 1.00, -8, "sustain"},
    {2, 1.25, -5, "sustain"},
}

-- Syncopated rhythm patterns
PATTERN_LIBRARY.syncopated_funk = {
    {1, 0.00, 0, "bass"},
    {3, 0.167, -8, "melody"},
    {2, 0.375, -5, "mid"},
    {4, 0.50, -10, "accent"},
    {2, 0.75, -5, "mid"},
    {3, 0.875, -8, "melody"},
}

-- Bossa nova pattern
PATTERN_LIBRARY.bossa_nova = {
    {1, 0.00, 0, "bass"},
    {3, 0.25, -8, "melody"},
    {2, 0.375, -5, "mid"},
    {1, 0.50, -3, "bass"},
    {4, 0.625, -10, "melody"},
    {2, 0.75, -5, "mid"},
    {3, 0.875, -8, "melody"},
}

-- Pattern categories for intelligent selection
local PATTERN_CATEGORIES = {
    travis = {"travis_basic", "travis_double"},
    folk = {"folk_basic", "folk_rolling"},
    jazz = {"jazz_walking"},
    flamenco = {"flamenco_rasgueado"},
    sweep = {"sweep_ascending", "sweep_descending"},
    hybrid = {"hybrid_alternating"},
    tremolo = {"tremolo_high"},
    campanella = {"campanella"},
    syncopated = {"syncopated_funk", "bossa_nova"},
}

-- =============================
-- Helper Functions
-- =============================

-- Find all overlapping notes at a given time (these form the "chord")
local function findChordAtTime(notes, time_pos, tolerance)
    tolerance = tolerance or 0.001
    local chord = {}

    for _, note in ipairs(notes) do
        if note.start_pos <= time_pos + tolerance and note.end_pos >= time_pos - tolerance then
            table.insert(chord, note)
        end
    end

    -- Sort by pitch (ascending)
    table.sort(chord, function(a, b) return a.pitch < b.pitch end)

    return chord
end

-- Find all distinct chord moments in the MIDI item
local function findChordMoments(notes, min_length_qn)
    local moments = {}
    local processed_starts = {}

    for _, note in ipairs(notes) do
        local length = note.end_pos - note.start_pos

        -- Only consider notes long enough to be "held"
        if length >= min_length_qn then
            -- Round start time to avoid floating point issues
            local rounded_start = math.floor(note.start_pos * 1000) / 1000

            if not processed_starts[rounded_start] then
                processed_starts[rounded_start] = true

                -- Find all notes that overlap at this start time
                local chord = findChordAtTime(notes, note.start_pos)

                if #chord > 0 then
                    -- Calculate the duration this chord is held
                    local min_end = math.huge
                    for _, n in ipairs(chord) do
                        min_end = math.min(min_end, n.end_pos)
                    end

                    table.insert(moments, {
                        start_pos = note.start_pos,
                        end_pos = min_end,
                        chord = chord,
                        duration = min_end - note.start_pos
                    })
                end
            end
        end
    end

    -- Sort by start time
    table.sort(moments, function(a, b) return a.start_pos < b.start_pos end)

    return moments
end

-- Select appropriate picking pattern based on chord characteristics
local function selectPattern(chord, duration, context)
    local num_notes = #chord
    context = context or {}

    -- Seed random based on position for reproducibility with variation
    math.randomseed(math.floor(chord[1].start_pos * 1000))
    for i = 1, 3 do math.random() end -- Advance RNG state

    -- Pattern selection logic based on chord size and musical context
    if num_notes == 1 then
        -- Single note: use tremolo or simple patterns
        return PATTERN_LIBRARY.tremolo_high

    elseif num_notes == 2 then
        -- Two notes: simple alternating patterns
        local patterns = {
            PATTERN_LIBRARY.folk_basic,
            PATTERN_LIBRARY.hybrid_alternating,
        }
        return patterns[math.random(1, #patterns)]

    elseif num_notes == 3 then
        -- Three notes: classic folk/country patterns
        local patterns = {
            PATTERN_LIBRARY.travis_basic,
            PATTERN_LIBRARY.folk_basic,
            PATTERN_LIBRARY.folk_rolling,
        }
        return patterns[math.random(1, #patterns)]

    elseif num_notes == 4 then
        -- Four notes: full fingerstyle palette
        local patterns = {
            PATTERN_LIBRARY.travis_double,
            PATTERN_LIBRARY.jazz_walking,
            PATTERN_LIBRARY.hybrid_alternating,
            PATTERN_LIBRARY.bossa_nova,
        }
        return patterns[math.random(1, #patterns)]

    elseif num_notes >= 5 then
        -- Five+ notes: complex patterns or sweeps
        local patterns = {
            PATTERN_LIBRARY.jazz_walking,
            PATTERN_LIBRARY.sweep_ascending,
            PATTERN_LIBRARY.sweep_descending,
            PATTERN_LIBRARY.campanella,
            PATTERN_LIBRARY.flamenco_rasgueado,
        }
        return patterns[math.random(1, #patterns)]
    end

    -- Default fallback
    return PATTERN_LIBRARY.travis_basic
end

-- Apply humanization to timing and velocity
local function humanize(base_time, base_velocity, technique)
    -- Timing humanization
    local time_offset = (math.random() - 0.5) * 2 * config.humanization

    -- Velocity humanization (less variation for consistent techniques)
    local vel_variation = config.velocity_variation
    if technique == "tremolo" or technique == "sweep" then
        vel_variation = vel_variation * 0.5  -- More consistent for fast techniques
    end

    local velocity_offset = (math.random() - 0.5) * 2 * vel_variation

    return base_time + time_offset, base_velocity + velocity_offset
end

-- Generate picking pattern from a chord moment
local function generatePickingFromChord(moment, pattern)
    local generated_notes = {}
    local chord = moment.chord
    local start_time = moment.start_pos
    local duration = moment.duration

    if #chord == 0 then return generated_notes end

    -- Calculate base velocity (average of chord)
    local base_velocity = 0
    for _, note in ipairs(chord) do
        base_velocity = base_velocity + note.velocity
    end
    base_velocity = base_velocity / #chord

    -- Determine how many times to repeat the pattern
    local pattern_duration = 1.0  -- Most patterns span 1 quarter note
    local num_repetitions = math.max(1, math.floor(duration / pattern_duration))

    -- Generate notes based on pattern
    for rep = 0, num_repetitions - 1 do
        for _, step in ipairs(pattern) do
            local note_index = step[1]
            local timing_offset = step[2]
            local velocity_mod = step[3]
            local technique = step[4]

            -- Wrap note index if chord is smaller than pattern expects
            local actual_index = ((note_index - 1) % #chord) + 1
            local source_note = chord[actual_index]

            -- Calculate timing
            local base_time = start_time + (rep * pattern_duration) + timing_offset

            -- Don't generate notes past the chord's end
            if base_time >= moment.end_pos then
                break
            end

            -- Calculate velocity
            local velocity = base_velocity + velocity_mod

            -- Apply humanization
            local actual_time, actual_velocity = humanize(base_time, velocity, technique)
            actual_velocity = math.max(1, math.min(127, math.floor(actual_velocity)))

            -- Determine note length based on technique
            local note_length
            if technique == "sustain" or technique == "campanella" then
                -- Let notes ring - sustain until next note or end
                note_length = 0.75  -- 3/4 of a quarter note
            elseif technique == "tremolo" or technique == "sweep" then
                -- Short, crisp notes
                note_length = 0.08  -- Very short
            elseif technique == "strum" then
                -- Medium length for strums
                note_length = 0.15
            else
                -- Default picking length
                note_length = 0.20
            end

            -- Create the note
            table.insert(generated_notes, {
                start_pos = actual_time,
                end_pos = math.min(actual_time + note_length, moment.end_pos),
                pitch = source_note.pitch,
                velocity = actual_velocity,
                channel = source_note.channel,
                selected = source_note.selected,
                muted = source_note.muted,
                technique = technique
            })
        end
    end

    return generated_notes
end

-- =============================
-- Main Processing
-- =============================

-- Process a single MIDI item
local function processMIDIItem(item)
    local take = reaper.GetActiveTake(item)
    if not take then return false end
    if not reaper.TakeIsMIDI(take) then return false end

    -- Get tempo information for time conversion
    local bpm = reaper.Master_GetTempo()
    local min_length_qn = config.min_chord_length * 4  -- Convert to quarter notes

    -- Read all MIDI notes
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
                start_pos = start_qn,
                end_pos = end_qn,
                pitch = pitch,
                velocity = vel,
                channel = chan,
                selected = selected,
                muted = muted,
            })
        end
    end

    if #notes == 0 then return false end

    -- Sort notes by start time
    table.sort(notes, function(a, b) return a.start_pos < b.start_pos end)

    -- Find all chord moments
    local chord_moments = findChordMoments(notes, min_length_qn)

    if #chord_moments == 0 then
        reaper.ShowMessageBox(
            "No sustained chords found.\n\nMake sure you have overlapping notes that are at least 1/8 note long.",
            "jtp gen: No Chords Found",
            0
        )
        return false
    end

    -- Generate picking patterns for each chord moment
    local all_generated_notes = {}
    local notes_to_delete = {}

    for _, moment in ipairs(chord_moments) do
        -- Select appropriate pattern for this chord
        local pattern = selectPattern(moment.chord, moment.duration)

        -- Generate picking notes
        local picking_notes = generatePickingFromChord(moment, pattern)

        -- Add to collection
        for _, note in ipairs(picking_notes) do
            table.insert(all_generated_notes, note)
        end

        -- Mark original chord notes for deletion
        for _, chord_note in ipairs(moment.chord) do
            table.insert(notes_to_delete, chord_note.index)
        end
    end

    -- Delete original notes (in reverse order)
    local unique_deletions = {}
    for _, idx in ipairs(notes_to_delete) do
        unique_deletions[idx] = true
    end

    local deletion_list = {}
    for idx in pairs(unique_deletions) do
        table.insert(deletion_list, idx)
    end
    table.sort(deletion_list, function(a, b) return a > b end)

    for _, idx in ipairs(deletion_list) do
        reaper.MIDI_DeleteNote(take, idx)
    end

    -- Insert new picking notes
    for _, note in ipairs(all_generated_notes) do
        local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.start_pos)
        local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.end_pos)

        reaper.MIDI_InsertNote(
            take,
            note.selected,
            note.muted,
            start_ppq,
            end_ppq,
            note.channel,
            note.pitch,
            note.velocity,
            true  -- no sort
        )
    end

    -- Sort MIDI events
    reaper.MIDI_Sort(take)

    return true
end

-- Main function
function main()
    -- Check for selected items
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then
        reaper.ShowMessageBox(
            "Please select at least one MIDI item containing sustained notes/chords.",
            "jtp gen: No Items Selected",
            0
        )
        return
    end

    reaper.Undo_BeginBlock()

    local processed_count = 0

    -- Process each selected item
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if processMIDIItem(item) then
            processed_count = processed_count + 1
        end
    end

    if processed_count > 0 then
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("jtp gen: Guitar Picking Transform (" .. processed_count .. " items)", -1)

        reaper.ShowMessageBox(
            "Successfully transformed " .. processed_count .. " MIDI item(s) into guitar picking patterns!",
            "jtp gen: Transform Complete",
            0
        )
    else
        reaper.ShowMessageBox(
            "No items were transformed.\n\nMake sure your MIDI items contain sustained/overlapping notes.",
            "jtp gen: No Processing",
            0
        )
    end
end

-- Run main function
main()
