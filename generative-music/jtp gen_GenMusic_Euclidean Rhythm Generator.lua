-- @description jtp gen: Euclidean Rhythm Generator
-- @author James
-- @version 1.0
-- @about
--   # Euclidean Rhythm Generator
--
--   ## Description
--   Generates Euclidean rhythms (evenly distributed rhythmic patterns)
--   on selected MIDI items. Based on Bjorklund's algorithm.
--
--   ## Usage
--   1. Select a MIDI item
--   2. Run the script
--   3. Enter: number of hits, total steps, and rotation
--
--   ## Examples
--   - 3,8,0 = Standard tresillo pattern
--   - 5,8,0 = Typical Cuban cinquillo
--   - 7,12,0 = Common West African bell pattern

if not reaper then
    return
end

-- Euclidean algorithm for rhythm generation
local function euclideanRhythm(hits, steps, rotation)
    rotation = rotation or 0

    if hits >= steps then
        local pattern = {}
        for i = 1, steps do
            pattern[i] = 1
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

local function getUserInput()
    local retval, user_input = reaper.GetUserInputs(
        "jtp gen: Euclidean Rhythm Generator",
        4,
        "Number of hits:,Total steps:,Rotation (0-steps):,Note (C=60):",
        "5,8,0,36"
    )

    if not retval then
        return nil
    end

    local hits, steps, rotation, note = user_input:match("([^,]+),([^,]+),([^,]+),([^,]+)")

    return {
        hits = tonumber(hits) or 5,
        steps = tonumber(steps) or 8,
        rotation = tonumber(rotation) or 0,
        note = tonumber(note) or 36
    }
end

function main()
    local params = getUserInput()
    if not params then
        return
    end

    reaper.Undo_BeginBlock()

    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        reaper.ShowMessageBox("Please select a MIDI item first.", "jtp gen: Euclidean Rhythm", 0)
        return
    end

    local take = reaper.GetActiveTake(item)
    if not take or not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox("Selected item is not a MIDI item.", "jtp gen: Euclidean Rhythm", 0)
        return
    end

    -- Generate pattern
    local pattern = euclideanRhythm(params.hits, params.steps, params.rotation)

    -- Insert notes
    local ppq_per_beat = reaper.MIDI_GetPPQPosFromProjTime(take, 1.0)
    local step_length = ppq_per_beat / 4  -- 16th notes

    for i, hit in ipairs(pattern) do
        if hit == 1 then
            local start_ppq = (i - 1) * step_length
            local end_ppq = start_ppq + step_length * 0.8  -- Slight gap
            reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, 0, params.note, 96, false)
        end
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()

    reaper.ShowConsoleMsg("jtp gen: Generated Euclidean rhythm [" .. params.hits .. "," .. params.steps .. "]\n")

    reaper.Undo_EndBlock("jtp gen: Euclidean Rhythm Generator", -1)
end

main()
