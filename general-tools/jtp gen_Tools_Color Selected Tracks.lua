-- @description jtp gen: Color Selected Tracks by Group
-- @author James
-- @version 1.0
-- @about
--   # Color Selected Tracks by Group
--
--   ## Description
--   Automatically assigns colors to selected tracks based on their names
--   or position, useful for organizing large projects.
--
--   ## Usage
--   1. Select the tracks you want to color
--   2. Run this script
--   3. Tracks will be colored in a gradient or pattern

if not reaper then
    return
end

-- Color palette (RGB values converted to REAPER color format)
local COLORS = {
    {255, 100, 100},  -- Red
    {100, 255, 100},  -- Green
    {100, 100, 255},  -- Blue
    {255, 255, 100},  -- Yellow
    {255, 100, 255},  -- Magenta
    {100, 255, 255},  -- Cyan
}

local function rgbToReaper(r, g, b)
    return reaper.ColorToNative(r, g, b)|0x1000000
end

function main()
    reaper.Undo_BeginBlock()

    local num_tracks = reaper.CountSelectedTracks(0)
    if num_tracks == 0 then
        reaper.ShowMessageBox("No tracks selected.", "jtp gen: Color Tracks", 0)
        return
    end

    -- Assign colors to selected tracks
    for i = 0, num_tracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local color_index = (i % #COLORS) + 1
        local color = rgbToReaper(COLORS[color_index][1], COLORS[color_index][2], COLORS[color_index][3])
        reaper.SetTrackColor(track, color)
    end

    reaper.UpdateArrange()
    reaper.ShowMessageBox("Colored " .. num_tracks .. " tracks!", "jtp gen: Color Tracks", 0)

    reaper.Undo_EndBlock("jtp gen: Color Selected Tracks", -1)
end

main()
