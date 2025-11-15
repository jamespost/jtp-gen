-- @description jtp gen: Example - Chord Progression to Guitar Picking
-- @author James
-- @version 1.0
-- @about
--   # Example Workflow Script
--   Demonstrates combining Chord Progression Generator with Guitar Picking Transformer
--
--   This example shows how to:
--   1. Generate a chord progression programmatically
--   2. Transform it into guitar picking patterns
--   3. Create complete guitar arrangements
--
--   This is a REFERENCE/EXAMPLE - modify for your needs!

if not reaper then return end

-- Example: Create a simple chord progression on selected track
-- Then you'd manually run the Guitar Picking Transformer on the result

function createExampleChordProgression()
    -- Get selected track
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first!", "Error", 0)
        return
    end

    -- Get current edit cursor position
    local cursor_pos = reaper.GetCursorPosition()

    -- Chord voicings (MIDI note numbers)
    -- C major, A minor, F major, G major
    local chord_progression = {
        {60, 64, 67, 72},  -- C major (C, E, G, C)
        {57, 60, 64, 69},  -- A minor (A, C, E, A)
        {53, 57, 60, 65},  -- F major (F, A, C, F)
        {55, 59, 62, 67},  -- G major (G, B, D, G)
    }

    -- Create MIDI item
    local item = reaper.CreateNewMIDIItemInProj(track, cursor_pos, cursor_pos + 8)
    local take = reaper.GetActiveTake(item)

    if not take then
        reaper.ShowMessageBox("Failed to create MIDI item", "Error", 0)
        return
    end

    -- Insert chords (each 2 beats long)
    local beat_duration = 60.0 / reaper.Master_GetTempo()  -- seconds per beat

    for i, chord in ipairs(chord_progression) do
        local start_time = cursor_pos + ((i - 1) * 2 * beat_duration)
        local end_time = start_time + (2 * beat_duration)

        -- Convert to QN and PPQ
        local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
        local end_qn = reaper.TimeMap2_timeToQN(0, end_time)

        local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn)
        local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, end_qn)

        -- Insert each note in the chord
        for _, note_pitch in ipairs(chord) do
            reaper.MIDI_InsertNote(
                take,
                false,  -- not selected
                false,  -- not muted
                start_ppq,
                end_ppq,
                0,      -- channel 0
                note_pitch,
                80,     -- velocity
                true    -- no sort yet
            )
        end
    end

    -- Sort MIDI
    reaper.MIDI_Sort(take)

    -- Select the item so it's ready for transformation
    reaper.SetMediaItemSelected(item, true)

    reaper.UpdateArrange()

    reaper.ShowMessageBox(
        "Chord progression created!\n\n" ..
        "Next step:\n" ..
        "Run 'jtp gen_GenMusic_Guitar Picking Transformer.lua'\n" ..
        "to transform these chords into picking patterns.",
        "Example Complete",
        0
    )
end

-- Main execution
reaper.Undo_BeginBlock()
createExampleChordProgression()
reaper.Undo_EndBlock("jtp gen: Create Example Chord Progression", -1)
