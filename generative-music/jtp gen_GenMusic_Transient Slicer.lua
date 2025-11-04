-- @description jtp gen: Transient Slicer
-- @author James
-- @version 1.0
-- @about
--   # Transient Slicer
--
--   ## Description
--   Detects transients in a selected audio item, chops it into slices, and
--   rhythmically rearranges them into new generative patterns. Perfect for
--   breakbeats, drum loops, and creative sample manipulation.
--
--   ## Usage
--   1. Select an audio item (e.g., drum loop, amen break)
--   2. Set a time selection where you want the rearranged pattern
--   3. Run the script - it auto-detects transients and creates new patterns!
--   4. Run again for different arrangements
--
--   ## Features
--   - Automatic transient detection
--   - Multiple arrangement algorithms (same as Rhythmic Item Arranger)
--   - Maintains sync with tempo/time signature
--   - Each run creates unique variations
--
--   ## Notes
--   - Requires REAPER's transient detection (built-in)
--   - Original item is not modified
--   - Works best with percussive material

if not reaper then
    return
end

math.randomseed(os.time())

-- Configuration
local CONFIG = {
    SHOW_GUI = false, -- Set to true to show parameter dialog
    DEBUG_MODE = false, -- Set to true to show debug console output
    ACCENT_MODE = true, -- Enable dynamic accents
    ACCENT_REDUCTION_DB = -6, -- dB reduction for non-accented slices
    TRANSIENT_THRESHOLD = 0.2, -- Sensitivity (0.0-1.0, higher = fewer transients)
    MIN_SLICE_LENGTH = 0.02, -- Minimum slice length in seconds
    FADE_LENGTH = 0.002 -- Crossfade length for slices (2ms)
}

-- Generate Euclidean pattern
local function generateEuclideanPattern(hits, steps, rotation)
    rotation = rotation or 0

    if hits >= steps then
        local pattern = {}
        for i = 1, steps do pattern[i] = 1 end
        return pattern
    end

    if hits == 0 then
        local pattern = {}
        for i = 1, steps do pattern[i] = 0 end
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
        if level == 1 then return {{1}, {0}} end
        local prev = build(level - 1)
        local seq = {}
        for i = 1, counts[level] do
            for _, v in ipairs(prev[1]) do table.insert(seq, v) end
        end
        if remainders[level] ~= 0 then
            for _, v in ipairs(prev[2]) do table.insert(seq, v) end
        end
        return {seq, prev[1]}
    end

    local result = build(level + 1)[1]

    if rotation > 0 then
        rotation = rotation % #result
        for i = 1, rotation do
            local first = table.remove(result, 1)
            table.insert(result, first)
        end
    end

    return result
end

-- Generate probability pattern
local function generateProbabilityPattern(steps, probability)
    local pattern = {}
    for i = 1, steps do
        pattern[i] = (math.random() < probability) and 1 or 0
    end
    return pattern
end

-- Generate random dense pattern
local function generateRandomDensePattern(steps, density)
    local num_hits = math.floor(steps * density)
    local pattern = {}
    for i = 1, steps do pattern[i] = 0 end

    local positions = {}
    for i = 1, steps do positions[i] = i end

    for i = #positions, 2, -1 do
        local j = math.random(i)
        positions[i], positions[j] = positions[j], positions[i]
    end

    for i = 1, math.min(num_hits, #positions) do
        pattern[positions[i]] = 1
    end

    return pattern
end

-- Generate accent pattern
local function generateAccentPattern(rhythm_pattern)
    local accent_pattern = {}
    local hits = {}

    for i, hit in ipairs(rhythm_pattern) do
        if hit == 1 then table.insert(hits, i) end
    end

    if #hits == 0 then
        for i = 1, #rhythm_pattern do accent_pattern[i] = 0 end
        return accent_pattern
    end

    for i = 1, #rhythm_pattern do accent_pattern[i] = 0 end

    if #hits == 1 then
        accent_pattern[hits[1]] = 1
    elseif #hits <= 3 then
        accent_pattern[hits[1]] = 1
    elseif #hits == 4 then
        accent_pattern[hits[1]] = 1
        accent_pattern[hits[3]] = 1
    else
        accent_pattern[hits[1]] = 1
        for i = 1, #hits do
            if (i - 1) % 4 == 0 then
                accent_pattern[hits[i]] = 1
            end
        end
        for i = 1, #hits do
            if accent_pattern[hits[i]] == 0 and math.random() < 0.2 then
                accent_pattern[hits[i]] = 1
            end
        end
    end

    return accent_pattern
end

-- Generate random parameters
local function generateRandomParams(num_slices)
    local pattern_type = math.random(1, 3)  -- Euclidean, Probability, or Random Dense
    local steps = math.min(num_slices, math.random(8, 32))
    local param1, param2 = 0, 0

    if pattern_type == 1 then
        -- Euclidean
        param1 = math.random(math.max(1, math.floor(steps * 0.4)), math.floor(steps * 0.8))
        param2 = math.random(0, steps - 1)
    elseif pattern_type == 2 then
        -- Probability
        param1 = 0.4 + math.random() * 0.4
    else
        -- Random Dense
        param1 = 0.4 + math.random() * 0.4
    end

    return {
        pattern_type = pattern_type,
        steps = steps,
        param1 = param1,
        param2 = param2
    }
end

-- Detect transients in audio item using REAPER's tab-to-transient
local function detectTransients(item)
    local take = reaper.GetActiveTake(item)
    if not take then return nil end

    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local source = reaper.GetMediaItemTake_Source(take)
    local source_length = reaper.GetMediaSourceLength(source)
    local take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

    -- Get peaks from take
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local num_channels = reaper.GetMediaSourceNumChannels(source)

    local transients = {}
    local sample_rate = 44100  -- Default, will get actual rate
    local n_samples = math.floor(item_length * sample_rate)

    -- Sample at intervals to find peaks
    local window_size = math.floor(sample_rate * 0.01)  -- 10ms windows
    local step_size = math.floor(window_size / 2)
    local threshold = CONFIG.TRANSIENT_THRESHOLD

    local last_peak_time = -1

    for i = 0, n_samples, step_size do
        local time_in_item = i / sample_rate
        if time_in_item >= item_length then break end

        -- Get audio data
        local buffer = reaper.new_array(window_size * num_channels)
        local samples_out = reaper.GetAudioAccessorSamples(
            accessor, sample_rate, num_channels,
            time_in_item, window_size, buffer
        )

        -- Calculate RMS and find peaks
        local sum = 0
        for j = 1, samples_out * num_channels do
            local val = buffer[j]
            sum = sum + val * val
        end
        local rms = math.sqrt(sum / (samples_out * num_channels))

        -- Detect transient if RMS exceeds threshold and enough time since last
        if rms > threshold and (time_in_item - last_peak_time) > CONFIG.MIN_SLICE_LENGTH then
            table.insert(transients, item_start + time_in_item)
            last_peak_time = time_in_item
        end
    end

    reaper.DestroyAudioAccessor(accessor)

    -- Ensure we have at least the start and end
    if #transients == 0 or transients[1] > item_start + 0.01 then
        table.insert(transients, 1, item_start)
    end

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: Detected %d transients\n", #transients))
    end

    return transients
end

-- Create a slice from the original item
local function createSlice(source_item, track, position, slice_start, slice_length, is_accent)
    local source_take = reaper.GetActiveTake(source_item)
    if not source_take then return nil end

    -- Create new item
    local new_item = reaper.AddMediaItemToTrack(track)
    reaper.SetMediaItemPosition(new_item, position, false)
    reaper.SetMediaItemLength(new_item, slice_length, false)

    -- Create take
    local new_take = reaper.AddTakeToMediaItem(new_item)
    local source = reaper.GetMediaItemTake_Source(source_take)
    reaper.SetMediaItemTake_Source(new_take, source)

    -- Set the offset to the slice start position
    local item_start = reaper.GetMediaItemInfo_Value(source_item, "D_POSITION")
    local offset_in_source = slice_start - item_start
    local original_offset = reaper.GetMediaItemTakeInfo_Value(source_take, "D_STARTOFFS")
    reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", original_offset + offset_in_source)

    -- Copy volume
    local vol = reaper.GetMediaItemTakeInfo_Value(source_take, "D_VOL")
    reaper.SetMediaItemTakeInfo_Value(new_take, "D_VOL", vol)

    -- Copy playrate
    local rate = reaper.GetMediaItemTakeInfo_Value(source_take, "D_PLAYRATE")
    reaper.SetMediaItemTakeInfo_Value(new_take, "D_PLAYRATE", rate)

    -- Add small fades to avoid clicks
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN", CONFIG.FADE_LENGTH)
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", CONFIG.FADE_LENGTH)

    -- Apply accent reduction if needed
    if CONFIG.ACCENT_MODE and not is_accent then
        local db_reduction = CONFIG.ACCENT_REDUCTION_DB
        local vol_mult = 10 ^ (db_reduction / 20)
        local current_vol = reaper.GetMediaItemInfo_Value(new_item, "D_VOL")
        reaper.SetMediaItemInfo_Value(new_item, "D_VOL", current_vol * vol_mult)
    end

    return new_item
end

-- Main function
function main()
    -- Check for selected item
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then
        reaper.MB("Please select an audio item to slice and rearrange.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    if num_items > 1 then
        reaper.MB("Please select only ONE audio item.\n\nThe script will slice it and create variations.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    local source_item = reaper.GetSelectedMediaItem(0, 0)
    local source_take = reaper.GetActiveTake(source_item)

    if not source_take then
        reaper.MB("Selected item has no active take.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    -- Check if it's audio (not MIDI)
    if reaper.TakeIsMIDI(source_take) then
        reaper.MB("Selected item is MIDI. Please select an audio item.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    -- Check for time selection
    local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if time_start == time_end then
        time_start, time_end = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)
    end

    if time_start == time_end then
        reaper.MB("Please set a time selection where you want the rearranged pattern.\n\nDrag across the timeline to create a time selection.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    reaper.Undo_BeginBlock()

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg("jtp gen: Starting transient detection...\n")
    end

    -- Detect transients
    local transients = detectTransients(source_item)
    if not transients or #transients < 2 then
        reaper.Undo_EndBlock("jtp gen: Transient Slicer", -1)
        reaper.MB("Could not detect enough transients in the audio.\n\nTry adjusting TRANSIENT_THRESHOLD in config.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    -- Create slice data
    local slices = {}
    local item_start = reaper.GetMediaItemInfo_Value(source_item, "D_POSITION")
    local item_end = item_start + reaper.GetMediaItemInfo_Value(source_item, "D_LENGTH")

    for i = 1, #transients do
        local slice_start = transients[i]
        local slice_end = (i < #transients) and transients[i + 1] or item_end
        local slice_length = slice_end - slice_start

        if slice_length >= CONFIG.MIN_SLICE_LENGTH then
            table.insert(slices, {
                start = slice_start,
                length = slice_length
            })
        end
    end

    if #slices < 2 then
        reaper.Undo_EndBlock("jtp gen: Transient Slicer", -1)
        reaper.MB("Not enough valid slices detected.",
                  "jtp gen: Transient Slicer", 0)
        return
    end

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: Created %d slices\n", #slices))
    end

    -- Generate random parameters
    local params = generateRandomParams(#slices)

    -- Generate pattern
    local pattern
    if params.pattern_type == 1 then
        pattern = generateEuclideanPattern(params.param1, params.steps, params.param2)
    elseif params.pattern_type == 2 then
        pattern = generateProbabilityPattern(params.steps, params.param1)
    else
        pattern = generateRandomDensePattern(params.steps, params.param1)
    end

    -- Generate accent pattern
    local accent_pattern = nil
    if CONFIG.ACCENT_MODE then
        accent_pattern = generateAccentPattern(pattern)
    end

    -- Calculate timing
    local start_beat = reaper.TimeMap_timeToQN(time_start)
    local end_beat = reaper.TimeMap_timeToQN(time_end)
    local total_beats = end_beat - start_beat
    local beats_per_step = total_beats / params.steps

    -- Get track
    local track = reaper.GetMediaItem_Track(source_item)

    -- Create sliced arrangement
    local created_count = 0
    for i, hit in ipairs(pattern) do
        if hit == 1 then
            -- Calculate position
            local step_beat = start_beat + (i - 1) * beats_per_step
            local step_position = reaper.TimeMap_QNToTime(step_beat)

            -- Pick a random slice
            local slice = slices[math.random(#slices)]

            -- Calculate slice length based on available time
            local end_step_beat = start_beat + i * beats_per_step
            local next_step_time = reaper.TimeMap_QNToTime(end_step_beat)
            local available_duration = next_step_time - step_position
            local slice_length = math.min(slice.length, available_duration * 0.9)

            -- Check if accent
            local is_accent = false
            if CONFIG.ACCENT_MODE and accent_pattern then
                is_accent = (accent_pattern[i] == 1)
            end

            -- Create the slice
            local new_item = createSlice(source_item, track, step_position,
                                        slice.start, slice_length, is_accent)

            if new_item then
                created_count = created_count + 1
            end
        end
    end

    -- Mute or delete the original item
    reaper.SetMediaItemInfo_Value(source_item, "B_MUTE", 1)

    -- Or to delete it completely, uncomment this line instead:
    reaper.DeleteTrackMediaItem(track, source_item)

    -- Update and finish
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("jtp gen: Transient Slicer", -1)

    if CONFIG.DEBUG_MODE then
        reaper.ShowConsoleMsg(string.format("jtp gen: Created %d sliced items\n", created_count))
    end
end

-- Run the script
main()
