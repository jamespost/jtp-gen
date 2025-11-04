# Reaper Lua Scripting Workspace Instructions

## Project Overview
This workspace contains Lua scripts for REAPER DAW (ReaScripts). All scripts are prefixed with "jtp gen" as a personal signifier.

## Project Structure
- `general-tools/` - Task management and utility scripts for REAPER workflow
- `generative-music/` - Generative composition and algorithmic music scripts
- `templates/` - Script templates for quick ReaScript development
- `lib/` - Shared utility functions and modules

## Coding Standards

### Script Naming Convention
All scripts must follow this pattern:
```
jtp gen_[Category]_[Description].lua
```
Examples:
- `jtp gen_Tools_Export Selected Items.lua`
- `jtp gen_GenMusic_Random Melody Generator.lua`

### ReaScript Structure
Every script should follow this basic structure:

```lua
-- @description jtp gen: [Script Purpose]
-- @author James
-- @version 1.0
-- @about
--   # Description
--   Detailed description of what the script does

-- Check if reaper API is available
if not reaper then
    return
end

-- Main script logic here
function main()
    reaper.Undo_BeginBlock()

    -- Script functionality

    reaper.Undo_EndBlock("jtp gen: [Action Name]", -1)
end

-- Run main function
main()
```

### Best Practices
- Always use `reaper.Undo_BeginBlock()` and `reaper.Undo_EndBlock()` for undoable actions
- Check if REAPER API is available with `if not reaper then return end`
- Use descriptive variable names and comment complex logic
- Defer heavy operations when possible using `reaper.defer()`
- Test scripts thoroughly before deployment

## ReaScript API
- Official API: https://www.reaper.fm/sdk/reascript/reascripthelp.html
- Use `reaper.` prefix for all REAPER API functions
- Common namespaces: `reaper.`, `gfx.`, `reaper.ImGui_` (if SWS/js_ReaScriptAPI installed)

## Development Workflow
1. Create new scripts from templates in `templates/` folder
2. Test scripts in REAPER's Actions list (Actions > Show action list > ReaScript > Load)
3. Place finalized scripts in appropriate category folder
4. Update version numbers and descriptions as needed

## Dependencies
- REAPER DAW (v6.0 or higher recommended)
- Optional: SWS Extension for additional API functions
- Optional: js_ReaScriptAPI for ImGui support

## Code Completion
When writing ReaScript code:
- Suggest REAPER API functions with proper `reaper.` prefix
- Include error checking and undo blocks
- Follow the established naming convention with "jtp gen" prefix
- Provide comments explaining REAPER-specific concepts
