-- @description jtp gen_GenMusic_DWUMMER Drum Generator
-- @author James
-- @version 4.0
-- @about
--   # DWUMMER Drum Generator v4.0 - Genre-Specific Infinite Variation
--   Complete implementation of Phases 0-4 + Genre Mode System
--
--   Phase 0: Initialization, deterministic seed management, time conversion, drum map lookup
--   Phase 1: I/O Handler MVP - MIDI item creation and note insertion
--   Phase 2: Core Rhythm Engine - Euclidean rhythm generation for multiple voices
--   Phase 3: Dynamics and Structure - Velocity humanization, swing, ghost notes, fills
--
--   **Phase 4: Musical Intelligence & Expressive Performance**
--   - 4.1: Motif-Based Groove Development - Recurring rhythmic ideas with variations
--   - 4.2: Dynamic Phrasing & Section Awareness - Auto-adapting groove based on song structure
--   - 4.3: Call-and-Response & Interaction - Voice interplay and rhythmic conversation
--   - 4.4: Expressive Ghost Note Placement - Context-aware embellishments
--   - 4.5: Intelligent Fill Placement & Variation - Musically appropriate fills with variety
--   - 4.6: Adaptive Dynamics & Microtiming - Natural push/pull and dynamic swells
--   - 4.7: Groove Surprise & "Mistake" Engine - Human unpredictability
--
--   **v3.1: Zach Hill Mode - Chaotic Technical Patterns**
--   - Adaptive burst patterns, double strokes, and paradiddles
--   - Physical limb constraint simulation for realistic drumming
--   - Focused riff generation with kit subsets
--   - Dynamic velocity based on timing and hand/foot movement
--   - Persistent adaptive parameters (learns from usage patterns)
--   - Phrase logic: 3x repeating riff then a fill (Zach-esque)
--
--   **v4.0 NEW: Genre Mode System - Infinitely Variable, Always Recognizable**
--   - **House:** 4-on-the-floor with variable hat patterns and ghost snares
--   - **Techno:** Relentless 16th groove with industrial textures
--   - **Electro:** Syncopated 808 patterns with angular rhythms
--   - **Drum & Bass:** Fast 2-step with Amen break variations
--   - **Jungle:** Rapid snare chops with shuffled feel
--   - **Hip Hop:** Boom-bap with laid-back swing and ghost notes
--   - **Trap:** Half-time snare with signature rapid hat rolls
--
--   Each genre has CORE IMMUTABLE patterns (what makes it recognizable) plus
--   VARIABLE ELEMENTS that change with every generation for infinite variety.
--   Physical limb constraints ensure realistic drumming performance.

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

-- Note: HAT_PEDAL for Zach Hill mode (hi-hat pedal articulation)
local HAT_PEDAL = 44

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
    local mode_items = {
        "Random (auto-generate all parameters)",
        "Manual (configure your own settings)",
        "Zach Hill Mode (chaotic, technical drum patterns)",
        "|Genre Modes (infinitely variable):|",
        "House (4-on-floor with variation)",
        "Techno (driving 16th groove)",
        "Electro (syncopated 808 style)",
        "Drum & Bass (fast 2-step breaks)",
        "Jungle (amen break variations)",
        "Hip Hop (boom-bap with swing)",
        "Trap (half-time with hat rolls)"
    }

    -- Position menu at mouse cursor
    gfx.x, gfx.y = reaper.GetMousePosition()
    local choice = gfx.showmenu(table.concat(mode_items, "|"))

    -- Returns 0 if cancelled, or 1-based index of selection
    return choice
end

-- =============================
-- GENRE MODE: Blueprint-Based Pattern Generator
-- =============================
-- Each genre has core immutable patterns plus variable elements
-- Using Zach Hill-style limb tracking and physical constraints

local GenreBlueprints = {
    HOUSE = {
        name = "House",
        bpm_range = {120, 130},
        core_patterns = {
            -- 4-on-the-floor kick (immutable)
            kick = {steps = {1, 5, 9, 13}, velocity = {95, 110}},
            -- Snare on 2 & 4 (can vary with ghosts)
            snare = {steps = {5, 13}, velocity = {90, 105}},
            -- Open hat on offbeats between each beat (CORE house element)
            hat_open = {steps = {3, 7, 11, 15}, velocity = {85, 100}},
        },
        variable_elements = {
            -- Closed hat: 8ths to 16ths with occasional skips
            hat_closed_density = {0.65, 0.95}, -- % of 16th notes filled
            hat_closed_velocity = {70, 90},
            -- Ghost snares
            ghost_snare_chance = 0.3,
            ghost_snare_velocity = {40, 60},
            -- Ride bell/tip for texture
            ride_layer_chance = 0.4,
            ride_velocity = {65, 85},
        }
    },

    TECHNO = {
        name = "Techno",
        bpm_range = {125, 140},
        core_patterns = {
            -- Relentless 4-on-the-floor
            kick = {steps = {1, 5, 9, 13}, velocity = {105, 120}},
            -- Clap/snare on 2 & 4 (harder than house)
            snare = {steps = {5, 13}, velocity = {100, 115}},
        },
        variable_elements = {
            -- Tight 16th hat grid (high density)
            hat_closed_density = {0.85, 1.0},
            hat_closed_velocity = {75, 95},
            -- Occasional hat accents
            hat_accent_chance = 0.25,
            hat_accent_velocity = {100, 115},
            -- Industrial percussion hits
            rim_layer_chance = 0.35,
            rim_velocity = {80, 100},
            -- Kick doubling for energy
            kick_double_chance = 0.20,
        }
    },

    ELECTRO = {
        name = "Electro",
        bpm_range = {120, 135},
        core_patterns = {
            -- 4-on-floor base with syncopation
            kick = {steps = {1, 5, 9, 13}, velocity = {100, 115}},
            -- 808 style claps (wider, more mechanical)
            snare = {steps = {5, 13}, velocity = {95, 110}},
        },
        variable_elements = {
            -- Angular 16th patterns
            hat_closed_density = {0.60, 0.85},
            hat_closed_velocity = {70, 90},
            -- Syncopated kick variations
            kick_syncopation_chance = 0.45, -- Add kicks on offbeats
            kick_syncopation_positions = {3, 7, 11, 15}, -- 16th note positions
            -- Cowbell/rim accents
            cowbell_chance = 0.30,
            cowbell_velocity = {85, 105},
            -- Snare rolls (fast)
            snare_roll_chance = 0.25,
        }
    },

    DNB = {
        name = "Drum & Bass",
        bpm_range = {170, 180},
        core_patterns = {
            -- 2-step kick pattern (1 & 3 or variations)
            kick = {steps = {1, 11}, velocity = {100, 120}}, -- Basic 2-step
            -- Signature DnB snare on 3rd beat (step 9)
            snare = {steps = {9}, velocity = {105, 120}},
        },
        variable_elements = {
            -- Amen-style break variations
            break_variation_chance = 0.80, -- High probability of complex breaks
            break_snare_positions = {3, 6, 9, 11, 14}, -- Possible break hits
            -- Ride cymbal pattern
            ride_density = {0.50, 0.75},
            ride_velocity = {70, 90},
            -- Ghost snares (critical for DnB feel)
            ghost_snare_chance = 0.60,
            ghost_snare_velocity = {35, 55},
            -- Kick pattern variations
            kick_shuffle_chance = 0.50,
        }
    },

    JUNGLE = {
        name = "Jungle",
        bpm_range = {160, 175},
        core_patterns = {
            -- Amen break foundation
            kick = {steps = {1, 10}, velocity = {95, 115}},
            snare = {steps = {5, 13}, velocity = {100, 118}},
        },
        variable_elements = {
            -- Rapid snare chops and rolls
            snare_chop_chance = 0.85,
            snare_chop_density = {0.70, 0.95},
            snare_roll_chance = 0.65,
            -- Shuffled hi-hat feel
            hat_shuffle_amount = {0.55, 0.70},
            hat_density = {0.60, 0.85},
            hat_velocity = {65, 85},
            -- Tom fills
            tom_fill_chance = 0.50,
            -- Ride bell patterns
            ride_bell_chance = 0.45,
        }
    },

    HIPHOP = {
        name = "Hip Hop",
        bpm_range = {85, 105},
        core_patterns = {
            -- Boom-bap: kick on 1 & 3 (steps 1 & 9)
            kick = {steps = {1, 9}, velocity = {100, 120}},
            -- Snare on 2 & 4 (steps 5 & 13)
            snare = {steps = {5, 13}, velocity = {95, 115}},
        },
        variable_elements = {
            -- Laid back feel (swing and timing)
            swing_amount = {0.55, 0.68},
            laid_back_timing = {-10, 10}, -- PPQ offset for feel
            -- Ghost snares (signature hip hop)
            ghost_snare_chance = 0.50,
            ghost_snare_velocity = {40, 60},
            -- Hi-hat variations (closed/open mix)
            hat_density = {0.40, 0.70}, -- Sparse to moderate
            hat_open_chance = 0.25,
            -- Kick doubling
            kick_double_chance = 0.35,
            -- Rimshot snare chance
            rimshot_snare_chance = 0.30,
        }
    },

    TRAP = {
        name = "Trap",
        bpm_range = {130, 160},
        core_patterns = {
            -- Half-time snare on beat 3 (step 9)
            snare = {steps = {9}, velocity = {100, 120}},
            -- 808 kick pattern (sparse but impactful)
            kick = {steps = {1}, velocity = {110, 127}},
        },
        variable_elements = {
            -- Signature rapid hi-hat rolls
            hat_roll_chance = 0.70, -- Very high
            hat_roll_speed = {16, 32}, -- 16th or 32nd note rolls
            hat_roll_length = {2, 6}, -- Number of notes in roll
            hat_roll_velocity = {80, 110},
            -- Hat triplet patterns
            hat_triplet_chance = 0.50,
            -- 808 kick variations
            kick_pattern_variation = 0.65,
            kick_extra_positions = {3, 5, 7, 11, 13, 15},
            -- Layered snares
            snare_layer_chance = 0.40,
            -- Open hat accents
            hat_open_accent_chance = 0.45,
        }
    }
}

-- Genre-aware note insertion with physical constraints (reusing Zach Hill limb system)
local function genreInsertNote(take, ppq_pos, note, velocity, duration, limb_state)
    local note_time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq_pos)
    local humanize_offset = (math.random() * 2 - 1) * (3 / 1000) -- Subtle humanization
    local final_time = note_time + humanize_offset

    -- Determine limb
    local limb = "RH"
    if note == DrumMap.KICK then
        limb = "RF"
    elseif note == HAT_PEDAL then
        limb = "LF"
    elseif note == DrumMap.HIHAT_CLOSED or note == DrumMap.HIHAT_OPEN or note == DrumMap.RIDE then
        limb = "RH" -- Right hand typically plays hats/ride
    else
        limb = (math.random() < 0.5) and "RH" or "LH"
    end

    -- Check physical constraints
    if limb_state[limb].lastNoteTime then
        local dt = final_time - limb_state[limb].lastNoteTime
        local min_interval = (limb == "RF" or limb == "LF") and 0.06 or 0.015
        if dt < min_interval then
            return false -- Can't play this note
        end
    end

    -- Insert note
    local ppq_with_offset = reaper.MIDI_GetPPQPosFromProjTime(take, final_time)
    local note_off = ppq_with_offset + (duration or 120)
    reaper.MIDI_InsertNote(take, false, false, ppq_with_offset, note_off, 0, note, velocity, false)

    -- Update limb state
    limb_state[limb].lastNoteTime = final_time
    limb_state[limb].lastPiece = note

    return true
end

-- Random value within range
local function randRange(min_val, max_val)
    return min_val + math.random() * (max_val - min_val)
end

local function randInt(min_val, max_val)
    return math.floor(randRange(min_val, max_val + 0.9999))
end

-- Generate a genre-based pattern
function generate_genre_pattern(genre_key)
    local blueprint = GenreBlueprints[genre_key]
    if not blueprint then
        reaper.ShowMessageBox("Unknown genre: " .. tostring(genre_key), "Error", 0)
        return
    end

    reaper.Undo_BeginBlock()

    -- Get time selection
    local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if time_end <= time_start then
        -- Use cursor position and pattern length
        time_start = reaper.GetCursorPosition()
        local bpm = reaper.Master_GetTempo()
        local bars = saved_pattern_length
        local seconds_per_beat = 60 / bpm
        time_end = time_start + (bars * 4 * seconds_per_beat)
    end

    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: DWUMMER " .. blueprint.name, -1)
        return
    end

    local new_item = reaper.CreateNewMIDIItemInProj(track, time_start, time_end, false)
    local take = reaper.GetActiveTake(new_item)
    if not take then
        reaper.Undo_EndBlock("jtp gen: DWUMMER " .. blueprint.name, -1)
        return
    end

    -- Initialize limb state
    local limb_state = {
        RF = {lastNoteTime = nil, lastPiece = DrumMap.KICK},
        LF = {lastNoteTime = nil, lastPiece = DrumMap.HIHAT_CLOSED}, -- Left foot not used in genre modes
        RH = {lastNoteTime = nil, lastPiece = DrumMap.HIHAT_CLOSED},
        LH = {lastNoteTime = nil, lastPiece = DrumMap.SNARE},
    }

    local PPQ = 960
    local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, time_start)
    local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, time_end)
    local total_ppq = end_ppq - start_ppq

    local time_sig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, time_start)
    local measure_len_ppq = time_sig_num * PPQ
    local num_measures = math.floor(total_ppq / measure_len_ppq)

    -- Generate pattern for each measure
    for measure = 1, num_measures do
        local measure_start_ppq = start_ppq + (measure - 1) * measure_len_ppq
        local measure_end_ppq = measure_start_ppq + measure_len_ppq
        local sixteenth_ppq = PPQ / 4

        -- CORE PATTERNS (immutable, defining the genre)

        -- Kick pattern
        for _, step in ipairs(blueprint.core_patterns.kick.steps) do
            local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
            local velocity = randInt(blueprint.core_patterns.kick.velocity[1],
                                    blueprint.core_patterns.kick.velocity[2])
            genreInsertNote(take, ppq_pos, DrumMap.KICK, velocity, PPQ * 0.15, limb_state)
        end

        -- Snare pattern
        for _, step in ipairs(blueprint.core_patterns.snare.steps) do
            local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
            local velocity = randInt(blueprint.core_patterns.snare.velocity[1],
                                    blueprint.core_patterns.snare.velocity[2])
            genreInsertNote(take, ppq_pos, DrumMap.SNARE, velocity, PPQ * 0.12, limb_state)
        end

        -- Open hat pattern (if defined in core - essential for house)
        if blueprint.core_patterns.hat_open then
            for _, step in ipairs(blueprint.core_patterns.hat_open.steps) do
                local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                local velocity = randInt(blueprint.core_patterns.hat_open.velocity[1],
                                        blueprint.core_patterns.hat_open.velocity[2])
                genreInsertNote(take, ppq_pos, DrumMap.HIHAT_OPEN, velocity, PPQ * 0.25, limb_state)
            end
        end

        -- VARIABLE ELEMENTS (changes each run)
        local var = blueprint.variable_elements

        -- === HOUSE VARIATIONS ===
        if genre_key == "HOUSE" then
            -- Hi-hat closed pattern (8ths to 16ths with variation)
            local hat_density = randRange(var.hat_closed_density[1], var.hat_closed_density[2])
            for step = 1, 16 do
                if math.random() < hat_density then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.hat_closed_velocity[1], var.hat_closed_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, sixteenth_ppq * 0.9, limb_state)
                end
            end

            -- Ghost snares (use actual snare at low velocity, not side stick)
            for step = 1, 16 do
                if step ~= 5 and step ~= 13 and math.random() < var.ghost_snare_chance then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.ghost_snare_velocity[1], var.ghost_snare_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.SNARE, velocity, sixteenth_ppq * 0.7, limb_state)
                end
            end

            -- Ride layer for texture
            if math.random() < var.ride_layer_chance then
                for step = 1, 16, 2 do -- 8th notes
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.ride_velocity[1], var.ride_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.RIDE, velocity, sixteenth_ppq * 2, limb_state)
                end
            end
        end

        -- === TECHNO VARIATIONS ===
        if genre_key == "TECHNO" then
            -- Tight 16th hat grid
            local hat_density = randRange(var.hat_closed_density[1], var.hat_closed_density[2])
            for step = 1, 16 do
                if math.random() < hat_density then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.hat_closed_velocity[1], var.hat_closed_velocity[2])

                    -- Occasional accents
                    if math.random() < var.hat_accent_chance then
                        velocity = randInt(var.hat_accent_velocity[1], var.hat_accent_velocity[2])
                    end

                    genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, sixteenth_ppq * 0.85, limb_state)
                end
            end

            -- Industrial rim hits
            if math.random() < var.rim_layer_chance then
                for step = 1, 16 do
                    if math.random() < 0.4 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(var.rim_velocity[1], var.rim_velocity[2])
                        genreInsertNote(take, ppq_pos, DrumMap.SIDE_STICK, velocity, sixteenth_ppq * 0.6, limb_state)
                    end
                end
            end

            -- Kick doubling for energy
            if math.random() < var.kick_double_chance then
                for _, step in ipairs({3, 7, 11, 15}) do
                    if math.random() < 0.5 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(95, 110)
                        genreInsertNote(take, ppq_pos, DrumMap.KICK, velocity, PPQ * 0.1, limb_state)
                    end
                end
            end
        end

        -- === ELECTRO VARIATIONS ===
        if genre_key == "ELECTRO" then
            -- Angular hat patterns
            local hat_density = randRange(var.hat_closed_density[1], var.hat_closed_density[2])
            for step = 1, 16 do
                if math.random() < hat_density then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.hat_closed_velocity[1], var.hat_closed_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, sixteenth_ppq * 0.8, limb_state)
                end
            end

            -- Syncopated kick variations
            if math.random() < var.kick_syncopation_chance then
                for _, step in ipairs(var.kick_syncopation_positions) do
                    if math.random() < 0.6 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(95, 110)
                        genreInsertNote(take, ppq_pos, DrumMap.KICK, velocity, PPQ * 0.12, limb_state)
                    end
                end
            end

            -- Cowbell/rim accents
            if math.random() < var.cowbell_chance then
                for step = 1, 16, 4 do -- Quarter notes
                    if math.random() < 0.7 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(var.cowbell_velocity[1], var.cowbell_velocity[2])
                        genreInsertNote(take, ppq_pos, DrumMap.SIDE_STICK, velocity, PPQ * 0.1, limb_state)
                    end
                end
            end

            -- Snare rolls (fast 32nds into snare hit)
            if math.random() < var.snare_roll_chance then
                local roll_start = measure_end_ppq - (sixteenth_ppq * 2)
                local thirty_second_ppq = PPQ / 8
                for i = 0, 7 do
                    local ppq_pos = roll_start + (i * thirty_second_ppq)
                    local velocity = 60 + (i * 6) -- Crescendo
                    genreInsertNote(take, ppq_pos, DrumMap.SNARE, velocity, thirty_second_ppq * 0.8, limb_state)
                end
            end
        end

        -- === DRUM & BASS VARIATIONS ===
        if genre_key == "DNB" then
            -- Amen-style break variations
            if math.random() < var.break_variation_chance then
                for _, step in ipairs(var.break_snare_positions) do
                    if math.random() < 0.65 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(85, 110)
                        genreInsertNote(take, ppq_pos, DrumMap.SNARE, velocity, sixteenth_ppq * 0.8, limb_state)
                    end
                end
            end

            -- Ride cymbal pattern
            local ride_density = randRange(var.ride_density[1], var.ride_density[2])
            for step = 1, 16 do
                if math.random() < ride_density then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.ride_velocity[1], var.ride_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.RIDE, velocity, sixteenth_ppq * 1.5, limb_state)
                end
            end

            -- Ghost snares (critical for DnB feel)
            for step = 1, 16 do
                if step ~= 9 and math.random() < var.ghost_snare_chance then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local velocity = randInt(var.ghost_snare_velocity[1], var.ghost_snare_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.SIDE_STICK, velocity, sixteenth_ppq * 0.6, limb_state)
                end
            end

            -- Kick shuffle variations
            if math.random() < var.kick_shuffle_chance then
                for _, step in ipairs({3, 7, 13, 15}) do
                    if math.random() < 0.5 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(90, 110)
                        genreInsertNote(take, ppq_pos, DrumMap.KICK, velocity, PPQ * 0.12, limb_state)
                    end
                end
            end
        end

        -- === JUNGLE VARIATIONS ===
        if genre_key == "JUNGLE" then
            -- Rapid snare chops
            if math.random() < var.snare_chop_chance then
                local chop_density = randRange(var.snare_chop_density[1], var.snare_chop_density[2])
                for step = 1, 16 do
                    if step ~= 5 and step ~= 13 and math.random() < chop_density then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(70, 100)
                        genreInsertNote(take, ppq_pos, DrumMap.SNARE, velocity, sixteenth_ppq * 0.7, limb_state)
                    end
                end
            end

            -- Snare rolls
            if math.random() < var.snare_roll_chance then
                local roll_start_step = math.random(1, 12)
                local thirty_second_ppq = PPQ / 8
                for i = 0, 5 do
                    local ppq_pos = measure_start_ppq + (roll_start_step - 1) * sixteenth_ppq + (i * thirty_second_ppq)
                    local velocity = 55 + (i * 8)
                    genreInsertNote(take, ppq_pos, DrumMap.SNARE, velocity, thirty_second_ppq * 0.75, limb_state)
                end
            end

            -- Shuffled hi-hat
            local hat_density = randRange(var.hat_density[1], var.hat_density[2])
            for step = 1, 16 do
                if math.random() < hat_density then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    -- Add shuffle (swing)
                    if step % 2 == 0 then
                        local shuffle_amount = randRange(var.hat_shuffle_amount[1], var.hat_shuffle_amount[2])
                        ppq_pos = ppq_pos + (sixteenth_ppq * shuffle_amount * 0.3)
                    end
                    local velocity = randInt(var.hat_velocity[1], var.hat_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, sixteenth_ppq * 0.8, limb_state)
                end
            end

            -- Tom fills
            if math.random() < var.tom_fill_chance then
                local toms = {DrumMap.TOM_HIGH, DrumMap.TOM_MID, DrumMap.TOM_LOW}
                for i = 1, 4 do
                    local step = 13 + (i - 1)
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    local tom = toms[math.random(1, #toms)]
                    local velocity = randInt(85, 110)
                    genreInsertNote(take, ppq_pos, tom, velocity, sixteenth_ppq, limb_state)
                end
            end

            -- Ride bell
            if math.random() < var.ride_bell_chance then
                for step = 1, 16, 2 do
                    if math.random() < 0.7 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(70, 90)
                        genreInsertNote(take, ppq_pos, DrumMap.RIDE, velocity, sixteenth_ppq * 1.5, limb_state)
                    end
                end
            end
        end

        -- === HIP HOP VARIATIONS ===
        if genre_key == "HIPHOP" then
            -- Swing/shuffle
            local swing_amount = randRange(var.swing_amount[1], var.swing_amount[2])

            -- Hi-hat pattern with swing
            local hat_density = randRange(var.hat_density[1], var.hat_density[2])
            for step = 1, 16 do
                if math.random() < hat_density then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    -- Apply swing to offbeats
                    if step % 2 == 0 then
                        ppq_pos = ppq_pos + (sixteenth_ppq * (swing_amount - 0.5) * 0.4)
                    end
                    -- Laid back timing
                    ppq_pos = ppq_pos + randRange(var.laid_back_timing[1], var.laid_back_timing[2])

                    local velocity = randInt(60, 80)
                    genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, sixteenth_ppq * 0.9, limb_state)
                end
            end

            -- Open hat variations
            if math.random() < var.hat_open_chance then
                for step = 1, 16, 4 do
                    if math.random() < 0.6 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(75, 95)
                        genreInsertNote(take, ppq_pos, DrumMap.HIHAT_OPEN, velocity, PPQ * 0.3, limb_state)
                    end
                end
            end

            -- Ghost snares (signature hip hop)
            for step = 1, 16 do
                if step ~= 5 and step ~= 13 and math.random() < var.ghost_snare_chance then
                    local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                    ppq_pos = ppq_pos + randRange(var.laid_back_timing[1], var.laid_back_timing[2])
                    local velocity = randInt(var.ghost_snare_velocity[1], var.ghost_snare_velocity[2])
                    genreInsertNote(take, ppq_pos, DrumMap.SIDE_STICK, velocity, sixteenth_ppq * 0.7, limb_state)
                end
            end

            -- Kick doubling
            if math.random() < var.kick_double_chance then
                for _, step in ipairs({2, 7, 11}) do
                    if math.random() < 0.6 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(90, 110)
                        genreInsertNote(take, ppq_pos, DrumMap.KICK, velocity, PPQ * 0.12, limb_state)
                    end
                end
            end

            -- Rimshot snare
            if math.random() < var.rimshot_snare_chance then
                for _, step in ipairs({5, 13}) do
                    if math.random() < 0.5 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(85, 105)
                        genreInsertNote(take, ppq_pos, DrumMap.SNARE_ACCENT, velocity, PPQ * 0.12, limb_state)
                    end
                end
            end
        end

        -- === TRAP VARIATIONS ===
        if genre_key == "TRAP" then
            -- Rapid hi-hat rolls (signature trap element)
            if math.random() < var.hat_roll_chance then
                local roll_start_step = math.random(1, 13)
                local roll_speed = var.hat_roll_speed[math.random(1, 2)] -- 16th or 32nd
                local roll_length = randInt(var.hat_roll_length[1], var.hat_roll_length[2])
                local roll_tick = PPQ / roll_speed

                for i = 0, roll_length - 1 do
                    local ppq_pos = measure_start_ppq + (roll_start_step - 1) * sixteenth_ppq + (i * roll_tick)
                    if ppq_pos < measure_end_ppq then
                        local velocity = randInt(var.hat_roll_velocity[1], var.hat_roll_velocity[2])
                        -- Crescendo effect
                        velocity = velocity + (i * 3)
                        velocity = math.min(127, velocity)
                        genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, roll_tick * 0.8, limb_state)
                    end
                end
            end

            -- Triplet hat patterns
            if math.random() < var.hat_triplet_chance then
                for beat = 1, 4 do
                    if math.random() < 0.6 then
                        local beat_ppq = measure_start_ppq + (beat - 1) * PPQ
                        local triplet_tick = PPQ / 3
                        for i = 0, 2 do
                            local ppq_pos = beat_ppq + (i * triplet_tick)
                            local velocity = randInt(70, 90)
                            genreInsertNote(take, ppq_pos, DrumMap.HIHAT_CLOSED, velocity, triplet_tick * 0.85, limb_state)
                        end
                    end
                end
            end

            -- 808 kick pattern variations
            if math.random() < var.kick_pattern_variation then
                for _, step in ipairs(var.kick_extra_positions) do
                    if math.random() < 0.4 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(105, 120)
                        genreInsertNote(take, ppq_pos, DrumMap.KICK, velocity, PPQ * 0.18, limb_state)
                    end
                end
            end

            -- Layered snares
            if math.random() < var.snare_layer_chance then
                local ppq_pos = measure_start_ppq + 8 * sixteenth_ppq -- Step 9
                local velocity = randInt(95, 110)
                genreInsertNote(take, ppq_pos, DrumMap.SNARE_ACCENT, velocity, PPQ * 0.12, limb_state)
            end

            -- Open hat accents
            if math.random() < var.hat_open_accent_chance then
                for step = 1, 16, 4 do
                    if math.random() < 0.7 then
                        local ppq_pos = measure_start_ppq + (step - 1) * sixteenth_ppq
                        local velocity = randInt(90, 110)
                        genreInsertNote(take, ppq_pos, DrumMap.HIHAT_OPEN, velocity, PPQ * 0.4, limb_state)
                    end
                end
            end
        end
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateItemInProject(new_item)
    reaper.Undo_EndBlock("jtp gen: DWUMMER " .. blueprint.name .. " Mode", -1)

    if DEBUG then
        reaper.ShowConsoleMsg(string.format("DWUMMER: Generated %s pattern with infinite variation\n", blueprint.name))
    end
end

-- =============================
-- ZACH HILL MODE: Chaotic Technical Drum Generator
-- =============================

-- Adaptive parameters for Zach Hill mode (persistent via ExtState)
local function GetZachParam(key, default)
    local val = reaper.GetExtState("jtp_gen_dwummer_zach", key)
    if val == "" then return default end
    return tonumber(val)
end

local function SetZachParam(key, value)
    reaper.SetExtState("jtp_gen_dwummer_zach", key, tostring(value), true)
end

-- Initialize Zach Hill adaptive parameters
local ZACH_BURST_CHANCE = GetZachParam("burst_chance", 0.250)
local ZACH_DOUBLE_STROKE_CHANCE = GetZachParam("double_stroke_chance", 0.250)
local ZACH_PARADIDDLE_CHANCE = GetZachParam("paradiddle_chance", 0.250)
local ZACH_FOCUSED_RIFF_CHANCE = GetZachParam("focused_riff_chance", 0.300)
local ZACH_ANCHOR_DOWNBEAT_CHANCE = GetZachParam("anchor_downbeat_chance", 0.300)
local ZACH_FOOT_PEDAL_QUARTER_CHANCE = GetZachParam("foot_pedal_quarter_chance", 0.300)
local ZACH_RANDOM_BEAT_ACCENT_CHANCE = GetZachParam("random_beat_accent_chance", 0.600)
local ZACH_SUBDIVS_MAX = GetZachParam("subdivs_max", 2)

-- Zach Hill phrase behavior (3 repeats then fill)
local ZACH_PHRASE_LENGTH = GetZachParam("phrase_length", 4) -- bars per phrase
local ZACH_REPEAT_BARS = GetZachParam("phrase_repeat_bars", 3) -- repeating riff bars before fill

-- Density and layering controls
local ZACH_TEXTURE_LAYER_CHANCE = GetZachParam("texture_layer_chance", 0.85) -- chance to add 8th-note hats/ride
local ZACH_LAYER_CYMBAL_CHANCE = GetZachParam("layer_cymbal_chance", 0.55) -- chance to layer cymbal on a stroke
local ZACH_KICK_UNDER_CHANCE = GetZachParam("kick_under_chance", 0.35) -- chance to add kick under a hand stroke
local ZACH_MIN_NOTES_PER_MEASURE = GetZachParam("min_notes_per_measure", 12)

-- Zach Hill mode drum map (adapted to DWUMMER's MIDI mapping)
local ZachDrumMap = {
    {note = DrumMap.KICK, prob = 0.38},
    {note = DrumMap.SNARE, prob = 0.38},
    {note = DrumMap.TOM_HIGH, prob = 0.20},
    {note = DrumMap.TOM_MID, prob = 0.20},
    {note = DrumMap.TOM_LOW, prob = 0.10},
    {note = DrumMap.HIHAT_CLOSED, prob = 0.15},
    {note = DrumMap.HIHAT_OPEN, prob = 0.05},
    {note = DrumMap.CRASH, prob = 0.007},
    {note = DrumMap.RIDE, prob = 0.007},
}

-- Zach Hill mode settings
local ZACH_PPQ = 960
local ZACH_SUBDIVS_MIN = 1
local ZACH_BURST_NOTES = 8
local ZACH_HUMANIZE_MS = 7
local ZACH_VEL_MIN = 7
local ZACH_VEL_MAX = 110
local ZACH_SUSTAIN_MODE = true
local ZACH_SUSTAIN_FACTOR = 0.9
local ZACH_MIN_FOOT_INTERVAL_SECS = 0.06
local ZACH_MIN_HAND_INTERVAL_SECS = 0.01
local ZACH_FOOT_PEDAL_VEL_MIN = 60
local ZACH_FOOT_PEDAL_VEL_MAX = 90

-- Hand movement times for physical realism
local function zachMoveTime(same, diff)
    return function(from, to)
        if from == to then return same else return diff end
    end
end

local zachTimeFn = zachMoveTime(0.01, 0.06)

local zachMovementTime = {
    [DrumMap.SNARE] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.SNARE, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.SNARE, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.SNARE, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.SNARE, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.SNARE, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.SNARE, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.SNARE, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.SNARE, DrumMap.RIDE)
    },
    [DrumMap.TOM_HIGH] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.TOM_HIGH, DrumMap.RIDE)
    },
    [DrumMap.TOM_MID] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.TOM_MID, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.TOM_MID, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.TOM_MID, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.TOM_MID, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.TOM_MID, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.TOM_MID, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.TOM_MID, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.TOM_MID, DrumMap.RIDE)
    },
    [DrumMap.TOM_LOW] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.TOM_LOW, DrumMap.RIDE)
    },
    [DrumMap.HIHAT_CLOSED] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.HIHAT_CLOSED, DrumMap.RIDE)
    },
    [DrumMap.HIHAT_OPEN] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.HIHAT_OPEN, DrumMap.RIDE)
    },
    [DrumMap.CRASH] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.CRASH, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.CRASH, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.CRASH, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.CRASH, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.CRASH, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.CRASH, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.CRASH, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.CRASH, DrumMap.RIDE)
    },
    [DrumMap.RIDE] = {
        [DrumMap.SNARE]=zachTimeFn(DrumMap.RIDE, DrumMap.SNARE),
        [DrumMap.TOM_HIGH]=zachTimeFn(DrumMap.RIDE, DrumMap.TOM_HIGH),
        [DrumMap.TOM_MID]=zachTimeFn(DrumMap.RIDE, DrumMap.TOM_MID),
        [DrumMap.TOM_LOW]=zachTimeFn(DrumMap.RIDE, DrumMap.TOM_LOW),
        [DrumMap.HIHAT_CLOSED]=zachTimeFn(DrumMap.RIDE, DrumMap.HIHAT_CLOSED),
        [DrumMap.HIHAT_OPEN]=zachTimeFn(DrumMap.RIDE, DrumMap.HIHAT_OPEN),
        [DrumMap.CRASH]=zachTimeFn(DrumMap.RIDE, DrumMap.CRASH),
        [DrumMap.RIDE]=zachTimeFn(DrumMap.RIDE, DrumMap.RIDE)
    },
}

-- Limb state tracking for physical realism
local zachLimbState = {
    RF = { lastNoteTime = nil, lastPiece = DrumMap.KICK },
    LF = { lastNoteTime = nil, lastPiece = HAT_PEDAL },
    RH = { lastNoteTime = nil, lastPiece = DrumMap.SNARE },
    LH = { lastNoteTime = nil, lastPiece = DrumMap.SNARE },
}

local zachGlobalPPQStart = 0
local zachCurrentMeasureAccents = {}
local zachCurrentMeasureStartPPQ = nil
local zachGlobalMeasureLenPPQ = nil

-- Zach Hill helper functions
local function zachRandomRange(minVal, maxVal)
    return math.floor(math.random() * (maxVal - minVal + 1)) + minVal
end

local function zachChooseDrum()
    local r = math.random()
    local cumulative = 0
    for _, d in ipairs(ZachDrumMap) do
        cumulative = cumulative + d.prob
        if r <= cumulative then
            return d.note
        end
    end
    return ZachDrumMap[#ZachDrumMap].note
end

local function zachPickLimbForNote(note)
    if note == DrumMap.KICK then
        return "RF"
    elseif note == HAT_PEDAL then
        return "LF"
    else
        return (math.random() < 0.5) and "RH" or "LH"
    end
end

local function zachCanLimbPlay(limbID, note, requestedTime)
    local st = zachLimbState[limbID]
    if not st then return false end
    local lastTime = st.lastNoteTime
    local lastPiece = st.lastPiece
    if not lastTime then return true end
    local dt = requestedTime - lastTime
    if dt < 0 then return false end
    if limbID == "RF" or limbID == "LF" then
        return dt >= ZACH_MIN_FOOT_INTERVAL_SECS
    end
    if dt < ZACH_MIN_HAND_INTERVAL_SECS then return false end
    local mtime = 0.01
    if zachMovementTime[lastPiece] and zachMovementTime[lastPiece][note] then
        mtime = zachMovementTime[lastPiece][note]
    end
    return dt >= mtime
end

local function zachGetDynamicVelocity(limbID, note, finalTime, notePPQ)
    local offFromStart = notePPQ - zachGlobalPPQStart
    local onQuarter = (offFromStart >= 0) and ((offFromStart % ZACH_PPQ) == 0)
    if onQuarter then return zachRandomRange(ZACH_VEL_MIN, ZACH_VEL_MAX) end

    local st = zachLimbState[limbID]
    local dt = st.lastNoteTime and (finalTime - st.lastNoteTime) or 999
    local baseMin, baseMax
    if dt < 0.03 then
        baseMin, baseMax = 30, 60
    elseif dt < 0.06 then
        baseMin, baseMax = 40, 80
    else
        baseMin, baseMax = 50, 110
    end

    local accentFactor = 0
    if zachCurrentMeasureAccents and zachCurrentMeasureStartPPQ and
       notePPQ >= zachCurrentMeasureStartPPQ and
       notePPQ < (zachCurrentMeasureStartPPQ + zachGlobalMeasureLenPPQ) then
        local accentWindow = ZACH_PPQ / 4
        for _, accentPPQ in ipairs(zachCurrentMeasureAccents) do
            local diff = math.abs(notePPQ - accentPPQ)
            local candidate = (accentWindow - diff) / accentWindow
            if candidate > accentFactor then accentFactor = candidate end
        end
    end

    local bonus = math.floor(accentFactor * 20)
    local finalMin = math.min(ZACH_VEL_MAX, baseMin + bonus)
    local finalMax = math.min(ZACH_VEL_MAX, baseMax + bonus)
    return zachRandomRange(finalMin, finalMax)
end

local function zachInsertNote(take, ppqPos, note, overrideVelMin, overrideVelMax, noteDurationTicks)
    local noteTime = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqPos)
    local humanizeOffsetSec = (math.random() * 2 - 1) * (ZACH_HUMANIZE_MS / 1000)
    local finalTime = noteTime + humanizeOffsetSec
    local limb = zachPickLimbForNote(note)
    if not zachCanLimbPlay(limb, note, finalTime) then return end

    local noteVelocity
    if overrideVelMin and overrideVelMax then
        local baseVel = zachRandomRange(overrideVelMin, overrideVelMax)
        local dev = zachRandomRange(-5, 5)
        noteVelocity = math.min(math.max(baseVel + dev, ZACH_VEL_MIN), ZACH_VEL_MAX)
    else
        local ppqWithOffset = reaper.MIDI_GetPPQPosFromProjTime(take, finalTime)
        noteVelocity = zachGetDynamicVelocity(limb, note, finalTime, ppqWithOffset)
    end

    local ppqWithOffset = reaper.MIDI_GetPPQPosFromProjTime(take, finalTime)
    local noteOffPPQ = noteDurationTicks and (ppqWithOffset + noteDurationTicks) or (ppqWithOffset + 1)
    reaper.MIDI_InsertNote(take, false, false, ppqWithOffset, noteOffPPQ, 0, note, noteVelocity, false)
    zachLimbState[limb].lastNoteTime = finalTime
    zachLimbState[limb].lastPiece = note
end

local function zachInsertDoubleStroke(take, basePPQ, note, spacingTicks)
    local duration = ZACH_SUSTAIN_MODE and math.floor(spacingTicks * ZACH_SUSTAIN_FACTOR) or nil
    zachInsertNote(take, basePPQ, note, nil, nil, duration)
    zachInsertNote(take, basePPQ + spacingTicks, note, nil, nil, duration)
end

local function zachInsertParadiddle(take, startPPQ, spacingTicks, kitFocus)
    local function pickNote()
        if kitFocus and #kitFocus > 0 then
            return kitFocus[zachRandomRange(1, #kitFocus)]
        else
            return zachChooseDrum()
        end
    end

    local strokes = { pickNote(), pickNote(), pickNote(), pickNote(),
                      pickNote(), pickNote(), pickNote(), pickNote() }
    local duration = ZACH_SUSTAIN_MODE and math.floor(spacingTicks * ZACH_SUSTAIN_FACTOR) or nil
    for i, n in ipairs(strokes) do
        local strokePPQ = startPPQ + (i-1)*spacingTicks
        zachInsertNote(take, strokePPQ, n, nil, nil, duration)
    end
end

local function zachChooseKitSubset(size)
    local subset = {}
    local pool = {}
    for _, d in ipairs(ZachDrumMap) do table.insert(pool, d.note) end
    for i = #pool, 1, -1 do
        if pool[i] == DrumMap.KICK or pool[i] == HAT_PEDAL then table.remove(pool, i) end
    end
    for i = 1, size do
        if #pool == 0 then break end
        local idx = zachRandomRange(1, #pool)
        table.insert(subset, pool[idx])
        table.remove(pool, idx)
    end
    return subset
end

local function zachInsertFocusedRiff(take, startPPQ, measureEndPPQ, kitFocus)
    if not kitFocus or #kitFocus < 1 then kitFocus = zachChooseKitSubset(zachRandomRange(2, 3)) end
    local patternLength = zachRandomRange(3, 5)
    local totalSpace = measureEndPPQ - startPPQ
    local spacing = math.floor(totalSpace / (patternLength * 2))
    local duration = ZACH_SUSTAIN_MODE and math.floor(spacing * ZACH_SUSTAIN_FACTOR) or nil
    local pos = startPPQ
    while pos < measureEndPPQ do
        for p = 1, patternLength do
            local note = kitFocus[zachRandomRange(1, #kitFocus)]
            local insertPos = pos + (p-1)*spacing
            if insertPos >= measureEndPPQ then break end
            zachInsertNote(take, insertPos, note, nil, nil, duration)
        end
        pos = pos + (patternLength * spacing)
    end
end

-- Generate a repeating riff spec to reuse over the phrase
local function zachGenerateRiffSpec()
    return {
        kitFocus = zachChooseKitSubset(zachRandomRange(2, 3)),
        patternLength = zachRandomRange(3, 5)
    }
end

local function zachInsertFocusedRiffWithSpec(take, startPPQ, measureEndPPQ, riffSpec)
    local kitFocus = riffSpec.kitFocus
    local patternLength = riffSpec.patternLength
    if not kitFocus or #kitFocus < 1 then
        kitFocus = zachChooseKitSubset(zachRandomRange(2, 3))
    end
    local totalSpace = measureEndPPQ - startPPQ
    -- Increase density: 3 strokes per pattern step instead of 2
    local spacing = math.max(1, math.floor(totalSpace / (patternLength * 3)))
    local duration = ZACH_SUSTAIN_MODE and math.floor(spacing * ZACH_SUSTAIN_FACTOR) or nil
    local pos = startPPQ
    while pos < measureEndPPQ do
        for p = 1, patternLength do
            local note = kitFocus[zachRandomRange(1, #kitFocus)]
            local insertPos = pos + (p-1)*spacing
            if insertPos >= measureEndPPQ then break end
            -- Primary stroke
            zachInsertNote(take, insertPos, note, nil, nil, duration)
            -- Optional interstitial stroke to avoid linearity
            if math.random() < 0.5 then
                local interPos = insertPos + math.floor(spacing * 0.5)
                if interPos < measureEndPPQ then
                    local interNote = kitFocus[zachRandomRange(1, #kitFocus)]
                    zachInsertNote(take, interPos, interNote, nil, nil, math.floor(duration * 0.8))
                end
            end
            -- Layering: cymbal on top
            if math.random() < ZACH_LAYER_CYMBAL_CHANCE then
                local cym = (math.random() < 0.6) and DrumMap.HIHAT_CLOSED or ((math.random() < 0.5) and DrumMap.RIDE or DrumMap.HIHAT_OPEN)
                zachInsertNote(take, insertPos, cym, 70, 105, duration)
            end
            -- Layering: kick under hand stroke
            if math.random() < ZACH_KICK_UNDER_CHANCE then
                zachInsertNote(take, insertPos, DrumMap.KICK, 65, 100, duration)
            end
        end
        pos = pos + (patternLength * spacing)
    end
end

-- Chaotic fill measure: heavier tom/snare activity and end crash
local function zachInsertChaosFill(take, measureStartPPQ, measureEndPPQ, timeSig_num)
    -- First half: light scaffolding (kick on 1, optional hats)
    local durationQ = ZACH_SUSTAIN_MODE and math.floor(ZACH_PPQ * ZACH_SUSTAIN_FACTOR) or nil
    zachInsertNote(take, measureStartPPQ, DrumMap.KICK, nil, nil, durationQ)
    for b = 2, timeSig_num - 1 do
        local quarterPPQ = measureStartPPQ + (b-1)*ZACH_PPQ
        if quarterPPQ >= measureEndPPQ then break end
        if math.random() < 0.5 then
            zachInsertNote(take, quarterPPQ, HAT_PEDAL, ZACH_FOOT_PEDAL_VEL_MIN, ZACH_FOOT_PEDAL_VEL_MAX, durationQ)
        end
    end

    -- Second half: bursts/paradiddles across toms and snare
    local fillStart = measureStartPPQ + math.floor((timeSig_num >= 4 and 3 or math.max(1, timeSig_num-1)) * ZACH_PPQ)
    if fillStart >= measureEndPPQ then fillStart = measureStartPPQ + math.floor(ZACH_PPQ * 0.5) end
    local cur = fillStart
    while cur < measureEndPPQ do
        local remaining = measureEndPPQ - cur
        local subdivs = math.max(3, ZACH_SUBDIVS_MAX)
        local ticksPerSub = math.max(1, math.floor(ZACH_PPQ / subdivs))
        if math.random() < 0.6 then
            -- Burst cluster
            local cluster = math.min(ZACH_BURST_NOTES + 2, math.max(4, math.floor(remaining / math.max(1, ticksPerSub/5))))
            for i = 0, cluster - 1 do
                local pos = cur + i * math.floor(ticksPerSub/(cluster+1))
                if pos >= measureEndPPQ then break end
                local note = (math.random() < 0.55) and DrumMap.SNARE or (math.random() < 0.5 and DrumMap.TOM_MID or DrumMap.TOM_LOW)
                local dur = ZACH_SUSTAIN_MODE and math.floor((ticksPerSub/(cluster+1)) * ZACH_SUSTAIN_FACTOR) or nil
                zachInsertNote(take, pos, note, nil, nil, dur)
                if math.random() < 0.5 then
                    local cym = (math.random() < 0.6) and DrumMap.HIHAT_CLOSED or DrumMap.RIDE
                    zachInsertNote(take, pos, cym, 70, 110, dur)
                end
            end
            cur = cur + ticksPerSub
        else
            -- Paradiddle-ish figure
            local strokeSpacing = math.floor(ticksPerSub * 0.25)
            zachInsertParadiddle(take, cur, strokeSpacing, {DrumMap.SNARE, DrumMap.TOM_HIGH, DrumMap.TOM_MID})
            cur = cur + ticksPerSub
        end
    end

    -- Strong ending: snare + crash at bar end
    local endCrashPos = measureEndPPQ - math.floor(ZACH_PPQ * 0.01)
    zachInsertNote(take, endCrashPos, DrumMap.SNARE, nil, nil, durationQ)
    local cymbals = {DrumMap.HIHAT_OPEN, DrumMap.CRASH, DrumMap.RIDE}
    local cym = cymbals[zachRandomRange(1, #cymbals)]
    zachInsertNote(take, endCrashPos, cym, nil, nil, durationQ)
end

local function zachChooseAccentCymbal()
    local cymbals = {DrumMap.HIHAT_OPEN, DrumMap.CRASH, DrumMap.RIDE}
    return cymbals[zachRandomRange(1, #cymbals)]
end

local function zachInsertAccent(take, beatPPQ)
    local duration = ZACH_SUSTAIN_MODE and math.floor(ZACH_PPQ * ZACH_SUSTAIN_FACTOR) or nil
    zachInsertNote(take, beatPPQ, DrumMap.SNARE, nil, nil, duration)
    zachInsertNote(take, beatPPQ, zachChooseAccentCymbal(), nil, nil, duration)
    if zachCurrentMeasureAccents then table.insert(zachCurrentMeasureAccents, beatPPQ) end
end

local function zachTryQuarterPedal(take, quarterPPQ)
    if math.random() < ZACH_FOOT_PEDAL_QUARTER_CHANCE then
        local duration = ZACH_SUSTAIN_MODE and math.floor(ZACH_PPQ * ZACH_SUSTAIN_FACTOR) or nil
        zachInsertNote(take, quarterPPQ, HAT_PEDAL, ZACH_FOOT_PEDAL_VEL_MIN, ZACH_FOOT_PEDAL_VEL_MAX, duration)
    end
end

-- Main Zach Hill pattern generation function
function generate_zach_hill_pattern()
    -- Reset limb states
    for limb, st in pairs(zachLimbState) do
        st.lastNoteTime = nil
        if limb == "RF" then st.lastPiece = DrumMap.KICK
        elseif limb == "LF" then st.lastPiece = HAT_PEDAL
        else st.lastPiece = DrumMap.SNARE end
    end

    reaper.Undo_BeginBlock()

    local timeStart, timeEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if timeEnd <= timeStart then
        reaper.ShowMessageBox("Please make a time selection first.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: DWUMMER Zach Hill Mode", -1)
        return
    end

    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select or create a drum track.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: DWUMMER Zach Hill Mode", -1)
        return
    end

    local newItem = reaper.CreateNewMIDIItemInProj(track, timeStart, timeEnd, false)
    local take = reaper.GetActiveTake(newItem)
    if not take then
        reaper.Undo_EndBlock("jtp gen: DWUMMER Zach Hill Mode", -1)
        return
    end

    zachGlobalPPQStart = reaper.MIDI_GetPPQPosFromProjTime(take, timeStart)
    local timeSig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, timeStart)
    local measureLenPPQ = timeSig_num * ZACH_PPQ
    zachGlobalMeasureLenPPQ = measureLenPPQ

    local startPPQ = zachGlobalPPQStart
    local endPPQ = reaper.MIDI_GetPPQPosFromProjTime(take, timeEnd)
    local totalPPQ = endPPQ - startPPQ
    if totalPPQ <= 0 then
        reaper.Undo_EndBlock("jtp gen: DWUMMER Zach Hill Mode", -1)
        return
    end

    local numMeasures = math.floor(totalPPQ / measureLenPPQ)
    local leftoverPPQ = totalPPQ % measureLenPPQ
    local measureStartPPQ = startPPQ

    -- Generate pattern per measure with 3x repeat then fill phrasing
    local riffSpec = nil
    for m = 1, numMeasures do
        zachCurrentMeasureAccents = {}
        zachCurrentMeasureStartPPQ = measureStartPPQ
        local measureEnd = measureStartPPQ + measureLenPPQ

        -- Anchor downbeat
        local doDownbeat = (math.random() < ZACH_ANCHOR_DOWNBEAT_CHANCE)
        if doDownbeat then
            local duration = ZACH_SUSTAIN_MODE and math.floor(ZACH_PPQ * ZACH_SUSTAIN_FACTOR) or nil
            zachInsertNote(take, measureStartPPQ, DrumMap.KICK, nil, nil, duration)
        end

        -- Random beat accent
        if math.random() < ZACH_RANDOM_BEAT_ACCENT_CHANCE then
            local randomBeatIndex = zachRandomRange(1, timeSig_num)
            local randomBeatPPQ = measureStartPPQ + (randomBeatIndex - 1) * ZACH_PPQ
            zachInsertAccent(take, randomBeatPPQ)
        end

        -- Quarter note pedal patterns
        for b = 1, timeSig_num do
            local quarterPPQ = measureStartPPQ + (b-1)*ZACH_PPQ
            zachTryQuarterPedal(take, quarterPPQ)
        end

        -- Texture layer: add hats/ride on 8ths across the bar to avoid sparsity
        if math.random() < ZACH_TEXTURE_LAYER_CHANCE then
            local eighthTicks = math.floor(ZACH_PPQ * 0.5)
            local t = measureStartPPQ
            while t < measureEnd do
                local cym = (math.random() < 0.7) and DrumMap.HIHAT_CLOSED or DrumMap.RIDE
                zachInsertNote(take, t, cym, 60, 95, math.floor(eighthTicks * ZACH_SUSTAIN_FACTOR))
                -- occasional open hat on offbeats
                if ((t - measureStartPPQ) % (ZACH_PPQ)) == math.floor(ZACH_PPQ * 0.5) and math.random() < 0.25 then
                    zachInsertNote(take, t, DrumMap.HIHAT_OPEN, 70, 105, math.floor(eighthTicks * 1.2))
                end
                t = t + eighthTicks
            end
        end

        -- Determine phrase position (1..ZACH_PHRASE_LENGTH)
        local phrasePos = ((m - 1) % (ZACH_PHRASE_LENGTH > 0 and ZACH_PHRASE_LENGTH or 4)) + 1

        if phrasePos <= (ZACH_REPEAT_BARS > 0 and ZACH_REPEAT_BARS or 3) then
            -- Repeating riff bars
            if phrasePos == 1 or not riffSpec then
                riffSpec = zachGenerateRiffSpec()
            end
            -- Keep the 'idea' consistent: reuse riffSpec across bars 1-3
            zachInsertFocusedRiffWithSpec(take, measureStartPPQ + ZACH_PPQ, measureEnd, riffSpec)
            measureStartPPQ = measureEnd
        else
            -- Fill bar
            zachInsertChaosFill(take, measureStartPPQ, measureEnd, timeSig_num)
            measureStartPPQ = measureEnd
            riffSpec = nil -- new idea after fill
        end
    end

    -- Handle leftover partial measure
    if leftoverPPQ > 0 then
        zachCurrentMeasureAccents = {}
        zachCurrentMeasureStartPPQ = measureStartPPQ
        local leftoverStart = measureStartPPQ
        local leftoverEnd = leftoverStart + leftoverPPQ
        local doDownbeatLeftover = (math.random() < ZACH_ANCHOR_DOWNBEAT_CHANCE)

        if doDownbeatLeftover then
            local duration = ZACH_SUSTAIN_MODE and math.floor(ZACH_PPQ * ZACH_SUSTAIN_FACTOR) or nil
            zachInsertNote(take, leftoverStart, DrumMap.KICK, nil, nil, duration)
        end

        local leftoverBeats = leftoverPPQ / ZACH_PPQ
        if math.random() < ZACH_RANDOM_BEAT_ACCENT_CHANCE then
            local randomBeatIndex = zachRandomRange(1, math.floor(leftoverBeats))
            local randomBeatPPQ = leftoverStart + (randomBeatIndex - 1) * ZACH_PPQ
            if randomBeatPPQ < leftoverEnd then
                zachInsertAccent(take, randomBeatPPQ)
            end
        end

        local leftoverFullBeats = math.floor(leftoverBeats)
        for b = 1, leftoverFullBeats do
            local quarterPPQ = leftoverStart + (b-1)*ZACH_PPQ
            if quarterPPQ >= leftoverEnd then break end
            zachTryQuarterPedal(take, quarterPPQ)
        end

        if math.random() < ZACH_FOCUSED_RIFF_CHANCE then
            local kitFocus = zachChooseKitSubset(zachRandomRange(2, 3))
            zachInsertFocusedRiff(take, leftoverStart + ZACH_PPQ, leftoverEnd, kitFocus)
        else
            local curTick = 0
            while curTick < leftoverPPQ do
                local subdivs = zachRandomRange(ZACH_SUBDIVS_MIN, ZACH_SUBDIVS_MAX)
                local ticksPerSub = math.floor((ZACH_PPQ / subdivs) + 0.5)
                for s = 1, subdivs do
                    local subTick = curTick + (s-1)*ticksPerSub
                    if subTick >= leftoverPPQ then break end
                    local actualTick = leftoverStart + subTick

                    if math.random() < ZACH_BURST_CHANCE then
                        for i = 0, ZACH_BURST_NOTES-1 do
                            local flurryTick = actualTick + i*math.floor(ticksPerSub/(ZACH_BURST_NOTES+1))
                            if flurryTick >= leftoverEnd then break end
                            local duration = ZACH_SUSTAIN_MODE and math.floor((ticksPerSub/(ZACH_BURST_NOTES+1)) * ZACH_SUSTAIN_FACTOR) or nil
                            zachInsertNote(take, flurryTick, zachChooseDrum(), nil, nil, duration)
                        end
                    else
                        local doDouble = (math.random() < ZACH_DOUBLE_STROKE_CHANCE)
                        local doPara = (not doDouble and math.random() < ZACH_PARADIDDLE_CHANCE)

                        if doDouble then
                            local note = zachChooseDrum()
                            local strokeSpacing = math.floor(ticksPerSub * 0.25)
                            zachInsertDoubleStroke(take, actualTick, note, strokeSpacing)
                        elseif doPara then
                            local strokeSpacing = math.floor(ticksPerSub * 0.25)
                            zachInsertParadiddle(take, actualTick, strokeSpacing, nil)
                        else
                            local duration = ZACH_SUSTAIN_MODE and math.floor(ticksPerSub * ZACH_SUSTAIN_FACTOR) or nil
                            zachInsertNote(take, actualTick, zachChooseDrum(), nil, nil, duration)
                        end
                    end
                end
                curTick = curTick + ZACH_PPQ
            end
        end
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateItemInProject(newItem)
    reaper.Undo_EndBlock("jtp gen: DWUMMER Zach Hill Mode", -1)

    if DEBUG then
        reaper.ShowConsoleMsg("DWUMMER: Zach Hill mode pattern generated\n")
    end
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
    elseif mode_choice == 3 then
        -- Zach Hill Mode
        generate_zach_hill_pattern()
        return
    -- Genre modes (choice 4 is separator, skip it)
    elseif mode_choice == 5 then
        -- House
        generate_genre_pattern("HOUSE")
        return
    elseif mode_choice == 6 then
        -- Techno
        generate_genre_pattern("TECHNO")
        return
    elseif mode_choice == 7 then
        -- Electro
        generate_genre_pattern("ELECTRO")
        return
    elseif mode_choice == 8 then
        -- Drum & Bass
        generate_genre_pattern("DNB")
        return
    elseif mode_choice == 9 then
        -- Jungle
        generate_genre_pattern("JUNGLE")
        return
    elseif mode_choice == 10 then
        -- Hip Hop
        generate_genre_pattern("HIPHOP")
        return
    elseif mode_choice == 11 then
        -- Trap
        generate_genre_pattern("TRAP")
        return
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
