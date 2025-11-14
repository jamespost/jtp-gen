-- @description jtp gen: Glue Items and Map to RS5K Starting from MIDI Note 36
-- @author James
-- @version 1.0
-- @about
--   # Description
--   Glues selected media items individually, creates a new track with RS5K instances,
--   and maps samples starting from MIDI note 36 (C1) ascending for each item.
--   Retains all original functionality including track creation, RS5K setup, and sample mapping.

-- Check if reaper API is available
if not reaper then
    return
end

-- Helper function to find parameter index by name
local function find_param_by_name(track, fx_idx, target_name)
  local num_params = reaper.TrackFX_GetNumParams(track, fx_idx)
  for i = 0, num_params - 1 do
    local _, name = reaper.TrackFX_GetParamName(track, fx_idx, i, "")
    if name == target_name then
      return i
    end
  end
  return -1
end

function main()
  -- Get the count of selected items
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then
    return reaper.MB("Please select at least one media item and run the script again.", "Error", 0)
  end

  -- Store selected items in a table
  local selected_items = {}
  for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    selected_items[#selected_items + 1] = item
  end

  -- Table to store new glued items
  local new_items = {}

  -- Glue each item individually
  for i = 1, #selected_items do
    local item = selected_items[i]

    -- Unselect all items
    reaper.SelectAllMediaItems(0, false)
    -- Select the current item
    reaper.SetMediaItemSelected(item, true)
    -- Glue the item
    reaper.Main_OnCommand(41588, 0) -- Item: Glue items

    -- The glued item is now selected
    -- Get the selected item (should be only one)
    local glued_item = reaper.GetSelectedMediaItem(0, 0)
    -- Store the new item
    new_items[#new_items + 1] = glued_item
  end

  -- Re-select all the new glued items
  reaper.SelectAllMediaItems(0, false)
  for i = 1, #new_items do
    reaper.SetMediaItemSelected(new_items[i], true)
  end

  -- Get the track of the first selected item
  local first_item = new_items[1]
  local track = reaper.GetMediaItem_Track(first_item)

  -- Find the index of the current track and add a new track right after it
  local track_index = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1 -- track indices are 0-based in API
  reaper.InsertTrackAtIndex(track_index + 1, true)
  local new_track = reaper.GetTrack(0, track_index + 1)

  -- Arm the new track for recording and set it to record MIDI from all inputs, all channels
  reaper.SetMediaTrackInfo_Value(new_track, "I_RECARM", 1)  -- Arm track
  reaper.SetMediaTrackInfo_Value(new_track, "I_RECINPUT", 4096+0x7E0)  -- Set input to all MIDI, all channels

  -- DWUMMER Drum Map (GM Standard) - matches the drum generator
  local drum_map = {
    36,  -- KICK
    38,  -- SNARE
    42,  -- HIHAT_CLOSED
    46,  -- HIHAT_OPEN
    41,  -- TOM_LOW
    45,  -- TOM_MID
    50,  -- TOM_HIGH
    51,  -- RIDE
    49,  -- CRASH
    40,  -- SNARE_ACCENT
    37,  -- SIDE_STICK
    44,  -- HAT_PEDAL
  }

  -- Drummer perspective pan map (normalized 0.0-1.0, where 0.5 is center)
  -- Negative values = left, Positive = right from drummer's perspective
  local pan_map = {
    0.5,   -- KICK - Center
    0.5,   -- SNARE - Center
    0.65,  -- HIHAT_CLOSED - Right (drummer's right hand)
    0.65,  -- HIHAT_OPEN - Right
    0.3,   -- TOM_LOW - Left
    0.45,  -- TOM_MID - Slightly left of center
    0.6,   -- TOM_HIGH - Slightly right
    0.7,   -- RIDE - Right
    0.75,  -- CRASH - Far right
    0.5,   -- SNARE_ACCENT - Center
    0.4,   -- SIDE_STICK - Slightly left
    0.65,  -- HAT_PEDAL - Right
  }

  -- Loop over glued items
  for i = 1, #new_items do
    local item = new_items[i]
    -- Get the active take and source of the item
    local take = reaper.GetActiveTake(item)
    local item_file = reaper.GetMediaItemTake_Source(take)
    local filenamebuf = reaper.GetMediaSourceFileName(item_file, "")

    -- Add an instance of RS5K to the new track
    local fx_index = reaper.TrackFX_AddByName(new_track, "ReaSamplOmatic5000 (Cockos)", false, -1)
    reaper.TrackFX_SetNamedConfigParm(new_track, fx_index, "FILE0", filenamebuf)
    reaper.TrackFX_SetParamNormalized(new_track, fx_index, 0, 1.0)  -- Set volume to 100%

    -- Set pitch mode to 0.0 (Sample mode - no pitch shifting)
    -- Parameter 8 controls the pitch mode: 0.0 = Sample, 0.5 = Note (semitone), 1.0 = Note (shifted)
    reaper.TrackFX_SetParamNormalized(new_track, fx_index, 8, 0.0)  -- Set to Sample mode

    -- Find and set pan parameter dynamically
    local pan_param = find_param_by_name(new_track, fx_index, "Pan")
    if pan_param >= 0 then
      -- Get pan value from pan map, or default to center if we run out of mapped positions
      local pan_value = pan_map[i] or 0.5
      reaper.TrackFX_SetParam(new_track, fx_index, pan_param, pan_value)
    end

    -- Get MIDI note from drum map, or use incrementing value if we run out of mapped drums
    local midi_note = drum_map[i] or (drum_map[#drum_map] + (i - #drum_map))

    -- Map the sample to the current MIDI note
    local note_normalized = midi_note / 127
    reaper.TrackFX_SetParamNormalized(new_track, fx_index, 3, note_normalized)  -- Note range start (Index 3)
    reaper.TrackFX_SetParamNormalized(new_track, fx_index, 4, note_normalized)  -- Note range end (Index 4)
    reaper.TrackFX_SetParamNormalized(new_track, fx_index, 5, note_normalized)  -- Root note
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("jtp gen: Glue Items and Map to RS5K from Note 36", -1)
