# jtp gen - Reaper Lua Scripts

A comprehensive collection of Lua scripts for REAPER DAW, focusing on task management tools and generative music composition.

## 📁 Project Structure

```
jtp gen/
├── general-tools/      # Task management and workflow utilities
├── generative-music/   # Algorithmic composition and generative scripts
├── templates/          # ReaScript templates for quick development
├── lib/                # Shared utility functions and modules
└── .github/            # Workspace configuration
```

## 🚀 Getting Started

### Prerequisites
- **REAPER DAW** (v6.0 or higher recommended)
- **VS Code** with Lua extension (optional, for development)
- **SWS Extension** (optional, for extended API functions)
- **js_ReaScriptAPI** (optional, for ImGui support)

### Installation

1. Clone or download this repository
2. In REAPER, go to **Actions** → **Show action list**
3. Click **ReaScript** → **Load** and browse to your script
4. Assign hotkeys as needed

## 📝 Script Naming Convention

All scripts follow this format:
```
jtp gen_[Category]_[Description].lua
```

**Examples:**
- `jtp gen_Tools_Export Selected Items.lua`
- `jtp gen_GenMusic_Random Melody Generator.lua`

## 🛠️ Development

### Creating a New Script

1. Start with a template from `templates/` folder
2. Follow the standard ReaScript structure:

```lua
-- @description jtp gen: [Script Purpose]
-- @author James
-- @version 1.0
-- @about
--   # Description
--   Detailed description of what the script does

if not reaper then
    return
end

function main()
    reaper.Undo_BeginBlock()

    -- Your script logic here

    reaper.Undo_EndBlock("jtp gen: [Action Name]", -1)
end

main()
```

### Best Practices

- ✅ Always wrap undoable actions in `Undo_BeginBlock()` / `Undo_EndBlock()`
- ✅ Check if REAPER API is available: `if not reaper then return end`
- ✅ Use descriptive variable names and comment your code
- ✅ Test thoroughly before deploying to production
- ✅ Use `reaper.defer()` for heavy operations to keep UI responsive
- ✅ Version your scripts and update the `@version` tag

### Useful ReaScript Functions

Common patterns you'll use:

```lua
-- Get selected items
local num_items = reaper.CountSelectedMediaItems(0)
local item = reaper.GetSelectedMediaItem(0, 0)

-- Get selected tracks
local num_tracks = reaper.CountSelectedTracks(0)
local track = reaper.GetSelectedTrack(0, 0)

-- Show console messages
reaper.ShowConsoleMsg("Debug: " .. tostring(value) .. "\n")

-- Update arrange view
reaper.UpdateArrange()
```

## 📚 Resources

- [REAPER ReaScript Documentation](https://www.reaper.fm/sdk/reascript/reascripthelp.html)
- [REAPER Forums - ReaScript](https://forum.cockos.com/forumdisplay.php?f=9)
- [ReaPack - Script Package Manager](https://reapack.com/)

## 📂 Categories

### General Tools
Scripts for enhancing REAPER workflow, task management, and productivity.

### Generative Music
Algorithmic composition tools, random generators, and experimental music creation scripts.

#### Featured Scripts

**Guitar Picking Transformer** (`jtp gen_GenMusic_Guitar Picking Transformer.lua`)
- Transforms sustained MIDI chords into sophisticated guitar picking patterns
- 14 distinct patterns: Travis picking, folk, jazz, flamenco, sweep, hybrid, tremolo, campanella, and more
- Intelligent pattern selection based on chord characteristics
- Humanization and articulation modeling
- Non-interactive workflow - perfect for rapid experimentation
- See `GUITAR_PICKING_MODE_README.md` for full documentation

**MIDI Note Arpeggiator** (`jtp gen_GenMusic_MIDI Note Arpeggiator.lua`)
- Multiple arpeggiation modes including Up-Down and Guitar Picking
- Velocity contouring for musical dynamics
- Configurable rate and note length settings

**Melody Generator Dialog** (`jtp gen_GenMusic_Melody Generator Dialog.lua`)
- Master Improviser Mode with 39+ improvisational techniques
- Pianist/Guitarist polyphony mode with chord voicings and fills
- Multiple generation modes: free, harmonic, voice leading
- Auto-detection of scale/key from region names
- See mode-specific READMEs for detailed information

## 🤝 Contributing

When adding new scripts:
1. Place them in the appropriate category folder
2. Follow the naming convention with `jtp gen` prefix
3. Include proper metadata tags (`@description`, `@version`, etc.)
4. Add comments explaining complex logic
5. Update this README if adding new categories

## 📄 License

These scripts are personal tools created by James for REAPER workflow enhancement.

## ✨ Credits

Created by James (jtp gen)
