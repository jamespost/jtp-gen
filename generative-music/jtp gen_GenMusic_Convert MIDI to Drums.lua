-- @description jtp gen: Convert MIDI to Drums
-- @author James
-- @version 2.0
-- @about
--   # jtp gen: Convert MIDI to Drums
--   Converts a polyphonic MIDI item (like rhythmic guitar patterns) to drum notation.
--   Uses INTENSITY-BASED mapping: velocity and note length/density determine drum choices.
--
--   Usage:
--   1. Select a MIDI item with your melodic/guitar pattern
--   2. Run this script
--   3. The item will be converted to drum notation
--
--   Mapping Strategy (Intensity-Based):
--   HIGH INTENSITY (long notes, high velocity):
--     - Kick, Snare, Crash/Ride cymbals
--     - Bold, powerful drum hits
--
--   MEDIUM INTENSITY (medium length/velocity):
--     - Snare, Toms, Mix of drums
--     - Balanced drum palette
--
--   LOW INTENSITY (short notes, low velocity):
--     - Hi-hats (closed/open), light snare touches
--     - Kicks interspersed for groove
--     - Fast, detailed patterns
--
--   The script analyzes note length and velocity to create dynamic,
--   expressive drum parts that match the energy of your input.

-- Check if reaper API is available
if not reaper then return end

--------------------------------------------------------------------------------
-- DRUM NOTE MAPPINGS (General MIDI standard)
--------------------------------------------------------------------------------

local KICK      = 36  -- Bass drum
local SNARE     = 38  -- Acoustic snare
local TOM1      = 48  -- Hi tom
local TOM2      = 47  -- Mid tom
local TOM3      = 45  -- Low tom
local CLOSED_HH = 42  -- Closed hi-hat
local OPEN_HH   = 46  -- Open hi-hat
local CRASH     = 49  -- Crash cymbal
local RIDE      = 51  -- Ride cymbal
local HAT_PEDAL = 44  -- Pedal hi-hat

-- Drum pieces organized by typical pitch function
local drum_pieces = {
    low = {KICK},                              -- Lowest notes
    tom_low = {TOM3},                          -- Low-mid
    tom_mid = {TOM2},                          -- Mid
    tom_high = {TOM1},                         -- Mid-high
    snare = {SNARE},                           -- Central
    hihat = {CLOSED_HH, OPEN_HH},             -- High
    cymbal = {CRASH, RIDE}                     -- Highest
}

--------------------------------------------------------------------------------
-- INTENSITY ANALYSIS
--------------------------------------------------------------------------------

-- Analyze velocity and note length characteristics of the MIDI item
local function analyze_intensity_characteristics(take)
    local _, note_count = reaper.MIDI_CountEvts(take)
    if note_count == 0 then return nil end

    local total_velocity = 0
    local total_length_ppq = 0
    local min_velocity = 127
    local max_velocity = 0
    local min_length = math.huge
    local max_length = 0

    -- Collect all note data
    local notes = {}
    for i = 0, note_count - 1 do
        local _, _, _, start_ppq, end_ppq, _, pitch, vel = reaper.MIDI_GetNote(take, i)
        local length = end_ppq - start_ppq

        table.insert(notes, {
            start_ppq = start_ppq,
            length = length,
            velocity = vel,
            pitch = pitch
        })

        total_velocity = total_velocity + vel
        total_length_ppq = total_length_ppq + length

        if vel < min_velocity then min_velocity = vel end
        if vel > max_velocity then max_velocity = vel end
        if length < min_length then min_length = length end
        if length > max_length then max_length = length end
    end

    -- Calculate averages and density
    local avg_velocity = total_velocity / note_count
    local avg_length = total_length_ppq / note_count

    -- Calculate note density (notes per quarter note)
    -- Get item length in PPQ
    local item_start_ppq = notes[1].start_ppq
    local item_end_ppq = notes[1].start_ppq
    for _, note in ipairs(notes) do
        if note.start_ppq < item_start_ppq then item_start_ppq = note.start_ppq end
        if note.start_ppq > item_end_ppq then item_end_ppq = note.start_ppq end
    end
    local item_length_ppq = item_end_ppq - item_start_ppq
    local density = note_count / (item_length_ppq / 960)  -- Notes per quarter note

    return {
        avg_velocity = avg_velocity,
        avg_length = avg_length,
        min_velocity = min_velocity,
        max_velocity = max_velocity,
        min_length = min_length,
        max_length = max_length,
        density = density,
        note_count = note_count
    }
end

--------------------------------------------------------------------------------
-- INTENSITY TO DRUM MAPPING
--------------------------------------------------------------------------------

-- Calculate intensity score for a single note based on velocity and length
-- Returns 0.0 (low intensity) to 1.0 (high intensity)
local function calculate_note_intensity(velocity, length_ppq, stats)
    -- Normalize velocity (0.0 to 1.0)
    local vel_range = stats.max_velocity - stats.min_velocity
    local vel_normalized = 0.5  -- Default if no range
    if vel_range > 0 then
        vel_normalized = (velocity - stats.min_velocity) / vel_range
    end

    -- Normalize length (0.0 to 1.0)
    local len_range = stats.max_length - stats.min_length
    local len_normalized = 0.5  -- Default if no range
    if len_range > 0 then
        len_normalized = (length_ppq - stats.min_length) / len_range
    end

    -- Intensity is weighted combination (velocity matters more)
    -- 70% velocity, 30% length
    local intensity = (vel_normalized * 0.7) + (len_normalized * 0.3)

    return intensity
end

-- Map intensity to drum piece
-- HIGH intensity → powerful drums (kick, snare, cymbals)
-- LOW intensity → detailed drums (hi-hats, light touches)
local function map_intensity_to_drum(intensity, pitch, stats, prev_drum)
    -- Use pitch as a secondary factor for variety within intensity range
    local pitch_factor = (pitch % 12) / 12  -- Normalize to 0-1 based on pitch class

    -- HIGH INTENSITY (0.65 - 1.0): Powerful hits
    if intensity >= 0.65 then
        local r = math.random()
        if r < 0.35 then
            return KICK  -- 35% kick
        elseif r < 0.70 then
            return SNARE  -- 35% snare
        elseif r < 0.85 then
            return CRASH  -- 15% crash
        else
            return RIDE  -- 15% ride
        end

    -- MEDIUM-HIGH INTENSITY (0.45 - 0.65): Mix with toms
    elseif intensity >= 0.45 then
        local r = math.random()
        if r < 0.30 then
            return SNARE  -- 30% snare
        elseif r < 0.50 then
            return KICK  -- 20% kick
        elseif r < 0.70 then
            -- Choose tom based on pitch
            if pitch_factor < 0.33 then
                return TOM3  -- Low tom
            elseif pitch_factor < 0.66 then
                return TOM2  -- Mid tom
            else
                return TOM1  -- High tom
            end
        else
            return CLOSED_HH  -- 30% hi-hat
        end

    -- MEDIUM-LOW INTENSITY (0.25 - 0.45): Hi-hat focused with rhythm
    elseif intensity >= 0.25 then
        local r = math.random()
        if r < 0.50 then
            return CLOSED_HH  -- 50% closed hi-hat
        elseif r < 0.65 then
            return SNARE  -- 15% snare
        elseif r < 0.80 then
            return KICK  -- 15% kick for groove
        elseif r < 0.90 then
            return OPEN_HH  -- 10% open hi-hat
        else
            return TOM1  -- 10% high tom
        end

    -- LOW INTENSITY (0.0 - 0.25): Fast, detailed hi-hat work
    else
        local r = math.random()
        if r < 0.60 then
            return CLOSED_HH  -- 60% closed hi-hat
        elseif r < 0.75 then
            return OPEN_HH  -- 15% open hi-hat
        elseif r < 0.90 then
            return KICK  -- 15% kick (for groove anchoring)
        else
            return SNARE  -- 10% light snare
        end
    end
end

--------------------------------------------------------------------------------
-- VELOCITY ADJUSTMENT FOR DRUMS
--------------------------------------------------------------------------------

-- Adjust velocity based on drum piece and original intensity
local function adjust_velocity_for_drum(velocity, drum_piece, intensity)
    -- High intensity notes should remain powerful
    if intensity >= 0.65 then
        if drum_piece == KICK or drum_piece == SNARE then
            return math.max(80, velocity)  -- Ensure minimum power
        elseif drum_piece == CRASH or drum_piece == RIDE then
            return math.max(70, velocity)  -- Cymbals need good attack
        end
    end

    -- Low intensity notes should be subtle
    if intensity < 0.25 then
        if drum_piece == CLOSED_HH or drum_piece == OPEN_HH then
            return math.min(70, math.floor(velocity * 0.6))  -- Quiet hi-hats
        elseif drum_piece == KICK then
            return math.min(60, math.floor(velocity * 0.7))  -- Light kick touches
        end
    end

    -- Standard adjustments
    if drum_piece == KICK or drum_piece == SNARE then
        return velocity  -- Full dynamics
    elseif drum_piece == TOM1 or drum_piece == TOM2 or drum_piece == TOM3 then
        return math.floor(velocity * 0.9)
    elseif drum_piece == CLOSED_HH or drum_piece == OPEN_HH then
        return math.floor(velocity * 0.7)
    elseif drum_piece == CRASH or drum_piece == RIDE then
        return math.max(60, velocity)
    end

    return velocity
end

--------------------------------------------------------------------------------
-- SMART DRUM CONVERSION WITH INTENSITY
--------------------------------------------------------------------------------

-- State tracking
local last_kick_ppq = nil
local MIN_KICK_INTERVAL = 240  -- Minimum PPQ between kicks
local last_drum_choices = {}
local kick_accent_every = 4  -- Accent every Nth kick for groove
local kick_count = 0

local function convert_to_drum_intensity_based(pitch, velocity, length_ppq, ppq_pos, stats)
    -- Calculate intensity for this note
    local intensity = calculate_note_intensity(velocity, length_ppq, stats)

    -- Get base drum choice from intensity mapping
    local prev_drum = last_drum_choices[1]
    local drum_note = map_intensity_to_drum(intensity, pitch, stats, prev_drum)

    -- Special rule: avoid rapid-fire kicks (but allow for fast low-intensity patterns)
    if drum_note == KICK then
        if last_kick_ppq and (ppq_pos - last_kick_ppq) < MIN_KICK_INTERVAL then
            -- Too soon for another kick
            if intensity >= 0.5 then
                drum_note = SNARE  -- High intensity → snare
            else
                drum_note = CLOSED_HH  -- Low intensity → hi-hat
            end
        else
            last_kick_ppq = ppq_pos
            kick_count = kick_count + 1
        end
    end

    -- Add variety: avoid too much repetition
    if last_drum_choices[1] == drum_note and
       last_drum_choices[2] == drum_note and
       last_drum_choices[3] == drum_note then
        -- Three in a row, add variety
        if drum_note == CLOSED_HH and math.random() < 0.4 then
            drum_note = OPEN_HH
        elseif drum_note == SNARE and intensity < 0.5 and math.random() < 0.3 then
            drum_note = CLOSED_HH
        elseif drum_note == KICK and math.random() < 0.5 then
            drum_note = SNARE
        end
    end

    -- Update history
    table.insert(last_drum_choices, 1, drum_note)
    if #last_drum_choices > 4 then
        table.remove(last_drum_choices)
    end

    -- Adjust velocity based on drum and intensity
    local adjusted_velocity = adjust_velocity_for_drum(velocity, drum_note, intensity)

    return drum_note, adjusted_velocity
end

--------------------------------------------------------------------------------
-- MAIN CONVERSION FUNCTION
--------------------------------------------------------------------------------

local function convert_midi_to_drums()
    -- Get selected item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        reaper.ShowMessageBox("Please select a MIDI item first.", "No Item Selected", 0)
        return
    end

    -- Get active take
    local take = reaper.GetActiveTake(item)
    if not take then
        reaper.ShowMessageBox("Selected item has no active take.", "Error", 0)
        return
    end

    -- Verify it's a MIDI take
    if not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox("Selected item is not a MIDI item.", "Error", 0)
        return
    end

    -- Analyze intensity characteristics
    local stats = analyze_intensity_characteristics(take)
    if not stats then
        reaper.ShowMessageBox("No notes found in MIDI item.", "Error", 0)
        return
    end

    -- Reset conversion state
    last_kick_ppq = nil
    last_drum_choices = {}
    kick_count = 0

    -- Get all notes
    local _, note_count = reaper.MIDI_CountEvts(take)
    local notes_to_convert = {}

    for i = 0, note_count - 1 do
        local _, selected, muted, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        local length_ppq = end_ppq - start_ppq

        table.insert(notes_to_convert, {
            idx = i,
            selected = selected,
            muted = muted,
            start_ppq = start_ppq,
            end_ppq = end_ppq,
            length_ppq = length_ppq,
            chan = chan,
            pitch = pitch,
            vel = vel
        })
    end

    -- Convert each note using intensity-based mapping
    for _, note_data in ipairs(notes_to_convert) do
        local drum_note, adjusted_vel = convert_to_drum_intensity_based(
            note_data.pitch,
            note_data.vel,
            note_data.length_ppq,
            note_data.start_ppq,
            stats
        )

        -- Update the note in place
        reaper.MIDI_SetNote(
            take,
            note_data.idx,
            note_data.selected,
            note_data.muted,
            note_data.start_ppq,
            note_data.end_ppq,
            0,  -- Channel 0 for drums
            drum_note,
            adjusted_vel,
            false
        )
    end

    -- Sort MIDI to ensure proper ordering
    reaper.MIDI_Sort(take)

    -- Update display
    reaper.UpdateItemInProject(item)

    -- Rename take to indicate conversion
    local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not take_name:match("%(drums%)") then
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name .. " (intensity drums)", true)
    end

    -- Show summary with intensity stats
    reaper.ShowMessageBox(
        string.format(
            "Converted %d notes to drum notation (Intensity-Based).\n\n" ..
            "Avg Velocity: %.1f\n" ..
            "Avg Note Length: %.0f PPQ\n" ..
            "Note Density: %.2f notes/quarter\n\n" ..
            "Mapping:\n" ..
            "• High intensity (long+loud) → Kick, Snare, Cymbals\n" ..
            "• Low intensity (short+quiet) → Hi-hats, light touches\n\n" ..
            "Rhythm and timing preserved exactly.",
            note_count,
            stats.avg_velocity,
            stats.avg_length,
            stats.density
        ),
        "Conversion Complete",
        0
    )
end

--------------------------------------------------------------------------------
-- SCRIPT ENTRY POINT
--------------------------------------------------------------------------------

reaper.Undo_BeginBlock()
convert_midi_to_drums()
reaper.Undo_EndBlock("jtp gen: Convert MIDI to Drums", -1)
reaper.UpdateArrange()
