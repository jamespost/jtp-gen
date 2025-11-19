-- @description jtp gen: Call & Response Generator
-- @author James
-- @version 2.0
-- @about
--   # Call & Response Generator
--   Generates complete musical call and response phrases from scratch!
--   Perfect for starting with a blank page - no existing material needed.
--
--   **GENERATION MODES:**
--   - Melodic Dialogue: Calls ascend, responses descend (conversational)
--   - Rhythmic Echo: Call establishes rhythm, response varies it
--   - Harmonic Answer: Response transposes call by interval (3rd/5th)
--   - Question/Answer: Call with tension, response resolves to tonic
--   - Sequence Chain: Each phrase transposes the previous
--   - Antecedent/Consequent: Classical period structure with resolution
--
--   **Features:**
--   - Generates BOTH call AND response from scratch
--   - Choose key, scale, tempo feel
--   - Multiple phrase pairs (2-8 exchanges)
--   - Phrase complexity controls (simple to virtuosic)
--   - Automatic harmonic coherence and voice leading
--   - Creates complete musical conversations
--
--   **Usage:**
--   1. Select track (script creates MIDI item if needed)
--   2. Choose key, scale, and conversation style
--   3. Script generates complete call/response musical dialogue!

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

local EXT_SECTION = 'jtp_gen_call_response'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- =============================
-- Configuration
-- =============================

local GENERATION_MODES = {
    DIALOGUE = 1,         -- Ascending calls, descending responses
    RHYTHMIC_ECHO = 2,    -- Establish rhythm, then vary
    HARMONIC_ANSWER = 3,  -- Transpose by interval
    QUESTION_ANSWER = 4,  -- Tension then resolution
    SEQUENCE = 5,         -- Progressive transposition
    CLASSICAL = 6,        -- Antecedent/consequent periods
}

local MODE_NAMES = {
    [1] = "1. Melodic Dialogue (conversational contours)",
    [2] = "2. Rhythmic Echo (rhythm focus)",
    [3] = "3. Harmonic Answer (interval transposition)",
    [4] = "4. Question/Answer (tension & resolution)",
    [5] = "5. Sequence Chain (progressive steps)",
    [6] = "6. Classical Period (antecedent/consequent)",
}

-- Scale definitions (intervals from root)
local SCALES = {
    major = {0, 2, 4, 5, 7, 9, 11},
    minor = {0, 2, 3, 5, 7, 8, 10},
    dorian = {0, 2, 3, 5, 7, 9, 10},
    phrygian = {0, 1, 3, 5, 7, 8, 10},
    lydian = {0, 2, 4, 6, 7, 9, 11},
    mixolydian = {0, 2, 4, 5, 7, 9, 10},
    minor_pentatonic = {0, 3, 5, 7, 10},
    major_pentatonic = {0, 2, 4, 7, 9},
    blues = {0, 3, 5, 6, 7, 10},
}

local SCALE_NAMES = {
    "Major", "Natural Minor", "Dorian", "Phrygian",
    "Lydian", "Mixolydian", "Minor Pentatonic",
    "Major Pentatonic", "Blues"
}

local SCALE_MAP = {
    [1] = "major", [2] = "minor", [3] = "dorian", [4] = "phrygian",
    [5] = "lydian", [6] = "mixolydian", [7] = "minor_pentatonic",
    [8] = "major_pentatonic", [9] = "blues"
}

local config = {
    humanization_time = 0.015,    -- ±15ms timing variation
    humanization_velocity = 12,   -- ±12 velocity variation
    phrase_gap = 0.5,             -- Gap between call and response (QN)
    call_response_gap = 2.0,      -- Gap between phrase pairs (QN)
    default_phrase_length = 2.0,  -- Length of each phrase in QN (2 bars in 4/4)
    default_note_density = 0.6,   -- How many notes per phrase (0-1)
    min_note_duration = 0.25,     -- Minimum note length (QN)
    octave_range = {-1, 1},       -- Range for note generation
}

-- =============================
-- Utility Functions
-- =============================

local function clamp(val, min_val, max_val)
    return math.max(min_val, math.min(max_val, val))
end

-- Region name parsing
local note_names = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}

local function parse_region_name(name)
    if not name then return nil, nil, nil end

    -- Pattern: "Note[#/b][Octave] ScaleName" e.g. "C4 Major" or "Dm"
    -- Try with octave first
    local note_str, octave_str, scale_str = name:match('^%s*([A-Ga-g][#b]?)(%d+)%s+([%w_]+)')
    if note_str then
        local note_class = nil
        local note_upper = note_str:upper()
        for i, n in ipairs(note_names) do
            if n == note_upper then
                note_class = i - 1
                break
            end
        end
        -- Handle flats
        if note_str:match('b') then
            note_class = (note_class - 1) % 12
        end
        return note_class, scale_str:lower(), tonumber(octave_str)
    end

    -- Try without octave: "C major" or "Dm"
    note_str, scale_str = name:match('^%s*([A-Ga-g][#b]?)%s+([%w_]+)')
    if note_str then
        local note_class = nil
        local note_upper = note_str:upper()
        for i, n in ipairs(note_names) do
            if n == note_upper then
                note_class = i - 1
                break
            end
        end
        if note_str:match('b') then
            note_class = (note_class - 1) % 12
        end
        return note_class, scale_str:lower(), 4 -- Default octave 4
    end

    return nil, nil, nil
end

local function get_region_at_position()
    local cursor_pos = reaper.GetCursorPosition()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if isrgn and pos <= cursor_pos and cursor_pos < rgnend then
            return name
        end
    end
    return nil
end

local function note_name_to_pitch(note_name, octave)
    local note_class = 0
    for i, n in ipairs(note_names) do
        if n == note_name then
            note_class = i - 1
            break
        end
    end
    return (octave + 1) * 12 + note_class
end

local function humanize(base_time, base_velocity)
    local time_offset = (math.random() - 0.5) * 2 * config.humanization_time
    local vel_offset = (math.random() - 0.5) * 2 * config.humanization_velocity
    return base_time + time_offset, clamp(base_velocity + vel_offset, 1, 127)
end

-- Popup menu utility
local function show_popup_menu(items, default_idx)
    local menu_str = ""
    for i, item in ipairs(items) do
        if i == default_idx then
            menu_str = menu_str .. "!" .. item .. "|"
        else
            menu_str = menu_str .. item .. "|"
        end
    end
    gfx.x, gfx.y = reaper.GetMousePosition()
    local choice = gfx.showmenu(menu_str)
    return choice
end

-- Build note pool from scale
local function buildNotePool(root_pitch, scale_intervals, octave_range)
    local pool = {}
    local root_octave = math.floor(root_pitch / 12)
    local root_pc = root_pitch % 12

    for octave = root_octave + octave_range[1], root_octave + octave_range[2] do
        for _, interval in ipairs(scale_intervals) do
            local pitch = (octave * 12) + root_pc + interval
            if pitch >= 36 and pitch <= 96 then
                table.insert(pool, pitch)
            end
        end
    end

    table.sort(pool)
    return pool
end

-- Get scale degree (1-7 for diatonic scales)
local function getScaleDegree(pitch, root_pitch, scale_intervals)
    local pc = (pitch - root_pitch) % 12
    for i, interval in ipairs(scale_intervals) do
        if interval == pc then
            return i
        end
    end
    return 1 -- Default to root if not in scale
end

-- Check if pitch is the tonic
local function isTonic(pitch, root_pitch)
    return (pitch % 12) == (root_pitch % 12)
end

-- Rhythmic pattern library
local RHYTHMS = {
    simple = {
        {0.5, 0.5, 0.5, 0.5},           -- Even eighths
        {1.0, 0.5, 0.5},                -- Quarter-two eighths
        {0.5, 0.5, 1.0},                -- Two eighths-quarter
        {1.0, 1.0},                     -- Two quarters
    },
    moderate = {
        {0.25, 0.25, 0.5, 0.5, 0.5},   -- Sixteenths opening
        {0.75, 0.25, 0.5, 0.5},        -- Dotted eighth syncopation
        {0.5, 0.25, 0.25, 1.0},        -- Mixed with longer ending
        {0.33, 0.33, 0.33, 1.0},       -- Triplets then sustain
    },
    complex = {
        {0.25, 0.25, 0.25, 0.25, 0.5, 0.5}, -- Sixteenth flurry
        {0.375, 0.125, 0.5, 0.5, 0.5},     -- Syncopated pickup
        {0.5, 0.25, 0.125, 0.125, 1.0},    -- Mixed complex
        {0.33, 0.33, 0.33, 0.5, 0.5},      -- Triplets with eighths
    }
}

-- =============================
-- Call Phrase Generation
-- =============================

-- Generate a call phrase from scratch
local function generateCallPhrase(start_time, note_pool, root_pitch, scale_intervals, rhythm_pattern, contour_type)
    local phrase = {}
    local time = start_time

    -- Contour types: ascending, descending, arch, valley, wave
    local contours = {
        ascending = function(idx, count) return idx / count end,
        descending = function(idx, count) return 1 - (idx / count) end,
        arch = function(idx, count)
            local mid = count / 2
            return 1 - math.abs((idx - mid) / mid)
        end,
        valley = function(idx, count)
            local mid = count / 2
            return math.abs((idx - mid) / mid)
        end,
        wave = function(idx, count)
            return (math.sin((idx / count) * math.pi * 2) + 1) / 2
        end,
    }

    local contour_fn = contours[contour_type] or contours.ascending
    local note_count = #rhythm_pattern

    -- Generate notes following contour
    for i, duration in ipairs(rhythm_pattern) do
        -- Get target pitch based on contour
        local contour_val = contour_fn(i, note_count)
        local pool_idx = math.floor(contour_val * (#note_pool - 1)) + 1
        pool_idx = clamp(pool_idx, 1, #note_pool)

        local pitch = note_pool[pool_idx]

        -- Add some randomness (20% chance to shift by one scale step)
        if math.random() < 0.2 and #note_pool > 1 then
            local shift = math.random() < 0.5 and -1 or 1
            local new_idx = clamp(pool_idx + shift, 1, #note_pool)
            pitch = note_pool[new_idx]
        end

        -- Base velocity with contour emphasis
        local velocity = 80 + math.floor(contour_val * 25)

        table.insert(phrase, {
            start_qn = time,
            end_qn = time + duration,
            pitch = pitch,
            velocity = velocity,
            channel = 0,
        })

        time = time + duration
    end

    return phrase
end

-- Select appropriate rhythm based on complexity
local function selectRhythm(complexity)
    local pool = RHYTHMS.simple
    if complexity >= 0.7 then
        pool = RHYTHMS.complex
    elseif complexity >= 0.4 then
        pool = RHYTHMS.moderate
    end
    return pool[math.random(#pool)]
end

-- =============================
-- Response Generators
-- =============================

-- 1. MELODIC DIALOGUE - Opposite contours
local function generateDialogueResponse(call_phrase, start_time, note_pool, root_pitch, scale_intervals)
    local response = {}

    -- Determine call's contour direction
    local call_direction = call_phrase[#call_phrase].pitch - call_phrase[1].pitch

    -- Use opposite contour for response
    local contour_type = call_direction > 0 and "descending" or "ascending"

    -- Extract rhythm from call
    local rhythm = {}
    for i, note in ipairs(call_phrase) do
        table.insert(rhythm, note.end_qn - note.start_qn)
    end

    -- Generate response with opposite contour
    return generateCallPhrase(start_time, note_pool, root_pitch, scale_intervals, rhythm, contour_type)
end

-- 2. RHYTHMIC ECHO - Similar pitches, varied rhythm
local function generateRhythmicEcho(call_phrase, start_time, note_pool, root_pitch, scale_intervals, complexity)
    local response = {}

    -- Extract pitch contour from call (simplified)
    local call_pitches = {}
    for _, note in ipairs(call_phrase) do
        table.insert(call_pitches, note.pitch)
    end

    -- Generate new rhythm
    local new_rhythm = selectRhythm(math.min(complexity + 0.2, 1.0))

    -- Apply pitches to new rhythm
    local time = start_time
    for i, dur in ipairs(new_rhythm) do
        local pitch_idx = math.min(i, #call_pitches)
        local base_pitch = call_pitches[pitch_idx]

        -- Slight variation (neighbor tones)
        if math.random() < 0.3 then
            base_pitch = base_pitch + (math.random() < 0.5 and -2 or 2)
            base_pitch = clamp(base_pitch, 36, 96)
        end

        table.insert(response, {
            start_qn = time,
            end_qn = time + dur,
            pitch = base_pitch,
            velocity = 75 + math.random(15),
            channel = 0,
        })

        time = time + dur
    end

    return response
end

-- 3. HARMONIC ANSWER - Transpose by interval
local function generateHarmonicAnswer(call_phrase, start_time, interval_semitones)
    local response = {}

    -- Common musical intervals
    local intervals = {3, 4, 5, 7, -3, -4, -5}
    local chosen_interval = interval_semitones or intervals[math.random(#intervals)]

    for _, note in ipairs(call_phrase) do
        local time_offset = start_time - call_phrase[1].start_qn
        local new_pitch = note.pitch + chosen_interval
        new_pitch = clamp(new_pitch, 36, 96)

        table.insert(response, {
            start_qn = note.start_qn + time_offset,
            end_qn = note.end_qn + time_offset,
            pitch = new_pitch,
            velocity = note.velocity - 5,
            channel = 0,
        })
    end

    return response
end

-- 4. QUESTION/ANSWER - Tension then resolution
local function generateQuestionAnswer(call_phrase, start_time, note_pool, root_pitch, scale_intervals)
    local response = {}

    -- Response guides toward tonic
    local target_tonic = root_pitch

    -- Find tonic in note pool near call's range
    local call_avg = 0
    for _, note in ipairs(call_phrase) do
        call_avg = call_avg + note.pitch
    end
    call_avg = call_avg / #call_phrase

    -- Adjust target tonic octave to match range
    while target_tonic < call_avg - 12 do
        target_tonic = target_tonic + 12
    end
    while target_tonic > call_avg + 12 do
        target_tonic = target_tonic - 12
    end

    -- Create stepwise motion to tonic
    local rhythm = {0.5, 0.5, 1.0} -- Slowing down at end
    local time = start_time
    local start_pitch = call_phrase[#call_phrase].pitch -- Start from where call ended

    for i, dur in ipairs(rhythm) do
        local progress = (i - 1) / (#rhythm - 1)
        local pitch = math.floor(start_pitch + (target_tonic - start_pitch) * progress)
        pitch = clamp(pitch, 36, 96)

        table.insert(response, {
            start_qn = time,
            end_qn = time + dur,
            pitch = pitch,
            velocity = 85 - (i * 8), -- Diminuendo
            channel = 0,
        })

        time = time + dur
    end

    return response
end

-- 5. SEQUENCE - Progressive transposition
local function generateSequenceResponse(call_phrase, start_time, scale_intervals)
    local response = {}

    -- Transpose by scale degree
    local transpositions = {2, 3, 4, 5, 7}
    local shift = transpositions[math.random(#transpositions)]

    -- Reverse direction if call was ascending
    local call_direction = call_phrase[#call_phrase].pitch - call_phrase[1].pitch
    if call_direction > 0 then
        shift = -shift
    end

    local time_offset = start_time - call_phrase[1].start_qn

    for _, note in ipairs(call_phrase) do
        local new_pitch = note.pitch + shift
        new_pitch = clamp(new_pitch, 36, 96)

        table.insert(response, {
            start_qn = note.start_qn + time_offset,
            end_qn = note.end_qn + time_offset,
            pitch = new_pitch,
            velocity = note.velocity - 7,
            channel = 0,
        })
    end

    return response
end

-- 6. CLASSICAL - Antecedent/Consequent period
local function generateClassicalResponse(call_phrase, start_time, note_pool, root_pitch, scale_intervals)
    local response = {}

    -- Classical period: consequent ends on tonic
    local target_tonic = root_pitch

    -- Match call's range
    local call_start = call_phrase[1].pitch
    while target_tonic < call_start - 12 do
        target_tonic = target_tonic + 12
    end
    while target_tonic > call_start + 12 do
        target_tonic = target_tonic - 12
    end

    -- Extract rhythm from call
    local rhythm = {}
    for _, note in ipairs(call_phrase) do
        table.insert(rhythm, note.end_qn - note.start_qn)
    end

    -- Response starts similar but ends on tonic
    local time = start_time
    for i, dur in ipairs(rhythm) do
        local pitch
        if i == #rhythm then
            -- Final note resolves to tonic
            pitch = target_tonic
        else
            -- Similar contour to call
            pitch = call_phrase[i].pitch
            -- Add slight variation
            if math.random() < 0.3 then
                pitch = pitch + (math.random() < 0.5 and -2 or 2)
            end
        end

        pitch = clamp(pitch, 36, 96)

        table.insert(response, {
            start_qn = time,
            end_qn = time + dur,
            pitch = pitch,
            velocity = 80,
            channel = 0,
        })

        time = time + dur
    end

    return response
end

-- =============================
-- Main Response Generation Dispatcher
-- =============================

local function generateResponse(call_phrase, start_time, note_pool, root_pitch, scale_intervals, mode, complexity)
    local generators = {
        [GENERATION_MODES.DIALOGUE] = function()
            return generateDialogueResponse(call_phrase, start_time, note_pool, root_pitch, scale_intervals)
        end,
        [GENERATION_MODES.RHYTHMIC_ECHO] = function()
            return generateRhythmicEcho(call_phrase, start_time, note_pool, root_pitch, scale_intervals, complexity)
        end,
        [GENERATION_MODES.HARMONIC_ANSWER] = function()
            return generateHarmonicAnswer(call_phrase, start_time, nil)
        end,
        [GENERATION_MODES.QUESTION_ANSWER] = function()
            return generateQuestionAnswer(call_phrase, start_time, note_pool, root_pitch, scale_intervals)
        end,
        [GENERATION_MODES.SEQUENCE] = function()
            return generateSequenceResponse(call_phrase, start_time, scale_intervals)
        end,
        [GENERATION_MODES.CLASSICAL] = function()
            return generateClassicalResponse(call_phrase, start_time, note_pool, root_pitch, scale_intervals)
        end,
    }

    local generator = generators[mode]
    if not generator then
        log('Invalid generation mode: ', mode)
        return {}
    end

    return generator()
end

-- =============================
-- MIDI Output
-- =============================

local function insertNote(take, note)
    local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.start_qn)
    local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.end_qn)

    -- Apply humanization
    local human_qn, human_vel = humanize(note.start_qn, note.velocity)
    start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, human_qn)

    reaper.MIDI_InsertNote(
        take,
        false,  -- selected
        false,  -- muted
        start_ppq,
        end_ppq,
        note.channel or 0,
        note.pitch,
        math.floor(human_vel),
        true    -- noSort
    )
end

-- =============================
-- User Interface
-- =============================

local function getUserInput()
    -- Default values from ExtState
    local defaults = {
        gen_mode = tonumber(get_ext('gen_mode', 1)),
        root_note = tonumber(get_ext('root_note', 60)),
        scale_type = tonumber(get_ext('scale_type', 1)),
        num_pairs = tonumber(get_ext('num_pairs', 4)),
        complexity = tonumber(get_ext('complexity', 0.5)),
        auto_detect = get_ext('auto_detect', '1') == '1',
    }

    -- Step 0: Auto vs Manual mode
    local mode_items = {"Auto (use last settings)", "Manual (configure all settings)"}
    local mode_choice = show_popup_menu(mode_items, 1)
    if mode_choice == 0 then return nil end

    local use_auto_mode = (mode_choice == 1)

    if use_auto_mode then
        log('Auto mode - using saved settings')
        local scale_name = SCALE_MAP[defaults.scale_type]
        return {
            mode = defaults.gen_mode,
            root_pitch = defaults.root_note,
            scale_intervals = SCALES[scale_name],
            scale_name = SCALE_NAMES[defaults.scale_type],
            num_pairs = defaults.num_pairs,
            complexity = defaults.complexity,
        }
    end

    -- MANUAL MODE
    -- Try auto-detection from region
    local auto_detected_note_class = nil
    local auto_detected_scale = nil
    local auto_detected_octave = nil
    local region_name = nil

    if defaults.auto_detect then
        region_name = get_region_at_position()
        if region_name then
            auto_detected_note_class, auto_detected_scale, auto_detected_octave = parse_region_name(region_name)
            if auto_detected_note_class then
                log('Auto-detected from region "', region_name, '": note class ', auto_detected_note_class, ', scale ', auto_detected_scale or 'none')
            end
        end
    end

    -- Step 1a: Auto-detect toggle
    local auto_detect_items = {"Auto-detect from region (ON)", "Manual selection (OFF)"}
    local default_auto_detect_idx = defaults.auto_detect and 1 or 2
    local force_manual = false

    if auto_detected_note_class and auto_detected_scale then
        table.insert(auto_detect_items, 2, "Override auto-detected values")
        if not defaults.auto_detect then
            default_auto_detect_idx = 3
        end
    end

    local auto_detect_choice = show_popup_menu(auto_detect_items, default_auto_detect_idx)
    if auto_detect_choice == 0 then return nil end

    local auto_detect_enabled
    if auto_detected_note_class and auto_detected_scale then
        if auto_detect_choice == 1 then
            auto_detect_enabled = true
            force_manual = false
        elseif auto_detect_choice == 2 then
            auto_detect_enabled = true
            force_manual = true
        else
            auto_detect_enabled = false
            force_manual = true
        end
    else
        auto_detect_enabled = (auto_detect_choice == 1)
        force_manual = not auto_detect_enabled
    end

    set_ext('auto_detect', auto_detect_enabled and '1' or '0')

    -- Step 1b: Root note and scale selection
    local root_note, scale_name

    if auto_detect_enabled and auto_detected_note_class and auto_detected_scale and not force_manual then
        -- Use auto-detected values
        local target_octave = auto_detected_octave or 4
        root_note = (target_octave + 1) * 12 + auto_detected_note_class
        root_note = clamp(root_note, 0, 127)
        scale_name = auto_detected_scale

        local root_name = note_names[(root_note % 12) + 1]
        local octave = math.floor(root_note / 12) - 1
        reaper.MB(
            string.format('Region detected: "%s"\\n\\nUsing: %s%d %s',
                region_name, root_name, octave, scale_name),
            'Auto-detect Active',
            0
        )
    else
        -- Manual selection
        local default_root_note = defaults.root_note
        if auto_detected_note_class and auto_detected_octave then
            local target_octave = auto_detected_octave or 4
            default_root_note = (target_octave + 1) * 12 + auto_detected_note_class
            default_root_note = clamp(default_root_note, 0, 127)
        end

        local default_note_name = note_names[(default_root_note % 12) + 1]
        local default_octave = math.floor(default_root_note / 12) - 1

        -- Note selection
        local default_note_idx = 1
        for i, name in ipairs(note_names) do
            if name == default_note_name then
                default_note_idx = i
                break
            end
        end

        local note_choice = show_popup_menu(note_names, default_note_idx)
        if note_choice == 0 then return nil end

        -- Octave selection
        local octaves = {"0","1","2","3","4","5","6","7","8","9"}
        local default_octave_idx = default_octave + 1
        local octave_choice = show_popup_menu(octaves, default_octave_idx)
        if octave_choice == 0 then return nil end

        -- Scale selection
        local scale_menu_items = {}
        for i, name in ipairs(SCALE_NAMES) do
            table.insert(scale_menu_items, name)
        end

        local default_scale_idx = defaults.scale_type
        if auto_detected_scale then
            for i, name in ipairs(SCALE_NAMES) do
                if SCALE_MAP[i]:lower() == auto_detected_scale:lower() then
                    default_scale_idx = i
                    break
                end
            end
        end

        local scale_choice = show_popup_menu(scale_menu_items, default_scale_idx)
        if scale_choice == 0 then return nil end

        local input_note_name = note_names[note_choice]
        local input_octave = tonumber(octaves[octave_choice])
        root_note = note_name_to_pitch(input_note_name, input_octave)
        scale_name = SCALE_MAP[scale_choice]

        -- Save for next time
        set_ext('root_note', root_note)
        set_ext('scale_type', scale_choice)
    end

    -- Step 2: Generation mode selection
    local gen_mode_items = {}
    for i = 1, 6 do
        table.insert(gen_mode_items, MODE_NAMES[i])
    end

    local gen_mode_choice = show_popup_menu(gen_mode_items, defaults.gen_mode)
    if gen_mode_choice == 0 then return nil end

    -- Step 3: Parameters dialog
    local captions = 'Number of Phrase Pairs (2-8),Complexity (0.0-1.0)'
    local defaults_csv = string.format('%d,%.2f', defaults.num_pairs, defaults.complexity)

    local ok, ret = reaper.GetUserInputs('jtp gen: Call & Response - Parameters', 2, captions, defaults_csv)
    if not ok then return nil end

    local pairs_str, complexity_str = ret:match('([^,]+),([^,]+)')
    local num_pairs = tonumber(pairs_str) or 4
    local complexity = tonumber(complexity_str) or 0.5

    num_pairs = clamp(num_pairs, 2, 8)
    complexity = clamp(complexity, 0, 1)

    -- Save all settings
    set_ext('gen_mode', gen_mode_choice)
    set_ext('num_pairs', num_pairs)
    set_ext('complexity', complexity)

    -- Find scale intervals from scale name
    local scale_intervals = SCALES[scale_name]
    if not scale_intervals then
        -- Try to find by matching
        for k, v in pairs(SCALES) do
            if k:lower() == scale_name:lower() then
                scale_intervals = v
                break
            end
        end
    end

    if not scale_intervals then
        scale_intervals = SCALES.major -- Fallback
    end

    local scale_display_name = SCALE_NAMES[1]
    for i, name in ipairs(SCALE_NAMES) do
        if SCALE_MAP[i] == scale_name then
            scale_display_name = name
            break
        end
    end

    return {
        mode = gen_mode_choice,
        root_pitch = root_note,
        scale_intervals = scale_intervals,
        scale_name = scale_display_name,
        num_pairs = num_pairs,
        complexity = complexity,
    }
end

-- =============================
-- Main Logic
-- =============================

local function main()
    -- Get user parameters
    local params = getUserInput()
    if not params then return end

    log('Starting Call & Response generation...')
    log('Mode: ', MODE_NAMES[params.mode])
    log('Root: ', params.root_pitch, ' Scale: ', params.scale_name)
    log('Pairs: ', params.num_pairs, ' Complexity: ', params.complexity)

    -- Get or create MIDI item
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track.", "No Track Selected", 0)
        return
    end

    -- Build note pool from scale
    local note_pool = buildNotePool(params.root_pitch, params.scale_intervals, config.octave_range)
    log('Note pool: ', #note_pool, ' notes')

    reaper.Undo_BeginBlock()

    -- Create new MIDI item at edit cursor
    local cursor_pos = reaper.GetCursorPosition()
    local total_length = params.num_pairs * (config.default_phrase_length * 2 + config.phrase_gap + config.call_response_gap)
    local item = reaper.CreateNewMIDIItemInProj(track, cursor_pos, cursor_pos + total_length)
    local take = reaper.GetActiveTake(item)

    if not take then
        reaper.ShowMessageBox("Failed to create MIDI item.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: Call & Response Generator (failed)", -1)
        return
    end

    -- Generate phrase pairs
    local time = 0.0
    local all_notes = {}
    local contour_types = {"ascending", "descending", "arch", "valley", "wave"}

    for pair = 1, params.num_pairs do
        -- Seed randomness based on pair number for variety
        math.randomseed(os.time() + pair * 1000)
        for _ = 1, 3 do math.random() end

        -- Select rhythm for this phrase
        local rhythm = selectRhythm(params.complexity)

        -- Select contour (vary each phrase)
        local contour = contour_types[((pair - 1) % #contour_types) + 1]

        -- Generate call phrase
        log('Generating pair ', pair, ' - Call at time ', time)
        local call_phrase = generateCallPhrase(time, note_pool, params.root_pitch, params.scale_intervals, rhythm, contour)

        -- Add call notes to collection
        for _, note in ipairs(call_phrase) do
            table.insert(all_notes, note)
        end

        -- Calculate call end time
        local call_end = call_phrase[#call_phrase].end_qn

        -- Generate response phrase
        local response_start = call_end + config.phrase_gap
        log('Generating pair ', pair, ' - Response at time ', response_start)

        local response_phrase = generateResponse(
            call_phrase,
            response_start,
            note_pool,
            params.root_pitch,
            params.scale_intervals,
            params.mode,
            params.complexity
        )

        -- Add response notes to collection
        for _, note in ipairs(response_phrase) do
            table.insert(all_notes, note)
        end

        -- Calculate next call start time
        local response_end = response_phrase[#response_phrase].end_qn
        time = response_end + config.call_response_gap
    end

    -- Insert all notes into MIDI item
    log('Inserting ', #all_notes, ' total notes')
    for _, note in ipairs(all_notes) do
        insertNote(take, note)
    end

    -- Sort MIDI events
    reaper.MIDI_Sort(take)

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("jtp gen: Call & Response Generator", -1)

    log('Complete! Generated ', params.num_pairs, ' call/response pairs')
    reaper.ShowMessageBox(
        string.format("Generated %d call/response pairs in %s!\nScale: %s",
            params.num_pairs,
            MODE_NAMES[params.mode]:match("^%d+%. (.+)"),
            params.scale_name),
        "Success",
        0
    )
end

main()
