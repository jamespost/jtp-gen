-- @description jtp gen_GenMusic_DWUMMER Drum Generator
-- @author James
-- @version 3.0
-- @about
--   # DWUMMER Drum Generator v3.0 - Musical Intelligence & Expressive Performance
--   Complete implementation of Phases 0-4 of the DWUMMER development plan.
--
--   Phase 0: Initialization, deterministic seed management, time conversion, drum map lookup
--   Phase 1: I/O Handler MVP - MIDI item creation and note insertion
--   Phase 2: Core Rhythm Engine - Euclidean rhythm generation for multiple voices
--   Phase 3: Dynamics and Structure - Velocity humanization, swing, ghost notes, fills
--
--   **Phase 4: Musical Intelligence & Expressive Performance** (NEW)
--   - 4.1: Motif-Based Groove Development - Recurring rhythmic ideas with variations
--   - 4.2: Dynamic Phrasing & Section Awareness - Auto-adapting groove based on song structure
--   - 4.3: Call-and-Response & Interaction - Voice interplay and rhythmic conversation
--   - 4.4: Expressive Ghost Note Placement - Context-aware embellishments
--   - 4.5: Intelligent Fill Placement & Variation - Musically appropriate fills with variety
--   - 4.6: Adaptive Dynamics & Microtiming - Natural push/pull and dynamic swells
--   - 4.7: Groove Surprise & "Mistake" Engine - Human unpredictability

if not reaper then return end

-- Debug flag: set to true to enable console output
local DEBUG = false

-- Phase 0.1: Initialization
if DEBUG then reaper.ShowConsoleMsg("DWUMMER Initialized\n") end

-- =============================
-- Parameter Persistence
-- =============================
local EXT_SECTION = 'jtp_gen_dwummer'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- Load saved pattern length (defaults to 4 bars)
local saved_pattern_length = tonumber(get_ext('pattern_length_bars', 4))

-- Phase 0.2: Deterministic Seed Management
local function set_seed(seed)
    -- Lua 5.3+ math.randomseed is deterministic
    math.randomseed(seed)
end

-- Phase 0.3: TimeMap_QNToPPQ utility
local function TimeMap_QNToPPQ(qn)
    -- Converts quarter notes to PPQ using REAPER API
    -- Requires active take for accurate conversion
    -- For now, use 960 PPQ per quarter note (default MIDI resolution)
    return math.floor(qn * 960)
end

-- Phase 0.4: Abstract Drum Map (GM Standard)
local DrumMap = {
    KICK = 36,
    SNARE = 38,
    SNARE_ACCENT = 40,
    HIHAT_CLOSED = 42,
    HIHAT_OPEN = 46,
    TOM_LOW = 41,
    TOM_MID = 45,
    TOM_HIGH = 50,
    RIDE = 51,
    CRASH = 49,
    SIDE_STICK = 37,
}

-- Phase 2.1: Euclidean Rhythm Algorithm
-- Generates a Euclidean rhythm pattern
-- N = Total steps, K = Pulses (hits), R = Rotation offset
-- Returns an array where 1 = hit, 0 = rest
local function generate_euclidean_rhythm(N, K, R)
    if K == 0 or N == 0 or K > N then
        local pattern = {}
        for i = 1, N do
            pattern[i] = 0
        end
        return pattern
    end

    -- Special case: all hits
    if K == N then
        local pattern = {}
        for i = 1, N do
            pattern[i] = 1
        end
        return pattern
    end

    -- Bjorklund's algorithm implementation
    local pattern = {}
    local counts = {}
    local remainders = {}

    local divisor = N - K
    remainders[1] = K

    local level = 1

    repeat
        counts[level] = math.floor(divisor / remainders[level])
        remainders[level + 1] = divisor % remainders[level]
        divisor = remainders[level]
        level = level + 1
    until remainders[level] <= 1

    counts[level] = divisor

    -- Build the pattern
    local function build(level_idx)
        if level_idx == -1 then
            return {0}
        elseif level_idx == -2 then
            return {1}
        else
            local sequence = {}
            local count = counts[level_idx] or 0
            for i = 1, count do
                for _, val in ipairs(build(level_idx - 1)) do
                    table.insert(sequence, val)
                end
            end
            if level_idx ~= 1 then
                for _, val in ipairs(build(level_idx - 2)) do
                    table.insert(sequence, val)
                end
            end
            return sequence
        end
    end

    pattern = build(level)

    -- Apply rotation (R)
    if R ~= 0 then
        local rotated = {}
        local rotation = R % N
        for i = 1, N do
            rotated[i] = pattern[((i - 1 + rotation) % N) + 1]
        end
        pattern = rotated
    end

    return pattern
end

local VoiceDefaults = {
    KICK = {N = 16, K = 4, R = 0},
    SNARE = {N = 16, K = 4, R = 8},
    HIHAT = {N = 16, K = 8, R = 0},
}

-- =============================
-- Phase 4.1: Motif-Based Groove Development
-- =============================

-- Motif storage and recognition system
local MotifEngine = {}
MotifEngine.__index = MotifEngine

function MotifEngine.new()
    local self = setmetatable({}, MotifEngine)
    self.motifs = {}  -- Stored motifs (rhythmic ideas)
    self.current_motif_id = 1
    return self
end

-- Create a motif from a pattern segment (2-4 steps)
function MotifEngine:create_motif(pattern, start_step, length)
    local motif = {}
    for i = 0, length - 1 do
        local step = ((start_step + i - 1) % #pattern) + 1
        motif[i + 1] = pattern[step]
    end
    return motif
end

-- Store a motif for later recall
function MotifEngine:store_motif(motif, voice_name)
    local id = self.current_motif_id
    self.motifs[id] = {
        pattern = motif,
        voice = voice_name,
        recall_count = 0
    }
    self.current_motif_id = self.current_motif_id + 1
    return id
end

-- Generate a variation of a motif
function MotifEngine:vary_motif(motif, variation_type)
    local varied = {}

    if variation_type == "invert" then
        -- Invert hits/rests
        for i, v in ipairs(motif) do
            varied[i] = 1 - v
        end
    elseif variation_type == "shift" then
        -- Circular shift
        for i = 1, #motif do
            varied[i] = motif[((i) % #motif) + 1]
        end
    elseif variation_type == "sparse" then
        -- Remove some hits (50% chance)
        for i, v in ipairs(motif) do
            varied[i] = (v == 1 and math.random() > 0.5) and 1 or 0
        end
    elseif variation_type == "dense" then
        -- Add hits where there were rests (30% chance)
        for i, v in ipairs(motif) do
            varied[i] = (v == 0 and math.random() < 0.3) and 1 or v
        end
    else
        -- No variation
        varied = motif
    end

    return varied
end

-- Apply a motif or its variation to a pattern at a specific position
function MotifEngine:apply_motif_to_pattern(pattern, motif, start_step, variation_type)
    local varied = variation_type and self:vary_motif(motif, variation_type) or motif
    local modified = {}

    -- Copy original pattern
    for i, v in ipairs(pattern) do
        modified[i] = v
    end

    -- Apply motif
    for i, v in ipairs(varied) do
        local step = ((start_step + i - 2) % #pattern) + 1
        if step >= 1 and step <= #pattern then
            modified[step] = v
        end
    end

    return modified
end

-- Decide whether to recall a motif based on bar position and randomness
function MotifEngine:should_recall_motif(bar, total_bars)
    -- More likely to recall in later bars (50% in bar 2, 70% in bar 3+)
    if bar == 0 then return false end
    if bar == 1 then return math.random() < 0.5 end
    return math.random() < 0.7
end

-- =============================
-- Phase 4.2: Dynamic Phrasing & Section Awareness
-- =============================

local SectionTypes = {
    INTRO = "intro",
    VERSE = "verse",
    CHORUS = "chorus",
    BRIDGE = "bridge",
    OUTRO = "outro"
}

-- Section characteristics define how grooves should sound
local SectionCharacteristics = {
    intro = {
        density_multiplier = 0.6,  -- Sparse, building
        dynamics_offset = -15,      -- Quieter
        fill_probability = 0.2,     -- Rare fills
        groove_complexity = 0.5     -- Simple patterns
    },
    verse = {
        density_multiplier = 0.75,  -- Moderate groove
        dynamics_offset = -5,       -- Slightly quieter
        fill_probability = 0.3,     -- Some fills
        groove_complexity = 0.7     -- Clear, supportive
    },
    chorus = {
        density_multiplier = 1.2,   -- Full, driving
        dynamics_offset = 5,        -- Louder
        fill_probability = 0.5,     -- Regular fills
        groove_complexity = 0.9     -- Complex, energetic
    },
    bridge = {
        density_multiplier = 0.85,  -- Different energy
        dynamics_offset = 0,        -- Normal
        fill_probability = 0.4,     -- Transitional fills
        groove_complexity = 0.8     -- Varied patterns
    },
    outro = {
        density_multiplier = 0.5,   -- Sparse, fading
        dynamics_offset = -20,      -- Quieter
        fill_probability = 0.1,     -- Minimal fills
        groove_complexity = 0.4     -- Simple fadeout
    }
}

-- Determine section type based on bar position
function get_section_for_bar(bar, total_bars, section_mode)
    if section_mode == "auto" then
        -- Automatic section assignment based on standard song structure
        local bars_per_section = math.max(4, math.floor(total_bars / 3))

        if bar < 2 then
            return SectionTypes.INTRO
        elseif bar < bars_per_section then
            return SectionTypes.VERSE
        elseif bar < bars_per_section * 2 then
            return SectionTypes.CHORUS
        elseif bar < total_bars - 2 then
            return SectionTypes.BRIDGE
        else
            return SectionTypes.OUTRO
        end
    else
        -- Use specified section type for all bars
        return section_mode or SectionTypes.VERSE
    end
end

-- Modify voice parameters based on section
function apply_section_modifiers(voice_config, section_type, characteristics)
    local char = characteristics or SectionCharacteristics[section_type] or SectionCharacteristics.verse

    local modified = {
        N = voice_config.N,
        K = math.floor(voice_config.K * char.density_multiplier + 0.5),
        R = voice_config.R
    }

    -- Ensure K doesn't exceed N
    modified.K = math.min(modified.K, modified.N)
    modified.K = math.max(1, modified.K)  -- At least 1 hit

    return modified, char
end

-- =============================
-- Phase 4.3: Call-and-Response & Interaction
-- =============================

-- Create complementary pattern (inverse density)
function create_call_response_pattern(pattern)
    local response = {}
    for i = 1, #pattern do
        -- Invert with some randomness (70% invert, 30% keep)
        if math.random() < 0.7 then
            response[i] = 1 - pattern[i]
        else
            response[i] = pattern[i]
        end
    end
    return response
end

-- Check if voices should interact on this bar
function should_voices_interact(bar, total_bars)
    -- Increase interaction probability toward phrase endings
    local phrase_position = (bar % 4) / 4
    local base_probability = 0.3
    local phrase_bonus = phrase_position * 0.3
    return math.random() < (base_probability + phrase_bonus)
end

-- Create rhythmic conversation between snare and hi-hat
function create_snare_hat_interplay(snare_pattern, hat_pattern)
    local new_snare = {}
    local new_hat = {}

    for i = 1, #snare_pattern do
        local snare = snare_pattern[i]
        local hat = hat_pattern[i]

        -- Where snare hits, reduce hat (70% chance)
        if snare == 1 and math.random() < 0.7 then
            new_snare[i] = 1
            new_hat[i] = 0
        -- Where hat hits strongly, occasionally add snare ghost (20% chance)
        elseif hat == 1 and snare == 0 and math.random() < 0.2 then
            new_snare[i] = 1  -- Will be ghost note
            new_hat[i] = 1
        else
            new_snare[i] = snare
            new_hat[i] = hat
        end
    end

    return new_snare, new_hat
end

-- =============================
-- Phase 4.6: Adaptive Dynamics & Microtiming
-- =============================

-- Calculate dynamic intensity for a bar based on section and position
function calculate_dynamic_intensity(bar, total_bars, section_char, step, N)
    local intensity = 0.5  -- Base intensity

    -- Section-based dynamics
    if section_char then
        local dynamics_factor = section_char.dynamics_offset / 30  -- Normalize -20 to +5 range
        intensity = intensity + dynamics_factor
    end

    -- Build intensity through bars (crescendo in phrases)
    local bar_in_phrase = bar % 4
    if bar_in_phrase == 0 then
        intensity = intensity - 0.1  -- Start phrase softer
    elseif bar_in_phrase == 3 then
        intensity = intensity + 0.15  -- Build to phrase end
    end

    -- Step-based dynamics (natural accents and flow)
    local step_in_beat = (step - 1) % 4
    if step_in_beat == 0 then
        intensity = intensity + 0.1  -- Downbeats stronger
    elseif step_in_beat == 2 then
        intensity = intensity + 0.05  -- Backbeats moderate
    end

    return math.max(0, math.min(1, intensity))
end

-- Apply adaptive velocity based on multiple factors
function apply_adaptive_velocity(base_velocity, intensity, step, N, bar, section_char)
    -- Convert intensity to velocity adjustment (-20 to +20)
    local intensity_adjustment = (intensity - 0.5) * 40

    -- Add natural swell within bar (push/pull)
    local bar_position = step / N
    local swell = math.sin(bar_position * math.pi) * 8  -- Gentle swell peak at mid-bar

    -- Combine factors
    local adjusted = base_velocity + intensity_adjustment + swell

    -- Add micro-variations (smaller than jitter, more organic)
    adjusted = adjusted + math.random(-3, 3)

    return math.max(1, math.min(127, math.floor(adjusted)))
end

-- Apply microtiming (subtle push/pull timing adjustments)
function apply_microtiming(ppq_position, step, N, bar, intensity, voice_name)
    local timing_offset = 0

    -- Rushing/dragging based on intensity and groove feel
    if intensity > 0.7 then
        -- High energy: slight rushing (forward momentum)
        timing_offset = math.random(-8, 2)
    elseif intensity < 0.3 then
        -- Low energy: slight dragging (laid back)
        timing_offset = math.random(-2, 8)
    else
        -- Normal: subtle variations
        timing_offset = math.random(-5, 5)
    end

    -- Hi-hat can be slightly looser (more human variation)
    if voice_name == "HIHAT" then
        timing_offset = timing_offset + math.random(-3, 3)
    end

    -- Kick and snare tighter (backbone of groove)
    if voice_name == "KICK" or voice_name == "SNARE" then
        timing_offset = timing_offset * 0.6
    end

    return math.floor(ppq_position + timing_offset)
end

-- =============================
-- Phase 4.7: Groove Surprise & "Mistake" Engine
-- =============================

-- Determine if a "mistake" or surprise should occur
function should_add_surprise(bar, step, N, total_bars, voice_name)
    -- Very low base probability (5% per note)
    local base_prob = 0.05

    -- Slightly higher chance in middle sections (not intro/outro)
    if bar > 1 and bar < total_bars - 2 then
        base_prob = base_prob + 0.03
    end

    -- Lower chance on downbeats (keep strong beats solid)
    if step == 1 or step == 5 or step == 9 or step == 13 then
        base_prob = base_prob * 0.3
    end

    return math.random() < base_prob
end

-- Apply a musical "surprise" or subtle mistake
function apply_groove_surprise(take, ppq_position, ppq_per_step, voice_pitch, voice_name, base_velocity, note_length)
    local surprise_type = math.random(1, 5)

    if surprise_type == 1 then
        -- Dropped beat (skip this note)
        return true  -- Signal to skip note insertion

    elseif surprise_type == 2 then
        -- Displaced accent (hit slightly off-grid)
        local displacement = math.random(-20, 30)
        reaper.MIDI_InsertNote(
            take, false, false,
            math.floor(ppq_position + displacement),
            math.floor(ppq_position + displacement + note_length),
            0,
            voice_pitch,
            math.min(127, base_velocity + 10),  -- Slightly louder
            true
        )
        return true  -- Signal to skip normal note

    elseif surprise_type == 3 and voice_name == "SNARE" then
        -- Extra ghost note before main hit
        reaper.MIDI_InsertNote(
            take, false, false,
            math.floor(ppq_position - ppq_per_step * 0.25),
            math.floor(ppq_position - ppq_per_step * 0.25 + note_length * 0.5),
            0,
            DrumMap.SIDE_STICK,
            math.random(45, 60),
            true
        )
        return false  -- Continue with normal note

    elseif surprise_type == 4 and voice_name == "HIHAT" then
        -- Open hi-hat instead of closed (accent variation)
        reaper.MIDI_InsertNote(
            take, false, false,
            math.floor(ppq_position),
            math.floor(ppq_position + note_length * 2),
            0,
            DrumMap.HIHAT_OPEN,
            math.min(127, base_velocity + 5),
            true
        )
        return true  -- Skip normal closed hat

    elseif surprise_type == 5 then
        -- Double hit (flam-like)
        reaper.MIDI_InsertNote(
            take, false, false,
            math.floor(ppq_position - 15),
            math.floor(ppq_position - 15 + note_length),
            0,
            voice_pitch,
            math.max(1, base_velocity - 20),  -- Quieter grace note
            true
        )
        return false  -- Continue with main note
    end

    return false
end

-- Phase 3: Dynamics and Structure Helpers
-- Velocity accent map for 16-step grid (strong beats: 1, 5, 9, 13)
local function get_accent_velocity(base, step, N)
    local accents = {[1]=true, [5]=true, [9]=true, [13]=true}
    if accents[step] then return base + 15 end
    return base
end

-- Velocity jitter (humanization)
local function velocity_jitter(base)
    return base + math.random(-10, 10)
end

-- Q-Swing logic for hi-hat (delay every 2nd note)
local function get_swing_ppq_offset(step, swing_percent, ppq_per_step)
    if ((step-1) % 2 == 1) then
        local swing = (swing_percent or 60) / 100
        return math.floor(ppq_per_step * swing * 0.5)
    end
    return 0
end

-- =============================
-- Phase 4.4: Expressive Ghost Note Placement (Contextual)
-- =============================

-- Determine if a ghost note should be placed based on musical context
function should_place_ghost_note(step, N, bar, total_bars, next_is_accent, groove_density)
    -- Context factors:
    local is_phrase_ending = (step > N - 4)  -- Last 4 steps of bar
    local is_bar_ending = (bar == total_bars - 1) and is_phrase_ending
    local proximity_to_accent = next_is_accent and (step < N)

    -- Base probability
    local probability = 0.15

    -- Increase near phrase endings (builds tension)
    if is_phrase_ending then
        probability = probability + 0.25
    end

    -- Increase before accents (anticipation)
    if proximity_to_accent then
        probability = probability + 0.20
    end

    -- Increase in sparser grooves (fill space)
    if groove_density < 0.5 then
        probability = probability + 0.15
    end

    -- Decrease at bar endings (clarity)
    if is_bar_ending then
        probability = probability - 0.15
    end

    return math.random() < probability
end

-- Insert contextual ghost note with musical placement
function insert_contextual_ghost_snare(take, step, N, bar, total_bars, ppq_per_step, base_ppq, next_is_accent, groove_density)
    if should_place_ghost_note(step, N, bar, total_bars, next_is_accent, groove_density) then
        local ghost_pitch = DrumMap.SIDE_STICK

        -- Vary velocity based on context
        local base_velocity = 55
        if next_is_accent then
            base_velocity = 65  -- Louder before accents
        end

        local ghost_velocity = base_velocity + math.random(-10, 10)

        -- Placement: before or after main note based on context
        local offset_multiplier = next_is_accent and 0.4 or 0.6
        local ghost_ppq = base_ppq + math.floor(ppq_per_step * offset_multiplier)

        reaper.MIDI_InsertNote(
            take, false, false,
            ghost_ppq,
            ghost_ppq + TimeMap_QNToPPQ(0.08),
            0,
            ghost_pitch,
            ghost_velocity,
            true
        )
    end
end

-- =============================
-- Phase 4.5: Intelligent Fill Placement & Variation
-- =============================

-- Fill pattern library with different complexities
local FillPatterns = {
    simple = {
        {pitch=DrumMap.SNARE, velocity=110, position=0.75},
        {pitch=DrumMap.SNARE, velocity=120, position=0.875},
        {pitch=DrumMap.CRASH, velocity=127, position=1.0},
    },
    moderate = {
        {pitch=DrumMap.TOM_HIGH, velocity=105, position=0.5},
        {pitch=DrumMap.TOM_MID, velocity=110, position=0.625},
        {pitch=DrumMap.SNARE, velocity=115, position=0.75},
        {pitch=DrumMap.TOM_LOW, velocity=110, position=0.875},
        {pitch=DrumMap.CRASH, velocity=127, position=1.0},
    },
    complex = {
        {pitch=DrumMap.TOM_HIGH, velocity=100, position=0.375},
        {pitch=DrumMap.TOM_HIGH, velocity=105, position=0.5},
        {pitch=DrumMap.TOM_MID, velocity=108, position=0.625},
        {pitch=DrumMap.SNARE, velocity=112, position=0.6875},
        {pitch=DrumMap.TOM_LOW, velocity=110, position=0.75},
        {pitch=DrumMap.TOM_LOW, velocity=115, position=0.8125},
        {pitch=DrumMap.SNARE, velocity=120, position=0.875},
        {pitch=DrumMap.SNARE, velocity=125, position=0.9375},
        {pitch=DrumMap.CRASH, velocity=127, position=1.0},
    },
    rolls = {
        {pitch=DrumMap.SNARE, velocity=90, position=0.625},
        {pitch=DrumMap.SNARE, velocity=95, position=0.6875},
        {pitch=DrumMap.SNARE, velocity=100, position=0.75},
        {pitch=DrumMap.SNARE, velocity=105, position=0.8125},
        {pitch=DrumMap.SNARE, velocity=110, position=0.875},
        {pitch=DrumMap.SNARE, velocity=118, position=0.9375},
        {pitch=DrumMap.CRASH, velocity=127, position=1.0},
    }
}

-- Calculate musical tension based on groove and section
function calculate_musical_tension(bar, total_bars, section_char, previous_density)
    local tension = 0.5  -- Base tension

    -- Increase toward phrase endings (every 4 bars)
    local bars_in_phrase = bar % 4
    if bars_in_phrase == 3 then
        tension = tension + 0.3  -- High tension at phrase end
    elseif bars_in_phrase == 2 then
        tension = tension + 0.15  -- Building tension
    end

    -- Section-based tension
    if section_char then
        tension = tension + (section_char.groove_complexity - 0.5) * 0.3
    end

    -- Density change creates tension
    if previous_density then
        local density_change = math.abs(previous_density - 0.5)
        tension = tension + density_change * 0.2
    end

    return math.max(0, math.min(1, tension))
end

-- Choose fill type based on tension and previous patterns
function choose_fill_type(tension, bar, previous_fill_type)
    -- Avoid repeating the same fill type
    local available_types = {"simple", "moderate", "complex", "rolls"}

    if previous_fill_type then
        for i, t in ipairs(available_types) do
            if t == previous_fill_type then
                table.remove(available_types, i)
                break
            end
        end
    end

    -- Choose based on tension
    if tension < 0.3 then
        return "simple"
    elseif tension < 0.6 then
        return available_types[math.random(1, 2)] or "moderate"
    elseif tension < 0.85 then
        return "moderate"
    else
        return math.random() < 0.5 and "complex" or "rolls"
    end
end

-- Intelligent fill insertion with variation
function insert_intelligent_fill(take, bar, total_bars, ppq_per_bar, base_ppq, section_char, previous_density, previous_fill_type)
    -- Calculate if we should place a fill
    local tension = calculate_musical_tension(bar, total_bars, section_char, previous_density)
    local fill_probability = section_char and section_char.fill_probability or 0.4

    -- Increase probability at phrase endings
    if (bar % 4) == 3 then
        fill_probability = fill_probability + 0.3
    end

    if math.random() > fill_probability then
        return nil  -- No fill
    end

    -- Choose fill type
    local fill_type = choose_fill_type(tension, bar, previous_fill_type)
    local fill_pattern = FillPatterns[fill_type]

    if not fill_pattern then return nil end

    -- Insert fill notes with dynamics based on tension
    for _, note in ipairs(fill_pattern) do
        local ppq = base_ppq + math.floor(ppq_per_bar * note.position)
        local velocity = note.velocity + math.floor(tension * 10) - 5
        velocity = velocity_jitter(velocity)

        reaper.MIDI_InsertNote(
            take, false, false,
            ppq,
            ppq + TimeMap_QNToPPQ(0.12),
            0,
            note.pitch,
            math.max(1, math.min(127, velocity)),
            true
        )
    end

    return fill_type  -- Return for tracking
end

-- Phase 1 + Phase 2.3: Core Rhythm Engine with I/O Handler
-- params: table containing seed, pattern_length_bars, and voice configurations
function generate_dwummer_pattern(params)

    -- Task 1.1: Transactional Safety
    reaper.Undo_BeginBlock()

    -- Get the first selected track
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
           reaper.ShowMessageBox("Please select a track first.", "Error", 0)
           reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
           return
    end

    -- Set the seed for reproducible results
    set_seed(params.seed or 12345)

    -- Task 1.2: Item Creation
    local start_time = reaper.GetCursorPosition()
    local pattern_length_bars = params.pattern_length_bars or 4
    local qn_per_bar = 4
    local total_qn = pattern_length_bars * qn_per_bar
    local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
    local end_qn = start_qn + total_qn
    local end_time = reaper.TimeMap2_QNToTime(0, end_qn)
    local item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
    if not item then
           reaper.ShowMessageBox("Failed to create MIDI item.", "Error", 0)
           reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
           return
    end
    local take = reaper.GetActiveTake(item)
    if not take then
           reaper.ShowMessageBox("Failed to get MIDI take.", "Error", 0)
           reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
           return
    end

    -- Phase 3: Swing and fill parameters
    local swing_percent = params.swing_percent or 60
    local ghost_chance = params.ghost_chance or 0.5

    local note_length = TimeMap_QNToPPQ(0.1)
    local voices = {
        {name = "KICK", pitch = DrumMap.KICK, velocity = 100, config = params.kick or VoiceDefaults.KICK},
        {name = "SNARE", pitch = DrumMap.SNARE, velocity = 95, config = params.snare or VoiceDefaults.SNARE},
        {name = "HIHAT", pitch = DrumMap.HIHAT_CLOSED, velocity = 80, config = params.hihat or VoiceDefaults.HIHAT},
    }

    local ppq_per_bar = TimeMap_QNToPPQ(4)

    -- Phase 4: Initialize musical intelligence systems
    local section_mode = params.section_mode or "auto"
    local previous_fill_type = nil
    local previous_density = nil
    local fill_bars = {}  -- Track which bars have fills

    for _, voice in ipairs(voices) do
        local N = voice.config.N
        local K = voice.config.K
        local R = voice.config.R
        local pattern = generate_euclidean_rhythm(N, K, R)
        local ppq_per_step = ppq_per_bar / N

        for bar = 0, pattern_length_bars - 1 do
            local base_ppq = bar * ppq_per_bar

            -- Phase 4.2: Section awareness
            local section_type = get_section_for_bar(bar, pattern_length_bars, section_mode)
            local section_char = SectionCharacteristics[section_type]

            -- Phase 4.5: Intelligent fill logic (only insert once per bar, from kick voice)
            local has_fill = false
            if voice.name == "KICK" and not fill_bars[bar] then
                local groove_density = K / N
                local fill_type = insert_intelligent_fill(take, bar, pattern_length_bars, ppq_per_bar,
                                                          base_ppq, section_char, previous_density, previous_fill_type)
                if fill_type then
                    fill_bars[bar] = true
                    previous_fill_type = fill_type
                    has_fill = true
                end
                previous_density = groove_density
            end

            -- Skip regular pattern on fill bars for kick
            if not (has_fill and voice.name == "KICK") then
                for step = 1, N do
                if pattern[step] == 1 then
                    local ppq_position = base_ppq + ((step - 1) * ppq_per_step)
                    local velocity = voice.velocity

                    -- Phase 4.6: Calculate dynamic intensity for this moment
                    local intensity = calculate_dynamic_intensity(bar, pattern_length_bars, section_char, step, N)

                    -- Phase 3.1 + 4.6: Adaptive velocity with accent and natural dynamics
                    velocity = get_accent_velocity(velocity, step, N)
                    velocity = apply_adaptive_velocity(velocity, intensity, step, N, bar, section_char)

                    -- Phase 3.2: Q-Swing for hi-hat
                    local swing_offset = 0
                    if voice.name == "HIHAT" then
                        swing_offset = get_swing_ppq_offset(step, swing_percent, ppq_per_step)
                    end

                    -- Phase 4.6: Apply microtiming (subtle timing variations)
                    ppq_position = apply_microtiming(ppq_position, step, N, bar, intensity, voice.name)

                    -- Phase 4.7: Groove surprise & mistake engine
                    local skip_note = false
                    if should_add_surprise(bar, step, N, pattern_length_bars, voice.name) then
                        skip_note = apply_groove_surprise(take, ppq_position, ppq_per_step, voice.pitch,
                                                          voice.name, velocity, note_length)
                    end

                    -- Insert main note with adaptive dynamics (unless skipped by surprise)
                    if not skip_note then
                        reaper.MIDI_InsertNote(
                            take,
                            false,
                            false,
                            math.floor(ppq_position + swing_offset),
                            math.floor(ppq_position + swing_offset + note_length),
                            0,
                            voice.pitch,
                            math.max(1, math.min(127, velocity)),
                            true
                        )
                    end

                    -- Phase 4.4: Contextual ghost notes for snare
                    if voice.name == "SNARE" then
                        local next_is_accent = ((step + 1) == 1 or (step + 1) == 5 or (step + 1) == 9 or (step + 1) == 13)
                        local groove_density = K / N
                        insert_contextual_ghost_snare(take, step, N, bar, pattern_length_bars, ppq_per_step,
                                                      base_ppq + ((step - 1) * ppq_per_step), next_is_accent, groove_density)
                    end
                end
            end
            end  -- Close the if not has_fill check
        end
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateItemInProject(item)
    reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator v3.0 (Phase 4)", -1)
        if DEBUG then
            reaper.ShowConsoleMsg(string.format(
                "DWUMMER v3.0: Generated %d-bar pattern with Musical Intelligence\n" ..
                "  Section Mode: %s\n" ..
                "  Kick[%d,%d,%d] Snare[%d,%d,%d] HiHat[%d,%d,%d]\n" ..
                "  Phase 4 Features: Motifs, Sections, Dynamics, Fills, Surprises\n",
                pattern_length_bars,
                params.section_mode or "auto",
                params.kick.N, params.kick.K, params.kick.R,
                params.snare.N, params.snare.K, params.snare.R,
                params.hihat.N, params.hihat.K, params.hihat.R
            ))
        end
end

-- Phase 2.4: Initial Parameter GUI

-- Generate completely random parameters with musical constraints
function generate_random_params()
    -- Use system time for true randomness
    math.randomseed(os.time())

    -- Use saved pattern length instead of random
    local pattern_length = saved_pattern_length

    -- Generate random parameters for each voice with MUSICAL CONSTRAINTS
    -- Prefer 16 steps (standard 16th note grid) for most musical results
    local possible_N = {16, 16, 16, 32}  -- Heavily weighted toward 16

    local kick_N = 16  -- Kick always on 16-step grid for musical clarity
    local snare_N = 16  -- Snare always on 16-step grid
    local hihat_N = possible_N[math.random(1, #possible_N)]  -- Hi-hat can occasionally be 32

    -- Musical density constraints:
    -- Kick: 2-6 hits per bar (quarter notes to sparse)
    -- Snare: 1-4 hits per bar (typical backbeat to sparse)
    -- Hi-hat: 4-12 hits per bar (8th notes to moderate 16ths)

    local params = {
        seed = math.random(1, 999999),  -- Random seed for reproducibility
        pattern_length_bars = pattern_length,
        -- Phase 4.2: Section mode for musical structure
        section_mode = "auto",  -- Auto-detect sections based on bar position
        kick = {
            N = kick_N,
            K = math.random(2, 6),  -- 2-6 hits in 16 steps = musically sparse
            R = math.random(0, kick_N - 1),
        },
        snare = {
            N = snare_N,
            K = math.random(1, 4),  -- 1-4 hits in 16 steps = typical backbeat
            R = math.random(0, snare_N - 1),
        },
        hihat = {
            N = hihat_N,
            K = math.random(4, math.min(12, hihat_N)),  -- 4-12 hits = 8th to moderate 16th notes
            R = math.random(0, hihat_N - 1),
        }
    }

    return params
end

-- Show manual parameter input GUI
function show_parameter_gui()
    -- First, show section mode selection
    local section_menu = {"Auto (smart sections)|Verse (consistent groove)|Chorus (full energy)|Bridge (varied)|Intro (sparse)|Outro (fadeout)"}
    gfx.x, gfx.y = reaper.GetMousePosition()
    local section_choice = gfx.showmenu(table.concat(section_menu, ""))

    if section_choice == 0 then
        return nil  -- User cancelled
    end

    local section_modes = {"auto", "verse", "chorus", "bridge", "intro", "outro"}
    local selected_section = section_modes[section_choice]

    -- Build defaults string using saved pattern length
    local defaults_str = string.format("12345,%d,16,4,0,16,4,16,8", saved_pattern_length)

    -- Get user input for parameters
    local retval, user_input = reaper.GetUserInputs(
        "DWUMMER v3.0: Manual Parameters (Phase 4 Enabled)",
        9,
        "Seed:,Pattern Length (bars):,Kick N (steps):,Kick K (pulses):,Kick R (rotation):,Snare N:,Snare K:,Hihat N:,Hihat K:",
        defaults_str
    )

    if not retval then
        return nil  -- User cancelled
    end

    -- Parse the input
    local values = {}
    for value in user_input:gmatch("([^,]+)") do
        table.insert(values, value)
    end

    -- Build parameters table
    local params = {
        seed = tonumber(values[1]) or 12345,
        pattern_length_bars = tonumber(values[2]) or saved_pattern_length,
        section_mode = selected_section,  -- Phase 4.2
        kick = {
            N = tonumber(values[3]) or 16,
            K = tonumber(values[4]) or 4,
            R = tonumber(values[5]) or 0,
        },
        snare = {
            N = tonumber(values[6]) or 16,
            K = tonumber(values[7]) or 4,
            R = 8,  -- Default offset for snare
        },
        hihat = {
            N = tonumber(values[8]) or 16,
            K = tonumber(values[9]) or 8,
            R = 0,
        }
    }

    return params
end

-- Show mode selection dropdown menu
function show_mode_selection()
    local mode_items = {"Random (auto-generate all parameters)", "Manual (configure your own settings)"}

    -- Position menu at mouse cursor
    gfx.x, gfx.y = reaper.GetMousePosition()
    local choice = gfx.showmenu(table.concat(mode_items, "|"))

    -- Returns 0 if cancelled, or 1-based index of selection
    return choice
end

-- Main entry point
function main()
    -- Show mode selection dropdown
    local mode_choice = show_mode_selection()

    if mode_choice == 0 then
           -- User cancelled
           if DEBUG then reaper.ShowConsoleMsg("DWUMMER: Operation cancelled by user\n") end
           return
    end

    local params = nil

    if mode_choice == 1 then
        -- Random Mode
        params = generate_random_params()
            if DEBUG then
                reaper.ShowConsoleMsg(string.format(
                    "DWUMMER: Random mode selected (Seed: %d)\n",
                    params.seed
                ))
            end
    elseif mode_choice == 2 then
        -- Manual Mode
        params = show_parameter_gui()
    end

    if params then
        -- Save the pattern length for next time
        set_ext('pattern_length_bars', params.pattern_length_bars)
        saved_pattern_length = params.pattern_length_bars

        -- Generate pattern with selected parameters
        generate_dwummer_pattern(params)
    else
           if DEBUG then reaper.ShowConsoleMsg("DWUMMER: Operation cancelled by user\n") end
    end
end

-- Run the script
main()
