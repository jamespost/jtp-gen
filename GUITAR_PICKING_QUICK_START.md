# Guitar Picking Transformer - Quick Reference

## What It Does
Transforms sustained MIDI chords into sophisticated guitar picking patterns - like a real guitarist holding down a chord shape and picking individual strings.

## Quick Start

### 1. Create Input
- Draw or record MIDI notes that overlap (form chords)
- Notes should be at least 1/8 note long
- Example: C major triad held for 2 beats

### 2. Run Script
- Select your MIDI item(s)
- Run: `jtp gen_GenMusic_Guitar Picking Transformer.lua`
- No dialog - instant transformation!

### 3. Result
- Original chords replaced with picking patterns
- Multiple patterns used automatically based on chord size
- Each run produces different variations (randomized)

## 14 Picking Patterns

| Pattern | Style | Best For |
|---------|-------|----------|
| Travis Basic/Double | Fingerstyle | Folk, country, singer-songwriter |
| Folk Basic/Rolling | Acoustic | Strumming alternative, gentle arpeggios |
| Jazz Walking | Jazz | Walking bass + melody, sophisticated |
| Flamenco Rasgueado | Flamenco | Rapid strumming, percussive |
| Sweep Ascending/Descending | Rock/Metal | Fast technical runs |
| Hybrid Alternating | Country/Rock | Pick + fingers combination |
| Tremolo | Classical | Sustained single-note effect |
| Campanella | Classical | Overlapping/ringing notes |
| Syncopated Funk | Funk | Off-beat grooves |
| Bossa Nova | Latin | Syncopated rhythmic feel |

## Pattern Selection (Automatic)

- **1 note**: Tremolo picking
- **2 notes**: Folk basic, Hybrid
- **3 notes**: Travis, Folk basic/rolling
- **4 notes**: Travis double, Jazz walking, Hybrid, Bossa nova
- **5+ notes**: Jazz, Sweep, Campanella, Flamenco

## Key Features

### Humanization
- ±15ms timing variation
- ±15 velocity variation
- Technique-specific adjustments

### Articulation
- **Sustain/Campanella**: Long ringing notes (75% duration)
- **Tremolo/Sweep**: Very short notes (0.08 QN)
- **Strum**: Medium notes (0.15 QN)
- **Standard**: Normal picking (0.20 QN)

### Smart Behavior
- Patterns repeat to fill chord duration
- Wraps note indices for smaller chords
- Velocity based on source chord average
- Randomized pattern selection

## Configuration

Edit these values at top of script:

```lua
min_chord_length = 1/8      -- Process notes this long or longer
humanization = 0.015        -- ±15ms timing variation
velocity_variation = 15     -- ±15 velocity variation
```

## Tips & Tricks

### More Variation
- Run script multiple times on duplicated items
- Comp your favorite results together

### Style Control
- Short chords (1 beat) → rhythmic patterns
- Long chords (4 beats) → flowing arpeggios
- Mix lengths for dynamic interest

### Refinement
- Use generated patterns as starting point
- Edit in piano roll for perfect result
- Undo and retry for different randomization

## Example Workflows

### Singer-Songwriter
1. Block out C-Am-F-G progression (whole notes)
2. Run transformer → Travis/Folk patterns
3. Clean up transitions by hand

### Jazz Comp
1. Create 7th chord voicings (half notes)
2. Run transformer → Jazz walking patterns
3. Adjust velocities for dynamics

### Flamenco Style
1. Create rich 5-6 note voicings (long sustains)
2. Run transformer → Rasgueado patterns appear
3. Add manual flourishes

## Common Issues

**"No sustained chords found"**
- Notes must be at least 1/8 note long
- Notes must overlap in time
- Try lowering `min_chord_length` in config

**Too mechanical**
- Increase humanization values
- Use REAPER's built-in humanize tool after
- Manually adjust some notes

**Wrong patterns**
- Try running again (randomized each time)
- Edit `selectPattern()` function to prefer certain styles
- Modify chord size to trigger different pattern sets

## File Location
`generative-music/jtp gen_GenMusic_Guitar Picking Transformer.lua`

## See Full Documentation
`GUITAR_PICKING_MODE_README.md` - Complete guide with examples and customization

---

*One-click transformation from block chords to intricate guitar picking!* 🎸
