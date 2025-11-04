-- @description jtp gen: [Script Name with Dialog]
-- @author James
-- @version 1.0
-- @about
--   # [Script Name]
--   Script with user input dialog

if not reaper then
    return
end

-- Get user input
local function getUserInput()
    local retval, user_input = reaper.GetUserInputs(
        "jtp gen: [Script Name]",  -- Dialog title
        1,                           -- Number of fields
        "Enter value:",             -- Field labels
        ""                           -- Default values
    )

    if not retval then
        return nil  -- User cancelled
    end

    return user_input
end

function main()
    -- Get user input
    local input = getUserInput()
    if not input then
        return  -- User cancelled
    end

    reaper.Undo_BeginBlock()

    -- Your script logic here using the input
    reaper.ShowConsoleMsg("User entered: " .. input .. "\n")

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("jtp gen: [Action Name]", -1)
end

main()
