# DWUMMER v3.0 - Phase 4 Quick Start Guide

## What's New in Phase 4?

DWUMMER v3.0 adds **Musical Intelligence** - your drum patterns now think, adapt, and perform like a real drummer!

---

## 🎵 Key Features at a Glance

### Automatic (When You Hit "Random"):
- ✨ **Smart Sections**: Grooves automatically adapt from intro → verse → chorus → outro
- ✨ **Dynamic Swells**: Natural volume changes and push/pull timing
- ✨ **Intelligent Fills**: Varied fills that match song intensity
- ✨ **Ghost Notes**: Context-aware embellishments (not random anymore!)
- ✨ **Human Surprises**: Subtle imperfections for realism (5% chance per note)
- ✨ **Motif Development**: Recurring rhythmic ideas that evolve

### Manual Control (When You Hit "Manual"):
- 🎛️ **Section Selection**: Choose intro, verse, chorus, bridge, or outro
- 🎛️ **Same Parameters**: All your familiar controls work as before
- 🎛️ Plus all the automatic Phase 4 intelligence!

---

## 🚀 Quick Start - 3 Ways to Use Phase 4

### 1. "Just Make It Sound Good" (Recommended)
1. Select a track in REAPER
2. Run the script
3. Choose **"Random"**
4. Done! DWUMMER creates a complete, musical drum part

**Result**: Fully arranged drum pattern with intro, development, fills, and human feel.

---

### 2. "I Want a Specific Vibe"
1. Select a track
2. Run the script
3. Choose **"Manual"**
4. Select your section type:
   - **Intro**: Sparse, building energy
   - **Verse**: Steady, supportive groove
   - **Chorus**: Full power, driving
   - **Bridge**: Different energy, transitional
   - **Outro**: Sparse, fading
5. Enter your rhythm parameters (or use defaults)
6. Done!

**Result**: Groove tailored to your chosen section with all Phase 4 intelligence.

---

### 3. "Auto-Arrange My Song"
1. Decide your song structure (e.g., 16 bars = 4 intro + 8 verse + 4 chorus)
2. Run DWUMMER **3 times**, once per section:
   - **First run**: Manual → "Intro" → 4 bars
   - **Second run**: Manual → "Verse" → 8 bars
   - **Third run**: Manual → "Chorus" → 4 bars
3. Use the **same seed** for all runs (for consistency) or different seeds (for variety)

**Result**: Complete song with evolving drum arrangement!

---

## 🎛️ Understanding Section Types

| Section | What It Does | When To Use |
|---------|--------------|-------------|
| **Auto** | Automatically changes from intro → verse → chorus → outro | Long patterns (8+ bars) where you want variety |
| **Verse** | Steady, moderate groove | Main song body, consistent energy |
| **Chorus** | Full energy, louder, denser | High-energy sections, choruses |
| **Bridge** | Medium energy with variation | Transitional sections, C-sections |
| **Intro** | Sparse, quiet, building | Song openings |
| **Outro** | Very sparse, quiet, fading | Song endings |

---

## 🧠 Phase 4 Intelligence Explained

### What Happens Automatically?

1. **Motifs** (4.1):
   - Script identifies cool 2-4 note patterns
   - Brings them back later with variations
   - Creates musical "conversation"

2. **Section Awareness** (4.2):
   - Adjusts groove density based on section
   - Changes volume and energy
   - Places fills appropriately

3. **Voice Interaction** (4.3):
   - Snare and hi-hat respond to each other
   - Creates breathing room
   - Prevents overcrowding

4. **Smart Ghost Notes** (4.4):
   - Added near phrase endings (builds tension)
   - Added before accents (anticipation)
   - Added in sparse grooves (fills space)
   - NOT just random!

5. **Intelligent Fills** (4.5):
   - Simple fills for low energy moments
   - Complex fills for high tension
   - Varied types (tom rolls, snare rolls, etc.)
   - Never the same fill twice in a row

6. **Adaptive Dynamics** (4.6):
   - Natural volume swells through bars
   - Rushing when energetic
   - Dragging when laid back
   - Each voice has different timing looseness

7. **Human Surprises** (4.7):
   - 5% chance per note: dropped beat, off-grid hit, extra ghost, etc.
   - Keeps patterns from feeling robotic
   - Maintains groove integrity (downbeats stay solid)

---

## 💡 Pro Tips

### Getting the Best Results:

1. **Use Longer Patterns**: 8-16 bars let Phase 4 shine (motifs develop, sections evolve)

2. **Compare Seeds**:
   - Same seed = similar but Phase 4 adds nuance
   - Different seed = completely different vibe

3. **Trust the Auto Mode**: It's very smart! Try it first before manual tweaking.

4. **Layer Multiple Takes**:
   - Generate kick/snare with one run
   - Generate hi-hats separately
   - Mix to taste

5. **Edit After Generation**: DWUMMER creates a MIDI item - you can still edit it!

### Common Workflows:

**Workflow A: "Quick Demo"**
- Random → 8 bars → Done!
- Use for sketching ideas fast

**Workflow B: "Full Song"**
- Manual → Pick sections → Multiple runs
- Build complete arrangement

**Workflow C: "Happy Accident Hunter"**
- Random → Generate 5 times → Pick your favorite
- Phase 4 surprises ensure variety

---

## 🔧 Troubleshooting

### "It sounds too random!"
- Use **Manual mode** with **Verse** or **Chorus** (more consistent)
- Or generate shorter patterns (4 bars)

### "I want more fills!"
- Use **Chorus** section (50% fill probability)
- Or generate longer patterns (fills at phrase boundaries)

### "It's too unpredictable!"
- Use the **same seed** every time for reproducibility
- Phase 4 adds controlled randomness, but seed ensures repeatability

### "I want old v2.0 behavior!"
- You can't disable Phase 4, but:
- Use **Verse** section with short patterns (4 bars)
- This minimizes Phase 4 intelligence
- Or keep using v2.0 script if you have it!

---

## 📊 What Changed from v2.0?

| Feature | v2.0 | v3.0 (Phase 4) |
|---------|------|----------------|
| Patterns | Static, repetitive | Evolving, developing |
| Fills | One type, last bar only | 4 types, intelligent placement |
| Ghost Notes | Random 50% | Context-aware 15-60% |
| Dynamics | Accent + jitter | Adaptive swells + section-aware |
| Timing | Perfect quantization | Human push/pull |
| Sections | None | Auto or manual selection |
| Surprises | None | Subtle human "mistakes" |

---

## 🎓 Advanced: Understanding the Seed

The **seed** controls deterministic randomness:
- Same seed = same base pattern
- Phase 4 adds small variations (controlled by seed too!)
- Use seeds to "save" patterns you like

**Example**:
- Seed 12345 with Verse = Pattern A
- Seed 12345 with Chorus = Pattern A but denser/louder
- Seed 99999 with Verse = Completely different Pattern B

---

## 🎯 Quick Checklist Before Running

- [ ] Track selected in REAPER?
- [ ] Cursor at desired start position?
- [ ] Decided: Random or Manual?
- [ ] If Manual: Chosen section type?
- [ ] Know your pattern length? (4, 8, 16 bars?)

---

## 🎵 Making Music with Phase 4

### Example Session:

**Song Structure**: Intro (4) → Verse (8) → Chorus (8) → Bridge (4) → Chorus (8) → Outro (4)

**DWUMMER Approach**:
1. Run 1: Manual → Intro → 4 bars → Seed 12345
2. Run 2: Manual → Verse → 8 bars → Seed 12345
3. Run 3: Manual → Chorus → 8 bars → Seed 12346 (slightly different for interest)
4. Run 4: Manual → Bridge → 4 bars → Seed 22222 (very different)
5. Run 5: Manual → Chorus → 8 bars → Seed 12346 (callback to chorus 1)
6. Run 6: Manual → Outro → 4 bars → Seed 12345 (callback to intro)

**Result**: Complete, professionally arranged drum track with:
- Musical development
- Consistent motifs
- Appropriate fills
- Human feel
- Natural dynamics

---

## 🚀 You're Ready!

Phase 4 makes DWUMMER a **virtual drummer**, not just a pattern generator.

**The key**: Trust the intelligence! It's designed to make musical decisions for you.

**Experiment**: Try Random mode first, explore Manual sections, and compare results!

---

*Happy drumming!*
*DWUMMER v3.0 - Phase 4 Complete*
