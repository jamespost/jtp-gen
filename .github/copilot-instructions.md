# REAPER Lua Scripting (jtp gen) - AI Agent Instructions

## Project Overview
Generative music and workflow automation scripts for REAPER DAW. Two categories:
- **general-tools/** - Workflow utilities (regions, colors, exports)
- **generative-music/** - Algorithmic composition (melody, chords, rhythm, guitar picking)

All scripts follow "jtp gen_[Category]_[Description].lua" naming with `@description`, `@author`, `@version` header tags.

## Critical Architecture Patterns

### MIDI Time Conversion (Essential for All MIDI Scripts)
REAPER has two time systems - understand or MIDI editing breaks:
```lua
-- PPQ (Pulses Per Quarter) = REAPER's internal MIDI time
-- QN (Quarter Notes) = Musical time for calculations
local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, start_ppq)
local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn)
```
**Pattern**: Always work in QN for musical logic, convert to PPQ only for MIDI insertion/deletion. See `jtp gen_GenMusic_Chord-Based Solo Generator.lua` lines 600-650 for reference implementation.

### Chord Detection & Timeline Building
Used by 3+ scripts for harmonic analysis:
```lua
-- Find overlapping notes at specific time = detect chords
local function findNotesAtTime(notes, time_qn, tolerance)
    -- Returns all notes active at time_qn (overlap_tolerance ~0.01 QN)
end

-- Build timeline of chord changes for generative processing
local function buildChordTimeline(notes)
    -- Collects note start/end points, samples midpoints, builds segments
    -- Returns: {start_qn, end_qn, pitches[], root}
end
```
**Key Insight**: Chords aren't stored in REAPER - they're detected by finding overlapping notes. See `jtp gen_GenMusic_Chord-Based Solo Generator.lua` lines 180-260.

### Pattern-Based Generation (Critical for Generative Scripts)
All generative scripts use pattern libraries + selection logic:
```lua
-- Pattern library: timing, velocity, technique hints
local PATTERN_LIBRARY = {
    pattern_name = {
        {note_index, timing_offset_qn, velocity_mod, technique_hint},
        -- ... more steps
    }
}

-- Selection based on musical context (chord size, duration, genre)
local function selectPattern(chord, duration, context)
    -- Returns appropriate pattern for musical situation
end
```
**Pattern**: Separate pattern data from selection logic. Guitar Picking has 14 patterns (`jtp gen_GenMusic_Guitar Picking Transformer.lua` lines 65-185), Melody Generator has 39+ improvisation techniques.

### ExtState Persistence (User Preference Storage)
Scripts remember last settings across sessions:
```lua
local EXT_SECTION = 'jtp_gen_[script_name]'

local function get_ext(key, default)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(default) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true) -- true = persist
end
```
Used in Chord-Based Solo Generator for mode selection, widely applicable pattern.

### Deterministic Randomization (DWUMMER Pattern)
For reproducible generation with variation:
```lua
-- Seed from position for consistent-but-varied results
math.randomseed(math.floor(position_qn * 1000))
for i = 1, 3 do math.random() end -- Advance RNG state

-- Now random() calls are deterministic per position
```
See DWUMMER specs: user seed input + position-based variation creates reproducible-yet-unique patterns.

## MIDI Processing Workflow

### Standard MIDI Edit Pattern
```lua
-- 1. Read notes
local _, note_count = reaper.MIDI_CountEvts(take)
for i = 0, note_count - 1 do
    local retval, sel, muted, start_ppq, end_ppq, chan, pitch, vel =
        reaper.MIDI_GetNote(take, i)
    -- Convert to QN, store note data
end

-- 2. Process/generate (work in QN)
-- ... your algorithmic logic ...

-- 3. Delete originals (reverse order to preserve indices)
for i = note_count - 1, 0, -1 do
    reaper.MIDI_DeleteNote(take, i)
end

-- 4. Insert new notes (noSort=true during loop)
for _, note in ipairs(generated_notes) do
    local ppq_start = reaper.MIDI_GetPPQPosFromProjQN(take, note.start_qn)
    reaper.MIDI_InsertNote(take, false, false, ppq_start, ppq_end, 0, pitch, vel, true)
end

-- 5. Sort once at end
reaper.MIDI_Sort(take)
```
**Critical**: Delete in reverse, insert with `noSort=true`, sort once at end = avoids index corruption.

## Script Templates

- **Basic** (`templates/jtp gen_Template_Basic.lua`) - Simple action, no dialog
- **WithDialog** (`templates/jtp gen_Template_WithDialog.lua`) - User input with `reaper.GetUserInputs()`
- **Deferred** (`templates/jtp gen_Template_Deferred.lua`) - Background processing with `reaper.defer()`

Start from template matching your UI needs. All include proper undo blocks and error checks.

## Common Utility Patterns

### From `lib/utils.lua` (require this for multi-file scripts):
```lua
local utils = require('lib.utils') -- Load shared utilities
utils.showError("message", "title") -- Consistent UI messaging
local items = utils.getSelectedItems() -- Returns table of items
```

### Humanization (Used in 5+ generative scripts):
```lua
local function humanize(base_time_qn, base_velocity)
    local time_jitter = (math.random() - 0.5) * 2 * 0.015 -- ±15ms
    local vel_jitter = (math.random() - 0.5) * 2 * 12    -- ±12 vel
    return base_time_qn + time_jitter, math.floor(base_velocity + vel_jitter)
end
```

### Swing/Groove Application:
```lua
local function apply_swing(time_qn, swing_amount)
    local beat_pos = time_qn % 1.0 -- Position in beat (0-1)
    if beat_pos > 0.4 and beat_pos < 0.6 then -- Off-beat eighth
        return time_qn + (swing_amount * 0.25) -- Push later
    end
    return time_qn
end
```

## Testing & Debugging
- Use `reaper.ShowConsoleMsg(tostring(value) .. "\n")` for logging
- Common pattern: `local DEBUG = true` flag with `log()` helper
- Clear console: `reaper.ClearConsole()`
- Test in REAPER: Actions > Show action list > ReaScript > Load

## Key API Surface Areas

**MIDI**: `MIDI_GetNote`, `MIDI_InsertNote`, `MIDI_DeleteNote`, `MIDI_Sort`, `MIDI_GetProjQNFromPPQPos`
**Items**: `CountSelectedMediaItems`, `GetSelectedMediaItem`, `GetActiveTake`, `TakeIsMIDI`
**Tracks**: `CountSelectedTracks`, `GetSelectedTrack`
**Time**: `MIDI_GetProjQNFromPPQPos`, `MIDI_GetPPQPosFromProjQN`, `Master_GetTempo`
**Undo**: `Undo_BeginBlock()`, `Undo_EndBlock("description", -1)`
**UI**: `ShowMessageBox`, `GetUserInputs`, `ShowConsoleMsg`

## When Creating New Scripts

1. **Start from template** - Don't write header boilerplate from scratch
2. **Check for undo blocks** - `Undo_BeginBlock/EndBlock` mandatory for state changes
3. **Time conversion** - QN for logic, PPQ for MIDI API, convert at boundaries
4. **Pattern library approach** - Separate data from logic (see Guitar Picking/Melody Gen)
5. **Test immediately** - Load in REAPER after writing, don't batch multiple scripts

## Documentation References
- Main README explains project scope and featured scripts
- Mode-specific READMEs (GUITAR_PICKING, PIANIST_MODE, MASTER_IMPROVISER) document complex generators
- DWUMMER_DEVELOPMENT_PLAN shows phased implementation approach for complex systems
