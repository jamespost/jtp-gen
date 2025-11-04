-- @description jtp gen: [Script Name - Deferred]
-- @author James
-- @version 1.0
-- @about
--   # [Script Name]
--   Script that runs continuously until stopped

if not reaper then
    return
end

-- State variables
local is_running = false

-- Initialize
local function init()
    is_running = true
end

-- Main loop
local function loop()
    if not is_running then
        return
    end

    -- Your continuous logic here
    -- This will run every defer cycle

    -- Schedule next iteration
    reaper.defer(loop)
end

-- Cleanup
local function cleanup()
    is_running = false
    reaper.Undo_EndBlock("jtp gen: [Action Name]", -1)
end

-- Main entry point
function main()
    reaper.Undo_BeginBlock()
    init()
    loop()
end

-- Run the script
main()
