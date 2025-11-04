-- lib/utils.lua
-- Common utility functions for jtp gen ReaScripts

local utils = {}

-- Logging function
function utils.log(message)
    reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

-- Check if items are selected
function utils.hasSelectedItems()
    return reaper.CountSelectedMediaItems(0) > 0
end

-- Check if tracks are selected
function utils.hasSelectedTracks()
    return reaper.CountSelectedTracks(0) > 0
end

-- Get all selected items
function utils.getSelectedItems()
    local items = {}
    local num_items = reaper.CountSelectedMediaItems(0)
    for i = 0, num_items - 1 do
        table.insert(items, reaper.GetSelectedMediaItem(0, i))
    end
    return items
end

-- Get all selected tracks
function utils.getSelectedTracks()
    local tracks = {}
    local num_tracks = reaper.CountSelectedTracks(0)
    for i = 0, num_tracks - 1 do
        table.insert(tracks, reaper.GetSelectedTrack(0, i))
    end
    return tracks
end

-- Convert RGB to REAPER color format
function utils.rgbToReaper(r, g, b)
    return reaper.ColorToNative(r, g, b)|0x1000000
end

-- Show error message
function utils.showError(message, title)
    title = title or "jtp gen: Error"
    reaper.ShowMessageBox(message, title, 0)
end

-- Show info message
function utils.showInfo(message, title)
    title = title or "jtp gen: Info"
    reaper.ShowMessageBox(message, title, 0)
end

return utils
