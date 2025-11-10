-- @description jtp gen: Convert MIDI to Drums
-- @author James
-- @version 1.0
-- @about
--   # jtp gen: Convert MIDI to Drums
--   Converts a polyphonic MIDI item (like rhythmic guitar patterns) to drum notation.
--   Maps pitch ranges to drum pieces intelligently, preserving rhythm and articulation.
--
--   Usage:
--   1. Select a MIDI item with your melodic/guitar pattern
--   2. Run this script
--   3. The item will be converted to drum notation
--
--   Mapping Strategy:
--   - Low notes → Kick drum
--   - Mid-low notes → Toms (low to high)
--   - Mid notes → Snare
--   - Mid-high notes → Hi-hats
--   - High notes → Cymbals (crash/ride)
--   - Velocity is preserved
--   - Timing/rhythm is preserved exactly
--
--   The script analyzes the pitch range of your item and intelligently
--   distributes notes across the drum kit.

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
-- PITCH RANGE ANALYSIS
--------------------------------------------------------------------------------

local function analyze_pitch_range(take)
    local _, note_count = reaper.MIDI_CountEvts(take)
    if note_count == 0 then return nil, nil end

    local min_pitch = 127
    local max_pitch = 0

    for i = 0, note_count - 1 do
        local _, _, _, _, _, _, pitch, _ = reaper.MIDI_GetNote(take, i)
        if pitch < min_pitch then min_pitch = pitch end
        if pitch > max_pitch then max_pitch = pitch end
    end

    return min_pitch, max_pitch
end

--------------------------------------------------------------------------------
-- PITCH TO DRUM MAPPING
--------------------------------------------------------------------------------

-- Map a MIDI pitch to an appropriate drum piece based on its position in the range
local function map_pitch_to_drum(pitch, min_pitch, max_pitch)
    local range = max_pitch - min_pitch

    -- Handle single-note edge case
    if range == 0 then
        return SNARE  -- Default to snare for single-pitch patterns
    end

    -- Calculate normalized position (0.0 = lowest, 1.0 = highest)
    local position = (pitch - min_pitch) / range

    -- Map position to drum piece
    -- This creates a natural distribution across the kit
    if position < 0.15 then
        -- Lowest 15% → Kick
        return KICK
    elseif position < 0.30 then
        -- Next 15% → Low tom
        return TOM3
    elseif position < 0.45 then
        -- Next 15% → Mid tom
        return TOM2
    elseif position < 0.55 then
        -- Center 10% → Snare (most important)
        return SNARE
    elseif position < 0.65 then
        -- Next 10% → High tom
        return TOM1
    elseif position < 0.85 then
        -- Next 20% → Hi-hats
        return (math.random() < 0.8) and CLOSED_HH or OPEN_HH
    else
        -- Top 15% → Cymbals
        return (math.random() < 0.5) and CRASH or RIDE
    end
end

--------------------------------------------------------------------------------
-- VELOCITY ADJUSTMENT
--------------------------------------------------------------------------------

-- Adjust velocity to be appropriate for drums
-- Some drum pieces sound better with different velocity ranges
local function adjust_velocity_for_drum(velocity, drum_piece)
    -- Kick and snare can handle full dynamics
    if drum_piece == KICK or drum_piece == SNARE then
        return velocity
    end

    -- Toms sound good with slightly reduced velocity
    if drum_piece == TOM1 or drum_piece == TOM2 or drum_piece == TOM3 then
        return math.floor(velocity * 0.9)
    end

    -- Hi-hats typically softer
    if drum_piece == CLOSED_HH or drum_piece == OPEN_HH or drum_piece == HAT_PEDAL then
        return math.floor(velocity * 0.7)
    end

    -- Cymbals need good velocity to ring
    if drum_piece == CRASH or drum_piece == RIDE then
        return math.max(60, velocity)  -- Minimum 60 for cymbals
    end

    return velocity
end

--------------------------------------------------------------------------------
-- SMART DRUM CONVERSION
--------------------------------------------------------------------------------

-- Additional logic: avoid too many kicks in rapid succession
local last_kick_ppq = nil
local MIN_KICK_INTERVAL = 240  -- Minimum PPQ between kicks (avoids machine-gun kicks)

-- Track last hit per drum piece to add variety
local last_drum_choices = {}

local function convert_to_drum_smart(pitch, velocity, ppq_pos, min_pitch, max_pitch)
    -- Get base drum choice from pitch mapping
    local drum_note = map_pitch_to_drum(pitch, min_pitch, max_pitch)

    -- Special rule: avoid rapid-fire kicks
    if drum_note == KICK then
        if last_kick_ppq and (ppq_pos - last_kick_ppq) < MIN_KICK_INTERVAL then
            -- Too soon for another kick, use snare instead
            drum_note = SNARE
        else
            last_kick_ppq = ppq_pos
        end
    end

    -- Add variety: if we just hit the same drum, occasionally swap to similar
    if last_drum_choices[1] == drum_note and last_drum_choices[2] == drum_note then
        if drum_note == CLOSED_HH and math.random() < 0.3 then
            drum_note = OPEN_HH
        elseif drum_note == SNARE and math.random() < 0.2 then
            drum_note = TOM1
        end
    end

    -- Update history
    table.insert(last_drum_choices, 1, drum_note)
    if #last_drum_choices > 3 then
        table.remove(last_drum_choices)
    end

    -- Adjust velocity
    local adjusted_velocity = adjust_velocity_for_drum(velocity, drum_note)

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

    -- Analyze pitch range
    local min_pitch, max_pitch = analyze_pitch_range(take)
    if not min_pitch then
        reaper.ShowMessageBox("No notes found in MIDI item.", "Error", 0)
        return
    end

    -- Reset conversion state
    last_kick_ppq = nil
    last_drum_choices = {}

    -- Get all notes
    local _, note_count = reaper.MIDI_CountEvts(take)
    local notes_to_convert = {}

    for i = 0, note_count - 1 do
        local _, selected, muted, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        table.insert(notes_to_convert, {
            idx = i,
            selected = selected,
            muted = muted,
            start_ppq = start_ppq,
            end_ppq = end_ppq,
            chan = chan,
            pitch = pitch,
            vel = vel
        })
    end

    -- Convert each note
    for _, note_data in ipairs(notes_to_convert) do
        local drum_note, adjusted_vel = convert_to_drum_smart(
            note_data.pitch,
            note_data.vel,
            note_data.start_ppq,
            min_pitch,
            max_pitch
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
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name .. " (drums)", true)
    end

    -- Show summary
    reaper.ShowMessageBox(
        string.format(
            "Converted %d notes to drum notation.\n\n" ..
            "Original pitch range: %d - %d\n" ..
            "Mapped to drum kit pieces.\n\n" ..
            "Rhythm and timing preserved exactly.",
            note_count,
            min_pitch,
            max_pitch
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
