# Melody Generator Algorithm Improvement Plan

This document outlines a step-by-step plan for improving the core melody generation algorithm in the `jtp gen_GenMusic_Melody Generator Dialog.lua` script. Each step addresses a specific musical or technical issue, with clear descriptions and progress tracking for collaborative development.

---

## Progress Tracker

| Step | Title | Status | Notes |
|------|-------|--------|-------|
| 1 | Fix repetition constraints for motif development | Completed | Implemented dynamic repetition_allowance, motif_mode parameter, and gradual repeat probability. Updated note generation logic in jtp gen_GenMusic_Melody Generator Dialog.lua. |
| 2 | Implement phrase-based structure instead of note-by-note | Completed | Replaced note-by-note generation with phrase objects (4-8 notes). Each phrase has contour type (arch/ascending/descending/valley/wave), internal coherence. Added contrast logic that varies next phrase based on previous contour. Implemented in generate_voice function. |
| 3 | Add melodic memory and motif repetition system | Completed | Added phrase_memory buffer (3-5 phrases), motif_repeat_chance parameter (0-100%, default 40%). Implemented retrieve_motif() with three variation types: transposition (2-5 scale degrees), augmentation (1.5x), and diminution (0.75x). Integrated into generate_voice function. Creates recognizable melodic themes. Version bumped to 1.8. |
| 4 | Replace random pruning with intelligent phrase-aware deletion | Not Started |  |
| 5 | Implement goal-oriented movement with tension/release | Completed | Added target note system (tonic/mediant/dominant), sectioning (intro/dev/conclusion), bias toward targets, leap bias when far, final tonic resolution. Implemented in jtp gen_GenMusic_Melody Generator Dialog.lua v1.9. |
| 6 | Improve contour shaping with musical context | Not Started |  |
| 7 | Couple rhythm and pitch with musical relationships | Not Started |  |
| 8 | Add configurable algorithm parameters to dialog | Not Started |  |
| 9 | Test and validate improvements with musical examples | Not Started |  |

---

## Step-by-Step Descriptions

### 1. Fix Repetition Constraints for Motif Development COMPLETE
- Allow 2-4 repeated notes for rhythmic motifs and musical patterns
- Replace `MAX_REPEATED=0` with a dynamic system
- Add a `motif_mode` parameter to toggle between melodic (varied) and rhythmic (repetitive) phrase generation
- Implementation: Add `repetition_allowance` parameter (default 2-3) and decrease repeat probability gradually

### 2. Implement Phrase-Based Structure Instead of Note-by-Note COMPLETE
- Replace single-note generation with phrase objects (4-8 notes)
- Each phrase has: contour type (arch, ascending, descending, valley, wave), tension level (low/medium/high), and internal coherence
- Store last phrase characteristics and create variation/contrast logic for next phrase
- Implementation: Added generate_phrase() function with 5 contour types, get_next_contour_type() for intelligent variation, refactored generate_voice() to work with phrases instead of individual notes. Version bumped to 1.7.

### 3. Add Melodic Memory and Motif Repetition System COMPLETE
- Store generated phrases in a memory buffer (last 3-5 phrases)
- Add `motif_repeat_chance` parameter (30-50%)
- When triggered, retrieve and transpose/vary a previous phrase instead of generating new
- Implement simple variation: transpose by 2-5 scale degrees, or rhythmic augmentation/diminution
- Creates recognizable melodic themes
- Implementation: Added phrase_memory buffer, retrieve_motif() function with three variation types, integrated motif repetition check into generate_voice() with configurable probability

### 4. Replace Random Pruning with Intelligent Phrase-Aware Deletion TOO PROBLEMATIC TO IMPLEMENT AS OF NOW (pruning adjustements are likely to create empty MIDI items)
- Current pruning randomly deletes notes, destroying patterns
- New approach: identify phrase boundaries (duration gaps, melodic leaps), preserve complete phrases, delete entire weak phrases instead of random notes
- Criteria for 'weak': too short (<3 notes), low variety, poor contour
- Lines 1369-1380

### 5. Implement Goal-Oriented Movement with Tension/Release COMPLETE
- Target note system added: phrases aim toward scale degrees 1 (tonic), 3 (mediant where available), and 5 (dominant)
- Sectioning: intro (low tension), development (high tension), conclusion (resolve to tonic)
- Movement bias: within phrase generation, step choices are nudged toward the section target with strength increasing across the phrase
- Leap bias: when far from target during development, leaps are more likely in the direction of the target
- Final resolution: last phrase resolves to the tonic and uses a longer ending note
- Implementation details:
	- Version bumped to 1.9 with header notes
	- New helpers: tension_factor(), degree_index_or_closest(), nudge_toward()
	- generate_phrase(...) extended with opts: {target_idx, tension_level, section, is_final}
	- generate_voice(...) divides phrases into intro/dev/conclusion and passes target/section info
	- Ensures last note per voice is tonic; conclusion last duration at least a half note
	- File: generative-music/jtp gen_GenMusic_Melody Generator Dialog.lua

### 6. Improve Contour Shaping with Musical Context
- Replace arbitrary 30% reversal with contour-aware logic
- Track cumulative direction (steps up/down counter)
- Implement contour templates: arch (up 4-6 steps, down), wave (oscillating), climb (gradual ascent)
- Add apex detection - avoid going too high/low
- Use register tracking to stay in singable range

### 7. Couple Rhythm and Pitch with Musical Relationships
- Link duration choices to melodic function: long notes on phrase endings and target tones, shorter notes during scalar runs, syncopation on approach to targets
- Add `rhythmic_profile` parameter: flowing (even rhythms), dance (syncopated), ballad (long notes with ornaments)
- Adjust duration weights dynamically based on phrase position

### 8. Add Configurable Algorithm Parameters to Dialog
- Expose new musicality controls in dialog (optional advanced section): `motif_repeat_chance` (0-100%), `phrase_length` (4-8), `tension_profile` (low/medium/high), `contour_type` (random/arch/wave/climb), `rhythmic_profile` (flowing/dance/ballad)
- Store in ExtState for persistence
- Add 'Use Musical Defaults' preset button

### 9. Test and Validate Improvements with Musical Examples
- Generate test melodies with different parameter combinations
- Verify: motifs repeat recognizably, phrases have clear shape, tension builds and resolves, no awkward random deletions mid-phrase, rhythms support melodic movement
- Create comparison examples: old algorithm vs new
- Document recommended settings for different musical styles

---

## Collaboration Guidelines
- Mark each step's status as "In Progress" or "Completed" in the table above
- Add notes on implementation details, challenges, or musical observations
- Reference code locations and commit hashes for major changes
- Use this document as a living roadmap for ongoing improvements

---

_Last updated: November 11, 2025_
