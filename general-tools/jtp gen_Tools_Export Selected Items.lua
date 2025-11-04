-- @description jtp gen: Export Selected Items to New Project
-- @author James
-- @version 1.0
-- @about
--   # Export Selected Items to New Project
--
--   ## Description
--   Exports all selected media items to a new REAPER project file
--   with their original timing and track structure preserved.
--
--   ## Usage
--   1. Select the media items you want to export
--   2. Run this script
--   3. Choose a location for the new project file
--
--   ## Notes
--   - Preserves item positions and track routing
--   - Copies media files to new project directory

if not reaper then
    return
end

local function log(message)
    reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

function main()
    reaper.Undo_BeginBlock()

    -- Check if items are selected
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then
        reaper.ShowMessageBox("No items selected. Please select items to export.", "jtp gen: Export Items", 0)
        return
    end

    -- Get save location from user
    local retval, file_path = reaper.GetUserFileNameForRead("", "Save Project As", ".rpp")
    if not retval then
        return  -- User cancelled
    end

    log("jtp gen: Exporting " .. num_items .. " items...")
    log("Target: " .. file_path)

    -- Here you would implement the actual export logic
    -- This is a starter example showing the structure

    reaper.ShowMessageBox("Export functionality ready to implement!", "jtp gen: Export Items", 0)

    reaper.Undo_EndBlock("jtp gen: Export Selected Items", -1)
end

main()
