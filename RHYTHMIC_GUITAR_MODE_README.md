# Rhythmic Guitar Mode - Implementation Summary

## Overview
Added a new **Rhythmic Guitar Mode** to `jtp gen_GenMusic_Melody Generator Dialog.lua` that adapts the drum-style rhythm generation algorithm for melodic guitar parts. This mode combines the aggressive rhythmic patterns from the adaptive drum generator with the melodic note selection from your existing melody algorithms.

## Changes Made (v1.6)

### New Feature: Rhythmic Guitar Mode
- **Toggle**: Added "Rhythmic Guitar Mode (0=off 1=on)" parameter in the dialog
- **Default**: OFF (preserves existing functionality)
- **Persistence**: Setting is saved between sessions via ExtState

### How It Works

#### Rhythm Generation (from Drum Script)
The mode uses these drum-inspired rhythmic patterns:
- **Burst patterns**: Rapid note flurries (8 notes)
- **Double strokes**: Two quick hits on the same note
- **Paradiddles**: 8-note alternating patterns
- **Focused riffs**: Repetitive patterns using note subsets
- **Anchor downbeats**: Strong measure-starting notes
- **Random beat accents**: Emphasized beats with higher velocity

#### Note Selection (from Melody Generator)
- Uses your existing scale/root note selection
- Auto-detection from region names still works
- Notes chosen from the selected scale
- Maintains musical coherence with your existing workflow

#### Physical Modeling
- **String simulation**: Tracks 6 virtual "strings" (S1-S6)
- **Timing constraints**: Minimum 10ms between notes on same string
- **Humanization**: ±7ms random timing offset per note
- **Dynamic velocity**: Accent-aware velocity (7-110)
- **Sustain mode**: Notes sustain for 90% of their duration

### Configuration Constants

The following probabilities control the rhythmic behavior:
```lua
BURST_CHANCE = 0.250              -- 25% chance of rapid flurries
DOUBLE_STROKE_CHANCE = 0.250      -- 25% chance of double hits
PARADIDDLE_CHANCE = 0.250         -- 25% chance of alternating patterns
FOCUSED_RIFF_CHANCE = 0.300       -- 30% chance of focused riff mode
ANCHOR_DOWNBEAT_CHANCE = 0.300    -- 30% chance of strong downbeat
RANDOM_BEAT_ACCENT_CHANCE = 0.600 -- 60% chance of random accent
```

Subdivision settings:
```lua
SUBDIVS_MIN = 1                   -- Minimum subdivisions per beat
SUBDIVS_MAX = 2                   -- Maximum subdivisions per beat
PPQ = 960                         -- Pulses per quarter note
```

### Usage

1. **Enable the mode**: In the parameters dialog, set "Rhythmic Guitar Mode" to 1
2. **Configure as normal**: Choose scale, root note, measures, etc.
3. **Generate**: The script will create aggressive, rhythmic guitar parts using your scale

### Example Workflow

**For Math Rock / Prog Metal:**
```
Root: E (octave 2)
Scale: Dorian or Phrygian
Measures: 4
Rhythmic Guitar Mode: 1
```

**For Jazz Fusion:**
```
Root: Ab (octave 3)
Scale: Melodic Minor or Lydian
Measures: 2
Rhythmic Guitar Mode: 1
```

### Technical Details

#### String State Tracking
Each of 6 virtual strings tracks:
- `last_note_time`: When the string was last struck
- `last_pitch`: The last pitch played on that string

This prevents physically impossible note sequences.

#### Accent System
Accents are tracked per measure and influence velocity:
- On-beat notes: Random velocity (7-110)
- Off-beat notes: Lower base velocity (50-90)
- Near-accent notes: Velocity boost up to +20

#### Pattern Types

1. **Burst Pattern**: 8 rapid notes divided across subdivision
2. **Double Stroke**: Same note twice with 25% spacing
3. **Paradiddle**: 8 alternating notes from scale
4. **Focused Riff**: Repetitive pattern using 2-4 notes from scale
5. **Standard**: Single note per subdivision

### Removed from Drum Script

These features were **not** included (as requested):
- ❌ Adaptive learning / rating system
- ❌ Automatic playback
- ❌ Delay and rating dialog
- ❌ Parameter adjustment based on user feedback
- ❌ ExtState tracking for adaptive parameters

### Compatibility

- **Works with all existing modes**: Auto-detect, CA mode, poly modes all still function
- **Mutually exclusive with CA mode**: If both enabled, Rhythmic Guitar takes precedence
- **Preserves all settings**: Scale, root, voices, theory weight, etc.

### Files Modified

- `generative-music/jtp gen_GenMusic_Melody Generator Dialog.lua`
  - Version bumped to 1.6
  - Added ~300 lines of rhythmic generation code
  - Updated dialog to include new parameter
  - Added ExtState persistence for mode toggle

### Testing Recommendations

1. Test with different scales (pentatonic, whole tone, blues)
2. Try different subdivision settings (adjust SUBDIVS_MAX for more/less complexity)
3. Experiment with probability values for different styles
4. Compare output with CA mode and standard modes

### Future Enhancement Ideas

- Add GUI to adjust probability constants
- Create presets (Math Rock, Jazz Fusion, Progressive, etc.)
- Add velocity curves/profiles
- Implement more complex string simulation (fret positions, open strings)
- Add palm muting simulation (shorter sustains)
- Harmonics support (octave + fifth ghost notes)

## Notes

The Lua type checker warnings about `math.random()` parameter types are expected and do not affect functionality. These occur because the type system cannot guarantee integer types even though the sanity checks ensure correct values.
