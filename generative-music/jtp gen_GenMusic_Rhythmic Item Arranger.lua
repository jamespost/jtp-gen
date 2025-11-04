-- @description jtp gen: Rhythmic Item Arranger
-- @author James
-- @version 1.0
-- @about
--   # Rhythmic Item Arranger
--
--   ## Description
--   Takes selected media items and arranges them into generative rhythmic patterns
--   within a time selection. Uses various algorithms including Euclidean rhythms,
--   probability-based patterns, and other algorithmic approaches for varied results.
--
--   ## Usage
--   1. Select one or more media items to use as source material
--   2. Set a time selection where you want the pattern generated
--   3. Run the script - it generates random patterns instantly!
--   4. Run again and again until you get something you like
--   5. (Optional) Hold Shift or set SHOW_GUI=true in config to manually choose parameters
--
--   ## Pattern Types
--   - Euclidean: Evenly distributed rhythms (e.g., 5 hits in 8 steps)
--   - Probability: Random placement based on probability percentage
--   - Swing Grid: Regular grid with swing/groove variation
--   - Fractal: Self-similar rhythmic subdivisions
--   - Random Dense: Completely random with density control
--
--   ## Notes
--   - Original items are not modified
--   - Each run generates different results for stochastic patterns
--   - Works with audio items on the timeline
--   - Set ACCENT_MODE=true in config to enable dynamic accents (some hits louder)

if not reaper then
    return
end

math.randomseed(os.time())

-- Configuration
local CONFIG = {
    MIN_ITEM_GAP = 0.001, -- Minimum gap between items in seconds
    DEFAULT_VELOCITY_VAR = 0.2, -- 20% velocity variation
    DEFAULT_LENGTH_VAR = 0.1, -- 10% length variation
    SHOW_GUI = false, -- Set to true to show parameter dialog (or hold Shift when running)
    SHOW_HELP = false, -- Set to true to show help on first run
    DEBUG_MODE = false, -- Set to true to show debug console output
    ACCENT_MODE = true, -- Set to true to enable accent pattern (some items louder)
    ACCENT_REDUCTION_DB = -6 -- dB reduction for non-accented items
}

-- Euclidean rhythm algorithm (Bjorklund's algorithm)
local function generateEuclideanPattern(hits, steps, rotation)
    rotation = rotation or 0

    if hits >= steps then
        local pattern = {}
        for i = 1, steps do
            pattern[i] = 1
        end
        return pattern
    end

    if hits == 0 then
        local pattern = {}
        for i = 1, steps do
            pattern[i] = 0
        end
        return pattern
    end

    local pattern = {}
    local counts = {}
    local remainders = {}

    local divisor = steps - hits
    remainders[1] = hits

    local level = 0
    repeat
        level = level + 1
        counts[level] = math.floor(divisor / remainders[level])
        remainders[level + 1] = divisor % remainders[level]
        divisor = remainders[level]
    until remainders[level + 1] <= 1

    counts[level + 1] = divisor

    local function build(level)
        if level == 1 then
            return {{1}, {0}}
        end

        local prev = build(level - 1)
        local seq = {}

        for i = 1, counts[level] do
            for _, v in ipairs(prev[1]) do
                table.insert(seq, v)
            end
        end

        if remainders[level] ~= 0 then
            for _, v in ipairs(prev[2]) do
                table.insert(seq, v)
            end
        end

        return {seq, prev[1]}
    end

    local result = build(level + 1)[1]

    -- Apply rotation
    if rotation > 0 then
        rotation = rotation % #result
        for i = 1, rotation do
            local first = table.remove(result, 1)
            table.insert(result, first)
        end
    end

    return result
end

-- Generate probability-based pattern
local function generateProbabilityPattern(steps, probability)
    local pattern = {}
    for i = 1, steps do
        pattern[i] = (math.random() < probability) and 1 or 0
    end
    return pattern
end

-- Generate swing grid pattern
local function generateSwingPattern(steps, swing_amount)
    local pattern = {}
    for i = 1, steps do
        pattern[i] = 1  -- All steps active
    end
    return pattern, swing_amount
end

-- Generate fractal pattern
local function generateFractalPattern(steps, depth)
    local pattern = {}
    for i = 1, steps do
        pattern[i] = 0
    end

    local function subdivide(start_pos, end_pos, current_depth)
        if current_depth <= 0 then
            return
        end

        pattern[start_pos] = 1

        if current_depth > 1 then
            local mid = math.floor((start_pos + end_pos) / 2)
            if mid > start_pos and mid <= end_pos then
                subdivide(start_pos, mid, current_depth - 1)
                subdivide(mid, end_pos, current_depth - 1)
            end
        end
    end

    subdivide(1, steps, depth)
    return pattern
end

-- Generate random dense pattern
local function generateRandomDensePattern(steps, density)
    local num_hits = math.floor(steps * density)
    local pattern = {}
    for i = 1, steps do
        pattern[i] = 0
    end

    local positions = {}
    for i = 1, steps do
        positions[i] = i
    end

    -- Shuffle and pick first num_hits positions
    for i = #positions, 2, -1 do
        local j = math.random(i)
        positions[i], positions[j] = positions[j], positions[i]
    end

    for i = 1, math.min(num_hits, #positions) do
        pattern[positions[i]] = 1
    end

    return pattern
end

-- Generate accent pattern (which hits should be accented)
local function generateAccentPattern(rhythm_pattern)
    local accent_pattern = {}
    local hits = {}

    -- Collect positions where there are hits
    for i, hit in ipairs(rhythm_pattern) do
        if hit == 1 then
            table.insert(hits, i)
        end
    end

    -- If no hits, return empty pattern
    if #hits == 0 then
        for i = 1, #rhythm_pattern do
            accent_pattern[i] = 0
        end
        return accent_pattern
    end

    -- Initialize all as non-accented
    for i = 1, #rhythm_pattern do
        accent_pattern[i] = 0
    end

    -- Common accent patterns based on number of hits
    if #hits == 1 then
        -- Single hit is always accented
        accent_pattern[hits[1]] = 1

    elseif #hits == 2 then
        -- Accent first hit
        accent_pattern[hits[1]] = 1

    elseif #hits == 3 then
        -- Accent first hit
        accent_pattern[hits[1]] = 1

    elseif #hits == 4 then
        -- Accent 1st and 3rd (classic 4-on-the-floor with backbeat feel)
        accent_pattern[hits[1]] = 1
        accent_pattern[hits[3]] = 1

    else
        -- For longer patterns, use musical accent logic:
        -- Accent downbeats (every 4th in standard time)
        -- Always accent the first hit
        accent_pattern[hits[1]] = 1

        -- Accent every 4th hit for typical bar structure
        for i = 1, #hits do
            if (i - 1) % 4 == 0 then
                accent_pattern[hits[i]] = 1
            end
        end

        -- Add some randomness: 20% chance for other hits to be accented
        for i = 1, #hits do
            if accent_pattern[hits[i]] == 0 and math.random() < 0.2 then
                accent_pattern[hits[i]] = 1
            end
        end
    end

    return accent_pattern
end

-- Get user input for pattern generation
local function getUserInput()
    local retval, user_input = reaper.GetUserInputs(
        "jtp gen: Rhythmic Item Arranger",
        6,
        "Pattern (1-5):,Steps (4-128):,Param 1:,Param 2:,Velocity Var (0-1):,Length Var (0-1):,extrawidth=200",
        "1,16,5,0,0.2,0.1"
    )

    if not retval then
        return nil
    end

    local pattern_type, steps, param1, param2, vel_var, len_var =
        user_input:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")

    return {
        pattern_type = tonumber(pattern_type) or 1,
        steps = tonumber(steps) or 16,
        param1 = tonumber(param1) or 5,
        param2 = tonumber(param2) or 0,
        velocity_var = tonumber(vel_var) or 0.2,
        length_var = tonumber(len_var) or 0.1
    }
end

-- Generate random parameters for automatic mode
local function generateRandomParams()
    -- Choose random pattern type
    local pattern_type = math.random(1, 5)

    -- Steps between 8-32 (most musical range)
    local steps = math.random(8, 32)

    -- Generate appropriate param1 based on pattern type
    local param1
    local param2 = 0

    if pattern_type == 1 then
        -- Euclidean: hits between 25%-75% of steps
        param1 = math.random(math.max(1, math.floor(steps * 0.25)), math.floor(steps * 0.75))
        -- Random rotation
        param2 = math.random(0, steps - 1)

    elseif pattern_type == 2 then
        -- Probability: 30%-70% chance
        param1 = 0.3 + math.random() * 0.4

    elseif pattern_type == 3 then
        -- Swing: 0.3-0.7 range
        param1 = 0.3 + math.random() * 0.4

    elseif pattern_type == 4 then
        -- Fractal: depth 2-4
        param1 = math.random(2, 4)

    elseif pattern_type == 5 then
        -- Random Dense: 30%-70% density
        param1 = 0.3 + math.random() * 0.4
    end

    -- Velocity and length variation
    local velocity_var = 0.1 + math.random() * 0.3  -- 10%-40%
    local length_var = 0.05 + math.random() * 0.2   -- 5%-25%

    return {
        pattern_type = pattern_type,
        steps = steps,
        param1 = param1,
        param2 = param2,
        velocity_var = velocity_var,
        length_var = length_var
    }
end

-- Show pattern type help
local function showHelp()
    local help_text = [[jtp gen: Rhythmic Item Arranger

PATTERN TYPES:
1. Euclidean - Evenly distributed hits
   Param 1: Number of hits (1-steps)
   Param 2: Rotation (0-steps)

2. Probability - Random based on chance
   Param 1: Probability (0.0-1.0, e.g., 0.5 = 50%)
   Param 2: (unused)

3. Swing Grid - Regular grid with swing
   Param 1: Swing amount (0.0-1.0)
   Param 2: (unused)

4. Fractal - Self-similar subdivisions
   Param 1: Depth (1-5)
   Param 2: (unused)

5. Random Dense - Random with density
   Param 1: Density (0.0-1.0, e.g., 0.6 = 60%)
   Param 2: (unused)

STEPS: Total number of grid positions (4-128)

VELOCITY VAR: Volume variation (0-1, 0=none, 1=max)
LENGTH VAR: Duration variation (0-1, 0=none, 1=max)

Each run generates different results!]]

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(help_text .. "\n")
    end
    reaper.MB(help_text, "jtp gen: Pattern Help", 0)
end

-- Create item copy at specific position with variations
local function createItemCopy(source_item, track, position, base_length, vel_var, len_var, is_accent)
    -- Calculate variations
    local velocity_mult = 1.0 + (math.random() * 2 - 1) * vel_var
    local length_mult = 1.0 + (math.random() * 2 - 1) * len_var

    velocity_mult = math.max(0.3, math.min(1.5, velocity_mult))
    length_mult = math.max(0.5, math.min(1.5, length_mult))

    local final_length = base_length * length_mult

    -- Create new item
    local new_item = reaper.AddMediaItemToTrack(track)
    reaper.SetMediaItemPosition(new_item, position, false)
    reaper.SetMediaItemLength(new_item, final_length, false)

    -- Copy takes from source
    local source_take_count = reaper.CountTakes(source_item)
    for i = 0, source_take_count - 1 do
        local source_take = reaper.GetTake(source_item, i)
        local new_take = reaper.AddTakeToMediaItem(new_item)

        -- Copy take properties
        local source = reaper.GetMediaItemTake_Source(source_take)
        reaper.SetMediaItemTake_Source(new_take, source)

        -- Apply volume variation
        local vol = reaper.GetMediaItemTakeInfo_Value(source_take, "D_VOL")
        reaper.SetMediaItemTakeInfo_Value(new_take, "D_VOL", vol * velocity_mult)

        -- Copy other properties
        local rate = reaper.GetMediaItemTakeInfo_Value(source_take, "D_PLAYRATE")
        reaper.SetMediaItemTakeInfo_Value(new_take, "D_PLAYRATE", rate)

        local offset = reaper.GetMediaItemTakeInfo_Value(source_take, "D_STARTOFFS")
        reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", offset)

        -- Set as active take if source was active
        if reaper.GetActiveTake(source_item) == source_take then
            reaper.SetActiveTake(new_take)
        end
    end

    -- Copy item properties
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN",
        reaper.GetMediaItemInfo_Value(source_item, "D_FADEINLEN"))
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN",
        reaper.GetMediaItemInfo_Value(source_item, "D_FADEOUTLEN"))

    -- Apply accent reduction if accent mode is enabled and this is not an accent
    if CONFIG.ACCENT_MODE and not is_accent then
        -- Convert dB to linear volume multiplier and apply to item volume
        local db_reduction = CONFIG.ACCENT_REDUCTION_DB
        local vol_mult = 10 ^ (db_reduction / 20)  -- dB to linear
        local current_vol = reaper.GetMediaItemInfo_Value(new_item, "D_VOL")
        reaper.SetMediaItemInfo_Value(new_item, "D_VOL", current_vol * vol_mult)
    end

    return new_item
end

-- Main function
function main()
    -- Check for selected items
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then
        reaper.MB("Please select one or more media items to arrange rhythmically.",
                  "jtp gen: Rhythmic Item Arranger", 0)
        return
    end

    -- Check for time selection (try both loop and time selection)
    local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    -- If no loop points, try getting time selection
    if time_start == time_end then
        time_start, time_end = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)
    end

    if time_start == time_end then
        reaper.MB("Please set a time selection where you want the pattern generated.\n\nDrag across the timeline to create a time selection.",
                  "jtp gen: Rhythmic Item Arranger", 0)
        return
    end

    -- Debug: Show time selection
    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: Time selection: %.3f to %.3f (%.3f seconds)\n",
                              time_start, time_end, time_end - time_start))
    end

    -- Check if Shift key is held to show GUI (requires js_ReaScriptAPI extension)
    local shift_held = false
    if reaper.JS_Mouse_GetState then
        shift_held = reaper.JS_Mouse_GetState(8) == 8
    end
    local show_gui = CONFIG.SHOW_GUI or shift_held

    -- Show help if configured (only when showing GUI)
    if CONFIG.SHOW_HELP and show_gui then
        showHelp()
    end

    -- Get parameters: either from user input or randomly generated
    local params
    if show_gui then
        params = getUserInput()
        if not params then
            return
        end
    else
        -- Generate random parameters for fast iteration
        params = generateRandomParams()
    end

    -- Validate parameters
    if params.steps < 4 or params.steps > 128 then
        reaper.MB("Steps must be between 4 and 128.", "jtp gen: Error", 0)
        return
    end

    reaper.Undo_BeginBlock()

    -- Get source items and their tracks
    local source_items = {}
    local source_tracks = {}
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(source_items, item)
        local track = reaper.GetMediaItem_Track(item)
        if not source_tracks[track] then
            source_tracks[track] = true
        end
    end

    -- Generate pattern based on type
    local pattern
    local swing_amount = 0

    if params.pattern_type == 1 then
        -- Euclidean
        local hits = math.min(math.max(1, params.param1), params.steps)
        local rotation = math.floor(params.param2)
        pattern = generateEuclideanPattern(hits, params.steps, rotation)
        if CONFIG.DEBUG_MODE then
            reaper.ShowConsoleMsg(string.format("jtp gen: Euclidean [%d,%d] rotation:%d\n",
                                  hits, params.steps, rotation))
        end

    elseif params.pattern_type == 2 then
        -- Probability
        local prob = math.max(0, math.min(1, params.param1))
        pattern = generateProbabilityPattern(params.steps, prob)
        if CONFIG.DEBUG_MODE then
            reaper.ShowConsoleMsg(string.format("jtp gen: Probability %.2f\n", prob))
        end

    elseif params.pattern_type == 3 then
        -- Swing Grid
        swing_amount = math.max(0, math.min(1, params.param1))
        pattern = generateSwingPattern(params.steps, swing_amount)
        if CONFIG.DEBUG_MODE then
            reaper.ShowConsoleMsg(string.format("jtp gen: Swing Grid %.2f\n", swing_amount))
        end

    elseif params.pattern_type == 4 then
        -- Fractal
        local depth = math.max(1, math.min(5, math.floor(params.param1)))
        pattern = generateFractalPattern(params.steps, depth)
        if CONFIG.DEBUG_MODE then
            reaper.ShowConsoleMsg(string.format("jtp gen: Fractal depth:%d\n", depth))
        end

    elseif params.pattern_type == 5 then
        -- Random Dense
        local density = math.max(0, math.min(1, params.param1))
        pattern = generateRandomDensePattern(params.steps, density)
        if CONFIG.DEBUG_MODE then
            reaper.ShowConsoleMsg(string.format("jtp gen: Random Dense %.2f\n", density))
        end

    else
        reaper.MB("Invalid pattern type. Please choose 1-5.", "jtp gen: Error", 0)
        return
    end

    -- Calculate timing using musical grid (beats)
    -- Convert time selection to beats (using project 0 and proper API)
    local start_beat = reaper.TimeMap_timeToQN(time_start)
    local end_beat = reaper.TimeMap_timeToQN(time_end)
    local total_beats = end_beat - start_beat

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: DEBUG - start_beat=%.3f, end_beat=%.3f, total=%.3f\n",
                              start_beat, end_beat, total_beats))
    end

    -- Calculate beat length per step
    local beats_per_step = total_beats / params.steps

    -- Get source item info for length calculation
    local selected_source = source_items[math.random(#source_items)]
    local source_length = reaper.GetMediaItemInfo_Value(selected_source, "D_LENGTH")

    -- Debug: Show pattern info
    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: Steps=%d, Beats=%.2f, Beats/step=%.3f\n",
                              params.steps, total_beats, beats_per_step))
    end

    -- Generate accent pattern if accent mode is enabled
    local accent_pattern = nil
    if CONFIG.ACCENT_MODE then
        accent_pattern = generateAccentPattern(pattern)
        if CONFIG.DEBUG_MODE then
            local accent_count = 0
            for _, accent in ipairs(accent_pattern) do
                if accent == 1 then accent_count = accent_count + 1 end
            end
            reaper.ShowConsoleMsg(string.format("jtp gen: Accent mode enabled - %d accents\n", accent_count))
        end
    end

    -- Create items based on pattern
    local created_count = 0
    local pattern_hits = 0
    for i, hit in ipairs(pattern) do
        if hit == 1 then
            pattern_hits = pattern_hits + 1
            -- Calculate beat position for this step
            local step_beat = start_beat + (i - 1) * beats_per_step

            -- Apply swing for swing grid pattern (offset even steps)
            if params.pattern_type == 3 and i % 2 == 0 then
                step_beat = step_beat + (beats_per_step * swing_amount * 0.5)
            end

            -- Convert beat position back to time
            local step_position = reaper.TimeMap_QNToTime(step_beat)

            -- Calculate item length in beats, then convert to time
            local end_step_beat = start_beat + i * beats_per_step
            local next_step_time = reaper.TimeMap_QNToTime(end_step_beat)
            local step_duration = next_step_time - step_position
            local base_item_length = math.min(source_length, step_duration * 0.9)

            -- Randomly select a source item for each hit
            local random_source = source_items[math.random(#source_items)]
            local target_track = reaper.GetMediaItem_Track(random_source)

            -- Determine if this hit should be accented
            local is_accent = false
            if CONFIG.ACCENT_MODE and accent_pattern then
                is_accent = (accent_pattern[i] == 1)
            end

            local new_item = createItemCopy(random_source, target_track, step_position,
                          base_item_length, params.velocity_var, params.length_var, is_accent)

            if new_item then
                created_count = created_count + 1
            elseif CONFIG.DEBUG_MODE then
                reaper.ShowConsoleMsg(string.format("jtp gen: WARNING - Failed to create item at step %d\n", i))
            end
        end
    end

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: Pattern hits=%d, Items created=%d\n",
                              pattern_hits, created_count))
    end    -- Update and finish
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("jtp gen: Rhythmic Item Arranger", -1)

    if CONFIG.DEBUG_MODE then
        if created_count > 0 then
            reaper.ShowConsoleMsg(string.format("jtp gen: Successfully created %d items\n", created_count))
        else
            reaper.ShowConsoleMsg("jtp gen: WARNING - No items were created!\n")
        end
    end
end

-- Run the script
main()
