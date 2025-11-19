# Call & Response Generator - Quick Start Guide

## Overview
The Call & Response Generator creates complete musical conversations from scratch - no existing MIDI needed! Perfect for video game music cutscenes, character themes, or any compositional work that needs musical dialogue.

## How to Use

### Basic Workflow
1. **Select a track** in REAPER (the script will create a new MIDI item)
2. **Run the script** from Actions > ReaScript
3. **Choose mode**:
   - **Auto**: Uses your last settings for instant generation
   - **Manual**: Configure all parameters via dialogs

### Auto Mode (One-Click Generation)
Perfect for rapid iteration! Select "Auto" and the script instantly generates using your previous settings. Great for workflow speed once you've found settings you like.

### Manual Mode (Full Configuration)
The script will guide you through popup menus:

**Step 1: Auto-Detection**
- **Auto-detect from region (ON)**: Script reads region name (e.g., "C4 Major")
- **Manual selection (OFF)**: Choose root note/scale manually
- **Override auto-detected values**: Use detected values as starting point but customize

**Step 2: Root Note & Scale**
- Select note name (C, C#, D, etc.)
- Select octave (0-9)
- Select scale from 9 options

**Step 3: Generation Mode**
- Choose from 6 call/response conversation styles

**Step 4: Parameters**
- **# Phrase Pairs**: How many call/response exchanges (2-8)
- **Complexity**: Simple rhythms (0.2) to virtuosic (0.9)

### The 6 Generation Modes

#### 1. Melodic Dialogue (Conversational)
- Calls ascend, responses descend (or vice versa)
- Creates natural conversation feel
- **Best for**: Character dialogue, question/answer scenarios

#### 2. Rhythmic Echo
- Call establishes a rhythm, response varies it
- Keeps similar pitches but transforms the groove
- **Best for**: Rhythmic motifs, groove-based music, percussion-like melodies

#### 3. Harmonic Answer
- Response transposes the call by a musical interval (3rd, 5th, etc.)
- Classic compositional technique
- **Best for**: Harmonized melodies, call-and-response vocals, theme variations

#### 4. Question/Answer (Tension & Resolution)
- Call creates tension, response resolves to tonic
- Satisfying musical conclusion
- **Best for**: Dramatic moments, resolution needs, ending phrases

#### 5. Sequence Chain
- Each phrase progressively transposes the previous
- Creates ascending or descending patterns
- **Best for**: Building intensity, baroque-style sequences, climactic moments

#### 6. Classical Period (Antecedent/Consequent)
- Formal classical structure with tonic resolution
- Response mirrors call but ends on root note
- **Best for**: Traditional compositions, elegant themes, formal music

## Scale Reference (Parameter 3)

1. **Major** - Bright, happy (C-D-E-F-G-A-B)
2. **Natural Minor** - Dark, emotional (C-D-Eb-F-G-Ab-Bb)
3. **Dorian** - Jazz/folk feel (C-D-Eb-F-G-A-Bb)
4. **Phrygian** - Spanish/exotic (C-Db-Eb-F-G-Ab-Bb)
5. **Lydian** - Dreamy, floating (C-D-E-F#-G-A-B)
6. **Mixolydian** - Blues/rock (C-D-E-F-G-A-Bb)
7. **Minor Pentatonic** - Blues, rock (C-Eb-F-G-Bb)
8. **Major Pentatonic** - Uplifting, simple (C-D-E-G-A)
9. **Blues** - Classic blues scale (C-Eb-F-Gb-G-Bb)

## Example Use Cases

### Character Theme (Video Game)
**Auto-detected region**: "C4 Major"
- Mode: Melodic Dialogue
- Pairs: 4
- Complexity: 0.5
- **Result**: Conversational melody, perfect for character introduction

### Battle Music Motif
**Manual setup**:
- Root: F (octave 4)
- Scale: Minor Pentatonic
- Mode: Sequence Chain
- Pairs: 6
- Complexity: 0.7
- **Result**: Intense, building sequences for action

### Puzzle Solving Cue
**Auto-detected region**: "D4 Lydian"
- Mode: Question/Answer
- Pairs: 3
- Complexity: 0.4
- **Result**: Thoughtful phrases with resolution

### Jazz Improvisation Idea
**Manual setup**:
- Root: G (octave 4)
- Scale: Dorian
- Mode: Rhythmic Echo
- Pairs: 8
- Complexity: 0.8
- **Result**: Complex rhythmic conversation

### Quick Workflow Tip
Create named regions in your project (e.g., "C4 Major", "Dm Dorian") and use Auto-detect mode to instantly generate in the correct key!

## Tips for Best Results

### Complexity Guidelines
- **0.0 - 0.3**: Simple, singable melodies (even quarter/eighth notes)
- **0.4 - 0.6**: Moderate complexity (mixed rhythms, some syncopation)
- **0.7 - 1.0**: Virtuosic (sixteenths, triplets, complex patterns)

### Phrase Pair Recommendations
- **2-3 pairs**: Short musical statements (intro/outro)
- **4-6 pairs**: Full musical idea (main theme)
- **7-8 pairs**: Extended development (variation section)

### Root Note Selection
- **48-60** (C3-C4): Low register, serious tone
- **60-72** (C4-C5): Middle register, versatile
- **72-84** (C5-C6): High register, bright/delicate

### Workflow Integration
1. **Generate base idea** with script
2. **Edit/humanize** individual notes as needed
3. **Duplicate and vary** for different game states
4. **Export stems** for implementation in game engine

## Common Root Notes (for reference)
- C = 60, 72 (middle C, high C)
- D = 62, 74
- E = 64, 76
- F = 65, 77
- G = 67, 79
- A = 69, 81
- B = 71, 83

Add 1 for sharp (#), subtract 1 for flat (b)

## Editing Generated Results

The script generates notes with:
- **Humanization**: Slight timing and velocity variations
- **Musical contours**: Phrases have shape (ascending, descending, etc.)
- **Harmonic coherence**: All notes fit the chosen scale
- **Rhythmic variety**: Different patterns based on complexity

After generation, you can:
- Adjust individual velocities for expression
- Tweak note timings for more/less swing
- Transpose entire phrases for different registers
- Copy/paste phrases to extend the musical conversation

## Script Persistence

The script remembers your last used settings between sessions, so hitting "OK" with the same values will recreate similar styles. Change the complexity or mode for instant variations!

---

**Version**: 2.0
**Category**: generative-music
**Author**: James
