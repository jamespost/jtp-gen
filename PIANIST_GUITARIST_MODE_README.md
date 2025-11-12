# Pianist/Guitarist Polyphony Mode

## Overview
Version 2.0 of the Melody Generator introduces a new polyphony mode that emulates how pianists and guitarists approach musical performance. Instead of playing continuous notes, this mode generates **chords on strong beats** and fills the space between them with **melodic runs, riffs, and arpeggios** that lead toward the next chord.

## Musical Concept
Think of how a pianist or guitarist performs:
- They establish harmonic anchors by playing chords on important beats
- They don't just hold chords - they fill the space between with melodic motion
- Runs and fills create forward momentum toward the next chord
- Strategic use of silence/space is as important as the notes themselves

## How It Works

### Chord Generation
1. **Beat Placement**: Chords are placed on strong beats at regular intervals
2. **Voice Leading**: Chord voicings use smooth voice leading (respecting Theory Weight parameter)
3. **Chord Duration**: Each chord is held for 30-60% of its allocated time slot
4. **Chord Types**: Randomly selects triads, seventh chords, or sus4 chords from the chosen scale

### Fill Types
The remaining space after each chord is filled with one of these patterns (70% probability):

#### 1. **Arpeggio Up**
- Ascends through the chord tones in order
- Quick, flowing motion upward
- 3-6 notes distributed across available time

#### 2. **Arpeggio Down**
- Descends through the chord tones in order
- Creates a cascading effect
- Slightly staccato articulation

#### 3. **Run to Chord**
- Scale-based passage approaching the next chord
- Starts 3-6 scale degrees away from target
- Uses 16th note-style rhythms for fluidity
- Creates anticipation and resolution

#### 4. **Decorative Fill**
- Ornamental notes around chord tones
- Uses neighbor tones from the scale
- Embellishes the harmony without leaving it

#### 5. **Chord Riff**
- Short repeating pattern built from chord tones
- 3-5 note motif that may repeat 1-2 times
- Rhythmically driven, creates groove

#### 6. **Silence**
- No fill generated - just space
- 30% chance (inverse of 70% fill probability)
- Musical rest for breathing and phrasing

## Parameters

### Num Voices
- Determines how many notes in each chord (typically 3-4 for realistic piano/guitar)
- More voices = fuller chords
- Fills are always monophonic (single-line melodies)

### Theory Weight
- **0.0**: Free voice leading, more creative chord voicings
- **0.5**: Balanced approach (recommended)
- **1.0**: Strict voice leading rules, smooth classical-style progressions

### Min/Max Notes
- Controls number of chord changes in the generated sequence
- More chord changes = faster harmonic rhythm
- Fewer chord changes = more space for elaborate fills

## Usage Tips

### For Piano-Style Results
- Use 4-6 voices for full chord voicings
- Set theory weight to 0.7-1.0 for smooth voice leading
- Choose scales like Major, Natural Minor, or Dorian

### For Guitar-Style Results
- Use 3-4 voices (typical guitar voicing)
- Set theory weight to 0.3-0.6 for more variety
- Try scales like Minor Pentatonic, Blues, or Mixolydian
- Shorter measures with more chord changes create strumming patterns

### For Jazz/Fusion
- Use 4-5 voices with 7th chords
- Mix of Dorian, Lydian, Mixolydian scales
- Theory weight around 0.5
- Longer measures let fills develop

## Integration with Other Features

### Auto-Detect Mode
- Pianist/Guitarist mode fully supports region detection
- Set your preferred parameters once, then use Auto mode for instant generation

### Rhythmic Guitar Mode
- These modes serve different purposes and cannot be used simultaneously
- Rhythmic Guitar = drum-style rhythmic patterns
- Pianist/Guitarist = harmonic progression with melodic fills

### Motif Repetition
- Applies to the chord progression structure
- Fills are generated fresh each time for variety

## Musical Examples

### Classic Pop Progression
- 4 voices, 4 measures, C Major scale
- Theory weight 0.6
- Creates recognizable chord changes with tasteful fills

### Jazz Comping
- 4-5 voices, 2 measures, D Dorian scale
- Theory weight 0.5
- Extended chords with bebop-style runs

### Blues Lead
- 3 voices, 4 measures, E Blues scale
- Theory weight 0.3
- Rhythmic chord stabs with bluesy fills

### Classical Arpeggiation
- 4 voices, 2 measures, F Major scale
- Theory weight 0.9
- Smooth chord progressions with elegant arpeggios

## Technical Details

### Time Structure
- Total duration divided equally among chord changes
- Each chord gets a time slot (e.g., 4 chords in 4 measures = 1 measure each)
- Chord holds for portion of slot, fill occupies remainder

### Fill Generation
- Fills are monophonic (channel 0)
- Note velocities range 45-85 for fills (lighter touch)
- Chord velocities range 70-95 (emphasized)
- Fill durations calculated to fit exact space between chords

### Voice Leading
- Uses the same voice leading engine as Harmonic mode
- Minimizes total voice movement
- Rewards contrary motion
- Penalizes parallel perfect intervals
- Blended with Theory Weight parameter

## Future Enhancements (Ideas)
- Dynamic velocity curves within fills (crescendo to next chord)
- Rhythmic patterns for chord attacks (syncopation, anticipation)
- Pedal tone option (sustained bass note through progression)
- Fill complexity parameter (simple vs. elaborate)
- Style presets (jazz, classical, rock, etc.)

## Credits
Developed for REAPER DAW as part of the jtp gen ReaScript collection.
Mode concept: Emulate natural piano/guitar performance with chords and fills.
Version 2.0 - November 2025
