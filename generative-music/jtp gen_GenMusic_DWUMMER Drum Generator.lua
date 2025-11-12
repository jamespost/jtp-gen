-- @description jtp gen_GenMusic_DWUMMER Drum Generator
-- @author James
-- @version 1.0
-- @about
--   # DWUMMER Drum Generator
--   Implements Phase 0 and Phase 1 of the DWUMMER development plan.
--   Phase 0: Initialization, deterministic seed management, time conversion, and drum map lookup.
--   Phase 1: I/O Handler MVP - Creates a 4-bar MIDI item with a single kick drum hit on beat 1.

-- Check if reaper API is available
if not reaper then return end

-- Phase 0.1: Initialization
reaper.ShowConsoleMsg("DWUMMER Initialized\n")

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

-- Phase 1: I/O Handler MVP
function create_midi_item_with_kick()
    -- Task 1.1: Transactional Safety
    reaper.Undo_BeginBlock()

    -- Get the first selected track
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
        return
    end

    -- Task 1.2: Item Creation
    -- Get cursor position as start time
    local start_time = reaper.GetCursorPosition()

    -- Calculate 4-bar duration in quarter notes, then convert to seconds
    -- Assuming 4/4 time signature: 4 bars = 16 quarter notes
    local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
    local end_qn = start_qn + 16  -- 4 bars of 4/4 time
    local end_time = reaper.TimeMap2_QNToTime(0, end_qn)

    -- Create the MIDI item
    local item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
    if not item then
        reaper.ShowMessageBox("Failed to create MIDI item.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
        return
    end

    -- Get the active take
    local take = reaper.GetActiveTake(item)
    if not take then
        reaper.ShowMessageBox("Failed to get MIDI take.", "Error", 0)
        reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)
        return
    end

    -- Task 1.3: Note Insertion (Fixed)
    -- Insert a single Kick note (Pitch 36, Velocity 100) on beat 1 (PPQ 0)
    local pitch = DrumMap.KICK
    local velocity = 100
    local ppq_position = 0  -- Beat 1, at the start
    local note_length = TimeMap_QNToPPQ(0.25)  -- 16th note length

    -- Insert note with noSort = true
    reaper.MIDI_InsertNote(
        take,           -- take
        false,          -- selected
        false,          -- muted
        ppq_position,   -- ppqpos
        ppq_position + note_length,  -- endppqpos
        0,              -- channel (0-based, so channel 1)
        pitch,          -- pitch
        velocity,       -- velocity
        true            -- noSortInOptional
    )

    -- Task 1.4: Finalization
    -- Sort MIDI events after insertion
    reaper.MIDI_Sort(take)

    -- Update MIDI item appearance
    reaper.UpdateItemInProject(item)

    -- Task 1.1: End transaction
    reaper.Undo_EndBlock("jtp gen: DWUMMER Drum Generator", -1)

    reaper.ShowConsoleMsg("DWUMMER: Created 4-bar MIDI item with kick on beat 1\n")
end

-- Initialize with default seed and run
set_seed(12345)
create_midi_item_with_kick()
