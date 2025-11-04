-- @description jtp gen: [Script Name]
-- @author James
-- @version 1.0
-- @about
--   # [Script Name]
--
--   ## Description
--   Detailed description of what this script does
--
--   ## Usage
--   1. Step by step instructions
--   2. How to use this script
--
--   ## Notes
--   - Any important notes or limitations

-- Check if reaper API is available
if not reaper then
    return
end

-- Configuration
local CONFIG = {
    -- Add configuration options here
}

-- Helper functions
local function log(message)
    reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

-- Main script logic
function main()
    -- Begin undo block
    reaper.Undo_BeginBlock()

    -- Your script functionality goes here
    log("jtp gen: Script started")

    -- Example: Get selected items count
    local num_items = reaper.CountSelectedMediaItems(0)
    log("Selected items: " .. num_items)

    -- Update the arrange view
    reaper.UpdateArrange()

    -- End undo block with descriptive name
    reaper.Undo_EndBlock("jtp gen: [Action Name]", -1)
end

-- Run the script
main()
