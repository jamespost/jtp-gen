-- @author James
-- @version 3.0
-- @about
--   # jtp gen: Melody Generator (Simple Dialog)
--   Generates a MIDI melody with a simple built-in REAPER dialog (no ImGui required).
--   Lets you set a few key parameters quickly and create a melody on the selected track.
--
--   NEW in v3.0: MASTER IMPROVISER MODE! 🎹🎸
--   The Pianist/Guitarist mode now thinks like a virtuoso improviser!
--
--   ** ADVANCED ORNAMENTATION (10 new ornament types): **
--   - Trills, turns, mordents: Classical ornaments with authentic execution
--   - Grace note clusters: Multiple grace notes leading elegantly to targets
--   - Chromatic approaches: Half-step approaches for jazzy sophistication
--   - Enclosures: Surround target notes from above and below
--
--   ** MOTIVIC DEVELOPMENT (5 techniques): **
--   - Sequence: Repeat musical ideas at different pitches
--   - Fragmentation: Break motifs into smaller pieces for variation
--   - Inversion: Flip melodic contours upside down
--   - Retrograde: Play motifs backwards
--   - Rhythmic displacement: Keep pitches, transform rhythm
--
--   ** POLYRHYTHMIC PATTERNS (5 advanced rhythms): **
--   - Triplet runs: Flowing 3-against-2 passages
--   - Quintuplet flourishes: Complex 5-note groupings
--   - Syncopated riffs: Off-beat accented patterns
--   - Rubato passages: Freely timed expressive phrases
--   - Hemiola patterns: 3-against-2 metric modulation
--
--   ** REGISTER EXPLORATION (4 dramatic techniques): **
--   - Octave leap arpeggios: Jump between registers dramatically
--   - Wide interval jumps: Leaps of 6ths, 7ths, octaves+
--   - Cascade descents: Rapid downward motion with accelerando
--   - Ascending rockets: Quick upward bursts to high register
--
--   ** HARMONIC SOPHISTICATION (4 advanced concepts): **
--   - Extended voicings: Add 9ths, 11ths, 13ths to chords
--   - Altered chord fills: Chromatic alterations and substitutions
--   - Tension/resolution: Build harmonic tension then release
--   - Modal exploration: Emphasize characteristic modal colors
--
--   Total: 39 distinct improvisational techniques that combine to create
--   endlessly varied, musical, sophisticated improvisations that sound like
--   a master player at work!
--
--   v2.1: Enhanced Pianist/Guitarist Mode!
--   - Polyphonic fills! Two-voice arpeggios, walking bass + melody, chord stabs
--   - 6 new fill types: polyphonic arps, bass walks, tremolo, grace notes, rhythmic stabs
--   - Timing humanization: groove/swing on chords, subtle note timing variations
--   - Dynamic chord durations: punchy (50-60%), medium (65-75%), sustained (75-85%)
--   - Velocity humanization: top notes emphasized, slight variations within chords
--   - Piano-like chord stagger (2ms per voice for realistic attack)
--
--   v2.0: Pianist/Guitarist Polyphony Mode!
--   - Thinks like a piano/guitar player: chords on strong beats, fills in between
--   - Fill types: arpeggios (up/down), scale runs to next chord, decorative ornaments
--   - Chord-based riffs and intelligent spacing (silence as a musical element)
--   - Target-aware runs that approach the next chord smoothly
--   - Voice leading applied to chord voicings for smooth progressions
--
--   NEW in v1.9: Goal-Oriented Tension and Release!
--   - Phrases now aim toward musical targets (tonic/mediant/dominant)
--   - Sections: intro (low tension), development (high tension), conclusion (resolve)
--   - Movement biases toward targets and increases leaps when far
--   - Final phrase resolves to tonic with a longer note
--
--   NEW in v1.8: Melodic Memory and Motif Repetition!
--   - Phrase memory buffer stores last 3-5 phrases
--   - Motif repetition chance parameter (30-50% default)
--   - Retrieves and varies previous phrases with transposition
--   - Creates recognizable melodic themes and development
--   - Augmentation/diminution for rhythmic variation
--
--   v1.7: Phrase-Based Structure!
--   - Replaced note-by-note generation with phrase-based system
--   - Each phrase has 4-8 notes with coherent contour shapes
--   - Five contour types: arch, ascending, descending, valley, wave
--   - Intelligent variation: next phrase contrasts with previous
--   - Creates more musical, structured melodies with clear phrases
--
--   v1.6: Rhythmic Guitar Mode!
--   - Adapted from adaptive drum generator
--   - Uses drum-style rhythm/articulation patterns with guitar note choices
--   - Features: bursts, double hits, focused riffs, rhythmic complexity
--   - Combines physical constraint modeling with melodic note selection
--   - Disabled by default - toggle in parameters dialog
--
--   NEW in v1.5: Auto Mode - One-Click Generation!
--   - First dialog: Choose "Auto" to instantly generate with last settings, or "Manual" to configure
--   - Auto mode = zero-click generation with your preferred settings
--   - Perfect for rapid iteration and workflow speed
--
--   Auto-detection mode (enabled by default) - automatically detects root note and
--   scale from the name of the region containing the selected item or edit cursor.
--   When a region is detected, note/octave/scale dialogs are skipped!
--
--   Advanced Polyphony with Music Theory (v1.4)
--   - Four polyphony modes: Free (creative), Harmonic (chords), Voice Leading (counterpoint), Pianist/Guitarist
--   - Pianist/Guitarist mode: Chords on strong beats with fills between (runs, riffs, arpeggios)
--   - Zach Hill Polyphonic mode (v3.x): Chaotic virtuoso adaptation of drum engine (bursts, double strokes, paradiddle pitch patterns, focused riff subsets, adaptive velocities)
--   - Theory Weight parameter (0-1) blends between free/creative and strict music theory
--   - Proper voice leading rules: contrary motion, smooth voice movement, consonance
--   - Avoids parallel perfect intervals, voice crossing, and other theory violations
--   - Weight 0 = original creative behavior, Weight 1 = strict theory adherence
--
--   Supported region name formats:
--   - "C Major", "Dm", "G# minor", "Ab Dorian" (defaults to octave 4)
--   - "C4 major", "D#2 minor", "Gb5 Lydian" (explicit octave 0-9)
--   - Supports sharps (#), flats (b), and various scale names
--
--   Dialog options:
--   - Auto-detect from region (ON) - Skip dialogs when region detected
--   - Override auto-detected values - Use detected values as defaults but allow changes
--   - Manual selection (OFF) - Always show all dialogs

-- Check if reaper API is available
if not reaper then return end

local DEBUG = false

local function log(...)
    if not DEBUG then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    reaper.ShowConsoleMsg(table.concat(parts, '') .. '\n')
end

if DEBUG then reaper.ClearConsole() end

-- =============================
-- Defaults and persistence
-- =============================
local EXT_SECTION = 'jtp_gen_melody_dialog'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- Reasonable defaults
local defaults = {
    measures = tonumber(get_ext('measures', 2)),
    min_notes = tonumber(get_ext('min_notes', 3)),
    max_notes = tonumber(get_ext('max_notes', 7)),
    min_keep = tonumber(get_ext('min_keep', 12)),
    max_keep = tonumber(get_ext('max_keep', 24)),
    root_note = tonumber(get_ext('root_note', 60)), -- Middle C
    scale_name = get_ext('scale_name', 'random'), -- type a name from list below or 'random'
    num_voices = tonumber(get_ext('num_voices', 4)), -- Number of melodic voices (1-16)
    auto_detect = get_ext('auto_detect', '1') == '1', -- Auto-detect from region name (default enabled)
    ca_mode = get_ext('ca_mode', '0') == '1', -- Cellular Automata mode (default disabled)
    poly_mode = get_ext('poly_mode', 'free'), -- Polyphony mode: 'free', 'harmonic', 'voice_leading'
    theory_weight = tonumber(get_ext('theory_weight', 0.5)), -- 0.0 = free, 1.0 = strict theory
    rhythmic_guitar_mode = get_ext('rhythmic_guitar_mode', '0') == '1', -- Rhythmic guitar mode (default disabled)
    motif_mode = get_ext('motif_mode', 'melodic'), -- 'melodic' or 'rhythmic'
    repetition_allowance = tonumber(get_ext('repetition_allowance', 3)), -- 2-4 allowed repeats
    motif_repeat_chance = tonumber(get_ext('motif_repeat_chance', 40)), -- 0-100% chance of repeating a previous phrase
}

-- Deferred execution flag for Zach Hill polyphonic mode
local zach_hill_defer = false

-- Small curated scale list (intervals from root)
local scales = {
    major = {0,2,4,5,7,9,11},
    natural_minor = {0,2,3,5,7,8,10},
    dorian = {0,2,3,5,7,9,10},
    phrygian = {0,1,3,5,7,8,10},
    lydian = {0,2,4,6,7,9,11},
    mixolydian = {0,2,4,5,7,9,10},
    locrian = {0,1,3,5,6,8,10},
    harmonic_minor = {0,2,3,5,7,8,11},
    melodic_minor = {0,2,3,5,7,9,11},
    major_pentatonic = {0,2,4,7,9},
    minor_pentatonic = {0,3,5,7,10},
    whole_tone = {0,2,4,6,8,10},
    blues = {0,3,5,6,7,10}
}

-- One-word mood descriptors for each scale/mode (display only)
scale_moods = {
    major = 'Bright',
    natural_minor = 'Sad',
    dorian = 'Soulful',
    phrygian = 'Dark',
    lydian = 'Dreamy',
    mixolydian = 'Bluesy',
    locrian = 'Tense',
    harmonic_minor = 'Exotic',
    melodic_minor = 'Elegant',
    major_pentatonic = 'Open',
    minor_pentatonic = 'Moody',
    whole_tone = 'Surreal',
    blues = 'Gritty'
}

-- Build sorted scale list for consistent menu ordering
local scale_keys = {}
for k in pairs(scales) do scale_keys[#scale_keys+1] = k end
table.sort(scale_keys)

-- =============================
-- Helpers
-- =============================
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function choose_random(t)
    return t[math.random(1, #t)]
end

local function table_contains(t, x)
    for i = 1, #t do if t[i] == x then return true end end
    return false
end

-- Zach Hill Polyphonic Melody Mode - REWRITTEN v2.0
-- Rhythmic Engine: Identical to DWUMMER Zach Hill Mode (bursts, doubles, paradiddles, riffs, physical constraints)
-- Melodic Engine: Sequencer-style note selection (repetitive patterns, stepwise motion, octave range)
local function generate_zach_hill_polyphonic(take, start_time, end_time, scale_notes, num_voices, measures, min_keep, max_keep, quarter_note)
    local function clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end

    -- =============================
    -- PERSISTENCE & CONFIGURATION
    -- =============================
    local EXT_ZACH = 'jtp_gen_melody_zach'
    local function get_zach(key, def)
        local v = reaper.GetExtState(EXT_ZACH, key)
        if v=='' then return def end
        return tonumber(v) or def
    end
    local function set_zach(key,val)
        reaper.SetExtState(EXT_ZACH, key, tostring(val), true)
    end

    -- DWUMMER Zach Hill rhythm parameters (adaptive)
    local BURST_CHANCE        = get_zach('burst_chance', 0.250)
    local DOUBLE_CHANCE       = get_zach('double_chance', 0.250)
    local PARADIDDLE_CHANCE   = get_zach('paradiddle_chance', 0.250)
    local FOCUSED_RIFF_CHANCE = get_zach('focused_riff_chance', 0.300)
    local ANCHOR_DOWNBEAT_CHANCE = get_zach('anchor_downbeat_chance', 0.300)
    local RANDOM_BEAT_ACCENT_CHANCE = get_zach('random_accent_chance', 0.600)
    local SUBDIVS_MAX         = get_zach('subdivs_max', 2) -- 1-3 for melodic context
    local SUBDIVS_MIN         = 1

    -- Zach Hill phrasing: 3 bars riff + 1 bar fill
    local PHRASE_LENGTH = 4
    local REPEAT_BARS = 3

    -- Density controls
    local MIN_NOTES_PER_MEASURE = 12 -- Ensure activity
    local TEXTURE_LAYER_CHANCE = 0.85 -- High chance for dense melodic texture

    -- =============================
    -- PPQ & TIME UTILITIES
    -- =============================
    local PPQ = 960
    local function timeToPPQ(t) return reaper.MIDI_GetPPQPosFromProjTime(take, t) end
    local function ppqToTime(ppq) return reaper.MIDI_GetProjTimeFromPPQPos(take, ppq) end

    local start_ppq = timeToPPQ(start_time)
    local end_ppq = timeToPPQ(end_time)
    local total_ppq = end_ppq - start_ppq

    local time_sig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, start_time)
    local measure_len_ppq = time_sig_num * PPQ
    local num_measures = math.floor(total_ppq / measure_len_ppq)

    -- =============================
    -- MELODIC SEQUENCER ENGINE
    -- =============================
    -- Infer sequencer style from register
    local avg_note = scale_notes[math.floor(#scale_notes / 2)]
    local seq_style
    if avg_note < 48 then seq_style = 'bass'
    elseif avg_note < 72 then seq_style = 'lead'
    else seq_style = 'arp' end

    -- Sequencer parameters by style (like synth sequencer mode)
    local range_limit, vel_base, vel_range
    if seq_style == 'bass' then
        range_limit = math.min(5, #scale_notes) -- Stay within 5 scale degrees
        vel_base, vel_range = 95, 20 -- Punchy
    elseif seq_style == 'lead' then
        range_limit = math.min(9, #scale_notes) -- More melodic freedom
        vel_base, vel_range = 85, 25 -- Dynamic variation
    else -- arpeggio
        range_limit = math.min(12, #scale_notes) -- Full range
        vel_base, vel_range = 75, 20 -- Consistent
    end

    -- Scale degree index tracking per voice
    local voice_scale_idx = {}
    for v = 0, num_voices - 1 do
        voice_scale_idx[v] = math.random(1, math.min(range_limit, #scale_notes))
    end

    -- Choose melodic note with sequencer logic
    local function choose_sequencer_note(voice_id, style)
        local current_idx = voice_scale_idx[voice_id]
        local move

        if style == 'bass' then
            -- Bass: root-fifth motion, occasional passing tones
            move = ({0, 0, 0, 4, 4, 1, -1})[math.random(1, 7)] -- Bias to root/fifth
        elseif style == 'lead' then
            -- Lead: stepwise with occasional leaps
            if math.random() < 0.7 then
                move = ({-1, 0, 1})[math.random(1, 3)] -- Stepwise
            else
                move = ({-3, -2, 2, 3})[math.random(1, 4)] -- Small leaps
            end
        else -- arp
            -- Arpeggio: systematic triadic motion
            move = ({-4, -2, 0, 2, 4})[math.random(1, 5)] -- Triadic intervals
        end

        -- Update and clamp to range
        current_idx = clamp(current_idx + move, 1, math.min(range_limit, #scale_notes))
        voice_scale_idx[voice_id] = current_idx

        return scale_notes[current_idx]
    end

    -- Choose note from focused riff subset (for focused riff mode)
    local function choose_riff_note(riff_subset, idx)
        return riff_subset[((idx % #riff_subset) + 1)]
    end

    -- =============================
    -- PHYSICAL CONSTRAINT ENGINE (from DWUMMER)
    -- =============================
    local HUMANIZE_MS = 3 -- Subtle timing humanization
    local MIN_VOICE_INTERVAL = 0.015 -- Minimum time between notes on same voice (like hand movement)

    local voice_state = {}
    for v = 0, num_voices - 1 do
        voice_state[v] = {
            last_note_time = nil,
            last_pitch = nil
        }
    end

    local function can_voice_play(voice_id, requested_time)
        local st = voice_state[voice_id]
        if not st.last_note_time then return true end
        local dt = requested_time - st.last_note_time
        return dt >= MIN_VOICE_INTERVAL
    end

    -- Dynamic velocity (from DWUMMER logic)
    local function get_dynamic_velocity(voice_id, note_time, measure_idx, accent, is_rapid)
        local base = vel_base

        -- Build intensity through measures
        base = base + math.floor((measure_idx / num_measures) * 15)

        -- Accent boost
        if accent then base = base + 20 end

        -- Rapid notes are quieter
        if is_rapid then base = base - 15 end

        -- Randomization
        base = base + math.random(-8, 8)

        return clamp(base, 20, 127)
    end

    -- Insert note with humanization and physical constraints
    local function insert_melodic_note(ppq_pos, voice_id, pitch, velocity, duration_ppq)
        local note_time = ppqToTime(ppq_pos)
        local humanize_offset = (math.random() * 2 - 1) * (HUMANIZE_MS / 1000)
        local final_time = note_time + humanize_offset

        -- Check physical constraint
        if not can_voice_play(voice_id, final_time) then
            return false -- Can't play this note
        end

        -- Insert note
        local ppq_with_offset = timeToPPQ(final_time)
        local note_off = ppq_with_offset + duration_ppq
        reaper.MIDI_InsertNote(take, false, false, ppq_with_offset, note_off, voice_id, pitch, velocity, false)

        -- Update voice state
        voice_state[voice_id].last_note_time = final_time
        voice_state[voice_id].last_pitch = pitch

        return true
    end

    -- =============================
    -- RHYTHM PATTERN FUNCTIONS (from DWUMMER)
    -- =============================

    -- Burst pattern: rapid cluster of notes
    local function insert_burst(measure_ppq, sub_tick, measure_end_ppq, voice_id, measure_idx, seq_style)
        local BURST_NOTES = 6
        local burst_subset = {}
        for i = 1, 5 do
            table.insert(burst_subset, choose_sequencer_note(voice_id, seq_style))
        end

        local sub_dur_ppq = math.floor(PPQ / 4) -- 16th note space
        local note_spacing = math.floor(sub_dur_ppq / (BURST_NOTES + 1))

        for b = 1, BURST_NOTES do
            local bt_ppq = sub_tick + (b - 1) * note_spacing
            if bt_ppq >= measure_end_ppq then break end

            -- Mirrored pitch selection (like original)
            local pitch_idx = (b <= BURST_NOTES/2) and b or (BURST_NOTES - b + 1)
            local pitch = burst_subset[math.min(pitch_idx, #burst_subset)]

            local velocity = get_dynamic_velocity(voice_id, ppqToTime(bt_ppq), measure_idx, false, true)
            local duration = math.floor(note_spacing * 0.8)

            insert_melodic_note(bt_ppq, voice_id, pitch, velocity, duration)
        end
    end

    -- Double stroke: same note hit twice quickly
    local function insert_double_stroke(sub_tick, voice_id, measure_idx, seq_style)
        local pitch = choose_sequencer_note(voice_id, seq_style)
        local spacing = math.floor(PPQ / 16) -- 32nd note spacing
        local duration = math.floor(spacing * 0.85)

        local velocity = get_dynamic_velocity(voice_id, ppqToTime(sub_tick), measure_idx, false, false)

        insert_melodic_note(sub_tick, voice_id, pitch, velocity, duration)
        insert_melodic_note(sub_tick + spacing, voice_id, pitch, velocity, duration)
    end

    -- Paradiddle pattern: 8-stroke rudiment with two pitches (L R L L R L R R)
    local function insert_paradiddle(sub_tick, voice_id, measure_idx, seq_style)
        local paradiddle_seq = {1, 2, 1, 1, 2, 1, 2, 2} -- Pitch alternation pattern
        local subset = {
            choose_sequencer_note(voice_id, seq_style),
            choose_sequencer_note(voice_id, seq_style)
        }

        local sub_dur_ppq = math.floor(PPQ / 4) -- 16th note space
        local stroke_spacing = math.floor(sub_dur_ppq / #paradiddle_seq)

        for idx, pitch_sel in ipairs(paradiddle_seq) do
            local stroke_ppq = sub_tick + (idx - 1) * stroke_spacing
            local pitch = subset[pitch_sel]
            local velocity = get_dynamic_velocity(voice_id, ppqToTime(stroke_ppq), measure_idx, false, false)
            local duration = math.floor(stroke_spacing * 0.85)

            insert_melodic_note(stroke_ppq, voice_id, pitch, velocity, duration)
        end
    end

    -- Focused riff: repetitive pattern with subset of notes (Zach Hill signature)
    local function insert_focused_riff(measure_start_ppq, measure_end_ppq, riff_spec, voice_id, measure_idx, seq_style)
        local riff_subset = riff_spec.subset
        local pattern_length = riff_spec.pattern_length

        local total_space = measure_end_ppq - measure_start_ppq
        local spacing = math.max(1, math.floor(total_space / (pattern_length * 3)))
        local duration = math.floor(spacing * 0.9)

        local pos = measure_start_ppq
        local idx = 0

        while pos < measure_end_ppq do
            for p = 1, pattern_length do
                idx = idx + 1
                local insert_pos = pos + (p - 1) * spacing
                if insert_pos >= measure_end_ppq then break end

                -- Primary stroke
                local pitch = choose_riff_note(riff_subset, idx)
                local velocity = get_dynamic_velocity(voice_id, ppqToTime(insert_pos), measure_idx, false, false)

                insert_melodic_note(insert_pos, voice_id, pitch, velocity, duration)

                -- Optional interstitial stroke (avoid linearity)
                if math.random() < 0.5 then
                    local inter_pos = insert_pos + math.floor(spacing * 0.5)
                    if inter_pos < measure_end_ppq then
                        local inter_pitch = choose_riff_note(riff_subset, idx + 1)
                        local inter_vel = get_dynamic_velocity(voice_id, ppqToTime(inter_pos), measure_idx, false, true)
                        insert_melodic_note(inter_pos, voice_id, inter_pitch, inter_vel, math.floor(duration * 0.8))
                    end
                end
            end
            pos = pos + (pattern_length * spacing)
        end
    end

    -- Chaotic fill: dense tom/snare activity (for fill bars)
    local function insert_chaos_fill(measure_start_ppq, measure_end_ppq, voice_id, measure_idx, seq_style)
        -- First half: anchor
        local anchor_pitch = choose_sequencer_note(voice_id, seq_style)
        local anchor_vel = get_dynamic_velocity(voice_id, ppqToTime(measure_start_ppq), measure_idx, true, false)
        insert_melodic_note(measure_start_ppq, voice_id, anchor_pitch, anchor_vel, math.floor(PPQ * 0.9))

        -- Second half: burst clusters
        local fill_start = measure_start_ppq + math.floor((time_sig_num - 1) * PPQ)
        local cur = fill_start

        while cur < measure_end_ppq do
            local remaining = measure_end_ppq - cur
            local subdivs = math.max(3, SUBDIVS_MAX)
            local ticks_per_sub = math.max(1, math.floor(PPQ / subdivs))

            if math.random() < 0.6 then
                -- Burst cluster
                local cluster_size = math.min(8, math.floor(remaining / math.max(1, ticks_per_sub / 5)))
                for i = 0, cluster_size - 1 do
                    local pos = cur + i * math.floor(ticks_per_sub / (cluster_size + 1))
                    if pos >= measure_end_ppq then break end

                    local pitch = choose_sequencer_note(voice_id, seq_style)
                    local velocity = get_dynamic_velocity(voice_id, ppqToTime(pos), measure_idx, false, true)
                    local duration = math.floor((ticks_per_sub / (cluster_size + 1)) * 0.8)

                    insert_melodic_note(pos, voice_id, pitch, velocity, duration)
                end
            else
                -- Paradiddle figure
                insert_paradiddle(cur, voice_id, measure_idx, seq_style)
            end

            cur = cur + ticks_per_sub
        end

        -- Strong ending: accent on last note
        local end_pos = measure_end_ppq - math.floor(PPQ * 0.05)
        local end_pitch = scale_notes[1] -- Resolve to tonic
        local end_vel = get_dynamic_velocity(voice_id, ppqToTime(end_pos), measure_idx, true, false)
        insert_melodic_note(end_pos, voice_id, end_pitch, end_vel, math.floor(PPQ * 0.4))
    end

    -- =============================
    -- MAIN GENERATION LOOP (DWUMMER structure)
    -- =============================

    -- Generate riff spec for phrase repetition
    local function generate_riff_spec(seq_style)
        local subset = {}
        for i = 1, math.random(2, 3) do
            table.insert(subset, choose_sequencer_note(0, seq_style))
        end
        return {
            subset = subset,
            pattern_length = math.random(3, 5)
        }
    end

    local measure_start_ppq = start_ppq
    local riff_spec = nil

    for m = 1, num_measures do
        local measure_end_ppq = measure_start_ppq + measure_len_ppq

        -- Determine phrase position (1..PHRASE_LENGTH)
        local phrase_pos = ((m - 1) % PHRASE_LENGTH) + 1

        -- Anchor downbeat (like DWUMMER)
        if math.random() < ANCHOR_DOWNBEAT_CHANCE then
            local anchor_pitch = choose_sequencer_note(0, seq_style)
            local anchor_vel = get_dynamic_velocity(0, ppqToTime(measure_start_ppq), m, true, false)
            insert_melodic_note(measure_start_ppq, 0, anchor_pitch, anchor_vel, math.floor(PPQ * 0.9))
        end

        -- Random beat accent
        if math.random() < RANDOM_BEAT_ACCENT_CHANCE then
            local random_beat_idx = math.random(1, time_sig_num)
            local random_beat_ppq = measure_start_ppq + (random_beat_idx - 1) * PPQ
            local accent_pitch = choose_sequencer_note(0, seq_style)
            local accent_vel = get_dynamic_velocity(0, ppqToTime(random_beat_ppq), m, true, false)
            insert_melodic_note(random_beat_ppq, 0, accent_pitch, accent_vel, math.floor(PPQ * 0.5))
        end

        -- Texture layer: 8th note melodic scaffold (like DWUMMER hat layer)
        if math.random() < TEXTURE_LAYER_CHANCE then
            local eighth_ticks = math.floor(PPQ * 0.5)
            local t = measure_start_ppq
            while t < measure_end_ppq do
                local pitch = choose_sequencer_note(1, seq_style)
                local vel = get_dynamic_velocity(1, ppqToTime(t), m, false, false) - 15 -- Quieter layer
                insert_melodic_note(t, 1, pitch, vel, math.floor(eighth_ticks * 0.85))
                t = t + eighth_ticks
            end
        end

        -- PHRASE LOGIC: 3x repeat riff, then fill (Zach Hill signature)
        if phrase_pos <= REPEAT_BARS then
            -- Repeating riff bars
            if phrase_pos == 1 or not riff_spec then
                riff_spec = generate_riff_spec(seq_style)
            end

            -- Insert focused riff (skip first beat if anchor was placed)
            local riff_start = measure_start_ppq + PPQ
            insert_focused_riff(riff_start, measure_end_ppq, riff_spec, 0, m, seq_style)

        else
            -- Fill bar: chaos!
            insert_chaos_fill(measure_start_ppq, measure_end_ppq, 0, m, seq_style)
            riff_spec = nil -- New idea after fill
        end

        measure_start_ppq = measure_end_ppq
    end

    -- =============================
    -- POST-PROCESSING
    -- =============================

    -- Sort MIDI events
    reaper.MIDI_Sort(take)

    -- Adaptive parameter evolution (like DWUMMER)
    set_zach('burst_chance', clamp(BURST_CHANCE + 0.02, 0.15, 0.40))

    log('Zach Hill Polyphonic v2.0: Generated ', num_measures, ' measures in ', seq_style, ' style')
    log('  Rhythm: DWUMMER Zach Hill engine (bursts, doubles, paradiddles, riffs)')
    log('  Melody: Sequencer-style note selection (repetitive, stepwise)')
end

-- =============================
-- Region name parsing
-- =============================

-- Parse region name to extract root note and scale
-- Supports formats like: "C Major", "Dm", "G# minor", "Ab Dorian", "C4 major", etc.
local function parse_region_name(region_name)
    if not region_name or region_name == "" then return nil, nil, nil end

    -- Normalize the string
    local name = region_name:lower():gsub("^%s*(.-)%s*$", "%1") -- trim whitespace

    -- Define note patterns with their pitch classes
    local note_patterns = {
        {"c#", 1}, {"c♯", 1}, {"db", 1}, {"d♭", 1}, {"c sharp", 1}, {"d flat", 1},
        {"c", 0},
        {"d#", 3}, {"d♯", 3}, {"eb", 3}, {"e♭", 3}, {"d sharp", 3}, {"e flat", 3},
        {"d", 2},
        {"e", 4},
        {"f#", 6}, {"f♯", 6}, {"gb", 6}, {"g♭", 6}, {"f sharp", 6}, {"g flat", 6},
        {"f", 5},
        {"g#", 8}, {"g♯", 8}, {"ab", 8}, {"a♭", 8}, {"g sharp", 8}, {"a flat", 8},
        {"g", 7},
        {"a#", 10}, {"a♯", 10}, {"bb", 10}, {"b♭", 10}, {"a sharp", 10}, {"b flat", 10},
        {"a", 9},
        {"b", 11}
    }

    -- Try to find note at start of name
    local found_note_class = nil
    local remaining_text = name

    for _, pattern_data in ipairs(note_patterns) do
        local pattern = pattern_data[1]
        local pitch_class = pattern_data[2]

        -- Try to match at start with word boundary
        if name:match("^" .. pattern .. "[%s_%-]") or name:match("^" .. pattern .. "$") then
            found_note_class = pitch_class
            remaining_text = name:gsub("^" .. pattern, ""):gsub("^[%s_%-]+", "")
            break
        end
    end

    if not found_note_class then return nil, nil, nil end

    -- Try to extract octave number (0-9) if present
    local found_octave = nil
    local octave_match = remaining_text:match("^(%d)")
    if octave_match then
        found_octave = tonumber(octave_match)
        -- Remove the octave from remaining text
        remaining_text = remaining_text:gsub("^%d+", ""):gsub("^[%s_%-]+", "")
    end

    -- Now try to find scale in remaining text
    local scale_patterns = {
        {"maj", "major"},
        {"major", "major"},
        {"m", "natural_minor"},
        {"min", "natural_minor"},
        {"minor", "natural_minor"},
        {"dor", "dorian"},
        {"dorian", "dorian"},
        {"phryg", "phrygian"},
        {"phrygian", "phrygian"},
        {"lyd", "lydian"},
        {"lydian", "lydian"},
        {"mix", "mixolydian"},
        {"mixolydian", "mixolydian"},
        {"loc", "locrian"},
        {"locrian", "locrian"},
        {"harm", "harmonic_minor"},
        {"harmonic", "harmonic_minor"},
        {"mel", "melodic_minor"},
        {"melodic", "melodic_minor"},
        {"pent", "major_pentatonic"},
        {"pentatonic", "major_pentatonic"},
        {"whole", "whole_tone"},
        {"blues", "blues"}
    }

    local found_scale = nil
    for _, scale_data in ipairs(scale_patterns) do
        local pattern = scale_data[1]
        local scale_name = scale_data[2]

        if remaining_text:match(pattern) then
            found_scale = scale_name
            break
        end
    end

    -- If no scale found, try to infer from minor indicator
    if not found_scale then
        -- Default to major
        found_scale = "major"
    end

    return found_note_class, found_scale, found_octave
end

-- Get region(s) at current position (selected item or edit cursor)
local function get_region_at_position()
    local pos = nil

    -- First, try to get position from selected item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    else
        -- No item selected, use edit cursor
        pos = reaper.GetCursorPosition()
    end

    if not pos then return nil end

    -- Find region at this position
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    for i = 0, num_markers + num_regions - 1 do
        local _, is_region, region_start, region_end, name, idx = reaper.EnumProjectMarkers(i)

        if is_region and pos >= region_start and pos < region_end then
            log('Found region: "', name, '" at position ', pos)
            return name
        end
    end

    log('No region found at position ', pos)
    return nil
end

-- =============================
-- Dialog helpers
-- =============================
-- Note names with enharmonic equivalents
local note_names = {"C","C#/Db","D","D#/Eb","E","F","F#/Gb","G","G#/Ab","A","A#/Bb","B"}

-- Map display names back to MIDI pitch class
local note_display_to_pitch_class = {
    ["C"] = 0,
    ["C#/Db"] = 1,
    ["D"] = 2,
    ["D#/Eb"] = 3,
    ["E"] = 4,
    ["F"] = 5,
    ["F#/Gb"] = 6,
    ["G"] = 7,
    ["G#/Ab"] = 8,
    ["A"] = 9,
    ["A#/Bb"] = 10,
    ["B"] = 11
}

local function note_name_to_pitch(name, octave)
    local pitch_class = note_display_to_pitch_class[name]
    if pitch_class then
        return (octave + 1) * 12 + pitch_class
    end
    return nil
end

local function show_popup_menu(items, default_idx)
    -- Build menu string for gfx.showmenu with checkmark on default
    local menu_str = ""
    for i, item in ipairs(items) do
        if i == default_idx then
            menu_str = menu_str .. "!" .. item .. "|"
        else
            menu_str = menu_str .. item .. "|"
        end
    end

    -- Position menu at mouse cursor
    gfx.x, gfx.y = reaper.GetMousePosition()
    local choice = gfx.showmenu(menu_str)
    return choice -- Returns 0 if cancelled, or 1-based index of selection
end

-- =============================
-- Dialog - Step 0: Mode Selection (Auto vs Manual)
-- =============================

-- Declare ALL variables at top level BEFORE any goto statements to avoid scope issues
local auto_detected_note_class = nil
local auto_detected_scale = nil
local auto_detected_octave = nil
local region_name = nil
local auto_detect_enabled
local force_manual = false
local root_note
local scale_name
local measures
local min_notes
local max_notes
local min_keep
local max_keep
local num_voices
local ca_mode
local ca_growth_rate
local ca_time_bias
local poly_mode
local theory_weight
local chosen_scale_key
local chosen_scale
local auto_detect_items
local default_auto_detect_idx
local auto_detect_choice
local default_root_note
local target_octave
local default_note_name
local default_octave
local default_note_idx
local note_choice
local octaves
local default_octave_idx
local octave_choice
local scale_menu_items
local default_scale_name
local default_scale_idx
local scale_choice
local input_note_name
local input_octave
local poly_modes
local default_poly_idx
local poly_choice
local captions
local defaults_csv
local ok
local ret
local fields
local rhythmic_guitar_mode
local motif_repeat_chance

local mode_items = {"Auto (use last settings)", "Manual (configure all settings)"}
local mode_choice = show_popup_menu(mode_items, 1)
if mode_choice == 0 then return end -- User cancelled

local use_auto_mode = (mode_choice == 1)

-- =============================
-- AUTO MODE - Skip all dialogs and use saved settings
-- =============================

if use_auto_mode then
    log('Auto mode selected - using last saved settings')
    -- Jump directly to melody generation
    goto GENERATE_MELODY
end

-- =============================
-- MANUAL MODE - Show all dialogs
-- =============================

-- =============================
-- Auto-detection from region name
-- =============================

if defaults.auto_detect then
    region_name = get_region_at_position()
    if region_name then
        auto_detected_note_class, auto_detected_scale, auto_detected_octave = parse_region_name(region_name)
        if auto_detected_note_class then
            log('Auto-detected from region "', region_name, '": note class ', auto_detected_note_class, ', scale ', auto_detected_scale or 'none', ', octave ', auto_detected_octave or 'default')
        end
    end
end

-- =============================
-- Dialog - Step 1a: Auto-detect Mode Toggle
-- =============================

auto_detect_items = {"Auto-detect from region (ON)", "Manual selection (OFF)"}
default_auto_detect_idx = defaults.auto_detect and 1 or 2

-- If auto-detect found something, add option to override
if auto_detected_note_class and auto_detected_scale then
    table.insert(auto_detect_items, 2, "Override auto-detected values")
    -- Adjust default if needed - item 2 is now override, item 3 is manual off
    if not defaults.auto_detect then
        default_auto_detect_idx = 3 -- Point to "Manual selection (OFF)"
    end
end

auto_detect_choice = show_popup_menu(auto_detect_items, default_auto_detect_idx)
if auto_detect_choice == 0 then return end -- User cancelled

-- Determine mode based on choice
if auto_detected_note_class and auto_detected_scale then
    -- Three-option menu
    if auto_detect_choice == 1 then
        auto_detect_enabled = true
        force_manual = false
    elseif auto_detect_choice == 2 then
        auto_detect_enabled = true
        force_manual = true -- Use auto-detect but allow override
    else -- choice == 3
        auto_detect_enabled = false
        force_manual = true
    end
else
    -- Two-option menu
    auto_detect_enabled = (auto_detect_choice == 1)
    force_manual = not auto_detect_enabled
end

set_ext('auto_detect', auto_detect_enabled and '1' or '0')

-- If user just turned on auto-detect, try to detect now
if auto_detect_enabled and not auto_detected_note_class then
    region_name = get_region_at_position()
    if region_name then
        auto_detected_note_class, auto_detected_scale, auto_detected_octave = parse_region_name(region_name)
    end
end

-- =============================
-- Dialog - Step 1b: Root Note Selection
-- =============================

-- If auto-detect is enabled and successful, skip the dialogs (unless user chose to override)
if auto_detect_enabled and auto_detected_note_class ~= nil and auto_detected_scale and not force_manual then
    -- Use auto-detected values
    target_octave = auto_detected_octave or 4
    root_note = (target_octave + 1) * 12 + auto_detected_note_class
    -- Clamp to valid MIDI range
    if root_note < 0 then root_note = 0 end
    if root_note > 127 then root_note = 127 end
    scale_name = auto_detected_scale

    -- Show confirmation message
    local root_name = note_names[(root_note % 12) + 1]  -- This is OK, only used in this block
    local octave = math.floor(root_note / 12) - 1  -- This is OK, only used in this block
    reaper.MB(
        string.format('Region detected: "%s"\n\nUsing: %s%d %s',
            region_name, root_name, octave, scale_name),
        'Auto-detect Active',
        0
    )
else
    -- Manual selection mode
    -- If we have auto-detected values but user chose to override, use those as defaults
    default_root_note = defaults.root_note
    if auto_detected_note_class and auto_detected_octave then
        target_octave = auto_detected_octave or 4
        default_root_note = (target_octave + 1) * 12 + auto_detected_note_class
        if default_root_note < 0 then default_root_note = 0 end
        if default_root_note > 127 then default_root_note = 127 end
    end

    default_note_name = note_names[(default_root_note % 12) + 1]
    default_octave = math.floor(default_root_note / 12) - 1

    -- Find default note index
    default_note_idx = 1
    for i, name in ipairs(note_names) do
        if name == default_note_name then
            default_note_idx = i
            break
        end
    end

    -- Show note selection menu
    note_choice = show_popup_menu(note_names, default_note_idx)
    if note_choice == 0 then return end -- User cancelled

    -- Show octave selection menu
    octaves = {"0","1","2","3","4","5","6","7","8","9"}
    default_octave_idx = default_octave + 1 -- Convert to 1-based index
    octave_choice = show_popup_menu(octaves, default_octave_idx)
    if octave_choice == 0 then return end -- User cancelled

    -- Show scale selection menu (with random option)
    scale_menu_items = {"random"}
    for _, name in ipairs(scale_keys) do
        local mood = scale_moods[name]
        local display = mood and (name .. " (" .. mood .. ")") or name
        table.insert(scale_menu_items, display)
    end

    -- Use auto-detected scale as default if overriding, otherwise use saved preference
    default_scale_name = auto_detected_scale or defaults.scale_name
    default_scale_idx = 1
    if default_scale_name ~= "random" then
        for i, display in ipairs(scale_menu_items) do
            local base = display:match('^([%w_]+)')
            if base == default_scale_name then
                default_scale_idx = i
                break
            end
        end
    end

    scale_choice = show_popup_menu(scale_menu_items, default_scale_idx)
    if scale_choice == 0 then return end -- User cancelled

    -- Process selections from menus
    input_note_name = note_names[note_choice]
    input_octave = tonumber(octaves[octave_choice])
    local chosen_display = scale_menu_items[scale_choice]
    if chosen_display == 'random' then
        scale_name = 'random'
    else
        scale_name = chosen_display:match('^([%w_]+)')
    end
    root_note = note_name_to_pitch(input_note_name, input_octave)
end

-- =============================
-- Dialog - Step 2: Generation Parameters
-- =============================

-- Show polyphony mode selection menu (only if multiple voices)
poly_mode = 'free'
theory_weight = defaults.theory_weight

if defaults.num_voices > 1 then
    poly_modes = {"Free (Creative)", "Harmonic (Chords)", "Voice Leading (Counterpoint)", "Pianist/Guitarist (Chords + Fills)", "Zach Hill Polyphonic (Chaotic Virtuoso)", "Synth Sequencer (House/Techno)"}
    default_poly_idx = 1
    if defaults.poly_mode == 'harmonic' then default_poly_idx = 2
    elseif defaults.poly_mode == 'voice_leading' then default_poly_idx = 3
    elseif defaults.poly_mode == 'pianist' then default_poly_idx = 4
    elseif defaults.poly_mode == 'synth_seq' then default_poly_idx = 6
    end

    poly_choice = show_popup_menu(poly_modes, default_poly_idx)
    if poly_choice == 0 then return end

    if poly_choice == 1 then poly_mode = 'free'
    elseif poly_choice == 2 then poly_mode = 'harmonic'
    elseif poly_choice == 3 then poly_mode = 'voice_leading'
    elseif poly_choice == 4 then poly_mode = 'pianist'
    elseif poly_choice == 5 then poly_mode = 'zach_hill'
    elseif poly_choice == 6 then poly_mode = 'synth_seq'
    end
end

captions = table.concat({
    'Measures',
    'Min Notes',
    'Max Notes',
    'Min Keep',
    'Max Keep',
    'Number of Voices (1-16)',
    'CA Mode (0=off 1=on)',
    'CA: Growth Rate (0.1-1.0)',
    'CA: Time Bias (0-1, 0.5=equal)',
    'Theory Weight (0=free 1=strict)',
    'Rhythmic Guitar Mode (0=off 1=on)',
    'Motif Repeat Chance (0-100%)'
}, ',')

defaults_csv = table.concat({
    tostring(defaults.measures),
    tostring(defaults.min_notes),
    tostring(defaults.max_notes),
    tostring(defaults.min_keep),
    tostring(defaults.max_keep),
    tostring(defaults.num_voices),
    defaults.ca_mode and '1' or '0',
    '0.4',  -- Default growth rate
    '0.6',  -- Default time bias (prefers horizontal)
    tostring(theory_weight),
    defaults.rhythmic_guitar_mode and '1' or '0',
    tostring(defaults.motif_repeat_chance)
}, ',')

ok, ret = reaper.GetUserInputs('jtp gen: Melody Generator - Parameters', 12, captions, defaults_csv)
if not ok then return end

fields = {}
for s in string.gmatch(ret .. ',', '([^,]*),') do fields[#fields+1] = s end

measures = tonumber(fields[1]) or defaults.measures
min_notes = tonumber(fields[2]) or defaults.min_notes
max_notes = tonumber(fields[3]) or defaults.max_notes
min_keep = tonumber(fields[4]) or defaults.min_keep
max_keep = tonumber(fields[5]) or defaults.max_keep
num_voices = tonumber(fields[6]) or defaults.num_voices
ca_mode = (tonumber(fields[7]) or 0) == 1
ca_growth_rate = tonumber(fields[8]) or 0.4
ca_time_bias = tonumber(fields[9]) or 0.6
theory_weight = tonumber(fields[10]) or theory_weight
rhythmic_guitar_mode = (tonumber(fields[11]) or 0) == 1
motif_repeat_chance = tonumber(fields[12]) or defaults.motif_repeat_chance

-- Sanity checks
measures = clamp(math.floor(measures + 0.5), 1, 128)
min_notes = clamp(math.floor(min_notes + 0.5), 1, 128)
max_notes = clamp(math.floor(max_notes + 0.5), min_notes, 256)
min_keep = clamp(math.floor(min_keep + 0.5), 0, 1000)
max_keep = clamp(math.floor(max_keep + 0.5), min_keep, 2000)
root_note = clamp(math.floor(root_note + 0.5), 0, 127)
num_voices = clamp(math.floor(num_voices + 0.5), 1, 16)
ca_growth_rate = clamp(ca_growth_rate, 0.1, 1.0)
ca_time_bias = clamp(ca_time_bias, 0.0, 1.0)
theory_weight = clamp(theory_weight, 0.0, 1.0)
motif_repeat_chance = clamp(motif_repeat_chance, 0, 100)

-- Resolve scale
if scale_name == 'random' or not scales[scale_name] then
    chosen_scale_key = choose_random(scale_keys)
else
    chosen_scale_key = scale_name
end
chosen_scale = scales[chosen_scale_key]

-- Persist for next run
set_ext('measures', measures)
set_ext('min_notes', min_notes)
set_ext('max_notes', max_notes)
set_ext('min_keep', min_keep)
set_ext('max_keep', max_keep)
set_ext('root_note', root_note)
set_ext('scale_name', chosen_scale_key)
set_ext('num_voices', num_voices)
set_ext('ca_mode', ca_mode and '1' or '0')
set_ext('poly_mode', poly_mode)
set_ext('theory_weight', theory_weight)
set_ext('rhythmic_guitar_mode', rhythmic_guitar_mode and '1' or '0')
set_ext('motif_repeat_chance', motif_repeat_chance)

-- =============================
-- GENERATE_MELODY label for auto mode
-- =============================

::GENERATE_MELODY::

-- If we jumped here from auto mode, we need to declare the variables
-- Otherwise they were set by the manual dialogs
if use_auto_mode then
    measures = defaults.measures
    min_notes = defaults.min_notes
    max_notes = defaults.max_notes
    min_keep = defaults.min_keep
    max_keep = defaults.max_keep
    root_note = defaults.root_note
    num_voices = defaults.num_voices
    ca_mode = defaults.ca_mode
    ca_growth_rate = 0.4
    ca_time_bias = 0.6
    poly_mode = defaults.poly_mode
    theory_weight = defaults.theory_weight
    rhythmic_guitar_mode = defaults.rhythmic_guitar_mode
    motif_repeat_chance = defaults.motif_repeat_chance

    -- Resolve scale
    if defaults.scale_name == 'random' or not scales[defaults.scale_name] then
        chosen_scale_key = choose_random(scale_keys)
    else
        chosen_scale_key = defaults.scale_name
    end
    chosen_scale = scales[chosen_scale_key]
end

-- =============================
-- Music Theory & Voice Leading Engine
-- =============================

-- Interval qualities for consonance/dissonance assessment
local INTERVAL_QUALITIES = {
    [0] = {type = 'perfect', consonance = 1.0, name = 'unison'},
    [1] = {type = 'dissonant', consonance = 0.2, name = 'minor 2nd'},
    [2] = {type = 'dissonant', consonance = 0.4, name = 'major 2nd'},
    [3] = {type = 'imperfect', consonance = 0.7, name = 'minor 3rd'},
    [4] = {type = 'imperfect', consonance = 0.8, name = 'major 3rd'},
    [5] = {type = 'perfect', consonance = 0.9, name = 'perfect 4th'},
    [6] = {type = 'dissonant', consonance = 0.1, name = 'tritone'},
    [7] = {type = 'perfect', consonance = 1.0, name = 'perfect 5th'},
    [8] = {type = 'imperfect', consonance = 0.7, name = 'minor 6th'},
    [9] = {type = 'imperfect', consonance = 0.8, name = 'major 6th'},
    [10] = {type = 'dissonant', consonance = 0.4, name = 'minor 7th'},
    [11] = {type = 'dissonant', consonance = 0.5, name = 'major 7th'},
    [12] = {type = 'perfect', consonance = 1.0, name = 'octave'}
}

-- Calculate interval between two pitches (0-12 semitones)
local function get_interval(pitch1, pitch2)
    local diff = math.abs(pitch1 - pitch2) % 12
    return diff
end

-- Get consonance rating for an interval (0.0 = very dissonant, 1.0 = perfect consonance)
local function get_consonance(pitch1, pitch2)
    local interval = get_interval(pitch1, pitch2)
    return INTERVAL_QUALITIES[interval].consonance
end

-- Check if motion between two voice pairs is parallel (forbidden in strict voice leading)
local function is_parallel_motion(voice1_from, voice1_to, voice2_from, voice2_to)
    local interval1 = get_interval(voice1_from, voice2_from)
    local interval2 = get_interval(voice1_to, voice2_to)
    local dir1 = voice1_to - voice1_from
    local dir2 = voice2_to - voice2_from

    -- Parallel if same interval type and same direction
    if interval1 == interval2 and dir1 * dir2 > 0 then
        -- Parallel perfect intervals (unison, 5th, octave) are forbidden
        if interval1 == 0 or interval1 == 7 or interval1 == 12 then
            return true, 'parallel_perfect'
        end
        return true, 'parallel_imperfect'
    end
    return false, nil
end

-- Check if motion is contrary (opposite directions - good!)
local function is_contrary_motion(voice1_from, voice1_to, voice2_from, voice2_to)
    local dir1 = voice1_to - voice1_from
    local dir2 = voice2_to - voice2_from
    return (dir1 * dir2 < 0) and (dir1 ~= 0 and dir2 ~= 0)
end

-- Check if motion is oblique (one voice stays, other moves - acceptable)
local function is_oblique_motion(voice1_from, voice1_to, voice2_from, voice2_to)
    local dir1 = voice1_to - voice1_from
    local dir2 = voice2_to - voice2_from
    return (dir1 == 0 and dir2 ~= 0) or (dir1 ~= 0 and dir2 == 0)
end

-- Build chord from scale degrees (triads and 7th chords)
local function build_chord(scale_notes, root_scale_idx, chord_type, octave_range)
    octave_range = octave_range or {-1, 1}

    local chord = {}
    local intervals

    if chord_type == 'triad' then
        -- Root, 3rd, 5th
        intervals = {0, 2, 4}
    elseif chord_type == 'seventh' then
        -- Root, 3rd, 5th, 7th
        intervals = {0, 2, 4, 6}
    elseif chord_type == 'sus4' then
        -- Root, 4th, 5th
        intervals = {0, 3, 4}
    else
        intervals = {0, 2, 4}  -- default triad
    end

    for _, interval in ipairs(intervals) do
        local scale_idx = ((root_scale_idx - 1 + interval) % #scale_notes) + 1
        local base_pitch = scale_notes[scale_idx]

        -- Add octave variations
        for oct = octave_range[1], octave_range[2] do
            table.insert(chord, base_pitch + (oct * 12))
        end
    end

    return chord
end

-- Voice leading: find smoothest voice movement (minimize total motion)
local function find_best_voice_leading(prev_pitches, target_chord, theory_weight)
    if #prev_pitches == 0 then
        -- First chord, just pick from target
        local result = {}
        for i = 1, math.min(#target_chord, 4) do
            table.insert(result, target_chord[i])
        end
        return result
    end

    -- Calculate all possible voice assignments
    local num_voices = #prev_pitches
    local best_assignment = nil
    local best_score = -math.huge

    -- Generate permutations (simplified for up to 4 voices)
    local function score_assignment(assignment)
        local total_motion = 0
        local contrary_bonus = 0
        local consonance_score = 0
        local parallel_penalty = 0

        -- Calculate total voice motion
        for i = 1, num_voices do
            total_motion = total_motion + math.abs(assignment[i] - prev_pitches[i])
        end

        -- Check voice leading quality
        for i = 1, num_voices - 1 do
            for j = i + 1, num_voices do
                -- Reward contrary motion
                if is_contrary_motion(prev_pitches[i], assignment[i], prev_pitches[j], assignment[j]) then
                    contrary_bonus = contrary_bonus + 5
                end

                -- Penalize parallel motion
                local is_parallel, parallel_type = is_parallel_motion(
                    prev_pitches[i], assignment[i],
                    prev_pitches[j], assignment[j]
                )
                if is_parallel then
                    if parallel_type == 'parallel_perfect' then
                        parallel_penalty = parallel_penalty + 20
                    else
                        parallel_penalty = parallel_penalty + 5
                    end
                end

                -- Reward consonant intervals
                consonance_score = consonance_score + get_consonance(assignment[i], assignment[j]) * 3
            end
        end

        -- Blend between smooth motion (low total_motion) and theory rules
        -- theory_weight = 0: prefer minimal motion (creative/free)
        -- theory_weight = 1: prefer theory rules (contrary motion, consonance, avoid parallels)
        local smooth_score = -total_motion
        local theory_score = contrary_bonus + consonance_score - parallel_penalty

        return (1 - theory_weight) * smooth_score + theory_weight * theory_score
    end

    -- Try different combinations from target_chord
    -- For simplicity, we'll try sorted ascending, descending, and closest matches
    local candidates = {}

    -- Candidate 1: Closest pitches
    local closest = {}
    local used = {}
    for i = 1, num_voices do
        local best_pitch = nil
        local best_dist = math.huge
        for _, pitch in ipairs(target_chord) do
            if not used[pitch] then
                local dist = math.abs(pitch - prev_pitches[i])
                if dist < best_dist then
                    best_dist = dist
                    best_pitch = pitch
                end
            end
        end
        if best_pitch then
            closest[i] = best_pitch
            used[best_pitch] = true
        else
            closest[i] = prev_pitches[i]  -- fallback
        end
    end
    table.insert(candidates, closest)

    -- Candidate 2: Ascending order
    local sorted_asc = {}
    for _, p in ipairs(target_chord) do table.insert(sorted_asc, p) end
    table.sort(sorted_asc)
    if #sorted_asc >= num_voices then
        table.insert(candidates, {table.unpack(sorted_asc, 1, num_voices)})
    end

    -- Candidate 3: Middle range
    local mid_start = math.max(1, math.floor(#sorted_asc / 2) - math.floor(num_voices / 2))
    if mid_start + num_voices - 1 <= #sorted_asc then
        table.insert(candidates, {table.unpack(sorted_asc, mid_start, mid_start + num_voices - 1)})
    end

    -- Score all candidates
    for _, candidate in ipairs(candidates) do
        local score = score_assignment(candidate)
        if score > best_score then
            best_score = score
            best_assignment = candidate
        end
    end

    return best_assignment or closest
end

-- =============================
-- 2D Cellular Automata Engine - "Growing Mold"
-- =============================

-- Cell structure: {time_step, scale_idx, age, voice_id}
-- Grid is stored as grid[time_step][scale_idx] = cell or nil

-- Configuration for CA growth
local CA_CONFIG = {
    spawn_prob = ca_mode and ca_growth_rate or 0.4,           -- Probability of spawning a neighbor
    horizontal_bias = ca_mode and ca_time_bias or 0.6,        -- 0.5 = equal, >0.5 = prefers time direction
    max_age = 8,                                              -- Cells die after this many generations
    initial_seeds = 2,                                        -- Number of starting cells
    max_poly_per_slice = nil,                                 -- Set dynamically based on num_voices
}

-- Create empty 2D grid
local function create_grid(time_steps, scale_size)
    local grid = {}
    for t = 1, time_steps do
        grid[t] = {}
        for s = 1, scale_size do
            grid[t][s] = nil
        end
    end
    return grid
end

-- Count living cells at a specific time slice (for polyphony limiting)
local function count_cells_at_time(grid, time_step)
    local count = 0
    for scale_idx, cell in pairs(grid[time_step] or {}) do
        if cell then count = count + 1 end
    end
    return count
end

-- Check if position is valid and empty
local function is_valid_position(grid, time_step, scale_idx, time_steps, scale_size)
    if time_step < 1 or time_step > time_steps then return false end
    if scale_idx < 1 or scale_idx > scale_size then return false end
    if grid[time_step][scale_idx] ~= nil then return false end
    return true
end

-- Try to spawn a new cell from parent
local function try_spawn(grid, parent_cell, direction, time_steps, scale_size, max_poly)
    local new_time = parent_cell.time_step
    local new_scale = parent_cell.scale_idx

    -- Apply direction: 1=up, 2=down, 3=left, 4=right
    if direction == 1 then new_scale = new_scale + 1      -- up (higher pitch)
    elseif direction == 2 then new_scale = new_scale - 1  -- down (lower pitch)
    elseif direction == 3 then new_time = new_time - 1    -- left (earlier time)
    elseif direction == 4 then new_time = new_time + 1    -- right (later time)
    end

    -- Check validity
    if not is_valid_position(grid, new_time, new_scale, time_steps, scale_size) then
        return false
    end

    -- Check polyphony constraint
    if count_cells_at_time(grid, new_time) >= max_poly then
        return false
    end

    -- Check spawn probability
    if math.random() > CA_CONFIG.spawn_prob then
        return false
    end

    -- Spawn the cell
    grid[new_time][new_scale] = {
        time_step = new_time,
        scale_idx = new_scale,
        age = 0,
        voice_id = parent_cell.voice_id
    }

    return true
end

-- Evolve the 2D CA grid for one generation
local function evolve_2d_ca(grid, time_steps, scale_size, max_poly)
    local all_cells = {}

    -- Collect all living cells
    for t = 1, time_steps do
        for s = 1, scale_size do
            if grid[t][s] then
                table.insert(all_cells, grid[t][s])
            end
        end
    end

    -- Age all cells and mark for death
    local cells_to_remove = {}
    for _, cell in ipairs(all_cells) do
        cell.age = cell.age + 1
        if cell.age >= CA_CONFIG.max_age then
            table.insert(cells_to_remove, cell)
        end
    end

    -- Remove dead cells
    for _, cell in ipairs(cells_to_remove) do
        grid[cell.time_step][cell.scale_idx] = nil
    end

    -- Try to spawn new cells from living cells
    -- Shuffle to randomize growth order
    for i = #all_cells, 2, -1 do
        local j = math.random(i)
        all_cells[i], all_cells[j] = all_cells[j], all_cells[i]
    end

    for _, cell in ipairs(all_cells) do
        if grid[cell.time_step] and grid[cell.time_step][cell.scale_idx] then
            -- Cell still alive, try to spawn

            -- Determine which directions to try based on bias
            local directions = {}
            if math.random() < CA_CONFIG.horizontal_bias then
                -- Prefer horizontal (time) first
                directions = {4, 3, 1, 2}  -- right, left, up, down
            else
                -- Prefer vertical (pitch) first
                directions = {1, 2, 4, 3}  -- up, down, right, left
            end

            -- Try one random direction
            local dir = directions[math.random(1, #directions)]
            try_spawn(grid, cell, dir, time_steps, scale_size, max_poly)
        end
    end
end

-- Generate 2D CA grid and return as note list
local function generate_2d_ca_notes(time_steps, scale_size, num_voices)
    CA_CONFIG.max_poly_per_slice = num_voices

    local grid = create_grid(time_steps, scale_size)

    -- Plant initial seeds at random positions
    for seed = 1, CA_CONFIG.initial_seeds do
        local rand_time = math.random(1, math.ceil(time_steps / 2))
        local rand_scale = math.random(1, scale_size)

        -- Make sure it's empty
        local attempts = 0
        while grid[rand_time][rand_scale] ~= nil and attempts < 20 do
            rand_time = math.random(1, time_steps)
            rand_scale = math.random(1, scale_size)
            attempts = attempts + 1
        end

        grid[rand_time][rand_scale] = {
            time_step = rand_time,
            scale_idx = rand_scale,
            age = 0,
            voice_id = seed - 1  -- 0-indexed for MIDI channel
        }
    end

    -- Evolve for multiple generations
    local generations = math.max(10, time_steps / 2)
    for gen = 1, generations do
        evolve_2d_ca(grid, time_steps, scale_size, CA_CONFIG.max_poly_per_slice)
    end

    -- Convert grid to note list
    local notes = {}
    for t = 1, time_steps do
        for s = 1, scale_size do
            if grid[t][s] then
                table.insert(notes, {
                    time_step = t,
                    scale_idx = s,
                    voice_id = grid[t][s].voice_id,
                    age = grid[t][s].age  -- Can use for velocity/duration
                })
            end
        end
    end

    log('Generated ', #notes, ' notes from 2D CA')
    return notes
end

-- =============================
-- Melody generation
-- =============================

-- Project / selection info
local bpm = reaper.Master_GetTempo()
local start_time = reaper.GetCursorPosition()

-- Get time signature - just get the numerator, ignore the weird denominator value
local _, time_sig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, start_time)
local beats_per_measure = time_sig_num
-- Calculate one beat's duration: BPM is always in quarter notes per minute
local quarter_note_duration = 60 / bpm

-- Simple, direct calculation: measures × beats per measure × quarter note duration
-- This works because BPM is always quarter notes per minute in REAPER
local measure_duration = quarter_note_duration * beats_per_measure
local end_time = start_time + (measure_duration * measures)

log('--- Melody Generator Debug ---')
log('BPM: ', bpm)
log('Time signature numerator (beats per measure): ', time_sig_num)
log('Measures requested: ', measures)
log('Quarter note duration: ', quarter_note_duration)
log('Measure duration (s): ', measure_duration)
log('Start time: ', start_time)
log('Computed end time: ', end_time)
log('Expected item length: ', end_time - start_time)

local track = reaper.GetSelectedTrack(0, 0)
if not track then
    reaper.ShowMessageBox('Please select a track first.', 'No Track', 0)
    return
end

-- Create MIDI item
local item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
local take = reaper.GetTake(item, 0)
if not take then return end

local actual_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
log('Actual created item length: ', actual_len)

local function timeToPPQ(t)
    return reaper.MIDI_GetPPQPosFromProjTime(take, t)
end

-- Velocity ranges based on duration buckets
local VELOCITY_16 = {40, 60}
local VELOCITY_8 = {50, 70}
local VELOCITY_4 = {60, 90}
local VELOCITY_2PLUS = {80, 100}

-- Calculate note durations - always based on quarter notes regardless of time signature
-- This keeps the note duration choices consistent
local sixteenth_note = quarter_note_duration / 4
local eighth_note = quarter_note_duration / 2
local quarter_note = quarter_note_duration
local half_note = quarter_note_duration * 2
local whole_note = measure_duration -- full measure duration

local function vel_for_dur(dur)
    if dur <= sixteenth_note then return math.random(VELOCITY_16[1], VELOCITY_16[2])
    elseif dur <= eighth_note then return math.random(VELOCITY_8[1], VELOCITY_8[2])
    elseif dur <= quarter_note then return math.random(VELOCITY_4[1], VELOCITY_4[2])
    else return math.random(VELOCITY_2PLUS[1], VELOCITY_2PLUS[2]) end
end

-- Duration choices with weights (in seconds)
-- Higher weight = more frequent. Adjust these to taste!
local dur_weights = {
    [sixteenth_note] = 5,   -- 16th (occasional fast notes)
    [eighth_note] = 5,     -- 8th (reduced from 30)
    [quarter_note] = 30,    -- quarter (now most common)
    [half_note] = 40,       -- half (increased)
    [whole_note] = 10,      -- whole (increased)
}

local function pick_duration(prev)
    local total = 0
    for _, w in pairs(dur_weights) do total = total + w end
    local r = math.random() * total
    local c = 0
    for d, w in pairs(dur_weights) do
        c = c + w
        if r <= c then return d end
    end
    return prev
end

-- Build note pitch set from chosen scale
local scale_notes = {}
for _, iv in ipairs(chosen_scale) do
    scale_notes[#scale_notes+1] = root_note + iv
end

local function find_index(t, v)
    for i = 1, #t do if t[i] == v then return i end end
    return 1
end

-- Simple motion logic constants
-- Motif development: dynamic repetition constraints
local motif_mode = defaults.motif_mode -- 'melodic' or 'rhythmic'
local repetition_allowance = clamp(defaults.repetition_allowance or 3, 2, 4)
local MAX_REPEATED = repetition_allowance
local NOTE_VARIETY = (motif_mode == 'rhythmic') and 0.85 or 0.99
local BIG_JUMP_CHANCE = 0.1
local BIG_JUMP_INTERVAL = 4

-- Initialize random seed
math.randomseed(reaper.time_precise())
for _ = 1,10 do math.random() end

reaper.Undo_BeginBlock()

-- =============================
-- RHYTHMIC GUITAR MODE (Drum-Style Rhythmic Generation)
-- =============================
if rhythmic_guitar_mode then
    log('Using Rhythmic Guitar mode - drum-style rhythm with melodic notes')

    -- Configuration constants adapted from drum script
    local PPQ = 960
    local SUBDIVS_MIN = 1
    local SUBDIVS_MAX = 2
    local BURST_NOTES = 8
    local HUMANIZE_MS = 7
    local VEL_MIN = 7
    local VEL_MAX = 110
    local SUSTAIN_MODE = true
    local SUSTAIN_FACTOR = 0.9

    -- Rhythmic pattern probabilities (adapted from drum script)
    local BURST_CHANCE = 0.250
    local DOUBLE_STROKE_CHANCE = 0.250
    local PARADIDDLE_CHANCE = 0.250
    local FOCUSED_RIFF_CHANCE = 0.300
    local ANCHOR_DOWNBEAT_CHANCE = 0.300
    local RANDOM_BEAT_ACCENT_CHANCE = 0.600

    -- Guitar string simulation (replace drum limbs with string tracking)
    local string_state = {
        S1 = {last_note_time = nil, last_pitch = nil},
        S2 = {last_note_time = nil, last_pitch = nil},
        S3 = {last_note_time = nil, last_pitch = nil},
        S4 = {last_note_time = nil, last_pitch = nil},
        S5 = {last_note_time = nil, last_pitch = nil},
        S6 = {last_note_time = nil, last_pitch = nil}
    }

    local MIN_STRING_INTERVAL_SECS = 0.01

    -- Helper: Choose a note from the scale
    local function choose_note()
        return scale_notes[math.random(1, #scale_notes)]
    end

    -- Helper: Pick a string for this note
    local function pick_string()
        local strings = {"S1", "S2", "S3", "S4", "S5", "S6"}
        return strings[math.random(1, #strings)]
    end

    -- Helper: Check if string can play at this time
    local function can_string_play(string_id, requested_time)
        local st = string_state[string_id]
        if not st.last_note_time then return true end
        local dt = requested_time - st.last_note_time
        return dt >= MIN_STRING_INTERVAL_SECS
    end

    -- Helper: Dynamic velocity with accent influence
    local function get_dynamic_velocity(note_ppq, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local on_quarter = ((note_ppq % PPQ) == 0)
        if on_quarter then return math.random(VEL_MIN, VEL_MAX) end

        local accent_factor = 0
        if accent_ppqs and measure_start_ppq then
            local accent_window = PPQ / 4
            for _, accent_ppq in ipairs(accent_ppqs) do
                local diff = math.abs(note_ppq - accent_ppq)
                local candidate = (accent_window - diff) / accent_window
                if candidate > accent_factor then accent_factor = candidate end
            end
        end

        local base_min, base_max = 50, 90
        local bonus = math.floor(accent_factor * 20)
        local final_min = math.min(VEL_MAX, base_min + bonus)
        local final_max = math.min(VEL_MAX, base_max + bonus)
        return math.random(final_min, final_max)
    end

    -- Helper: Insert note with humanization
    local function insert_guitar_note(take, ppq_pos, pitch, override_vel_min, override_vel_max, note_duration_ticks, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local note_time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq_pos)
        local humanize_offset_sec = (math.random() * 2 - 1) * (HUMANIZE_MS / 1000)
        local final_time = note_time + humanize_offset_sec

        local string_id = pick_string()
        if not can_string_play(string_id, final_time) then return end

        local note_velocity
        if override_vel_min and override_vel_max then
            note_velocity = math.random(override_vel_min, override_vel_max)
        else
            note_velocity = get_dynamic_velocity(ppq_pos, accent_ppqs, measure_start_ppq, measure_len_ppq)
        end

        local ppq_with_offset = reaper.MIDI_GetPPQPosFromProjTime(take, final_time)
        local note_off_ppq = note_duration_ticks and (ppq_with_offset + note_duration_ticks) or (ppq_with_offset + 1)

        reaper.MIDI_InsertNote(take, false, false, ppq_with_offset, note_off_ppq, 0, pitch, note_velocity, false)

        string_state[string_id].last_note_time = final_time
        string_state[string_id].last_pitch = pitch
    end

    -- Pattern: Double stroke
    local function insert_double_stroke(take, base_ppq, spacing_ticks, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local pitch = choose_note()
        local duration = SUSTAIN_MODE and math.floor(spacing_ticks * SUSTAIN_FACTOR) or nil
        insert_guitar_note(take, base_ppq, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
        insert_guitar_note(take, base_ppq + spacing_ticks, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
    end

    -- Pattern: Paradiddle (8-note pattern)
    local function insert_paradiddle(take, start_ppq, spacing_ticks, kit_focus, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local function pick_note()
            if kit_focus and #kit_focus > 0 then
                return kit_focus[math.random(1, #kit_focus)]
            else
                return choose_note()
            end
        end

        local strokes = {}
        for i = 1, 8 do
            strokes[i] = pick_note()
        end

        local duration = SUSTAIN_MODE and math.floor(spacing_ticks * SUSTAIN_FACTOR) or nil
        for i, pitch in ipairs(strokes) do
            local stroke_ppq = start_ppq + (i - 1) * spacing_ticks
            insert_guitar_note(take, stroke_ppq, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
        end
    end

    -- Pattern: Focused riff (repetitive pattern on subset of notes)
    local function choose_note_subset(size)
        local subset = {}
        local pool = {}
        for _, note in ipairs(scale_notes) do
            table.insert(pool, note)
        end

        for i = 1, math.min(size, #pool) do
            local idx = math.random(1, #pool)
            table.insert(subset, pool[idx])
            table.remove(pool, idx)
        end
        return subset
    end

    local function insert_focused_riff(take, start_ppq, measure_end_ppq, note_focus, accent_ppqs, measure_start_ppq, measure_len_ppq)
        if not note_focus or #note_focus < 1 then
            note_focus = choose_note_subset(math.random(2, 4))
        end

        local pattern_length = math.random(3, 5)
        local total_space = measure_end_ppq - start_ppq
        local spacing = math.floor(total_space / (pattern_length * 2))
        local duration = SUSTAIN_MODE and math.floor(spacing * SUSTAIN_FACTOR) or nil

        local pos = start_ppq
        while pos < measure_end_ppq do
            for p = 1, pattern_length do
                local pitch = note_focus[math.random(1, #note_focus)]
                local insert_pos = pos + (p - 1) * spacing
                if insert_pos >= measure_end_ppq then break end
                insert_guitar_note(take, insert_pos, pitch, nil, nil, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
            end
            pos = pos + (pattern_length * spacing)
        end
    end

    -- Pattern: Insert accent (strong beat with emphasis)
    local function insert_accent(take, beat_ppq, accent_ppqs, measure_start_ppq, measure_len_ppq)
        local duration = SUSTAIN_MODE and math.floor(PPQ * SUSTAIN_FACTOR) or nil
        local pitch = choose_note()
        insert_guitar_note(take, beat_ppq, pitch, 80, 110, duration, accent_ppqs, measure_start_ppq, measure_len_ppq)
        if accent_ppqs then table.insert(accent_ppqs, beat_ppq) end
    end

    -- Main generation loop
    local start_ppq = timeToPPQ(start_time)
    local end_ppq = timeToPPQ(end_time)
    local total_ppq = end_ppq - start_ppq

    local time_sig_num, _ = reaper.TimeMap_GetTimeSigAtTime(0, start_time)
    local measure_len_ppq = time_sig_num * PPQ

    local num_measures = math.floor(total_ppq / measure_len_ppq)
    local leftover_ppq = total_ppq % measure_len_ppq
    local measure_start_ppq = start_ppq

    for m = 1, num_measures do
        local current_measure_accents = {}
        local measure_end = measure_start_ppq + measure_len_ppq

        -- Anchor downbeat
        if math.random() < ANCHOR_DOWNBEAT_CHANCE then
            local duration = SUSTAIN_MODE and math.floor(PPQ * SUSTAIN_FACTOR) or nil
            insert_guitar_note(take, measure_start_ppq, choose_note(), nil, nil, duration, current_measure_accents, measure_start_ppq, measure_len_ppq)
        end

        -- Random beat accent
        if math.random() < RANDOM_BEAT_ACCENT_CHANCE then
            local random_beat_idx = math.random(1, time_sig_num)
            local random_beat_ppq = measure_start_ppq + (random_beat_idx - 1) * PPQ
            insert_accent(take, random_beat_ppq, current_measure_accents, measure_start_ppq, measure_len_ppq)
        end

        -- Focused riff mode for entire measure
        if math.random() < FOCUSED_RIFF_CHANCE then
            local note_focus = choose_note_subset(math.random(2, 4))
            insert_focused_riff(take, measure_start_ppq + PPQ, measure_end, note_focus, current_measure_accents, measure_start_ppq, measure_len_ppq)
        else
            -- Beat-by-beat generation
            for beat_idx = 1, time_sig_num do
                local beat_ppq = measure_start_ppq + (beat_idx - 1) * PPQ

                local subdivs = math.random(SUBDIVS_MIN, SUBDIVS_MAX)
                local ticks_per_sub = math.floor(PPQ / subdivs)

                for s = 1, subdivs do
                    local sub_tick = beat_ppq + (s - 1) * ticks_per_sub
                    if sub_tick >= measure_end then break end

                    if math.random() < BURST_CHANCE then
                        -- Burst pattern
                        for i = 0, BURST_NOTES - 1 do
                            local flurry_tick = sub_tick + i * math.floor(ticks_per_sub / (BURST_NOTES + 1))
                            if flurry_tick >= measure_end then break end
                            local duration = SUSTAIN_MODE and math.floor((ticks_per_sub / (BURST_NOTES + 1)) * SUSTAIN_FACTOR) or nil
                            insert_guitar_note(take, flurry_tick, choose_note(), nil, nil, duration, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        end
                    else
                        local do_double = (math.random() < DOUBLE_STROKE_CHANCE)
                        local do_para = (not do_double and math.random() < PARADIDDLE_CHANCE)

                        if do_double then
                            local stroke_spacing = math.floor(ticks_per_sub * 0.25)
                            insert_double_stroke(take, sub_tick, stroke_spacing, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        elseif do_para then
                            local stroke_spacing = math.floor(ticks_per_sub * 0.25)
                            insert_paradiddle(take, sub_tick, stroke_spacing, nil, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        else
                            local duration = SUSTAIN_MODE and math.floor(ticks_per_sub * SUSTAIN_FACTOR) or nil
                            insert_guitar_note(take, sub_tick, choose_note(), nil, nil, duration, current_measure_accents, measure_start_ppq, measure_len_ppq)
                        end
                    end
                end
            end
        end

        measure_start_ppq = measure_end
    end

    -- Handle leftover beats
    if leftover_ppq > 0 then
        local leftover_start = measure_start_ppq
        local leftover_end = leftover_start + leftover_ppq
        local current_measure_accents = {}

        if math.random() < ANCHOR_DOWNBEAT_CHANCE then
            local duration = SUSTAIN_MODE and math.floor(PPQ * SUSTAIN_FACTOR) or nil
            insert_guitar_note(take, leftover_start, choose_note(), nil, nil, duration, current_measure_accents, leftover_start, leftover_ppq)
        end

        local leftover_beats = leftover_ppq / PPQ
        local cur_tick = 0
        while cur_tick < leftover_ppq do
            local subdivs = math.random(SUBDIVS_MIN, SUBDIVS_MAX)
            local ticks_per_sub = math.floor(PPQ / subdivs)

            for s = 1, subdivs do
                local sub_tick = cur_tick + (s - 1) * ticks_per_sub
                if sub_tick >= leftover_ppq then break end
                local actual_tick = leftover_start + sub_tick

                if math.random() < BURST_CHANCE then
                    for i = 0, BURST_NOTES - 1 do
                        local flurry_tick = actual_tick + i * math.floor(ticks_per_sub / (BURST_NOTES + 1))
                        if flurry_tick >= leftover_end then break end
                        local duration = SUSTAIN_MODE and math.floor((ticks_per_sub / (BURST_NOTES + 1)) * SUSTAIN_FACTOR) or nil
                        insert_guitar_note(take, flurry_tick, choose_note(), nil, nil, duration, current_measure_accents, leftover_start, leftover_ppq)
                    end
                else
                    local duration = SUSTAIN_MODE and math.floor(ticks_per_sub * SUSTAIN_FACTOR) or nil
                    insert_guitar_note(take, actual_tick, choose_note(), nil, nil, duration, current_measure_accents, leftover_start, leftover_ppq)
                end
            end
            cur_tick = cur_tick + PPQ
        end
    end

    reaper.MIDI_Sort(take)

-- =============================
-- CELLULAR AUTOMATA MODE
-- =============================
elseif ca_mode then
    log('Using 2D CA mode - growing mold algorithm')

    -- Calculate time grid resolution
    local time_resolution = eighth_note  -- Each step is an 8th note
    local total_duration = end_time - start_time
    local time_steps = math.floor(total_duration / time_resolution)

    log('Time steps: ', time_steps, ', Scale size: ', #scale_notes)

    -- Generate 2D CA notes
    local ca_notes = generate_2d_ca_notes(time_steps, #scale_notes, num_voices)

    -- Insert notes from CA grid into MIDI
    for _, note_data in ipairs(ca_notes) do
        local note_time = start_time + ((note_data.time_step - 1) * time_resolution)
        local note_pitch = scale_notes[note_data.scale_idx]
        local note_duration = time_resolution  -- Could vary based on age
        local note_velocity = math.random(60, 100)  -- Could use age for velocity
        local note_channel = note_data.voice_id

        reaper.MIDI_InsertNote(
            take, false, false,
            timeToPPQ(note_time),
            timeToPPQ(note_time + note_duration),
            note_channel,
            note_pitch,
            note_velocity,
            false
        )
    end

-- =============================
-- STANDARD MODE with Polyphony Modes
-- =============================
else
    log('Using standard mode with polyphony: ', poly_mode, ', theory weight: ', theory_weight)

    -- Simple motion logic constants
    local MAX_REPEATED = 0
    local NOTE_VARIETY = 0.99
    local BIG_JUMP_CHANCE = 0.1
    local BIG_JUMP_INTERVAL = 4

    -- =============================
    -- Mode 1: FREE - Independent voice generation (original behavior)
    -- =============================
    if poly_mode == 'free' or num_voices == 1 then
        log('Free polyphony mode - independent voices')

        -- =============================
        -- Phrase-Based Generation System (Step 2)
        -- =============================

        -- Phrase structure: {pitches, durations, contour_type, tension_level}
        -- contour_type: 'arch', 'ascending', 'descending', 'valley', 'wave'
        -- tension_level: 'low', 'medium', 'high'

        -- Generate a phrase with a specific contour type
        -- Map a simple tension factor
        local function tension_factor(level)
            if level == 'low' then return 0.3
            elseif level == 'high' then return 0.8
            else return 0.5 end -- 'medium'
        end

        -- Choose degree indices for targets (1=tonic, 3=mediant when available, 5=dominant when available)
        local function degree_index_or_closest(degree)
            if #scale_notes == 0 then return 1 end
            return math.max(1, math.min(degree, #scale_notes))
        end

        -- Nudging helper: bias movement toward target
        local function nudge_toward(current_idx, base_step, progress, target_idx, level, section)
            local idx = current_idx
            local step = base_step or 0
            local dist = target_idx and (target_idx - idx) or 0
            local absdist = math.abs(dist)
            local dir = (dist > 0) and 1 or (dist < 0 and -1 or 0)

            -- Probability to prefer moving toward target grows with progress and tension
            local bias_p = (progress or 0) * tension_factor(level)
            if math.random() < bias_p then
                -- Move one step toward target
                step = dir ~= 0 and dir or step
            end

            -- If far from target during development, allow an extra leap toward it
            if section == 'development' and absdist >= 3 and math.random() < 0.35 then
                step = step + dir
            end

            return clamp(idx + step, 1, #scale_notes)
        end

        -- Generate a phrase with a specific contour type, biased toward target where applicable
        -- opts: {target_idx, tension_level='medium', section='intro'|'development'|'conclusion', is_final=false}
        local function generate_phrase(start_pitch, contour_type, phrase_length, opts)
            phrase_length = phrase_length or math.random(4, 8)
            local pitches = {}
            local durations = {}

            -- Starting pitch
            local current_idx = find_index(scale_notes, start_pitch)
            table.insert(pitches, scale_notes[current_idx])

            opts = opts or {}
            local target_idx = opts.target_idx or degree_index_or_closest(1)
            local tlevel = opts.tension_level or 'medium'
            local section = opts.section or 'intro'

            -- Generate contour based on type
            if contour_type == 'arch' then
                -- Ascend for first half, descend for second half
                local peak_point = math.floor(phrase_length / 2)
                for i = 2, phrase_length do
                    if i <= peak_point then
                        -- Ascending
                        local step = math.random(1, 2)
                        local progress = (i - 1) / (phrase_length - 1)
                        current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    else
                        -- Descending
                        local step = -math.random(1, 2)
                        local progress = (i - 1) / (phrase_length - 1)
                        current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    end
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'ascending' then
                -- Gradual climb
                for i = 2, phrase_length do
                    local step = math.random(1, 2)
                    if math.random() < 0.2 then step = -1 end -- occasional drop for interest
                    local progress = (i - 1) / (phrase_length - 1)
                    current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'descending' then
                -- Gradual descent
                for i = 2, phrase_length do
                    local step = -math.random(1, 2)
                    if math.random() < 0.2 then step = 1 end -- occasional rise for interest
                    local progress = (i - 1) / (phrase_length - 1)
                    current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'valley' then
                -- Descend first, then ascend (inverse arch)
                local valley_point = math.floor(phrase_length / 2)
                for i = 2, phrase_length do
                    if i <= valley_point then
                        -- Descending
                        local step = -math.random(1, 2)
                        local progress = (i - 1) / (phrase_length - 1)
                        current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    else
                        -- Ascending
                        local step = math.random(1, 2)
                        local progress = (i - 1) / (phrase_length - 1)
                        current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    end
                    table.insert(pitches, scale_notes[current_idx])
                end

            elseif contour_type == 'wave' then
                -- Oscillating up and down
                local direction = 1
                for i = 2, phrase_length do
                    local step = math.random(1, 2) * direction
                    local progress = (i - 1) / (phrase_length - 1)
                    current_idx = nudge_toward(current_idx, step, progress, target_idx, tlevel, section)
                    table.insert(pitches, scale_notes[current_idx])
                    -- Change direction occasionally
                    if math.random() < 0.4 then
                        direction = -direction
                    end
                end
            end

            -- Generate durations for the phrase
            for i = 1, phrase_length do
                local dur = pick_duration(quarter_note)
                table.insert(durations, dur)
            end

            -- If this is the final phrase in the conclusion, force resolution to tonic and lengthen ending
            if opts.is_final and section == 'conclusion' then
                pitches[#pitches] = scale_notes[1] -- tonic
                if durations[#durations] < half_note then
                    durations[#durations] = half_note
                end
            end

            return {
                pitches = pitches,
                durations = durations,
                contour_type = contour_type,
                tension_level = tlevel, -- carry tension level
                length = #pitches
            }
        end

        -- Determine contour variation based on previous phrase
        local function get_next_contour_type(prev_contour)
            local contour_types = {'arch', 'ascending', 'descending', 'valley', 'wave'}

            if not prev_contour then
                -- First phrase, choose randomly
                return contour_types[math.random(1, #contour_types)]
            end

            -- Create contrast: if previous was ascending, prefer descending or arch
            local contrast_map = {
                ascending = {'descending', 'arch', 'valley'},
                descending = {'ascending', 'arch', 'valley'},
                arch = {'valley', 'wave', 'ascending'},
                valley = {'arch', 'wave', 'descending'},
                wave = {'arch', 'ascending', 'descending'}
            }

            local candidates = contrast_map[prev_contour] or contour_types
            return candidates[math.random(1, #candidates)]
        end

        -- Transpose a phrase by a number of scale degrees
        local function transpose_phrase(phrase, scale_degrees)
            local transposed = {
                pitches = {},
                durations = {},
                contour_type = phrase.contour_type,
                tension_level = phrase.tension_level,
                length = phrase.length
            }

            -- Copy durations unchanged
            for i = 1, #phrase.durations do
                transposed.durations[i] = phrase.durations[i]
            end

            -- Transpose pitches by scale degrees
            for i = 1, #phrase.pitches do
                local original_pitch = phrase.pitches[i]
                local original_idx = find_index(scale_notes, original_pitch)
                local new_idx = clamp(original_idx + scale_degrees, 1, #scale_notes)
                transposed.pitches[i] = scale_notes[new_idx]
            end

            return transposed
        end

        -- Apply rhythmic augmentation (longer durations) or diminution (shorter)
        local function vary_rhythm(phrase, factor)
            local varied = {
                pitches = {},
                durations = {},
                contour_type = phrase.contour_type,
                tension_level = phrase.tension_level,
                length = phrase.length
            }

            -- Copy pitches unchanged
            for i = 1, #phrase.pitches do
                varied.pitches[i] = phrase.pitches[i]
            end

            -- Scale durations by factor (0.5 = diminution, 2.0 = augmentation)
            for i = 1, #phrase.durations do
                varied.durations[i] = phrase.durations[i] * factor
            end

            return varied
        end

        -- Retrieve and vary a phrase from memory
        local function retrieve_motif(phrase_memory)
            if #phrase_memory == 0 then return nil end

            -- Choose a random phrase from memory
            local source_phrase = phrase_memory[math.random(1, #phrase_memory)]

            -- Decide variation type
            local variation_type = math.random(1, 3)

            if variation_type == 1 then
                -- Transpose by 2-5 scale degrees (up or down)
                local transpose_amount = math.random(2, 5) * (math.random(2) == 1 and 1 or -1)
                log('  Retrieving motif with transposition: ', transpose_amount, ' degrees')
                return transpose_phrase(source_phrase, transpose_amount)
            elseif variation_type == 2 then
                -- Rhythmic augmentation (longer notes)
                log('  Retrieving motif with augmentation')
                return vary_rhythm(source_phrase, 1.5)
            else
                -- Rhythmic diminution (shorter notes)
                log('  Retrieving motif with diminution')
                return vary_rhythm(source_phrase, 0.75)
            end
        end

        -- Generate a single voice of melody using phrases
        local function generate_voice(channel)
            -- Phrase count and pruning for this voice
            local NUM_PHRASES = math.random(tonumber(min_notes) or 2, tonumber(max_notes) or 5)
            local notes_to_keep = math.random(tonumber(min_keep) or 12, tonumber(max_keep) or 24)

            -- Phrase memory buffer (stores last 3-5 phrases)
            local phrase_memory = {}
            local max_memory_size = math.random(3, 5)

            -- Track phrase memory for variation
            local prev_contour = nil
            local note_start = start_time

            log('Generating ', NUM_PHRASES, ' phrases for channel ', channel, ' (motif repeat chance: ', motif_repeat_chance, '%)')

            -- Sectioning: intro (25%), development (50%), conclusion (remainder)
            local intro_ct = math.max(1, math.floor(NUM_PHRASES * 0.25))
            local dev_ct = math.max(1, math.floor(NUM_PHRASES * 0.5))
            if intro_ct + dev_ct > NUM_PHRASES - 1 then
                dev_ct = math.max(1, NUM_PHRASES - intro_ct - 1)
            end
            local concl_ct = math.max(1, NUM_PHRASES - intro_ct - dev_ct)

            local function section_of(n)
                if n <= intro_ct then return 'intro'
                elseif n <= intro_ct + dev_ct then return 'development'
                else return 'conclusion' end
            end

            -- Targets by section
            local DEG_TONIC = 1
            local DEG_MEDIANT = degree_index_or_closest(3)
            local DEG_DOMINANT = degree_index_or_closest(5)

            -- Generate phrases one by one
            for phrase_num = 1, NUM_PHRASES do
                local phrase = nil
                local section = section_of(phrase_num)
                local is_final = (phrase_num == NUM_PHRASES)
                local tlevel = (section == 'intro' and 'low') or (section == 'development' and 'high') or 'medium'
                local target_idx = (section == 'intro' and (math.random() < 0.5 and DEG_TONIC or DEG_MEDIANT))
                                    or (section == 'development' and DEG_DOMINANT)
                                    or DEG_TONIC -- conclusion prefers tonic

                -- Check if we should repeat a motif from memory
                if #phrase_memory > 0 and math.random(100) <= motif_repeat_chance then
                    -- Retrieve and vary a previous phrase
                    phrase = retrieve_motif(phrase_memory)
                    log('  Phrase ', phrase_num, ': MOTIF REPETITION (varied from memory)')
                end

                -- If no motif repetition, generate new phrase
                if not phrase then
                    -- Determine contour type based on previous phrase
                    local contour_type = get_next_contour_type(prev_contour)

                    -- Choose starting pitch
                    local start_pitch
                    if phrase_num == 1 then
                        -- First phrase: random starting note
                        start_pitch = scale_notes[math.random(1, #scale_notes)]
                    else
                        -- Subsequent phrases: end near where we left off
                        -- Get last inserted note for this channel
                        local last_pitch = scale_notes[math.random(1, #scale_notes)] -- fallback
                        local _, note_count = reaper.MIDI_CountEvts(take)
                        for i = note_count - 1, 0, -1 do
                            local _, _, _, _, _, chan, pitch = reaper.MIDI_GetNote(take, i)
                            if chan == channel then
                                last_pitch = pitch
                                break
                            end
                        end
                        start_pitch = last_pitch
                    end

                    -- Generate the phrase
                    local phrase_length = math.random(4, 8)
                    phrase = generate_phrase(start_pitch, contour_type, phrase_length, {
                        target_idx = target_idx,
                        tension_level = tlevel,
                        section = section,
                        is_final = is_final
                    })

                    log('  Phrase ', phrase_num, ': ', contour_type, ', length=', phrase.length)
                end

                -- Insert all notes from the phrase
                for i = 1, phrase.length do
                    local pitch = phrase.pitches[i]
                    local duration = phrase.durations[i]
                    local velocity = vel_for_dur(duration)
                    local note_end = note_start + duration

                    -- Clamp to item end to avoid overflow
                    if note_end > end_time then note_end = end_time end

                    reaper.MIDI_InsertNote(
                        take, false, false,
                        timeToPPQ(note_start),
                        timeToPPQ(note_end),
                        channel,
                        pitch,
                        velocity,
                        false
                    )

                    note_start = note_end
                end

                -- Add phrase to memory buffer
                table.insert(phrase_memory, phrase)
                -- Keep memory buffer size limited
                if #phrase_memory > max_memory_size then
                    table.remove(phrase_memory, 1) -- Remove oldest phrase
                end

                -- Store this phrase's characteristics for next iteration
                prev_contour = phrase.contour_type
            end

            -- Prune excess notes for this voice if needed
            local voice_note_count = 0
            local _, total_cnt = reaper.MIDI_CountEvts(take)
            for i = 0, total_cnt - 1 do
                local _, _, _, _, _, chan = reaper.MIDI_GetNote(take, i)
                if chan == channel then voice_note_count = voice_note_count + 1 end
            end

            if voice_note_count > notes_to_keep then
                log('  Pruning from ', voice_note_count, ' to ', notes_to_keep, ' notes')
                local deleted = 0
                for i = total_cnt - 1, 0, -1 do
                    if deleted >= (voice_note_count - notes_to_keep) then break end
                    local _, _, _, _, _, chan = reaper.MIDI_GetNote(take, i)
                    if chan == channel then
                        reaper.MIDI_DeleteNote(take, i)
                        deleted = deleted + 1
                    end
                end
            end

            -- Ensure final resolution note is tonic for this channel
            local _, ncnt = reaper.MIDI_CountEvts(take)
            for i = ncnt - 1, 0, -1 do
                local ok, sel, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
                if ok and chan == channel then
                    if pitch ~= scale_notes[1] then
                        reaper.MIDI_SetNote(take, i, sel, muted, startppq, endppq, chan, scale_notes[1], vel, false)
                    end
                    break
                end
            end
        end

        -- Generate all voices independently
        for voice = 0, num_voices - 1 do
            generate_voice(voice)
        end

    -- =============================
    -- Mode 2: HARMONIC - Chord-based generation
    -- =============================
    elseif poly_mode == 'harmonic' then
        log('Harmonic polyphony mode - chord progression')

    local NUM_CHORDS = math.random(tonumber(min_notes) or 3, tonumber(max_notes) or 7)
        local chord_types = {'triad', 'seventh', 'sus4'}

        local prev_chord_pitches = {}
        local note_start = start_time

        for i = 1, NUM_CHORDS do
            -- Pick a random root from scale
            local root_idx = math.random(1, #scale_notes)
            local chord_type = choose_random(chord_types)

            -- Build chord pool
            local chord_pool = build_chord(scale_notes, root_idx, chord_type, {-1, 1})

            -- Use voice leading to choose pitches
            local chord_pitches = find_best_voice_leading(prev_chord_pitches, chord_pool, theory_weight)

            -- Pick duration for this chord
            local chord_dur = pick_duration(quarter_note)
            local note_end = note_start + chord_dur

            -- Insert all voices for this chord
            for voice = 0, math.min(num_voices - 1, #chord_pitches - 1) do
                local pitch = chord_pitches[voice + 1]
                local vel = vel_for_dur(chord_dur)
                reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_end), voice, pitch, vel, false)
            end

            prev_chord_pitches = chord_pitches
            note_start = note_end
        end

    -- =============================
    -- Mode 3: VOICE LEADING - Counterpoint with proper voice leading
    -- =============================
    elseif poly_mode == 'voice_leading' then
        log('Voice leading polyphony mode - counterpoint with theory weight: ', theory_weight)

    local NUM_NOTES = math.random(tonumber(min_notes) or 3, tonumber(max_notes) or 7)

        -- Track state for all voices
        local voice_states = {}
        for v = 0, num_voices - 1 do
            voice_states[v] = {
                pitch = scale_notes[math.random(1, #scale_notes)],
                direction = (math.random(2) == 1) and 1 or -1,
                repeated = 0
            }
        end

        -- Function to generate next note for a voice with voice leading awareness
        local function next_note_vl(voice_id, prev_note, all_current_pitches)
            local state = voice_states[voice_id]
            local move = 0

            -- Decide movement based on blend of free and theory-guided
            if math.random() < (1 - theory_weight) then
                -- Free/creative movement
                if state.repeated >= MAX_REPEATED or math.random() < NOTE_VARIETY then
                    move = state.direction
                    if math.random() > 0.7 then move = -move end
                    state.repeated = 0
                else
                    if math.random() < BIG_JUMP_CHANCE then
                        move = (math.random(2) == 1 and -1 or 1) * math.random(1, BIG_JUMP_INTERVAL)
                        state.repeated = 0
                    end
                end
            else
                -- Theory-guided movement
                -- Prefer stepwise motion (small intervals)
                if math.random() < 0.7 then
                    move = (math.random(2) == 1 and 1 or -1)
                else
                    move = (math.random(2) == 1 and 1 or -1) * 2
                end

                -- Check for contrary motion opportunity
                local other_directions = {}
                for v = 0, num_voices - 1 do
                    if v ~= voice_id then
                        table.insert(other_directions, voice_states[v].direction)
                    end
                end

                -- Encourage contrary motion at higher theory weights
                if #other_directions > 0 and math.random() < (theory_weight * 0.7) then
                    local avg_dir = 0
                    for _, d in ipairs(other_directions) do avg_dir = avg_dir + d end
                    avg_dir = avg_dir / #other_directions
                    -- Move opposite to average
                    if avg_dir > 0 then move = -math.abs(move)
                    else move = math.abs(move) end
                end
            end

            -- MULTI-OCTAVE VOICE LEADING: Allow notes outside single octave
            -- Find current position in scale, then apply chromatic offset for octaves
            local idx = find_index(scale_notes, prev_note % 12 == 0 and prev_note or
                        ((prev_note % 12) + scale_notes[1]) % 12 + scale_notes[1])

            -- Calculate which octave we're in
            local octave_offset = math.floor((prev_note - scale_notes[1]) / 12)

            -- Calculate new index with wrapping for multi-octave range
            local new_idx = idx + move
            local new_octave_offset = octave_offset

            -- Handle octave wrapping
            while new_idx > #scale_notes do
                new_idx = new_idx - #scale_notes
                new_octave_offset = new_octave_offset + 1
            end
            while new_idx < 1 do
                new_idx = new_idx + #scale_notes
                new_octave_offset = new_octave_offset - 1
            end

            -- Clamp to reasonable MIDI range (C-1 to G9)
            new_octave_offset = clamp(new_octave_offset, -2, 8)

            local new_pitch = scale_notes[new_idx] + (new_octave_offset * 12)

            -- Additional safety clamp to MIDI range
            new_pitch = clamp(new_pitch, 0, 127)

            -- Update state
            state.direction = (new_pitch > prev_note) and 1 or ((new_pitch < prev_note) and -1 or 0)
            state.pitch = new_pitch

            return new_pitch
        end

        -- Generate first chord
        local note_start = start_time
        local prev_dur = pick_duration(quarter_note)
        local all_current = {}

        for voice = 0, num_voices - 1 do
            local pitch = voice_states[voice].pitch
            all_current[voice] = pitch
            reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_start + prev_dur), voice, pitch, vel_for_dur(prev_dur), false)
        end

        -- Generate subsequent notes with voice leading
        local note_end = note_start + prev_dur
        for i = 2, NUM_NOTES do
            local new_all_current = {}

            -- Move all voices
            for voice = 0, num_voices - 1 do
                local new_pitch = next_note_vl(voice, all_current[voice], all_current)
                new_all_current[voice] = new_pitch
            end

            -- Check voice leading quality and possibly adjust
            if theory_weight > 0.5 then
                -- Avoid voice crossing for adjacent voices
                for voice = 0, num_voices - 2 do
                    if new_all_current[voice] < new_all_current[voice + 1] then
                        -- Swap if needed
                        new_all_current[voice], new_all_current[voice + 1] = new_all_current[voice + 1], new_all_current[voice]
                    end
                end
            end

            prev_dur = pick_duration(prev_dur)
            note_start = note_end
            note_end = note_start + prev_dur

            -- Insert all voices
            for voice = 0, num_voices - 1 do
                reaper.MIDI_InsertNote(take, false, false, timeToPPQ(note_start), timeToPPQ(note_end), voice, new_all_current[voice], vel_for_dur(prev_dur), false)
            end

            all_current = new_all_current
        end

        -- Prune if needed
    local notes_to_keep = math.random(tonumber(min_keep) or 12, tonumber(max_keep) or 24)
        local _, total_cnt = reaper.MIDI_CountEvts(take)
        if total_cnt > notes_to_keep then
            local deleted = 0
            for i = total_cnt - 1, 0, -1 do
                if deleted >= (total_cnt - notes_to_keep) then break end
                reaper.MIDI_DeleteNote(take, i)
                deleted = deleted + 1
            end
        end

        -- Close voice leading branch
        -- (Ensures clean separation before inserting Zach Hill polyphonic mode)

    -- =============================
    -- Mode 5: ZACH HILL POLYPHONIC (Deferred Generation)
    -- =============================
    elseif poly_mode == 'zach_hill' then
        zach_hill_defer = true  -- handled after branch chain

    -- =============================
    -- Mode 4: PIANIST/GUITARIST - Master Improviser Mode
    -- Advanced improvisational system with sophisticated ornamentation,
    -- motivic development, polyrhythms, and expressive phrasing
    -- =============================
    elseif poly_mode == 'pianist' then
        log('Pianist/Guitarist Master Improviser Mode - Advanced improvisational features')

        -- Configuration - MORE chord changes for MORE FILLS!
        local NUM_CHORD_CHANGES = math.random(4, 8) -- More chord changes = more fills!
        local chord_types = {'triad', 'seventh', 'sus4', 'ninth', 'sus2'}

        -- Expanded fill types with sophisticated improvisational techniques
        local FILL_TYPES = {
            -- Original fills
            'arpeggio_up',           -- Arpeggio ascending
            'arpeggio_down',         -- Arpeggio descending
            'run_to_chord',          -- Scale run approaching the chord
            'decorative',            -- Ornamental notes around chord tones
            'chord_riff',            -- Quick chord-tone based riff
            'polyphonic_arp',        -- Two-voice arpeggio (polyphonic)
            'walk_bass_melody',      -- Bass note + melody (polyphonic)
            'tremolo_chord',         -- Rapid alternation between 2-3 chord tones
            'grace_notes_to_chord',  -- Quick grace note flourish
            'rhythmic_stabs',        -- Short rhythmic chord hits

            -- NEW: Advanced ornamental fills
            'trill_ornament',        -- Rapid alternation between two adjacent notes
            'turn_ornament',         -- Upper neighbor, main note, lower neighbor, main note
            'mordent',               -- Quick lower/upper neighbor and return
            'grace_cluster',         -- Multiple grace notes leading to target
            'chromatic_approach',    -- Chromatic notes approaching chord tones
            'enclosure',             -- Surround target from above and below

            -- NEW: Motivic development
            'motif_sequence',        -- Take a short idea and repeat it higher/lower
            'motif_fragment',        -- Break a motif into smaller pieces
            'motif_inversion',       -- Flip the contour upside down
            'motif_retrograde',      -- Play backwards
            'motif_rhythmic_shift',  -- Keep pitches, change rhythm

            -- NEW: Advanced rhythmic patterns
            'triplet_run',           -- Triplet-based flowing passage
            'quintuplet_flourish',   -- Five-note grouping for complexity
            'syncopated_riff',       -- Off-beat accented pattern
            'rubato_passage',        -- Freely timed expressive phrase
            'hemiola_pattern',       -- 3 against 2 polyrhythm

            -- NEW: Register and interval exploration
            'octave_leap_arp',       -- Arpeggios with octave displacements
            'wide_interval_jump',    -- Dramatic leaps (6ths, 7ths, octaves+)
            'cascade_descent',       -- Rapid downward motion across registers
            'ascending_rocket',      -- Quick upward burst to high register

            -- NEW: Harmonic sophistication
            'extended_voicing',      -- Add 9ths, 11ths, 13ths to chords
            'altered_chord_fill',    -- Use altered scale tones
            'tension_resolution',    -- Build and release harmonic tension
            'modal_exploration',     -- Explore characteristic modal notes

            -- Space/rest
            'silence'                -- Rest/space
        }

        -- =============================
        -- HELPER FUNCTIONS FOR ADVANCED IMPROVISATION
        -- =============================

        -- Helper: Get chord tones as a pool
        local function get_chord_tones(root_scale_idx, chord_type)
            return build_chord(scale_notes, root_scale_idx, chord_type, {-1, 1})
        end

        -- =============================
        -- LEFT HAND & RIGHT HAND THINKING MODULES
        -- =============================

        -- LEFT HAND THOUGHTS: Harmonic foundation, bass, and accompaniment decisions
        -- The left hand is responsible for establishing harmony and rhythm
        local LeftHand = {
            -- State tracking
            last_chord_time = 0,
            last_bass_note = nil,
            energy_level = 0.5, -- 0=sparse, 1=dense
            voicing_preference = 'closed', -- 'closed', 'open', 'rootless'

            -- Decision: Should I play a bass note?
            should_play_bass = function(self, chord_time, time_since_last_chord)
                -- Always play bass on chord changes
                if time_since_last_chord >= quarter_note * 3 then
                    return true, 'chord_change'
                end

                -- Walking bass: play on strong beats
                if self.energy_level > 0.6 and math.random() < 0.7 then
                    return true, 'walking'
                end

                -- Pedal tone: sustain bass
                if self.energy_level < 0.4 and math.random() < 0.5 then
                    return true, 'pedal'
                end

                return false, 'rest'
            end,

            -- Decision: What bass note should I play?
            choose_bass_note = function(self, chord_root, chord_tones, bass_type)
                if bass_type == 'chord_change' then
                    -- Play the root
                    self.last_bass_note = chord_root - 12 -- One octave down
                    return self.last_bass_note

                elseif bass_type == 'walking' then
                    -- Walk toward next chord root (simple chromatic/scale-based walking)
                    if self.last_bass_note then
                        local direction = (chord_root > self.last_bass_note) and 1 or -1
                        -- Find closest scale note to last bass
                        local closest_idx = 1
                        local closest_dist = math.huge
                        for idx, note in ipairs(scale_notes) do
                            local dist = math.abs(note - 12 - self.last_bass_note)
                            if dist < closest_dist then
                                closest_dist = dist
                                closest_idx = idx
                            end
                        end
                        local bass_idx = clamp(closest_idx + direction, 1, #scale_notes)
                        self.last_bass_note = scale_notes[bass_idx] - 12
                        return self.last_bass_note
                    else
                        self.last_bass_note = chord_root - 12
                        return self.last_bass_note
                    end

                elseif bass_type == 'pedal' then
                    -- Sustain current bass note
                    return self.last_bass_note or (chord_root - 12)
                end

                return chord_root - 12
            end,

            -- Decision: How should I voice this chord?
            choose_voicing = function(self, chord_pool)
                local sorted_tones = {}
                for _, tone in ipairs(chord_pool) do
                    if not table_contains(sorted_tones, tone) then
                        table.insert(sorted_tones, tone)
                    end
                end
                table.sort(sorted_tones)

                if self.voicing_preference == 'closed' then
                    -- Closed voicing: notes close together in middle register
                    local voicing = {}
                    for i = 1, math.min(3, #sorted_tones) do
                        table.insert(voicing, sorted_tones[i])
                    end
                    return voicing

                elseif self.voicing_preference == 'open' then
                    -- Open voicing: spread out notes
                    local voicing = {}
                    if #sorted_tones >= 3 then
                        table.insert(voicing, sorted_tones[1])
                        table.insert(voicing, sorted_tones[math.ceil(#sorted_tones / 2)])
                        table.insert(voicing, sorted_tones[#sorted_tones])
                    else
                        voicing = sorted_tones
                    end
                    return voicing

                elseif self.voicing_preference == 'rootless' then
                    -- Rootless voicing: omit the root (jazz style)
                    local voicing = {}
                    for i = 2, math.min(4, #sorted_tones) do
                        table.insert(voicing, sorted_tones[i])
                    end
                    if #voicing == 0 then voicing = {sorted_tones[1]} end
                    return voicing
                end

                return sorted_tones
            end,

            -- Decision: What's my rhythmic approach?
            choose_rhythm_pattern = function(self)
                if self.energy_level > 0.7 then
                    return 'active' -- Syncopated, busy
                elseif self.energy_level > 0.4 then
                    return 'moderate' -- Steady, on-beat
                else
                    return 'sparse' -- Long sustained notes
                end
            end,

            -- Update energy based on musical context
            update_energy = function(self, time_in_phrase)
                -- Energy tends to build toward middle, release at end
                if time_in_phrase < 0.3 then
                    self.energy_level = math.random() * 0.4 + 0.3 -- 0.3-0.7
                elseif time_in_phrase < 0.7 then
                    self.energy_level = math.random() * 0.3 + 0.5 -- 0.5-0.8
                else
                    self.energy_level = math.random() * 0.4 + 0.2 -- 0.2-0.6
                end
            end
        }

        -- RIGHT HAND THOUGHTS: Melodic expression, fills, and ornamentation decisions
        -- The right hand is responsible for melody, embellishment, and virtuosity
        local RightHand = {
            -- State tracking
            last_phrase_type = nil,
            improvisation_intensity = 0.5, -- 0=simple, 1=virtuosic
            melodic_direction = 0, -- -1=descending, 0=static, 1=ascending
            phrase_count = 0,

            -- Decision: What type of fill should I play?
            choose_fill_type = function(self, available_duration, chord_context, target_root)
                -- Update intensity over time
                self.phrase_count = self.phrase_count + 1
                self:update_intensity()

                local duration_factor = available_duration / quarter_note

                -- Short duration: quick ornaments
                if duration_factor < 1 then
                    local quick_fills = {'mordent', 'trill_ornament', 'grace_notes_to_chord'}
                    return quick_fills[math.random(1, #quick_fills)]

                -- Medium duration: runs and arpeggios
                elseif duration_factor < 3 then
                    if self.improvisation_intensity > 0.6 then
                        -- Virtuosic options
                        local medium_virtuoso = {'chromatic_approach', 'triplet_run', 'enclosure',
                                                  'grace_cluster', 'syncopated_riff'}
                        return medium_virtuoso[math.random(1, #medium_virtuoso)]
                    else
                        -- Simpler options
                        local medium_simple = {'arpeggio_up', 'arpeggio_down', 'decorative',
                                                'run_to_chord', 'turn_ornament'}
                        return medium_simple[math.random(1, #medium_simple)]
                    end

                -- Long duration: developed phrases
                else
                    if self.improvisation_intensity > 0.7 then
                        -- Complex development
                        local long_complex = {'motif_sequence', 'cascade_descent', 'ascending_rocket',
                                              'quintuplet_flourish', 'wide_interval_jump', 'tension_resolution'}
                        return long_complex[math.random(1, #long_complex)]
                    else
                        -- Musical phrases
                        local long_musical = {'motif_fragment', 'rubato_passage', 'modal_exploration',
                                              'polyphonic_arp', 'chord_riff'}
                        return long_musical[math.random(1, #long_musical)]
                    end
                end
            end,

            -- Decision: Should I add ornamentation to this phrase?
            should_add_ornament = function(self, note_duration)
                if note_duration < eighth_note then
                    return false -- Too short
                end

                -- More likely at higher intensity
                local ornament_chance = self.improvisation_intensity * 0.4
                return math.random() < ornament_chance
            end,

            -- Decision: What's my dynamic approach?
            choose_dynamics = function(self, fill_type, position_in_phrase)
                local base_vel = 60
                local vel_range = 20

                -- Adjust based on intensity
                base_vel = base_vel + (self.improvisation_intensity * 20)

                -- Adjust based on phrase position
                if position_in_phrase < 0.3 then
                    -- Start softer
                    base_vel = base_vel - 10
                elseif position_in_phrase > 0.7 then
                    -- End with emphasis
                    base_vel = base_vel + 10
                end

                -- Certain fill types are naturally louder
                if fill_type == 'cascade_descent' or fill_type == 'ascending_rocket' or
                   fill_type == 'wide_interval_jump' then
                    base_vel = base_vel + 15
                end

                return {
                    base = clamp(base_vel, 40, 100),
                    range = vel_range
                }
            end,

            -- Decision: Should I rest or play?
            should_play_fill = function(self, time_since_last_fill)
                -- Sparse at low intensity
                if self.improvisation_intensity < 0.3 then
                    return math.random() < 0.4
                end

                -- Always play at high intensity
                if self.improvisation_intensity > 0.7 then
                    return true
                end

                -- Medium intensity: vary based on timing
                if time_since_last_fill < quarter_note then
                    return math.random() < 0.3 -- Less likely if we just played
                else
                    return math.random() < 0.8 -- More likely after space
                end
            end,

            -- Decision: What register should I play in?
            choose_register = function(self, chord_tones)
                -- Track melodic direction
                if self.melodic_direction > 0 then
                    -- Ascending: favor higher notes
                    local sorted = {}
                    for _, t in ipairs(chord_tones) do table.insert(sorted, t) end
                    table.sort(sorted)
                    return sorted[math.ceil(#sorted * 0.7)] -- Upper 30%

                elseif self.melodic_direction < 0 then
                    -- Descending: favor lower notes
                    local sorted = {}
                    for _, t in ipairs(chord_tones) do table.insert(sorted, t) end
                    table.sort(sorted)
                    return sorted[math.ceil(#sorted * 0.3)] -- Lower 30%
                else
                    -- Static: middle register
                    return chord_tones[math.random(1, #chord_tones)]
                end
            end,

            -- Update improvisation intensity
            update_intensity = function(self)
                -- Intensity evolves: builds toward climax, releases
                if self.phrase_count <= 3 then
                    -- Building
                    self.improvisation_intensity = math.min(1.0, self.improvisation_intensity + 0.1)
                elseif self.phrase_count <= 6 then
                    -- Peak
                    self.improvisation_intensity = math.random() * 0.2 + 0.7 -- 0.7-0.9
                else
                    -- Release
                    self.improvisation_intensity = math.max(0.3, self.improvisation_intensity - 0.15)
                end

                -- Update direction occasionally
                if math.random() < 0.3 then
                    local directions = {-1, 0, 1}
                    self.melodic_direction = directions[math.random(1, #directions)]
                end
            end,

            -- Remember what we played for contrast
            remember_phrase = function(self, fill_type)
                self.last_phrase_type = fill_type
            end
        }

        -- COORDINATION: How the hands work together
        local HandCoordination = {
            -- Decide if hands should play together or independently
            should_synchronize = function(left_energy, right_intensity, moment_type)
                -- Always sync on chord changes
                if moment_type == 'chord_change' then
                    return true
                end

                -- Sync for dramatic moments at high energy
                if left_energy > 0.7 and right_intensity > 0.7 then
                    return math.random() < 0.6
                end

                -- Usually independent for textural interest
                return math.random() < 0.2
            end,

            -- Left hand can request the right hand to leave space
            left_requests_space = function(left_pattern)
                if left_pattern == 'active' then
                    return true, 'bass_prominent' -- Right hand plays simpler
                end
                return false, nil
            end,

            -- Right hand can request left hand support
            right_requests_support = function(right_fill_type)
                -- Virtuosic fills need harmonic support
                if right_fill_type == 'cascade_descent' or
                   right_fill_type == 'ascending_rocket' or
                   right_fill_type == 'wide_interval_jump' then
                    return true, 'sustain' -- Left hand holds chord
                end
                return false, nil
            end
        }

        -- Helper: Get chromatic neighbor (not necessarily in scale)
        local function get_chromatic_neighbor(pitch, direction)
            return pitch + direction
        end

        -- Helper: Get chromatic approach notes (half-step below/above target)
        local function get_chromatic_approaches(target_pitch)
            return {target_pitch - 1, target_pitch + 1}
        end

        -- Helper: Get blue notes for blues feel (b3, b5, b7)
        local function get_blue_notes(root_pitch)
            return {
                root_pitch + 3,  -- Minor 3rd (blue note)
                root_pitch + 6,  -- Flat 5 (tritone, blues note)
                root_pitch + 10  -- Minor 7th (blue note)
            }
        end

        -- Helper: Check if pitch is in scale
        local function is_in_scale(pitch)
            for _, scale_pitch in ipairs(scale_notes) do
                if (pitch % 12) == (scale_pitch % 12) then
                    return true
                end
            end
            return false
        end

        -- Helper: Get closest scale tone to a chromatic pitch
        local function snap_to_scale(pitch)
            local best_pitch = scale_notes[1]
            local best_dist = math.abs(pitch - best_pitch)

            for _, scale_pitch in ipairs(scale_notes) do
                local dist = math.abs(pitch - scale_pitch)
                if dist < best_dist then
                    best_dist = dist
                    best_pitch = scale_pitch
                end
            end

            return best_pitch
        end

        -- Helper: Create velocity curve (crescendo/diminuendo)
        local function create_velocity_curve(num_notes, start_vel, end_vel)
            local velocities = {}
            for i = 1, num_notes do
                local t = (i - 1) / math.max(1, num_notes - 1)
                local vel = math.floor(start_vel + t * (end_vel - start_vel))
                table.insert(velocities, clamp(vel, 20, 127))
            end
            return velocities
        end

        -- Helper: Apply rubato timing (speed up/slow down)
        local function apply_rubato(base_duration, intensity)
            -- intensity: -1 (slow down) to +1 (speed up)
            local factor = 1.0 + (intensity * 0.3)
            return base_duration / factor
        end

        -- Helper: Get motif from previous fills (for development)
        local motif_memory = {}
        local function store_motif(pitches)
            if #pitches >= 2 and #pitches <= 5 then
                table.insert(motif_memory, pitches)
                if #motif_memory > 5 then
                    table.remove(motif_memory, 1)
                end
            end
        end

        local function get_stored_motif()
            if #motif_memory == 0 then return nil end
            return motif_memory[math.random(1, #motif_memory)]
        end

        -- Helper: Generate arpeggio fill
        local function generate_arpeggio(start_time, duration, chord_tones, direction)
            local notes = {}
            local sorted_tones = {}

            -- Deduplicate and sort chord tones
            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            if direction == 'down' then
                -- Reverse for descending
                local reversed = {}
                for i = #unique_tones, 1, -1 do
                    table.insert(reversed, unique_tones[i])
                end
                sorted_tones = reversed
            else
                sorted_tones = unique_tones
            end

            -- Slower, more controlled arpeggios - use 8th or quarter notes
            local note_dur = math.max(eighth_note, duration / math.min(#sorted_tones, 4))
            local num_notes = math.floor(duration / note_dur)
            num_notes = math.min(num_notes, 6) -- Max 6 notes in an arpeggio

            local t = start_time

            for i = 1, num_notes do
                local pitch = sorted_tones[((i - 1) % #sorted_tones) + 1]
                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.85, -- Slight staccato
                    pitch = pitch,
                    velocity = math.random(55, 75)
                })
                t = t + note_dur

                if t >= start_time + duration then break end
            end

            return notes
        end

        -- Helper: Generate scale run approaching target chord
        local function generate_run(start_time, duration, target_chord_root)
            local notes = {}
            local target_idx = find_index(scale_notes, target_chord_root)

            -- Start from a few scale degrees away
            local start_offset = math.random(2, 4) * (math.random(2) == 1 and 1 or -1)
            local start_idx = clamp(target_idx + start_offset, 1, #scale_notes)

            -- Use 16th or 8th notes depending on duration available
            local base_note_dur = (duration < half_note) and (quarter_note_duration / 4) or (quarter_note_duration / 2)
            local num_notes = math.floor(duration / base_note_dur)
            num_notes = clamp(num_notes, 3, 8) -- Reasonable run length

            local note_dur = duration / num_notes
            local direction = (target_idx > start_idx) and 1 or -1

            local t = start_time
            local current_idx = start_idx

            for i = 1, num_notes do
                local pitch = scale_notes[current_idx]
                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.75,
                    pitch = pitch,
                    velocity = math.random(60, 80)
                })

                -- Move toward target
                current_idx = current_idx + direction
                current_idx = clamp(current_idx, 1, #scale_notes)

                t = t + note_dur

                if t >= start_time + duration then break end
            end

            return notes
        end

        -- Helper: Generate decorative fill around chord tones
        local function generate_decorative(start_time, duration, chord_tones)
            local notes = {}

            -- Slower decorative notes - 8th or quarter note based
            local note_dur = math.max(eighth_note, duration / 5)
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 2, 6)

            local t = start_time

            for i = 1, num_notes do
                -- Pick a chord tone or neighboring scale degree
                local base_tone = chord_tones[math.random(1, #chord_tones)]
                local base_idx = find_index(scale_notes, base_tone)

                -- Occasionally add neighbor tone
                local offset = 0
                if math.random() < 0.5 then
                    offset = (math.random(2) == 1) and 1 or -1
                end

                local pitch_idx = clamp(base_idx + offset, 1, #scale_notes)
                local pitch = scale_notes[pitch_idx]

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.7,
                    pitch = pitch,
                    velocity = math.random(50, 70)
                })

                t = t + note_dur

                if t >= start_time + duration then break end
            end

            return notes
        end

        -- Helper: Generate chord-based riff
        local function generate_chord_riff(start_time, duration, chord_tones)
            local notes = {}

            -- Create a short repeating pattern from chord tones
            local pattern_length = math.random(2, 4)
            local pattern = {}

            -- Use unique chord tones only
            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end

            for i = 1, pattern_length do
                pattern[i] = unique_tones[math.random(1, #unique_tones)]
            end

            -- Calculate note duration - use 8th notes typically
            local note_dur = math.max(eighth_note * 0.75, duration / (pattern_length * 2))
            local t = start_time
            local max_repeats = math.floor(duration / (note_dur * pattern_length))
            max_repeats = clamp(max_repeats, 1, 3)

            for rep = 1, max_repeats do
                for i = 1, pattern_length do
                    if t >= start_time + duration then break end
                    table.insert(notes, {
                        time = t,
                        duration = note_dur * 0.8,
                        pitch = pattern[i],
                        velocity = math.random(65, 85)
                    })
                    t = t + note_dur
                end
                if t >= start_time + duration then break end
            end

            return notes
        end

        -- Helper: Generate polyphonic arpeggio (two voices)
        local function generate_polyphonic_arp(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            if #unique_tones < 2 then return generate_arpeggio(start_time, duration, chord_tones, 'up') end

            -- Create two-voice pattern: low and high notes alternate/overlap
            local note_dur = math.max(eighth_note * 0.75, duration / 5)
            local num_events = math.floor(duration / note_dur)
            num_events = clamp(num_events, 3, 8)

            local t = start_time
            local low_idx = 1
            local high_idx = math.min(#unique_tones, math.random(3, 4))

            for i = 1, num_events do
                if t >= start_time + duration then break end

                -- Alternate or combine voices
                if i % 3 == 0 then
                    -- Both notes together (interval)
                    table.insert(notes, {
                        time = t,
                        duration = note_dur * 0.9,
                        pitch = unique_tones[low_idx],
                        velocity = math.random(60, 75),
                        voice = 0
                    })
                    table.insert(notes, {
                        time = t,
                        duration = note_dur * 0.9,
                        pitch = unique_tones[high_idx],
                        velocity = math.random(55, 70),
                        voice = 1
                    })
                else
                    -- Single note from alternating register
                    local use_high = (i % 2 == 0)
                    local idx = use_high and high_idx or low_idx
                    table.insert(notes, {
                        time = t,
                        duration = note_dur * 0.8,
                        pitch = unique_tones[idx],
                        velocity = math.random(55, 75),
                        voice = use_high and 1 or 0
                    })
                end

                -- Move indices
                low_idx = (low_idx % #unique_tones) + 1
                high_idx = ((high_idx - 1) % #unique_tones) + 1

                t = t + note_dur
            end

            return notes
        end

        -- Helper: Generate walking bass + melody (polyphonic)
        local function generate_walk_bass_melody(start_time, duration, chord_tones, target_root)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            -- Bass walks toward target
            local bass_note = unique_tones[1] -- Lowest chord tone
            local target_idx = target_root and find_index(scale_notes, target_root) or find_index(scale_notes, unique_tones[1])
            local bass_idx = find_index(scale_notes, bass_note)

            local note_dur = quarter_note
            local num_steps = math.floor(duration / note_dur)
            num_steps = clamp(num_steps, 1, 4)

            local direction = (target_idx > bass_idx) and 1 or -1
            local t = start_time

            for i = 1, num_steps do
                if t >= start_time + duration then break end

                -- Bass note
                local bass_pitch = scale_notes[bass_idx]
                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.9,
                    pitch = bass_pitch,
                    velocity = math.random(70, 85),
                    voice = 0
                })

                -- Melody note from upper chord tones
                if #unique_tones >= 3 then
                    local melody_pitch = unique_tones[math.random(2, #unique_tones)]
                    table.insert(notes, {
                        time = t + note_dur * 0.5, -- Offset for rhythm
                        duration = note_dur * 0.4,
                        pitch = melody_pitch,
                        velocity = math.random(60, 75),
                        voice = 1
                    })
                end

                -- Walk bass
                bass_idx = clamp(bass_idx + direction, 1, #scale_notes)
                t = t + note_dur
            end

            return notes
        end

        -- Helper: Generate tremolo between chord tones
        local function generate_tremolo(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end

            if #unique_tones < 2 then return generate_arpeggio(start_time, duration, chord_tones, 'up') end

            -- Pick 2-3 notes to alternate rapidly
            local tremolo_notes = {}
            for i = 1, math.min(3, #unique_tones) do
                table.insert(tremolo_notes, unique_tones[math.random(1, #unique_tones)])
            end

            -- Very fast alternation
            local note_dur = sixteenth_note * 0.75
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 4, 16)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                local pitch = tremolo_notes[((i - 1) % #tremolo_notes) + 1]
                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.7,
                    pitch = pitch,
                    velocity = math.random(50, 70),
                    voice = 0
                })
                t = t + note_dur
            end

            return notes
        end

        -- Helper: Generate grace notes into chord
        local function generate_grace_notes(start_time, duration, target_root)
            local notes = {}

            local target_idx = find_index(scale_notes, target_root)

            -- Quick grace note flourish (2-4 notes) leading to target
            local num_grace = math.random(2, 4)
            local grace_dur = (duration / num_grace) * 0.6 -- Quick notes

            local current_idx = clamp(target_idx + math.random(2, 4) * (math.random(2) == 1 and 1 or -1), 1, #scale_notes)
            local direction = (target_idx > current_idx) and 1 or -1

            local t = start_time
            for i = 1, num_grace do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = grace_dur * 0.6,
                    pitch = scale_notes[current_idx],
                    velocity = math.random(55, 75),
                    voice = 0
                })

                current_idx = clamp(current_idx + direction, 1, #scale_notes)
                t = t + grace_dur
            end

            return notes
        end

        -- Helper: Generate rhythmic chord stabs
        local function generate_rhythmic_stabs(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end

            -- 2-3 short chord hits
            local num_stabs = math.random(2, 3)
            local stab_spacing = duration / num_stabs

            local t = start_time
            for i = 1, num_stabs do
                if t >= start_time + duration then break end

                -- Pick 2-3 notes for each stab
                local num_voices_in_stab = math.min(3, #unique_tones)
                local stab_dur = eighth_note * 0.5 -- Short and punchy

                for v = 1, num_voices_in_stab do
                    local pitch = unique_tones[math.random(1, #unique_tones)]
                    table.insert(notes, {
                        time = t,
                        duration = stab_dur,
                        pitch = pitch,
                        velocity = math.random(70, 90),
                        voice = v - 1
                    })
                end

                t = t + stab_spacing
            end

            return notes
        end

        -- =============================
        -- NEW: ADVANCED ORNAMENTAL FILLS
        -- =============================

        -- Trill: Rapid alternation between two adjacent notes
        local function generate_trill(start_time, duration, target_pitch)
            local notes = {}
            local main_note = target_pitch
            local upper_note = get_chromatic_neighbor(target_pitch, 1) -- Half step above

            local trill_speed = sixteenth_note * 0.75
            local num_notes = math.floor(duration / trill_speed)
            num_notes = clamp(num_notes, 4, 12)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                local pitch = (i % 2 == 1) and main_note or upper_note
                local vel = math.random(55, 75) + (i <= 3 and 10 or 0) -- Start slightly louder

                table.insert(notes, {
                    time = t,
                    duration = trill_speed * 0.8,
                    pitch = pitch,
                    velocity = vel,
                    voice = 0
                })

                t = t + trill_speed
            end

            return notes
        end

        -- Turn: Upper neighbor, main note, lower neighbor, main note
        local function generate_turn(start_time, duration, main_pitch)
            local notes = {}
            local upper = get_chromatic_neighbor(main_pitch, 1)
            local lower = get_chromatic_neighbor(main_pitch, -1)

            local pattern = {upper, main_pitch, lower, main_pitch}
            local note_dur = duration / 4

            local t = start_time
            for i, pitch in ipairs(pattern) do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.85,
                    pitch = pitch,
                    velocity = math.random(60, 75),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Mordent: Quick neighbor tone ornament
        local function generate_mordent(start_time, duration, main_pitch, is_upper)
            local notes = {}
            local neighbor = get_chromatic_neighbor(main_pitch, is_upper and 1 or -1)

            local quick_dur = duration * 0.25
            local main_dur = duration * 0.75

            -- Quick neighbor
            table.insert(notes, {
                time = start_time,
                duration = quick_dur,
                pitch = neighbor,
                velocity = math.random(55, 70),
                voice = 0
            })

            -- Main note
            table.insert(notes, {
                time = start_time + quick_dur,
                duration = main_dur,
                pitch = main_pitch,
                velocity = math.random(65, 80),
                voice = 0
            })

            return notes
        end

        -- Grace note cluster: Multiple grace notes leading to target
        local function generate_grace_cluster(start_time, duration, target_pitch)
            local notes = {}
            local num_grace = math.random(2, 4)
            local grace_dur = (duration / num_grace) * 0.6

            -- Start from a few semitones away
            local start_offset = math.random(3, 5) * (math.random(2) == 1 and 1 or -1)
            local current_pitch = target_pitch + start_offset

            local t = start_time
            for i = 1, num_grace do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = grace_dur * 0.7,
                    pitch = current_pitch,
                    velocity = math.random(50, 65),
                    voice = 0
                })

                -- Move toward target
                if current_pitch > target_pitch then
                    current_pitch = current_pitch - 1
                else
                    current_pitch = current_pitch + 1
                end

                t = t + grace_dur
            end

            return notes
        end

        -- Chromatic approach: Half-step approaches to chord tones
        local function generate_chromatic_approach(start_time, duration, chord_tones)
            local notes = {}

            local num_targets = math.random(2, 4)
            local time_per_target = duration / num_targets

            local t = start_time
            for i = 1, num_targets do
                if t >= start_time + duration then break end

                local target = chord_tones[math.random(1, #chord_tones)]
                local approach = get_chromatic_neighbor(target, math.random(2) == 1 and 1 or -1)

                local approach_dur = time_per_target * 0.4
                local target_dur = time_per_target * 0.6

                -- Approach note
                table.insert(notes, {
                    time = t,
                    duration = approach_dur,
                    pitch = approach,
                    velocity = math.random(55, 70),
                    voice = 0
                })

                -- Target note
                table.insert(notes, {
                    time = t + approach_dur,
                    duration = target_dur,
                    pitch = target,
                    velocity = math.random(65, 80),
                    voice = 0
                })

                t = t + time_per_target
            end

            return notes
        end

        -- Enclosure: Surround target from above and below
        local function generate_enclosure(start_time, duration, target_pitch)
            local notes = {}

            local above = get_chromatic_neighbor(target_pitch, 1)
            local below = get_chromatic_neighbor(target_pitch, -1)

            local approach_dur = duration * 0.25
            local target_dur = duration * 0.5

            -- Above
            table.insert(notes, {
                time = start_time,
                duration = approach_dur,
                pitch = above,
                velocity = math.random(55, 70),
                voice = 0
            })

            -- Below
            table.insert(notes, {
                time = start_time + approach_dur,
                duration = approach_dur,
                pitch = below,
                velocity = math.random(55, 70),
                voice = 0
            })

            -- Target
            table.insert(notes, {
                time = start_time + approach_dur * 2,
                duration = target_dur,
                pitch = target_pitch,
                velocity = math.random(70, 85),
                voice = 0
            })

            return notes
        end

        -- =============================
        -- NEW: MOTIVIC DEVELOPMENT FILLS
        -- =============================

        -- Motif sequence: Repeat a pattern at different pitches
        local function generate_motif_sequence(start_time, duration, chord_tones)
            local notes = {}

            local motif = get_stored_motif()
            if not motif or #motif < 2 then
                -- Create a simple motif if none stored
                motif = {}
                for i = 1, math.random(2, 4) do
                    table.insert(motif, chord_tones[math.random(1, #chord_tones)])
                end
            end

            local num_repeats = math.random(2, 3)
            local time_per_repeat = duration / num_repeats
            local note_dur = time_per_repeat / #motif

            local t = start_time
            for rep = 1, num_repeats do
                -- Transpose motif for each repeat
                local transpose = (rep - 1) * (math.random(2) == 1 and 2 or -2) -- Up or down by 2 scale degrees

                for _, pitch in ipairs(motif) do
                    if t >= start_time + duration then break end

                    local transposed = snap_to_scale(pitch + transpose)

                    table.insert(notes, {
                        time = t,
                        duration = note_dur * 0.85,
                        pitch = transposed,
                        velocity = math.random(60, 80),
                        voice = 0
                    })

                    t = t + note_dur
                end
            end

            return notes
        end

        -- Motif fragmentation: Break motif into smaller pieces
        local function generate_motif_fragment(start_time, duration, chord_tones)
            local notes = {}

            local motif = get_stored_motif()
            if not motif or #motif < 3 then
                motif = {}
                for i = 1, math.random(3, 5) do
                    table.insert(motif, chord_tones[math.random(1, #chord_tones)])
                end
            end

            -- Take fragments of the motif
            local fragment_size = math.random(2, math.ceil(#motif / 2))
            local fragment = {}
            for i = 1, fragment_size do
                table.insert(fragment, motif[i])
            end

            -- Repeat fragment with variation
            local note_dur = duration / (fragment_size * 2)
            local t = start_time

            for rep = 1, 2 do
                for _, pitch in ipairs(fragment) do
                    if t >= start_time + duration then break end

                    table.insert(notes, {
                        time = t,
                        duration = note_dur * 0.8,
                        pitch = pitch,
                        velocity = math.random(60, 75),
                        voice = 0
                    })

                    t = t + note_dur
                end
            end

            return notes
        end

        -- Motif inversion: Flip intervals upside down
        local function generate_motif_inversion(start_time, duration, chord_tones)
            local notes = {}

            local motif = get_stored_motif()
            if not motif or #motif < 2 then
                motif = {}
                for i = 1, math.random(2, 4) do
                    table.insert(motif, chord_tones[math.random(1, #chord_tones)])
                end
            end

            -- Invert intervals
            local inverted = {}
            table.insert(inverted, motif[1]) -- Keep first note

            for i = 2, #motif do
                local interval = motif[i] - motif[i-1]
                local inverted_pitch = inverted[i-1] - interval -- Flip direction
                table.insert(inverted, snap_to_scale(inverted_pitch))
            end

            local note_dur = duration / #inverted
            local t = start_time

            for _, pitch in ipairs(inverted) do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.85,
                    pitch = pitch,
                    velocity = math.random(60, 80),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Motif retrograde: Play backwards
        local function generate_motif_retrograde(start_time, duration, chord_tones)
            local notes = {}

            local motif = get_stored_motif()
            if not motif or #motif < 2 then
                motif = {}
                for i = 1, math.random(2, 4) do
                    table.insert(motif, chord_tones[math.random(1, #chord_tones)])
                end
            end

            local note_dur = duration / #motif
            local t = start_time

            -- Play backwards
            for i = #motif, 1, -1 do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.85,
                    pitch = motif[i],
                    velocity = math.random(60, 80),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Rhythmic shift: Keep pitches, change rhythm
        local function generate_rhythmic_shift(start_time, duration, chord_tones)
            local notes = {}

            local motif = get_stored_motif()
            if not motif or #motif < 2 then
                motif = {}
                for i = 1, math.random(2, 3) do
                    table.insert(motif, chord_tones[math.random(1, #chord_tones)])
                end
            end

            -- Create irregular rhythm
            local rhythms = {}
            local remaining = duration
            local t = start_time

            for i = 1, #motif do
                local dur
                if i == #motif then
                    dur = remaining
                else
                    -- Random rhythm
                    dur = (math.random(2) == 1) and eighth_note or (eighth_note * 1.5)
                    dur = math.min(dur, remaining)
                end

                table.insert(notes, {
                    time = t,
                    duration = dur * 0.85,
                    pitch = motif[i],
                    velocity = math.random(60, 80),
                    voice = 0
                })

                t = t + dur
                remaining = remaining - dur
                if remaining <= 0 then break end
            end

            return notes
        end

        -- =============================
        -- NEW: ADVANCED RHYTHMIC PATTERNS
        -- =============================

        -- Triplet run: Flowing passage with triplet feel
        local function generate_triplet_run(start_time, duration, chord_tones, target_root)
            local notes = {}

            local target_idx = target_root and find_index(scale_notes, target_root) or find_index(scale_notes, chord_tones[1])
            local start_offset = math.random(3, 6) * (math.random(2) == 1 and 1 or -1)
            local start_idx = clamp(target_idx + start_offset, 1, #scale_notes)

            -- Triplet duration (3 notes in the space of 2)
            local triplet_unit = (quarter_note * 2/3)
            local num_triplets = math.floor(duration / triplet_unit)
            num_triplets = clamp(num_triplets, 3, 12)

            local direction = (target_idx > start_idx) and 1 or -1
            local current_idx = start_idx
            local t = start_time

            -- Create velocity curve (crescendo into target)
            local velocities = create_velocity_curve(num_triplets, 55, 80)

            for i = 1, num_triplets do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = triplet_unit * 0.85,
                    pitch = scale_notes[current_idx],
                    velocity = velocities[i],
                    voice = 0
                })

                current_idx = clamp(current_idx + direction, 1, #scale_notes)
                t = t + triplet_unit
            end

            return notes
        end

        -- Quintuplet flourish: Five-note grouping for complexity
        local function generate_quintuplet_flourish(start_time, duration, chord_tones)
            local notes = {}

            -- Quintuplet duration (5 notes in space of 4)
            local quint_unit = (quarter_note * 4/5)
            local num_quints = math.floor(duration / quint_unit)
            num_quints = clamp(num_quints, 5, 10)

            local t = start_time
            for i = 1, num_quints do
                if t >= start_time + duration then break end

                -- Alternate between chord tones and neighbors
                local pitch
                if i % 2 == 1 then
                    pitch = chord_tones[math.random(1, #chord_tones)]
                else
                    local base = chord_tones[math.random(1, #chord_tones)]
                    local base_idx = find_index(scale_notes, base)
                    pitch = scale_notes[clamp(base_idx + (math.random(2) == 1 and 1 or -1), 1, #scale_notes)]
                end

                table.insert(notes, {
                    time = t,
                    duration = quint_unit * 0.8,
                    pitch = pitch,
                    velocity = math.random(60, 75),
                    voice = 0
                })

                t = t + quint_unit
            end

            return notes
        end

        -- Syncopated riff: Off-beat accented pattern
        local function generate_syncopated_riff(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end

            -- Create syncopated rhythm (emphasis on off-beats)
            local pattern_length = 4
            local note_dur = (duration / pattern_length)

            local t = start_time
            for i = 1, pattern_length do
                if t >= start_time + duration then break end

                local is_offbeat = (i % 2 == 0)
                local offset = is_offbeat and (note_dur * 0.25) or 0 -- Push offbeats forward
                local vel = is_offbeat and math.random(75, 90) or math.random(55, 70)
                local dur = is_offbeat and (note_dur * 0.6) or (note_dur * 0.4)

                table.insert(notes, {
                    time = t + offset,
                    duration = dur,
                    pitch = unique_tones[math.random(1, #unique_tones)],
                    velocity = vel,
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Rubato passage: Freely timed expressive phrase
        local function generate_rubato_passage(start_time, duration, chord_tones)
            local notes = {}

            local num_notes = math.random(4, 7)
            local base_dur = duration / num_notes

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                -- Apply rubato: middle notes rushed, end note held
                local rubato_factor
                if i <= 2 then
                    rubato_factor = math.random() * 0.3 - 0.15 -- Slight variation
                elseif i <= num_notes - 1 then
                    rubato_factor = math.random() * 0.5 - 0.4 -- Rush (negative = faster)
                else
                    rubato_factor = math.random() * 0.5 + 0.2 -- Hold final note
                end

                local note_duration = apply_rubato(base_dur, rubato_factor)

                table.insert(notes, {
                    time = t,
                    duration = note_duration * 0.9,
                    pitch = chord_tones[math.random(1, #chord_tones)],
                    velocity = math.random(55, 75),
                    voice = 0
                })

                t = t + note_duration
            end

            return notes
        end

        -- Hemiola pattern: 3 against 2 polyrhythm
        local function generate_hemiola(start_time, duration, chord_tones)
            local notes = {}

            -- Divide duration into 3 equal parts (3 against underlying 2 or 4)
            local hemiola_dur = duration / 3

            local t = start_time
            for i = 1, 3 do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = hemiola_dur * 0.85,
                    pitch = chord_tones[math.random(1, #chord_tones)],
                    velocity = math.random(65, 85),
                    voice = 0
                })

                t = t + hemiola_dur
            end

            return notes
        end

        -- =============================
        -- NEW: REGISTER EXPLORATION & WIDE INTERVALS
        -- =============================

        -- Octave leap arpeggio: Arpeggios with octave displacements
        local function generate_octave_leap_arp(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            local note_dur = eighth_note
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 3, 8)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                local base_pitch = unique_tones[((i - 1) % #unique_tones) + 1]

                -- Occasionally jump octaves for drama
                local octave_shift = 0
                if i % 3 == 0 and math.random() < 0.6 then
                    octave_shift = (math.random(2) == 1) and 12 or -12
                end

                local pitch = clamp(base_pitch + octave_shift, 36, 96)

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.8,
                    pitch = pitch,
                    velocity = math.random(60, 80),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Wide interval jump: Dramatic leaps
        local function generate_wide_jump(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            if #unique_tones < 2 then return generate_arpeggio(start_time, duration, chord_tones, 'up') end

            -- Create dramatic leaps between registers
            local num_jumps = math.random(2, 4)
            local time_per_jump = duration / num_jumps

            local t = start_time
            for i = 1, num_jumps do
                if t >= start_time + duration then break end

                -- Pick from different registers
                local low_note = unique_tones[1]
                local high_note = unique_tones[#unique_tones]

                local pitch = (i % 2 == 1) and high_note or low_note

                -- Add octave for even more drama
                if math.random() < 0.4 then
                    pitch = pitch + ((pitch == high_note) and 12 or -12)
                    pitch = clamp(pitch, 36, 96)
                end

                table.insert(notes, {
                    time = t,
                    duration = time_per_jump * 0.7,
                    pitch = pitch,
                    velocity = math.random(70, 90),
                    voice = 0
                })

                t = t + time_per_jump
            end

            return notes
        end

        -- Cascade descent: Rapid downward motion across registers
        local function generate_cascade_descent(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            -- Start high, cascade down
            local current_pitch = unique_tones[#unique_tones] + 12 -- Start an octave up
            current_pitch = clamp(current_pitch, 36, 96)

            local note_dur = sixteenth_note * 0.9
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 6, 16)

            -- Velocities increase as we descend (accelerando feel)
            local velocities = create_velocity_curve(num_notes, 60, 85)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.7,
                    pitch = current_pitch,
                    velocity = velocities[i],
                    voice = 0
                })

                -- Move down chromatically or by scale steps
                if math.random() < 0.7 then
                    -- Scale step
                    local idx = find_index(scale_notes, snap_to_scale(current_pitch))
                    idx = clamp(idx - 1, 1, #scale_notes)
                    current_pitch = scale_notes[idx]
                else
                    -- Chromatic
                    current_pitch = current_pitch - 1
                end

                current_pitch = clamp(current_pitch, 36, 96)
                t = t + note_dur
            end

            return notes
        end

        -- Ascending rocket: Quick upward burst
        local function generate_ascending_rocket(start_time, duration, chord_tones, target_root)
            local notes = {}

            local target_idx = target_root and find_index(scale_notes, target_root) or find_index(scale_notes, chord_tones[1])

            -- Start low
            local start_idx = clamp(target_idx - 8, 1, #scale_notes)
            local current_idx = start_idx

            local note_dur = sixteenth_note * 0.85
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 6, 12)

            -- Velocities increase as we ascend
            local velocities = create_velocity_curve(num_notes, 55, 90)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.75,
                    pitch = scale_notes[current_idx],
                    velocity = velocities[i],
                    voice = 0
                })

                current_idx = clamp(current_idx + 1, 1, #scale_notes)
                t = t + note_dur
            end

            return notes
        end

        -- =============================
        -- NEW: HARMONIC SOPHISTICATION
        -- =============================

        -- Extended voicing fill: Add 9ths, 11ths, 13ths
        local function generate_extended_voicing(start_time, duration, chord_tones)
            local notes = {}

            local unique_tones = {}
            for _, tone in ipairs(chord_tones) do
                if not table_contains(unique_tones, tone) then
                    table.insert(unique_tones, tone)
                end
            end
            table.sort(unique_tones)

            -- Add extensions (9th, 11th, 13th)
            local root = unique_tones[1]
            local extensions = {
                snap_to_scale(root + 14), -- 9th
                snap_to_scale(root + 17), -- 11th
                snap_to_scale(root + 21)  -- 13th
            }

            -- Combine chord tones with extensions
            local extended_pool = {}
            for _, p in ipairs(unique_tones) do table.insert(extended_pool, p) end
            for _, p in ipairs(extensions) do table.insert(extended_pool, p) end

            local note_dur = eighth_note
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 3, 6)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.85,
                    pitch = extended_pool[math.random(1, #extended_pool)],
                    velocity = math.random(60, 75),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Altered chord fill: Use chromatic alterations
        local function generate_altered_fill(start_time, duration, chord_tones)
            local notes = {}

            local num_notes = math.random(3, 6)
            local note_dur = duration / num_notes

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                local base = chord_tones[math.random(1, #chord_tones)]

                -- 40% chance to alter (raise or lower by semitone)
                local pitch = base
                if math.random() < 0.4 then
                    pitch = base + (math.random(2) == 1 and 1 or -1)
                end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.8,
                    pitch = pitch,
                    velocity = math.random(60, 75),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Tension and resolution: Build tension then resolve
        local function generate_tension_resolution(start_time, duration, chord_tones, target_root)
            local notes = {}

            local tension_dur = duration * 0.6
            local resolution_dur = duration * 0.4

            -- Tension phase: chromatic notes, dissonance
            local num_tension = math.random(3, 5)
            local tension_note_dur = tension_dur / num_tension

            local t = start_time
            for i = 1, num_tension do
                if t >= start_time + tension_dur then break end

                local pitch = chord_tones[math.random(1, #chord_tones)]
                -- Add chromatic tension
                pitch = pitch + math.random(-1, 1)

                table.insert(notes, {
                    time = t,
                    duration = tension_note_dur * 0.7,
                    pitch = pitch,
                    velocity = math.random(65, 80),
                    voice = 0
                })

                t = t + tension_note_dur
            end

            -- Resolution phase: resolve to chord tones
            local num_resolution = 2
            local resolution_note_dur = resolution_dur / num_resolution

            for i = 1, num_resolution do
                if t >= start_time + duration then break end

                local pitch = target_root or chord_tones[1]

                table.insert(notes, {
                    time = t,
                    duration = resolution_note_dur * 0.9,
                    pitch = pitch,
                    velocity = math.random(70, 85),
                    voice = 0
                })

                t = t + resolution_note_dur
            end

            return notes
        end

        -- Modal exploration: Emphasize characteristic modal notes
        local function generate_modal_exploration(start_time, duration, chord_tones)
            local notes = {}

            -- Find characteristic notes (b2, #4, b6, b7, etc.)
            local root = chord_tones[1]
            local modal_notes = {}

            for _, tone in ipairs(scale_notes) do
                local interval = (tone - root) % 12
                -- Characteristic intervals: b2, b3, #4, b6, b7
                if interval == 1 or interval == 3 or interval == 6 or interval == 8 or interval == 10 then
                    table.insert(modal_notes, tone)
                end
            end

            -- If no modal notes found, use scale notes
            if #modal_notes == 0 then
                modal_notes = scale_notes
            end

            local note_dur = eighth_note
            local num_notes = math.floor(duration / note_dur)
            num_notes = clamp(num_notes, 3, 7)

            local t = start_time
            for i = 1, num_notes do
                if t >= start_time + duration then break end

                table.insert(notes, {
                    time = t,
                    duration = note_dur * 0.85,
                    pitch = modal_notes[math.random(1, #modal_notes)],
                    velocity = math.random(60, 80),
                    voice = 0
                })

                t = t + note_dur
            end

            return notes
        end

        -- Main generation loop for pianist/guitarist mode
        local prev_chord_pitches = {}
        local chord_times = {} -- Store when chords happen
        local fills = {} -- Store fill events
        local bass_notes = {} -- Store bass line separately

        -- First pass: determine chord positions and types
        local total_duration = end_time - start_time
        local time_per_chord = total_duration / NUM_CHORD_CHANGES

        log('Total duration: ', total_duration, 's, Time per chord: ', time_per_chord, 's')
        log('=== PIANIST MODE: HANDS THINKING INDEPENDENTLY ===')

        for i = 1, NUM_CHORD_CHANGES do
            local chord_time = start_time + (i - 1) * time_per_chord
            local time_in_phrase = (i - 1) / (NUM_CHORD_CHANGES - 1)

            -- LEFT HAND THINKING: Update state
            LeftHand:update_energy(time_in_phrase)
            local left_rhythm = LeftHand:choose_rhythm_pattern()

            log('\n--- Chord ', i, ' at ', string.format('%.2f', chord_time), 's ---')
            log('  Left hand energy: ', string.format('%.2f', LeftHand.energy_level), ', rhythm: ', left_rhythm)

            -- Add subtle groove/swing to chord timing (±5% of beat)
            local groove_offset = (math.random() * 2 - 1) * (quarter_note_duration * 0.05)
            chord_time = chord_time + groove_offset

            -- Choose root and chord type
            local root_idx = math.random(1, #scale_notes)
            local chord_type = choose_random(chord_types)
            local chord_pool = get_chord_tones(root_idx, chord_type)
            local chord_root = scale_notes[root_idx]

            -- LEFT HAND DECISION: Should I play bass?
            local time_since_last = i > 1 and (chord_time - chord_times[#chord_times].time) or 999
            local should_bass, bass_type = LeftHand:should_play_bass(chord_time, time_since_last)

            if should_bass then
                local bass_pitch = LeftHand:choose_bass_note(chord_root, chord_pool, bass_type)
                table.insert(bass_notes, {
                    time = chord_time,
                    pitch = bass_pitch,
                    duration = time_per_chord * 0.9,
                    type = bass_type,
                    velocity = (bass_type == 'walking') and math.random(75, 90) or math.random(70, 85)
                })
                log('  Left hand bass: ', bass_type, ', pitch: ', bass_pitch)
            else
                log('  Left hand: resting (no bass)')
            end

            -- LEFT HAND DECISION: How should I voice the chord?
            -- Randomly update voicing preference
            if math.random() < 0.3 then
                local voicing_types = {'closed', 'open', 'rootless'}
                LeftHand.voicing_preference = voicing_types[math.random(1, #voicing_types)]
            end

            local chord_voicing = LeftHand:choose_voicing(chord_pool)

            -- Voice lead to this chord (but use left hand's chosen voicing as a guide)
            local chord_pitches = find_best_voice_leading(prev_chord_pitches, chord_voicing, theory_weight)

            -- LEFT HAND DECISION: Chord duration based on rhythm pattern
            local chord_hold_percent
            if left_rhythm == 'sparse' then
                chord_hold_percent = math.random(60, 80) -- Long sustain
                log('  Left hand voicing: ', LeftHand.voicing_preference, ' (sparse, sustained)')
            elseif left_rhythm == 'moderate' then
                chord_hold_percent = math.random(45, 60) -- Medium
                log('  Left hand voicing: ', LeftHand.voicing_preference, ' (moderate)')
            else -- active
                chord_hold_percent = math.random(30, 45) -- Short, punchy
                log('  Left hand voicing: ', LeftHand.voicing_preference, ' (active, staccato)')
            end

            local chord_hold = time_per_chord * chord_hold_percent / 100
            local fill_space = time_per_chord - chord_hold

            log('  Chord hold: ', string.format('%.2f', chord_hold), 's, fill space: ', string.format('%.2f', fill_space), 's')

            -- Store chord info
            table.insert(chord_times, {
                time = chord_time,
                duration = chord_hold,
                pitches = chord_pitches,
                root = scale_notes[root_idx],
                chord_tones = chord_pool
            })

            -- RIGHT HAND THINKING: Should I play a fill?
            if i < NUM_CHORD_CHANGES and fill_space > eighth_note then
                -- RIGHT HAND DECISION: Should I play or rest?
                if RightHand:should_play_fill(fill_space) then
                    -- Reuse root_idx for next root
                    root_idx = math.random(1, #scale_notes)

                    -- Create fill entry directly in table to avoid local variables
                    fills[#fills + 1] = {
                        type = RightHand:choose_fill_type(fill_space, chord_pool, scale_notes[root_idx]),
                        time = chord_time + chord_hold,
                        duration = fill_space * 0.9,
                        target_root = scale_notes[root_idx],
                        chord_tones = chord_pool,
                        dynamics = nil, -- Set below
                        needs_support = nil -- Set below
                    }

                    -- Set dynamics
                    fills[#fills].dynamics = RightHand:choose_dynamics(fills[#fills].type, (i - 1) / NUM_CHORD_CHANGES)

                    -- Check coordination
                    fills[#fills].needs_support = (function()
                        local ns, st = HandCoordination.right_requests_support(fills[#fills].type)
                        if ns then log('    (requesting ', st, ' from left hand)') end
                        return ns
                    end)()

                    log('  Right hand: "', fills[#fills].type, '" at ', string.format('%.2f', fills[#fills].time), 's')
                    log('    Intensity: ', string.format('%.2f', RightHand.improvisation_intensity),
                        ', dynamics: ', fills[#fills].dynamics.base, '±', fills[#fills].dynamics.range)

                    RightHand:remember_phrase(fills[#fills].type)
                else
                    log('  Right hand: resting (silence)')
                end

                -- Check coordination: Does left hand need right hand to simplify?
                if (function()
                    local ns, sr = HandCoordination.left_requests_space(left_rhythm)
                    if ns then
                        log('  Left hand requests space: ', sr)
                        RightHand.improvisation_intensity = math.max(0.2, RightHand.improvisation_intensity - 0.2)
                    end
                    return ns
                end)() then end
            end

            prev_chord_pitches = chord_pitches
        end

        -- Second pass: Insert LEFT HAND bass notes
        log('\n=== INSERTING LEFT HAND BASS LINE ===')
        for _, bass_note in ipairs(bass_notes) do
            local bass_humanize = (math.random() * 2 - 1) * 0.003 -- ±3ms

            reaper.MIDI_InsertNote(
                take, false, false,
                timeToPPQ(bass_note.time + bass_humanize),
                timeToPPQ(bass_note.time + bass_note.duration),
                num_voices, -- Use a separate channel for bass
                bass_note.pitch,
                bass_note.velocity,
                false
            )
            log('  Bass note: ', bass_note.type, ' at ', string.format('%.2f', bass_note.time), 's')
        end

        -- Third pass: Insert LEFT HAND chords with humanization
        log('\n=== INSERTING LEFT HAND CHORDS ===')
        for _, chord_event in ipairs(chord_times) do
            -- Slight timing offset per chord for groove
            local chord_humanize = (math.random() * 2 - 1) * 0.005 -- ±5ms

            for voice = 0, math.min(num_voices - 1, #chord_event.pitches - 1) do
                local pitch = chord_event.pitches[voice + 1]

                -- Varied velocities within chord - top note slightly louder
                local vel_base = math.random(70, 90)
                local vel = (voice == 0) and vel_base + math.random(5, 10) or vel_base + math.random(-5, 5)
                vel = clamp(vel, 60, 100)

                -- Very slight stagger on chord notes (piano-like)
                local voice_offset = voice * 0.002 -- 2ms stagger per voice

                reaper.MIDI_InsertNote(
                    take, false, false,
                    timeToPPQ(chord_event.time + chord_humanize + voice_offset),
                    timeToPPQ(chord_event.time + chord_event.duration),
                    voice,
                    pitch,
                    vel,
                    false
                )
            end
        end

        -- Fourth pass: Insert RIGHT HAND fills with humanization
        log('\n=== INSERTING RIGHT HAND FILLS ===')
        for _, fill_event in ipairs(fills) do
            local fill_notes = {}

            -- Apply right hand's dynamic choices
            local dyn = fill_event.dynamics or {base = 65, range = 20}

            -- Original fill types
            if fill_event.type == 'arpeggio_up' then
                fill_notes = generate_arpeggio(fill_event.time, fill_event.duration, fill_event.chord_tones, 'up')
            elseif fill_event.type == 'arpeggio_down' then
                fill_notes = generate_arpeggio(fill_event.time, fill_event.duration, fill_event.chord_tones, 'down')
            elseif fill_event.type == 'run_to_chord' and fill_event.target_root then
                fill_notes = generate_run(fill_event.time, fill_event.duration, fill_event.target_root)
            elseif fill_event.type == 'decorative' then
                fill_notes = generate_decorative(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'chord_riff' then
                fill_notes = generate_chord_riff(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'polyphonic_arp' then
                fill_notes = generate_polyphonic_arp(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'walk_bass_melody' then
                fill_notes = generate_walk_bass_melody(fill_event.time, fill_event.duration, fill_event.chord_tones, fill_event.target_root)
            elseif fill_event.type == 'tremolo_chord' then
                fill_notes = generate_tremolo(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'grace_notes_to_chord' and fill_event.target_root then
                fill_notes = generate_grace_notes(fill_event.time, fill_event.duration, fill_event.target_root)
            elseif fill_event.type == 'rhythmic_stabs' then
                fill_notes = generate_rhythmic_stabs(fill_event.time, fill_event.duration, fill_event.chord_tones)

            -- NEW: Advanced ornamental fills
            elseif fill_event.type == 'trill_ornament' then
                local target = fill_event.chord_tones[math.random(1, #fill_event.chord_tones)]
                fill_notes = generate_trill(fill_event.time, fill_event.duration, target)
            elseif fill_event.type == 'turn_ornament' then
                local target = fill_event.chord_tones[math.random(1, #fill_event.chord_tones)]
                fill_notes = generate_turn(fill_event.time, fill_event.duration, target)
            elseif fill_event.type == 'mordent' then
                local target = fill_event.chord_tones[math.random(1, #fill_event.chord_tones)]
                fill_notes = generate_mordent(fill_event.time, fill_event.duration, target, math.random(2) == 1)
            elseif fill_event.type == 'grace_cluster' then
                local target = fill_event.target_root or fill_event.chord_tones[math.random(1, #fill_event.chord_tones)]
                fill_notes = generate_grace_cluster(fill_event.time, fill_event.duration, target)
            elseif fill_event.type == 'chromatic_approach' then
                fill_notes = generate_chromatic_approach(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'enclosure' then
                local target = fill_event.target_root or fill_event.chord_tones[math.random(1, #fill_event.chord_tones)]
                fill_notes = generate_enclosure(fill_event.time, fill_event.duration, target)

            -- NEW: Motivic development fills
            elseif fill_event.type == 'motif_sequence' then
                fill_notes = generate_motif_sequence(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'motif_fragment' then
                fill_notes = generate_motif_fragment(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'motif_inversion' then
                fill_notes = generate_motif_inversion(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'motif_retrograde' then
                fill_notes = generate_motif_retrograde(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'motif_rhythmic_shift' then
                fill_notes = generate_rhythmic_shift(fill_event.time, fill_event.duration, fill_event.chord_tones)

            -- NEW: Advanced rhythmic patterns
            elseif fill_event.type == 'triplet_run' then
                fill_notes = generate_triplet_run(fill_event.time, fill_event.duration, fill_event.chord_tones, fill_event.target_root)
            elseif fill_event.type == 'quintuplet_flourish' then
                fill_notes = generate_quintuplet_flourish(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'syncopated_riff' then
                fill_notes = generate_syncopated_riff(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'rubato_passage' then
                fill_notes = generate_rubato_passage(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'hemiola_pattern' then
                fill_notes = generate_hemiola(fill_event.time, fill_event.duration, fill_event.chord_tones)

            -- NEW: Register exploration
            elseif fill_event.type == 'octave_leap_arp' then
                fill_notes = generate_octave_leap_arp(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'wide_interval_jump' then
                fill_notes = generate_wide_jump(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'cascade_descent' then
                fill_notes = generate_cascade_descent(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'ascending_rocket' then
                fill_notes = generate_ascending_rocket(fill_event.time, fill_event.duration, fill_event.chord_tones, fill_event.target_root)

            -- NEW: Harmonic sophistication
            elseif fill_event.type == 'extended_voicing' then
                fill_notes = generate_extended_voicing(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'altered_chord_fill' then
                fill_notes = generate_altered_fill(fill_event.time, fill_event.duration, fill_event.chord_tones)
            elseif fill_event.type == 'tension_resolution' then
                fill_notes = generate_tension_resolution(fill_event.time, fill_event.duration, fill_event.chord_tones, fill_event.target_root)
            elseif fill_event.type == 'modal_exploration' then
                fill_notes = generate_modal_exploration(fill_event.time, fill_event.duration, fill_event.chord_tones)

            -- 'silence' means no fill notes - just space
            end

            -- Store motif for future development (extract pitches from fill notes)
            if #fill_notes > 0 and #fill_notes <= 5 then
                local pitches = {}
                for _, note in ipairs(fill_notes) do
                    table.insert(pitches, note.pitch)
                end
                store_motif(pitches)
            end

            -- Insert fill notes with timing humanization and RIGHT HAND dynamics
            for note_idx, note in ipairs(fill_notes) do
                -- Add subtle timing variation (±10ms)
                local humanize_offset = (math.random() * 2 - 1) * 0.010
                local note_time = note.time + humanize_offset

                -- Apply right hand's chosen dynamics instead of fill's default velocity
                local position_in_fill = (note_idx - 1) / math.max(1, #fill_notes - 1)
                local half_range = math.floor(dyn.range / 2)
                local velocity = dyn.base + math.random(-half_range, half_range)

                -- Slight dynamic curve within phrase
                if position_in_fill < 0.3 then
                    velocity = velocity - 5 -- Start softer
                elseif position_in_fill > 0.7 then
                    velocity = velocity + 5 -- End stronger
                end

                velocity = math.floor(clamp(velocity, 40, 110))

                -- Use voice from note if specified (for polyphonic fills), otherwise channel 0
                local channel = note.voice or 0

                reaper.MIDI_InsertNote(
                    take, false, false,
                    timeToPPQ(note_time),
                    timeToPPQ(note_time + note.duration),
                    channel,
                    note.pitch,
                    velocity, -- Use right hand's dynamic choice
                    false
                )
            end
        end

        log('\n=== GENERATION COMPLETE ===')
        log('Generated ', NUM_CHORD_CHANGES, ' chords with ', #fills, ' fills and ', #bass_notes, ' bass notes')
        log('Left hand energy range: ', string.format('%.2f', LeftHand.energy_level))
        log('Right hand intensity range: ', string.format('%.2f', RightHand.improvisation_intensity))

    -- =============================
    -- Mode 6: SYNTH SEQUENCER - House/Techno/Electro
    -- Step-sequenced feel with repetitive rhythms, melodic variation
    -- Suitable for basslines, leads, and arpeggios
    -- =============================
    elseif poly_mode == 'synth_seq' then
        log('Synth Sequencer Mode - House/Techno/Electro')

        -- Sequencer style: bassline, lead, or arpeggio
        -- Infer from register: low=bass, mid=lead, high=arp
        local avg_note = scale_notes[math.floor(#scale_notes / 2)]
        local seq_style
        if avg_note < 48 then seq_style = 'bass'
        elseif avg_note < 72 then seq_style = 'lead'
        else seq_style = 'arp' end

        -- 16th note grid for step sequencer feel
        local sixteenth = quarter_note / 4
        local pattern_len = 16 -- One bar pattern (16 steps)
        local num_patterns = measures * 4 -- Four patterns per measure

        -- Pattern parameters by style
        local note_density, range_limit, rest_chance, vel_base, vel_range
        if seq_style == 'bass' then
            note_density = 0.6 -- Sparser, groove-based
            range_limit = math.floor(5) -- Stay within 5 scale degrees
            rest_chance = 0.35 -- More space in basslines
            vel_base, vel_range = 95, 20 -- Punchy
        elseif seq_style == 'lead' then
            note_density = 0.7 -- Medium density
            range_limit = math.floor(9) -- More melodic freedom
            rest_chance = 0.25 -- Some syncopation
            vel_base, vel_range = 85, 25 -- Dynamic variation
        else -- arpeggio
            note_density = 0.85 -- Dense, flowing
            range_limit = math.floor(12) -- Full range
            rest_chance = 0.15 -- Continuous feel
            vel_base, vel_range = 75, 20 -- Consistent
        end

        -- Generate base pattern (will repeat with variations)
        local base_pattern = {}
        local active_count = 0
        for step = 1, pattern_len do
            if math.random() < note_density then
                base_pattern[step] = {active = true, offset = 0}
                active_count = active_count + 1
            else
                base_pattern[step] = {active = false}
            end
        end

        -- Ensure at least some activity
        if active_count < 4 then
            base_pattern[1] = {active = true, offset = 0}
            base_pattern[5] = {active = true, offset = 0}
            base_pattern[9] = {active = true, offset = 0}
            base_pattern[13] = {active = true, offset = 0}
        end

        -- Generate pitched sequences (multi-voice aware)
        local current_time = start_time
        -- Track a separate scale index per voice so multiple voices can move independently
        local voice_scale_idx = {}
        local num_seq_voices = clamp(num_voices, 1, 16)
        for v = 0, num_seq_voices - 1 do
            voice_scale_idx[v] = math.random(1, math.min(range_limit, #scale_notes))
        end

        for pattern_num = 1, num_patterns do
            -- Decide variation level for this pattern
            local variation = math.random()
            local pitch_shift = 0

            if variation < 0.7 then
                -- Repeat base pattern (70% of time - REPETITIVE)
                pitch_shift = 0
            elseif variation < 0.9 then
                -- Transpose pattern up/down (20%)
                pitch_shift = choose_random({-2, -1, 1, 2})
            else
                -- Rhythmic variation (10%)
                for step = 1, pattern_len do
                    if base_pattern[step].active and math.random() < 0.5 then
                        base_pattern[step].active = false
                    elseif not base_pattern[step].active and math.random() < 0.3 then
                        base_pattern[step].active = true
                    end
                end
            end

            -- Generate notes from pattern
            for step = 1, pattern_len do
                local step_time = current_time + (step - 1) * sixteenth

                if base_pattern[step].active and math.random() > rest_chance then
                    -- Iterate voices so sequencer can be polyphonic when num_voices > 1
                    for voice = 0, num_seq_voices - 1 do
                        -- Small chance each voice skips this active step to avoid total clutter
                        if voice == 0 or math.random() > 0.35 then
                            local move
                            if seq_style == 'bass' then
                                -- Bass: root-fifth motion, occasional passing tones
                                move = choose_random({0, 0, 0, 4, 4, 1, -1}) -- Bias to root/fifth
                            elseif seq_style == 'lead' then
                                -- Lead: stepwise with occasional leaps
                                if math.random() < 0.7 then
                                    move = choose_random({-1, 0, 1}) -- Stepwise
                                else
                                    move = choose_random({-3, -2, 2, 3}) -- Small leaps
                                end
                            else -- arp
                                -- Arpeggio: systematic triadic motion
                                move = choose_random({-4, -2, 0, 2, 4}) -- Triadic intervals
                            end

                            local idx = clamp((voice_scale_idx[voice] or 1) + move + pitch_shift, 1, math.min(range_limit, #scale_notes))
                            voice_scale_idx[voice] = idx
                            local pitch = scale_notes[idx]

                            -- Duration: equal chance of 1/16, 1/8, 1/4, 1/2 notes
                            local r = math.random()
                            local dur
                            if r < 0.25 then
                                dur = sixteenth * 0.9      -- 1/16
                            elseif r < 0.50 then
                                dur = eighth_note * 0.9    -- 1/8
                            elseif r < 0.75 then
                                dur = quarter_note * 0.9   -- 1/4
                            else
                                dur = half_note * 0.9      -- 1/2
                            end

                            -- Velocity variation
                            local vel = vel_base + math.random(-math.floor(vel_range/2), math.floor(vel_range/2))
                            -- Accent certain steps (1, 5, 9, 13 = downbeats)
                            if step % 4 == 1 and voice == 0 then vel = vel + 10 end
                            vel = clamp(math.floor(vel), 40, 120)

                            reaper.MIDI_InsertNote(
                                take, false, false,
                                timeToPPQ(step_time),
                                timeToPPQ(step_time + dur),
                                voice, pitch, vel, false
                            )
                        end
                    end
                end
            end

            current_time = current_time + pattern_len * sixteenth
        end

        log('Synth Sequencer: Generated ', num_patterns, ' patterns in ', seq_style, ' style')
    end
end

-- Name the take
local root_name = note_names[(root_note % 12) + 1]
local octave = math.floor(root_note / 12) - 1
local take_name = string.format('%s%d %s', root_name, octave, chosen_scale_key)
reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)

-- Execute deferred Zach Hill polyphonic generation if selected
if zach_hill_defer then
    generate_zach_hill_polyphonic(take, start_time, end_time, scale_notes, num_voices, measures, defaults.min_keep, defaults.max_keep, quarter_note)
end

reaper.Undo_EndBlock('jtp gen: Melody Generator (Dialog)', -1)
reaper.UpdateArrange()
