# DWUMMER v4.0 - Genre Modes Guide

## Overview
DWUMMER now includes 7 genre-specific modes that generate **infinitely variable yet always recognizable** drum patterns. Each genre has:
- **Core Patterns:** Immutable elements that define the genre (never change)
- **Variable Elements:** Components that randomize each generation for infinite variety

## How It Works
The genre system uses:
1. **Blueprint Architecture:** Each genre has a blueprint defining core vs. variable elements
2. **Physical Limb Constraints:** Borrowed from Zach Hill mode - realistic hand/foot movement limits
3. **Probabilistic Variation:** Every variable element has probability ranges that create authentic but unique patterns

## Genre Breakdown

### 🏠 House (120-130 BPM)
**Core (Always Present):**
- 4-on-the-floor kick on every beat
- Snare on beats 2 & 4

**Variable (Changes Each Run):**
- Hi-hat density (65-95% of 16th notes)
- Open hat on offbeats (70% chance)
- Ghost snares scattered throughout
- Ride cymbal texture layer (40% chance)

**Character:** Groovy, driving, but with breathing room and texture variation.

---

### ⚙️ Techno (125-140 BPM)
**Core (Always Present):**
- Relentless 4-on-the-floor kick
- Hard clap/snare on 2 & 4

**Variable (Changes Each Run):**
- Tight 16th hi-hat grid (85-100% density)
- Random hat accents (25% chance)
- Industrial rim/percussion layers (35% chance)
- Kick doubling for energy (20% chance)

**Character:** Mechanical, driving, with industrial edge. Denser than house.

---

### 🔌 Electro (120-135 BPM)
**Core (Always Present):**
- 4-on-the-floor kick foundation
- 808-style claps on 2 & 4

**Variable (Changes Each Run):**
- Angular hi-hat patterns (60-85% density)
- Syncopated kick variations on offbeats (45% chance)
- Cowbell/rim accents on quarters (30% chance)
- Fast 32nd note snare rolls (25% chance)

**Character:** Funky, syncopated, with 808 flavor and robotic precision.

---

### 🥁 Drum & Bass (170-180 BPM)
**Core (Always Present):**
- 2-step kick pattern (typically beats 1 & 3)
- Signature DnB snare on beat 3 (the defining characteristic)

**Variable (Changes Each Run):**
- Amen-style break variations (80% chance for complex patterns)
- Ride cymbal pattern density (50-75%)
- Heavy ghost snare layering (60% chance)
- Kick shuffle variations (50% chance)

**Character:** Fast, breakbeat-driven, with the iconic DnB "crack" on beat 3.

---

### 🌴 Jungle (160-175 BPM)
**Core (Always Present):**
- Amen break foundation (kick pattern)
- Classic backbeat snare pattern

**Variable (Changes Each Run):**
- Rapid snare chops and slices (85% chance, 70-95% density)
- Frequent snare rolls (65% chance)
- Shuffled hi-hat feel with variable swing (55-70%)
- Tom fills (50% chance)
- Ride bell patterns (45% chance)

**Character:** Chaotic, chopped breaks, heavy snare manipulation, more organic than DnB.

---

### 🎤 Hip Hop (85-105 BPM)
**Core (Always Present):**
- Boom-bap: kick on beats 1 & 3
- Snare on beats 2 & 4

**Variable (Changes Each Run):**
- Swing amount (55-68% - the laid-back feel)
- Laid-back timing variations
- Ghost snare frequency (50% chance)
- Hi-hat density (40-70% - sparse to moderate)
- Open hat variations (25% chance)
- Kick doubling (35% chance)
- Rimshot snare alternates (30% chance)

**Character:** Laid-back, swung, with space and ghost notes. The "feel" varies dramatically.

---

### 🔥 Trap (130-160 BPM)
**Core (Always Present):**
- Half-time snare on beat 3 (THE trap signature)
- 808 kick on beat 1

**Variable (Changes Each Run):**
- Rapid hi-hat rolls (70% chance, 16th or 32nd notes, 2-6 notes long)
- Hi-hat triplet patterns (50% chance)
- 808 kick pattern variations across measure (65% chance)
- Layered snare sounds (40% chance)
- Open hat accents (45% chance)

**Character:** Modern, hi-hat roll-driven, spacious but with bursts of rapid-fire hats.

---

## Usage Tips

### Generate Multiple Variations
Run the script multiple times on the same genre to hear infinite variations:
```
1. Select genre (e.g., "House")
2. Generate pattern
3. Mute/solo the new item
4. Generate again for a different variation
5. Compare and choose your favorite
```

### Combining Patterns
Layer different variations for complexity:
- Generate House pattern → duplicate item → generate again → blend the two

### Genre Hybrids
Use time selection to create genre transitions:
- Bars 1-4: Generate Hip Hop
- Bars 5-8: Generate Trap (same tempo)
- Creates evolving beat

### Working with Tempo
While each genre has a "typical" BPM range, DWUMMER generates based on your project tempo:
- For authentic results, set project BPM within the genre's range
- Experiment outside ranges for creative results

---

## Technical Details

### Pattern Length
Uses saved pattern length preference (default: 4 bars)
- Can be changed in Manual mode
- Persists across DWUMMER sessions

### Physical Constraints
All genres use limb-tracking:
- Right Foot (RF): Kick
- Left Foot (LF): Hi-hat pedal
- Right Hand (RH): Hi-hats, ride, some snare
- Left Hand (LH): Snare, toms, some cymbals

Minimum time intervals prevent physically impossible patterns:
- Feet: 60ms between hits
- Hands: 15ms between hits (faster for single drum)

### Humanization
All genres include:
- Subtle timing variations (±3ms)
- Velocity micro-adjustments
- Natural accents based on context

---

## Comparison with Other Modes

**Random Mode:** Pure Euclidean rhythm generation - abstract, mathematical patterns
**Manual Mode:** Full control over Euclidean parameters - for experimenters
**Zach Hill Mode:** Chaotic technical drumming - math-rock/experimental
**Genre Modes:** Musically authentic, infinitely variable, genre-specific patterns

---

## Future Expansion Ideas

Potential additions for future versions:
- **Breakcore:** Ultra-fast, chaotic breaks
- **Afrobeat:** Polyrhythmic, syncopated grooves
- **Reggaeton:** Dembow rhythm variations
- **Footwork:** 160 BPM juke patterns
- **Halftime:** Slow, heavy, sub-bass focused
- **User Genre Blueprints:** Define your own core/variable system

---

## Credits
DWUMMER v4.0 Genre System built on the foundation of:
- Phase 0-4 Musical Intelligence features
- Zach Hill Mode's limb constraint system
- Genre pattern research and distillation by James

Enjoy creating infinite drum variations that always sound right! 🥁
