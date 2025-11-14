-- @description jtp gen: MIDI Note Arpeggiator
-- @author James
-- @version 1.0
-- @about
--   # MIDI Note Arpeggiator
--   Arpeggiates sustained notes in selected MIDI items
--   Currently supports up-down symmetrical arpeggiation
--   Designed to be extensible for additional arpeggiation modes

if not reaper then
    return
end

-- Arpeggiation modes (extensible for future additions)
local ARP_MODES = {
    UP_DOWN = 1,
    -- Future modes can be added here:
    -- UP = 2,
    -- DOWN = 3,
    -- RANDOM = 4,
    -- etc.
}

-- Configuration
local config = {
    arp_mode = ARP_MODES.UP_DOWN,
    arp_rate = 1/16,  -- 16th notes
    min_note_length = 1/16  -- Minimum note length to consider for arpeggiation
}

-- Get user input for arpeggiation settings
local function getUserInput()
    local retval, user_input = reaper.GetUserInputs(
        "jtp gen: MIDI Note Arpeggiator",
        3,
        "Arp Rate (1/4, 1/8, 1/16, 1/32):,Min Note Length (1/4, 1/8, 1/16):,Velocity Contour (0=off, 1=on):,extrawidth=200",
        "1/16,1/16,1"
    )

    if not retval then
        return nil
    end

    -- Parse input
    local rate_str, min_len_str, vel_contour_str = user_input:match("([^,]+),([^,]+),([^,]+)")

    -- Convert fraction strings to numbers
    local function parseFraction(str)
        str = str:match("^%s*(.-)%s*$")  -- trim whitespace
        local num, denom = str:match("(%d+)/(%d+)")
        if num and denom then
            return tonumber(num) / tonumber(denom)
        end
        return tonumber(str)
    end

    local arp_rate = parseFraction(rate_str)
    local min_length = parseFraction(min_len_str)
    local vel_contour = tonumber(vel_contour_str:match("^%s*(.-)%s*$"))

    if not arp_rate or not min_length then
        reaper.ShowMessageBox("Invalid input. Please use format like '1/16' or '0.0625'", "Error", 0)
        return nil
    end

    if not vel_contour or (vel_contour ~= 0 and vel_contour ~= 1) then
        reaper.ShowMessageBox("Velocity Contour must be 0 (off) or 1 (on)", "Error", 0)
        return nil
    end

    return {
        arp_rate = arp_rate,
        min_note_length = min_length,
        velocity_contour = vel_contour == 1
    }
end

-- Find overlapping notes at a given time position
local function findOverlappingNotes(notes, time_pos, tolerance)
    tolerance = tolerance or 0.0001
    local overlapping = {}

    for _, note in ipairs(notes) do
        if note.start_pos <= time_pos + tolerance and note.end_pos >= time_pos + tolerance then
            table.insert(overlapping, note)
        end
    end

    -- Sort by pitch
    table.sort(overlapping, function(a, b) return a.pitch < b.pitch end)

    return overlapping
end

-- Generate up-down symmetrical arpeggio pattern
local function generateUpDownPattern(num_notes)
    if num_notes <= 1 then
        return {1}
    end

    local pattern = {}

    -- Up
    for i = 1, num_notes do
        table.insert(pattern, i)
    end

    -- Down (excluding first and last to avoid repeats)
    for i = num_notes - 1, 2, -1 do
        table.insert(pattern, i)
    end

    return pattern
end

-- Calculate velocity for a position in the arpeggio pattern
local function calculateVelocityContour(pattern_position, pattern_length, base_velocity)
    -- Create a smooth contour: rise to peak, then fall back
    -- Pattern position is 1-indexed
    local normalized_pos = (pattern_position - 1) / (pattern_length - 1)

    -- Triangle wave: 0 -> 1 -> 0
    local contour
    if normalized_pos <= 0.5 then
        contour = normalized_pos * 2  -- Rise from 0 to 1
    else
        contour = (1 - normalized_pos) * 2  -- Fall from 1 to 0
    end

    -- Scale velocity: keep at least 50% of base velocity, peak at 100%
    local min_vel = base_velocity * 0.5
    local velocity = min_vel + (base_velocity - min_vel) * contour

    return math.floor(velocity + 0.5)  -- Round to nearest integer
end

-- Arpeggiate notes using the specified mode
local function arpeggiateNotes(notes, arp_rate, mode, velocity_contour)
    if #notes <= 1 then
        return notes  -- Nothing to arpeggiate
    end

    -- Find the time span for arpeggiation
    local start_time = math.huge
    local end_time = -math.huge

    for _, note in ipairs(notes) do
        start_time = math.min(start_time, note.start_pos)
        end_time = math.max(end_time, note.end_pos)
    end

    local duration = end_time - start_time
    local arp_length = arp_rate  -- Each arpeggiated note length

    -- Generate arpeggio pattern based on mode
    local pattern
    if mode == ARP_MODES.UP_DOWN then
        pattern = generateUpDownPattern(#notes)
    else
        pattern = generateUpDownPattern(#notes)  -- Default to up-down
    end

    -- Create new arpeggiated notes
    local new_notes = {}
    local current_time = start_time
    local pattern_index = 1
    local cycle_position = 1

    while current_time < end_time do
        local note_index = pattern[pattern_index]
        local original_note = notes[note_index]

        -- Calculate velocity with optional contouring
        local velocity = original_note.velocity
        if velocity_contour then
            velocity = calculateVelocityContour(cycle_position, #pattern, original_note.velocity)
        end

        local new_note = {
            start_pos = current_time,
            end_pos = math.min(current_time + arp_length, end_time),
            pitch = original_note.pitch,
            velocity = velocity,
            channel = original_note.channel,
            selected = original_note.selected,
            muted = original_note.muted
        }

        table.insert(new_notes, new_note)

        current_time = current_time + arp_length
        cycle_position = cycle_position + 1
        pattern_index = pattern_index + 1
        if pattern_index > #pattern then
            pattern_index = 1
            cycle_position = 1
        end
    end

    return new_notes
end

-- Process a single MIDI item
local function processMIDIItem(item, settings)
    local take = reaper.GetActiveTake(item)
    if not take then return false end
    if not reaper.TakeIsMIDI(take) then return false end

    -- Get tempo information
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local bpm = reaper.Master_GetTempo()
    local beat_length = 60.0 / bpm

    -- Convert settings to quarter note time
    local arp_rate_qn = settings.arp_rate * 4  -- Convert to quarter notes
    local min_length_qn = settings.min_note_length * 4

    -- Read all MIDI notes from the take
    local _, note_count = reaper.MIDI_CountEvts(take)
    local notes = {}

    for i = 0, note_count - 1 do
        local retval, selected, muted, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if retval then
            local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, start_ppq)
            local end_qn = reaper.MIDI_GetProjQNFromPPQPos(take, end_ppq)
            local length_qn = end_qn - start_qn

            -- Only process notes longer than minimum length
            if length_qn >= min_length_qn then
                table.insert(notes, {
                    index = i,
                    start_pos = start_qn,
                    end_pos = end_qn,
                    pitch = pitch,
                    velocity = vel,
                    channel = chan,
                    selected = selected,
                    muted = muted,
                    start_ppq = start_ppq,
                    end_ppq = end_ppq
                })
            end
        end
    end

    if #notes == 0 then
        return false
    end

    -- Sort notes by start position
    table.sort(notes, function(a, b) return a.start_pos < b.start_pos end)

    -- Find groups of overlapping notes and arpeggiate them
    local processed_indices = {}
    local new_notes_to_add = {}
    local notes_to_delete = {}

    for i, note in ipairs(notes) do
        if not processed_indices[i] then
            -- Find all notes that overlap with this note
            local overlapping = {}
            for j, other_note in ipairs(notes) do
                if not processed_indices[j] then
                    -- Check if notes overlap
                    if note.start_pos < other_note.end_pos and note.end_pos > other_note.start_pos then
                        table.insert(overlapping, other_note)
                        processed_indices[j] = true
                    end
                end
            end

            -- If we have overlapping notes (chords), arpeggiate them
            if #overlapping > 1 then
                local arpeggiated = arpeggiateNotes(overlapping, arp_rate_qn, settings.arp_mode, settings.velocity_contour)

                -- Mark original notes for deletion
                for _, orig_note in ipairs(overlapping) do
                    table.insert(notes_to_delete, orig_note.index)
                end

                -- Add new arpeggiated notes
                for _, new_note in ipairs(arpeggiated) do
                    table.insert(new_notes_to_add, new_note)
                end
            end
        end
    end

    if #notes_to_delete == 0 then
        return false  -- No sustained notes found
    end

    -- Delete original notes (in reverse order to maintain indices)
    table.sort(notes_to_delete, function(a, b) return a > b end)
    for _, idx in ipairs(notes_to_delete) do
        reaper.MIDI_DeleteNote(take, idx)
    end

    -- Add new arpeggiated notes
    for _, note in ipairs(new_notes_to_add) do
        local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.start_pos)
        local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, note.end_pos)

        reaper.MIDI_InsertNote(
            take,
            note.selected,
            note.muted,
            start_ppq,
            end_ppq,
            note.channel,
            note.pitch,
            note.velocity,
            true  -- no sort
        )
    end

    -- Sort the MIDI
    reaper.MIDI_Sort(take)

    return true
end

-- Main function
function main()
    -- Check if any items are selected
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then
        reaper.ShowMessageBox("Please select at least one MIDI item.", "jtp gen: No Items Selected", 0)
        return
    end

    -- Get user settings
    local settings = getUserInput()
    if not settings then
        return  -- User cancelled
    end

    -- Add mode to settings
    settings.arp_mode = config.arp_mode

    reaper.Undo_BeginBlock()

    local processed_count = 0

    -- Process each selected item
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if processMIDIItem(item, settings) then
            processed_count = processed_count + 1
        end
    end

    if processed_count == 0 then
        reaper.ShowMessageBox(
            "No sustained notes found to arpeggiate.\n\nMake sure your MIDI items contain notes longer than the minimum note length.",
            "jtp gen: No Notes Processed",
            0
        )
    else
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("jtp gen: Arpeggiate MIDI Notes (Up-Down)", -1)
    end
end

-- Run main function
main()
