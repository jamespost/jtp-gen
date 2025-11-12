# Pianist/Guitarist Mode - Bug Fixes

## Issue
The initial implementation was generating too many fast chord changes with no clear distinction between sustained chords and fills.

## Fixes Applied

### 1. Reduced Chord Changes (Line ~2090)
**Before:** `math.random(tonumber(min_notes) or 3, tonumber(max_notes) or 8)`
**After:** `math.random(2, 4)` - Much fewer chords

**Why:** Fewer chord changes = each chord gets more time to breathe and be filled around

### 2. Increased Chord Sustain Duration (Line ~2120)
**Before:** `60-80% of time_per_chord` held for chord, 20-40% for fills
**After:** Same proportions but with better logging and gap management

**Key change:** Fills now use 90% of available space to avoid overlap

### 3. Slowed Down Arpeggios
- Now uses **8th or quarter notes** instead of arbitrary fast divisions
- Maximum 6 notes per arpeggio
- Breaks early if duration exceeded
- Deduplicates chord tones to avoid repeated pitches

### 4. Calmer Scale Runs
- Reduced start offset from 3-6 to **2-4 scale degrees**
- Adaptive note duration (16th or 8th based on available time)
- Maximum 8 notes (was 12)
- More controlled approach to target

### 5. Slower Decorative Fills
- Base duration now **8th note minimum**
- Fewer notes (2-6 instead of 4-8)
- 50% chance of neighbor tones (up from 40%)
- Better timing control

### 6. More Controlled Riffs
- Uses unique chord tones only (no duplicates)
- Shorter patterns (2-4 notes)
- Maximum 3 repeats
- Better duration calculation using 8th notes

### 7. Improved Fill Logic
- 70% chance of generating a fill, 30% silence
- Removed 'silence' from fill type selection (redundant)
- Fills target the NEXT chord root for better voice leading
- Better logging for debugging

## Result
- **Chords:** Now sustain for meaningful durations (60-80% of their time slot)
- **Fills:** Slower, more musical, clearly distinct from chords
- **Timing:** Proper spacing with rests between sections
- **Overall feel:** Like a pianist/guitarist playing sustained chords with melodic fills between

## Testing Recommendations

### Try these settings:
- **4 measures, 4 voices** - Classic piano chord progression
- **2 measures, 3 voices** - Guitar-style strumming
- **8 measures, 5 voices** - Jazz comping with space

### What you should hear:
1. Chord hits on strong beats
2. Chords ring out/sustain
3. Brief melodic fills between chords
4. Occasional silence/space
5. Fills lead smoothly into the next chord

### If it's still too fast:
- The script now has debug logging - check REAPER's console
- Look for "Time per chord" values - should be multiple seconds
- Each chord should have clear "hold" and "fill space" logged
