# Guitar Picking Transformer - Implementation Guide

## Overview
The **Guitar Picking Transformer** (`jtp gen_GenMusic_Guitar Picking Transformer.lua`) is a sophisticated MIDI transformation script that takes sustained notes/chords and converts them into realistic guitar picking patterns.

Unlike interactive tools, this script transforms existing MIDI clips with a "generate and go" approach - perfect for creative experimentation and rapid iteration.

## Musical Concept

### The Core Idea
Imagine a guitarist holding down a chord shape on the fretboard. Instead of just strumming or letting it ring, they:
- Pick individual strings in patterns (Travis picking, fingerstyle)
- Create melodic runs and arpeggios through the chord tones
- Apply different picking techniques (sweeps, hybrid picking, tremolo)
- Add rhythmic variations and syncopation

This script does exactly that - it treats your sustained MIDI notes as "held chord voicings" and transforms them into intricate picking patterns.

## How It Works

### Input: Sustained Chords
The script looks for **overlapping or sustained notes** in your MIDI item:
- Minimum length: 1/8 note (adjustable in config)
- Any number of simultaneous notes (1-6+ notes work great)
- Notes can have different lengths - the script uses the shortest duration

### Output: Picking Patterns
Each chord moment is transformed into one of 14 different picking patterns:

#### 1. **Travis Picking** (Folk/Country)
- Alternating bass notes with melody on high strings
- Classic fingerstyle foundation
- Two variants: basic (4 notes) and double (8 notes)

#### 2. **Folk Patterns**
- Simple alternating bass
- Rolling arpeggios through chord tones
- Great for singer-songwriter styles

#### 3. **Jazz Walking**
- Walking bass-style motion through chord
- 8-note pattern with rhythmic complexity
- Works beautifully with 7th chords

#### 4. **Flamenco Rasgueado**
- Rapid strumming technique
- Staggered attacks across strings (3ms apart)
- Percussive and dramatic

#### 5. **Sweep Picking**
- Fast directional runs (ascending/descending)
- Short, crisp note articulations
- Great for technical passages

#### 6. **Hybrid Picking**
- Alternates between pick and fingers
- 8-note patterns with varied articulation
- Versatile for many styles

#### 7. **Tremolo**
- Rapid repeated notes on highest string
- 8 repetitions with subtle velocity variation
- Creates shimmering sustained effect

#### 8. **Campanella**
- Overlapping/ringing notes
- Longer sustains create harp-like effect
- Beautiful for open-voiced chords

#### 9. **Syncopated Funk**
- Off-beat accents and rhythmic displacement
- Funky, groove-oriented feel

#### 10. **Bossa Nova**
- Latin-inspired rhythmic pattern
- 7-note cycle with characteristic syncopation

## Pattern Selection Logic

The script intelligently chooses patterns based on chord characteristics:

### Single Note (1 note)
- **Tremolo picking** - rapid repetition for sustain

### Two Notes
- Folk basic or Hybrid alternating
- Simple back-and-forth patterns

### Three Notes
- Travis basic, Folk basic, or Folk rolling
- Classic fingerstyle territory

### Four Notes
- Full palette: Travis double, Jazz walking, Hybrid, Bossa nova
- Most versatile range for patterns

### Five+ Notes
- Jazz walking, Sweep picking, Campanella, Flamenco rasgueado
- Complex patterns for rich voicings

## Musical Features

### Humanization
- **Timing**: ±15ms random offset per note
- **Velocity**: ±15 velocity variation
- **Technique-aware**: Less variation for tremolo/sweep (more consistent)

### Articulation Modeling
- **Sustain techniques** (campanella): Notes ring for 75% of duration
- **Sweep/tremolo**: Very short notes (0.08 quarter notes)
- **Strumming**: Medium length (0.15 quarter notes)
- **Standard picking**: Natural length (0.20 quarter notes)

### Pattern Repetition
- Patterns automatically repeat to fill the chord duration
- Most patterns span 1 quarter note
- Repeats until chord changes or ends

### Velocity Dynamics
- Base velocity calculated from average of chord notes
- Pattern steps have velocity modifiers (-12 to +5)
- Humanization adds further variation
- Final velocity clamped to 1-127 range

## Usage Workflow

### Basic Usage
1. **Create sustained chords** in a MIDI item
   - Draw notes or record chord voicings
   - Make sure notes overlap (play simultaneously)
   - Minimum 1/8 note length

2. **Select the MIDI item(s)**
   - Multiple items can be processed at once
   - Script processes each independently

3. **Run the script**
   - Actions > Show action list > ReaScript > Load
   - Select `jtp gen_GenMusic_Guitar Picking Transformer.lua`
   - Script runs immediately - no dialog needed

4. **Result**
   - Original chords are replaced with picking patterns
   - Undo available if you want to try again

### Creative Applications

#### Sketch to Arrangement
1. Block out chord progression with simple sustained notes
2. Run transformer to create intricate guitar part
3. Refine by hand if desired

#### Variation Generator
1. Duplicate your MIDI item
2. Run transformer multiple times on different copies
3. Each run produces different random patterns
4. Comp together your favorite sections

#### Style Exploration
- Use short chords (1 beat) for rhythmic patterns
- Use long chords (2-4 beats) for flowing arpeggios
- Mix chord lengths for dynamic variation

## Configuration Options

Located at the top of the script, easily adjustable:

```lua
local config = {
    min_chord_length = 1/8,      -- Minimum note length to process
    humanization = 0.015,         -- Timing randomization (±15ms)
    velocity_variation = 15,      -- Velocity randomization (±15)
    string_count = 6,             -- Guitar string simulation
    min_string_interval = 0.020,  -- 20ms between same-string hits
}
```

### Customization Tips

**More Mechanical Feel:**
- Reduce `humanization` to 0.005 (±5ms)
- Reduce `velocity_variation` to 5

**More Human Feel:**
- Increase `humanization` to 0.025 (±25ms)
- Increase `velocity_variation` to 20

**Faster Picking:**
- Edit pattern timing offsets (reduce spacing)
- Adjust `min_string_interval` to allow quicker repeats

**Longer Sustains:**
- Edit technique articulation in `generatePickingFromChord()`
- Increase sustain/campanella note lengths

## Advanced: Creating Custom Patterns

Patterns are defined in `PATTERN_LIBRARY` table. Format:

```lua
PATTERN_LIBRARY.my_pattern = {
    {note_index, timing_offset, velocity_mod, "technique"},
    -- note_index: 1=lowest, 2=mid-low, 3=mid-high, 4=highest (wraps for larger chords)
    -- timing_offset: 0.0-1.0 (fraction of quarter note)
    -- velocity_mod: -20 to +20 (added to base velocity)
    -- technique: "bass", "melody", "mid", "sweep", "tremolo", "sustain", "strum"
}
```

Example - Simple Arpeggio Up:
```lua
PATTERN_LIBRARY.simple_up = {
    {1, 0.00, 0, "bass"},
    {2, 0.25, -5, "mid"},
    {3, 0.50, -8, "melody"},
    {4, 0.75, -10, "melody"},
}
```

After defining, add to `selectPattern()` function in the appropriate chord size section.

## Technical Details

### Chord Detection Algorithm
1. Finds all notes in MIDI item
2. Groups notes that overlap in time
3. Uses shortest note duration as chord duration
4. Sorts chord notes by pitch (lowest to highest)

### Time Handling
- All positions in quarter notes (QN)
- Conversion to/from PPQ for REAPER API
- Humanization applied in QN, then converted

### Note Index Wrapping
- Patterns can reference note indices 1-4+
- If chord has fewer notes, indices wrap using modulo
- Example: 3-note chord, pattern asks for note 4 → wraps to note 1

## Integration with Existing Scripts

### Complementary Tools

**Use After:**
- `jtp gen_GenMusic_Chord Progression Generator.lua` - Generate chord progressions first
- `jtp gen_GenMusic_Melody Generator Dialog.lua` - Use harmonic mode output as input

**Use Before:**
- `jtp gen_GenMusic_Scale Transposer.lua` - Transpose picking patterns
- `jtp gen_GenMusic_Rhythmic Item Arranger.lua` - Arrange picking sections

### Workflow Integration

**Idea Generator Workflow:**
1. Chord Progression Generator → basic chords
2. Guitar Picking Transformer → intricate patterns
3. Rhythmic Item Arranger → structure/arrangement
4. Manual refinement and humanization

**Sketch to Performance:**
1. Manually sketch chord progression (block chords)
2. Guitar Picking Transformer → realistic guitar part
3. Duplicate and vary → create verse/chorus variations
4. Export and arrange → full song structure

## Limitations and Considerations

### What It Does Well
✓ Transforms sustained chords into realistic picking
✓ Multiple pattern styles (14 distinct patterns)
✓ Intelligent pattern selection based on chord size
✓ Humanization and articulation modeling
✓ Fast, non-interactive workflow

### What It Doesn't Do
✗ Interactive real-time playing
✗ Respond to live input
✗ Learn from user preferences
✗ Analyze harmonic context (doesn't know key/scale)
✗ Model fretboard positions (no open strings vs. fretted)

### Best Practices
- **Chord length matters**: Longer chords = more pattern repetitions
- **Velocity consistency**: Source chord velocities affect output
- **Undo is your friend**: Try multiple times for different results
- **Edit after**: Generated patterns are starting points, not final

## Future Enhancement Ideas

### Potential Additions
- **Style presets**: One-click "folk", "jazz", "flamenco" modes
- **Pattern complexity slider**: Simple to complex pattern selection
- **Fretboard modeling**: Simulate actual guitar fingerings and positions
- **Open string emphasis**: Add weight to likely open strings (E, A, D, G, B, E)
- **Palm muting simulation**: Shorter sustains for lower strings
- **Harmonics**: Add octave/harmonic ghost notes
- **Strum direction**: Model downstrokes vs. upstrokes
- **Adaptive patterns**: Change pattern based on chord duration
- **Velocity curves**: Crescendo/decrescendo within patterns
- **Interactive GUI**: Real-time pattern preview and selection

### Community Contributions
Feel free to:
- Add new patterns to `PATTERN_LIBRARY`
- Create style-specific variants
- Share your custom patterns
- Suggest improvements

## Troubleshooting

### "No sustained chords found"
**Problem**: Script can't find notes long enough to process
**Solution**:
- Check your notes are at least 1/8 note long
- Lower `min_chord_length` in config if needed
- Make sure notes actually overlap in time

### Patterns sound too mechanical
**Problem**: Not enough humanization
**Solution**:
- Increase `humanization` and `velocity_variation` in config
- Run through REAPER's humanize function after transformation
- Manually adjust timing in piano roll

### Patterns are too sparse
**Problem**: Not enough notes being generated
**Solution**:
- Use longer chord durations (more pattern repetitions)
- Edit patterns to have more steps
- Duplicate and layer multiple transformations

### Wrong pattern selection
**Problem**: Pattern doesn't fit the style you want
**Solution**:
- Modify `selectPattern()` function to prefer certain patterns
- Create pattern categories and weight them
- Add style parameter to script (requires dialog addition)

## Credits and Version History

**Version 1.0** - November 2025
- Initial release
- 14 distinct picking patterns
- Intelligent pattern selection
- Humanization and articulation modeling
- Non-interactive transform workflow

**Author**: James
**Script Series**: jtp gen (James's personal ReaScript collection)
**License**: Free to use and modify
**REAPER Version**: 6.0+ recommended

## Related Documentation

See also:
- `PIANIST_GUITARIST_MODE_README.md` - Chord + fill generation
- `RHYTHMIC_GUITAR_MODE_README.md` - Drum-style rhythmic guitar
- Main project `README.md` - Complete script overview

---

*Transform sustained chords into sophisticated guitar picking patterns with one click!* 🎸
