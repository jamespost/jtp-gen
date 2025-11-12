# DWUMMER: Phased Development Plan for Implementation (Lua ReaScript)

This plan outlines a modular, phased development strategy for the DWUMMER ReaScript, prioritizing the delivery of functional and testable code at the end of each stage.

## Phase 0: Setup and Boilerplate (Foundation) ✅ COMPLETE

**Goal:** Establish the necessary project structure, ensure the script is runnable, and implement the core mechanism for guaranteeing reproducible results.

| Task ID | Description | Specification Section | Key Concept/API |
|---------|-------------|----------------------|-----------------|
| 0.1 | Add a simple `reaper.ShowConsoleMsg("DWUMMER Initialized")` to verify execution. | N/A | Lua Script Environment |
| 0.2 | Implement the Deterministic Seed Management function. This function must initialize the script's Pseudo-Random Number Generator (PRNG) using a user-specified numerical seed. This ensures that any subsequent randomization (velocity, timing) is perfectly repeatable. | Section 1.1, 6.3 | Seeded PRNG |
| 0.3 | Implement the utility function `TimeMap_QNToPPQ` to accurately convert musical time (Quarter Notes) into REAPER's internal PPQ (Pulses Per Quarter note) required for MIDI insertion. | Section 2.1, 2.2 | REAPER Time Map Functions |
| 0.4 | Define the internal Abstract Drum Map lookup table, mapping abstract names (e.g., KICK, SNARE_ACCENT) to their default General MIDI (GM) pitch values (e.g., 36, 38, 42). | Section 6.1 | GM Standard Key Map |

**Phase 0 Deliverable:** A runnable Lua script that initializes a random seed, verifies execution in the console, and contains the core utility functions for time and pitch mapping.

---

## Phase 1: I/O Handler MVP (Core Functionality) ✅ COMPLETE

**Goal:** Create a functional bridge between the script's logic and the REAPER timeline, allowing the script to autonomously create a new MIDI item and insert notes without user interaction in the MIDI Editor.

| Task ID | Description | Specification Section | Key Concept/API |
|---------|-------------|----------------------|-----------------|
| 1.1 | Implement Transactional Safety. Place `reaper.Undo_BeginBlock()` at the start of the main generation function and `reaper.Undo_EndBlock(script_description, 1)` at the end. | Section 2.3 | Undo_BeginBlock/EndBlock |
| 1.2 | Implement Item Creation. Define a 4-bar duration (using time map functions) and call `reaper.InsertMediaItem(track, start_time, end_time)` on the currently selected track. | Section 2.1 | InsertMediaItem |
| 1.3 | Implement Note Insertion (Fixed). Retrieve the media item's active take. Insert a single Kick note (Pitch 36, Velocity 100) on beat 1 (PPQ 0) using `reaper.MIDI_InsertNote(...)`. Use the `noSort = true` flag during insertion. | Section 2.2 | MIDI_InsertNote |
| 1.4 | Implement Finalization. Call `reaper.MIDI_Sort(take)` once after note insertion is complete to order the events. | Section 2.2 | MIDI_Sort |

**Phase 1 Deliverable:** A core action that, when run, creates a new 4-bar MIDI item on the selected track containing a single Kick drum hit on the first beat. This is the script's "Hello World" output.

---

## Phase 2: Core Rhythm Engine (Algorithmic Generation) ✅ COMPLETE

**Goal:** Integrate the primary Euclidean algorithm to generate full, complex rhythmic patterns for multiple drum voices, utilizing the I/O Handler developed in Phase 1.

| Task ID | Description | Specification Section | Key Concept/API |
|---------|-------------|----------------------|-----------------|
| 2.1 | Implement the Euclidean Rhythm Algorithm. Create a function that, given parameters $N$ (Steps), $K$ (Pulses), and $R$ (Rotation), returns an array of hit placements for a single measure. | Section 3.1 | Euclidean Algorithm |
| 2.2 | Implement Multi-Voice Generation. Create independent parameter sets ($N, K, R$) for the three core voices: Kick (36), Snare (38), and Closed Hi-Hat (42). | Section 3.1 | Independent Layering |
| 2.3 | Integrate and Loop. Loop the Euclidean generation over the 4-bar duration (from 1.2), calculating the absolute PPQ position for each hit and passing it to the I/O Handler (1.3). | Section 3.1 | PPQ Offsets |
| 2.4 | Initial Parameter GUI (MVP). Implement a simple Lua window or dialogue box that allows the user to input the Seed (0.2), Pattern Length (4, 8), and the K/N values for the Kick, enabling parameter testing and repeatability checks. | Section 7.1, 6.3 | ReaScript GUI/Input |

**Phase 2 Deliverable:** The script can generate a full 4- or 8-bar rhythmic pattern (Kick, Snare, Hi-Hat) based on mathematical parameters. Running the script with the same input seed will produce an identical, complex, and editable MIDI item.

---

## Phase 3: Dynamics and Structure MVP (Musicality and Polish)

**Goal:** Implement the essential humanization parameters (groove/dynamics) and the first structural element (fills) to make the generated patterns sound professional and musical.

| Task ID | Description | Specification Section | Key Concept/API |
|---------|-------------|----------------------|-----------------|
| 3.1 | Implement Velocity Humanization. Modify the note insertion logic to apply two dynamics: (a) higher velocity on metrically strong beats (accents) and (b) a low-level random velocity jitter ($\pm 5$ to $\pm 10$) using the seeded PRNG. | Section 4.1 | Velocity Jitter |
| 3.2 | Implement Q-Swing logic. Add a function that, based on a user-defined Swing Percentage (50%–75%), calculates the precise PPQ offset to delay every second note (the off-beat) of the Hi-Hat pattern. | Section 4.2 | Swing Offsetting |
| 3.3 | Implement Snare Ghost Probability. Introduce a probabilistic layer (0–50% chance) to insert low-velocity (50–70) Snare hits (Pitch 37/Side Stick) on 1/16th positions adjacent to the main Snare hit. | Section 4.3 | Probabilistic Insertion |
| 3.4 | Implement Basic Drum Fill Logic. Define a rule-based sequence for the last bar of a 4-bar pattern, replacing the groove with a rapid sequence of notes using Toms (50) and Snare (38), achieving high rhythmic density. | Section 5.1 | Rule-Based Fill Generation |

**Phase 3 Deliverable:** The script generates highly realistic, grooving drum patterns, featuring dynamic velocity, swing, subtle ghost notes, and a musically placed drum fill, making the output immediately production-ready.

---

## Phase 4: Workflow and VST Integration (Final Touches)

**Goal:** Finalize the GUI, implement VST compatibility, and integrate the script into the core REAPER workflow for maximum efficiency.

| Task ID | Description | Specification Section | Key Concept/API |
|---------|-------------|----------------------|-----------------|
| 4.1 | Implement Custom Drum Map Loading. Add a function to load a user-specified REAPER note name .txt file. Dynamically update the internal pitch map (from 0.4) using the contents of this file to override GM values. | Section 6.2 | Custom Map Parsing |
| 4.2 | Post-Generation VST Setup. When the MIDI item is created, automatically apply the loaded custom note map to the new MIDI take and ensure the MIDI Editor will display "Named Notes" if opened. | Section 6.2 | MIDI Take Metadata |
| 4.3 | Finalize the Modular GUI. Structure the remaining controls (Genre Presets, Velocity/Timing sliders, Fill Complexity, etc.) into the defined modular layout for transparent control. | Section 7.1 | ReaScript GUI Framework |
| 4.4 | Action List Integration. Register and expose the main script function and a non-GUI version (e.g., DWUMMER: Generate Last Pattern (No GUI)) to the REAPER Action List for keybinding, enabling single-press generation. | Section 7.3 | REAPER Action List |

**Phase 4 Deliverable:** The fully featured DWUMMER script, with a complete GUI, VST compatibility via custom maps, and seamless integration into the REAPER Action List and workflow.
