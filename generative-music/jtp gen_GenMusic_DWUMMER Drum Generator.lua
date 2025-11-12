-- @description jtp gen_GenMusic_DWUMMER Drum Generator
-- @author James
-- @version 2.0
-- @about
--   # DWUMMER Drum Generator
--   Implements Phase 0, Phase 1, and Phase 2 of the DWUMMER development plan.
--   Phase 0: Initialization, deterministic seed management, time conversion, and drum map lookup.
--   Phase 1: I/O Handler MVP - Creates a 4-bar MIDI item with a single kick drum hit on beat 1.
--   Phase 2: Core Rhythm Engine - Full Euclidean rhythm generation for multiple drum voices with parameter GUI.

-- Check if reaper API is available
if not reaper then return end

-- Phase 0.1: Initialization
reaper.ShowConsoleMsg("DWUMMER Initialized\n")

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

-- Snare ghost note probability (side stick, velocity 50-70)
local function maybe_insert_ghost_snare(take, bar, step, N, ppq_per_bar, ppq_per_step, base_ppq, prng_seed)
    local ghost_chance = 0.5 -- 50% probability
    if math.random() < ghost_chance then
        local ghost_pitch = DrumMap.SIDE_STICK
        local ghost_velocity = math.random(50, 70)
        local ghost_ppq = base_ppq + math.floor(ppq_per_step * 0.5) -- 1/16th after main snare
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

-- Drum fill logic for last bar
local function insert_drum_fill(take, bar, ppq_per_bar, N, base_ppq)
    local fill_notes = {
        {pitch=DrumMap.TOM_HIGH, velocity=110},
        {pitch=DrumMap.SNARE, velocity=120},
        {pitch=DrumMap.TOM_MID, velocity=105},
        {pitch=DrumMap.TOM_LOW, velocity=100},
        {pitch=DrumMap.CRASH, velocity=127},
    }
    local steps = #fill_notes
    local fill_ppq_step = ppq_per_bar / steps
    for i, note in ipairs(fill_notes) do
        local ppq = base_ppq + math.floor((i-1) * fill_ppq_step)
        reaper.MIDI_InsertNote(
            take, false, false,
            ppq,
            ppq + TimeMap_QNToPPQ(0.12),
            0,
            note.pitch,
            velocity_jitter(note.velocity),
            true
        )
    end
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

    for _, voice in ipairs(voices) do
        local N = voice.config.N
        local K = voice.config.K
        local R = voice.config.R
        local pattern = generate_euclidean_rhythm(N, K, R)
        local ppq_per_step = ppq_per_bar / N

        for bar = 0, pattern_length_bars - 1 do
            local base_ppq = bar * ppq_per_bar

            -- Phase 3.4: Fill logic for last bar
            if bar == pattern_length_bars - 1 and voice.name == "KICK" then
                insert_drum_fill(take, bar, ppq_per_bar, N, base_ppq)
            end

            for step = 1, N do
                if pattern[step] == 1 then
                    local ppq_position = base_ppq + ((step - 1) * ppq_per_step)
                    local velocity = voice.velocity

                    -- Phase 3.1: Velocity accent + jitter
                    velocity = get_accent_velocity(velocity, step, N)
                    velocity = velocity_jitter(velocity)

                    -- Phase 3.2: Q-Swing for hi-hat
                    local swing_offset = 0
                    if voice.name == "HIHAT" then
                        swing_offset = get_swing_ppq_offset(step, swing_percent, ppq_per_step)
                    end

                    -- Insert main note
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

                    -- Phase 3.3: Snare ghost notes
                    if voice.name == "SNARE" and math.random() < ghost_chance then
                        maybe_insert_ghost_snare(take, bar, step, N, ppq_per_bar, ppq_per_step, base_ppq + ((step - 1) * ppq_per_step), params.seed)
                    end
                end
            end
        end
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateItemInProject(item)
    reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
    reaper.ShowConsoleMsg(string.format(
        "DWUMMER: Generated %d-bar pattern with Kick[%d,%d,%d] Snare[%d,%d,%d] HiHat[%d,%d,%d] (Phase 3)\n",
        pattern_length_bars,
        params.kick.N, params.kick.K, params.kick.R,
        params.snare.N, params.snare.K, params.snare.R,
        params.hihat.N, params.hihat.K, params.hihat.R
    ))
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
    -- Build defaults string using saved pattern length
    local defaults_str = string.format("12345,%d,16,4,0,16,4,16,8", saved_pattern_length)

    -- Get user input for parameters
    local retval, user_input = reaper.GetUserInputs(
        "DWUMMER: Manual Parameters",
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
        reaper.ShowConsoleMsg("DWUMMER: Operation cancelled by user\n")
        return
    end

    local params = nil

    if mode_choice == 1 then
        -- Random Mode
        params = generate_random_params()
        reaper.ShowConsoleMsg(string.format(
            "DWUMMER: Random mode selected (Seed: %d)\n",
            params.seed
        ))
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
        reaper.ShowConsoleMsg("DWUMMER: Operation cancelled by user\n")
    end
end

-- Run the script
main()
