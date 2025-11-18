-- @description jtp gen: Smart Chord Progression Generator
-- @author James
-- @version 1.0
-- @about
--   # Smart Chord Progression Generator
--   Generates chord progressions using functional harmony principles and voice leading optimization.
--   Uses algorithmic reasoning based on:
--   - Functional harmony (tonic/subdominant/dominant relationships)
--   - Voice leading efficiency (minimal movement between chords)
--   - Tension/release curves
--   - Circle of fifths movement
--   Creates MIDI items with smooth voice-led chord progressions.

if not reaper then
    return
end

-- ============================================================================
-- MUSIC THEORY DATA STRUCTURES
-- ============================================================================

-- Note names to MIDI numbers (C4 = 60)
local NOTE_NAMES = {
    ["C"] = 0, ["C#"] = 1, ["Db"] = 1,
    ["D"] = 2, ["D#"] = 3, ["Eb"] = 3,
    ["E"] = 4,
    ["F"] = 5, ["F#"] = 6, ["Gb"] = 6,
    ["G"] = 7, ["G#"] = 8, ["Ab"] = 8,
    ["A"] = 9, ["A#"] = 10, ["Bb"] = 10,
    ["B"] = 11
}

-- Scale degrees (intervals from root in semitones)
local MAJOR_SCALE = {0, 2, 4, 5, 7, 9, 11}
local MINOR_SCALE = {0, 2, 3, 5, 7, 8, 10}  -- Natural minor

-- Chord qualities (intervals from root)
local CHORD_TYPES = {
    major = {0, 4, 7},           -- Major triad
    minor = {0, 3, 7},           -- Minor triad
    diminished = {0, 3, 6},      -- Diminished triad
    dominant7 = {0, 4, 7, 10},   -- Dominant 7th
    minor7 = {0, 3, 7, 10},      -- Minor 7th
    major7 = {0, 4, 7, 11}       -- Major 7th
}

-- Key names
local KEY_NAMES = {"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}

-- Functional harmony roles
local FUNCTION_TONIC = 1
local FUNCTION_SUBDOMINANT = 2
local FUNCTION_DOMINANT = 3

-- ============================================================================
-- PERSISTENCE (ExtState)
-- ============================================================================

local EXT_SECTION = 'jtp_gen_chords_dialog'

local function get_ext(key, def)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == nil or v == '' then return tostring(def) end
    return v
end

local function set_ext(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- ============================================================================
-- CHORD PROGRESSION ALGORITHM
-- ============================================================================

-- Get diatonic chords for a major key
local function getMajorDiatonicChords(rootNote)
    return {
        {degree = 1, root = (rootNote + 0) % 12, quality = "major", name = "I", func = FUNCTION_TONIC},
        {degree = 2, root = (rootNote + 2) % 12, quality = "minor", name = "ii", func = FUNCTION_SUBDOMINANT},
        {degree = 3, root = (rootNote + 4) % 12, quality = "minor", name = "iii", func = FUNCTION_TONIC},
        {degree = 4, root = (rootNote + 5) % 12, quality = "major", name = "IV", func = FUNCTION_SUBDOMINANT},
        {degree = 5, root = (rootNote + 7) % 12, quality = "major", name = "V", func = FUNCTION_DOMINANT},
        {degree = 6, root = (rootNote + 9) % 12, quality = "minor", name = "vi", func = FUNCTION_TONIC},
        {degree = 7, root = (rootNote + 11) % 12, quality = "diminished", name = "vii°", func = FUNCTION_DOMINANT}
    }
end

-- Get diatonic chords for a minor key
local function getMinorDiatonicChords(rootNote)
    return {
        {degree = 1, root = (rootNote + 0) % 12, quality = "minor", name = "i", func = FUNCTION_TONIC},
        {degree = 2, root = (rootNote + 2) % 12, quality = "diminished", name = "ii°", func = FUNCTION_SUBDOMINANT},
        {degree = 3, root = (rootNote + 3) % 12, quality = "major", name = "III", func = FUNCTION_TONIC},
        {degree = 4, root = (rootNote + 5) % 12, quality = "minor", name = "iv", func = FUNCTION_SUBDOMINANT},
        {degree = 5, root = (rootNote + 7) % 12, quality = "major", name = "V", func = FUNCTION_DOMINANT},
        {degree = 6, root = (rootNote + 8) % 12, quality = "major", name = "VI", func = FUNCTION_SUBDOMINANT},
        {degree = 7, root = (rootNote + 10) % 12, quality = "major", name = "VII", func = FUNCTION_DOMINANT}
    }
end

-- Calculate "distance" between two chords (for voice leading weight)
local function getChordDistance(chord1, chord2)
    local root_distance = math.abs(chord1.root - chord2.root)
    if root_distance > 6 then
        root_distance = 12 - root_distance
    end

    -- Circle of fifths is optimal (distance of 5 or 7 semitones)
    if root_distance == 5 or root_distance == 7 then
        return 1  -- Low distance = good
    elseif root_distance == 0 then
        return 3  -- Same root = interesting color change
    else
        return root_distance
    end
end

-- Get weighted next chord based on functional harmony
local function getNextChordWeights(currentChord, allChords, tension, adventureLevel)
    local weights = {}

    for i, chord in ipairs(allChords) do
        local weight = 0

        -- Functional harmony weights
        if currentChord.func == FUNCTION_TONIC then
            if chord.func == FUNCTION_SUBDOMINANT then
                weight = 40  -- I → IV/ii common
            elseif chord.func == FUNCTION_DOMINANT then
                weight = 30  -- I → V possible
            elseif chord.func == FUNCTION_TONIC and chord.degree ~= currentChord.degree then
                weight = 20  -- I → vi/iii for variety
            end
        elseif currentChord.func == FUNCTION_SUBDOMINANT then
            if chord.func == FUNCTION_DOMINANT then
                weight = 50  -- IV → V strong tendency
            elseif chord.func == FUNCTION_TONIC then
                weight = 30  -- IV → I also good
            elseif chord.func == FUNCTION_SUBDOMINANT and chord.degree ~= currentChord.degree then
                weight = 15  -- Subdominant → subdominant less common
            end
        elseif currentChord.func == FUNCTION_DOMINANT then
            if chord.func == FUNCTION_TONIC then
                weight = 70  -- V → I very strong resolution
            elseif chord.func == FUNCTION_SUBDOMINANT then
                weight = 20  -- Deceptive resolution
            elseif chord.func == FUNCTION_DOMINANT and chord.degree ~= currentChord.degree then
                weight = 10  -- Secondary dominant chains
            end
        end

        -- Avoid immediate repetition
        if chord.degree == currentChord.degree then
            weight = weight * 0.1
        end

        -- Voice leading bonus (shorter distance = higher weight)
        local distance = getChordDistance(currentChord, chord)
        weight = weight * (1 + (4 - distance) / 4)

        -- Tension management
        -- When tension is high, favor returning to tonic
        if tension > 0.6 and chord.func == FUNCTION_TONIC and chord.degree == 1 then
            weight = weight * 2
        end

        -- Adventure level modifies predictability
        if adventureLevel > 0.5 then
            -- More adventurous = flatten weights a bit
            weight = weight * (0.5 + math.random() * adventureLevel)
        end

        weights[i] = math.max(weight, 1)  -- Minimum weight of 1
    end

    return weights
end

-- Select next chord using weighted random selection
local function selectWeightedChord(chords, weights)
    local total = 0
    for _, w in ipairs(weights) do
        total = total + w
    end

    local rand = math.random() * total
    local cumulative = 0

    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if rand <= cumulative then
            return chords[i]
        end
    end

    return chords[1]  -- Fallback
end

-- Generate chord progression
local function generateProgression(keyRoot, isMinor, length, adventureLevel)
    local chords = isMinor and getMinorDiatonicChords(keyRoot) or getMajorDiatonicChords(keyRoot)
    local progression = {}

    -- Start with tonic
    local currentChord = chords[1]
    table.insert(progression, currentChord)

    local tension = 0

    for i = 2, length do
        -- Update tension based on current function
        if currentChord.func == FUNCTION_DOMINANT then
            tension = tension + 0.2
        elseif currentChord.func == FUNCTION_TONIC then
            tension = math.max(0, tension - 0.3)
        end

        -- Special case: last chord should resolve to tonic
        if i == length then
            currentChord = chords[1]
        else
            local weights = getNextChordWeights(currentChord, chords, tension, adventureLevel)
            currentChord = selectWeightedChord(chords, weights)
        end

        table.insert(progression, currentChord)
    end

    return progression
end

-- ============================================================================
-- VOICE LEADING ALGORITHM
-- ============================================================================

-- Generate all possible voicings for a chord within range
local function generateVoicings(chord, minNote, maxNote)
    local intervals = CHORD_TYPES[chord.quality]
    if not intervals then return {} end

    local voicings = {}

    -- Try different bass notes (root positions and inversions)
    for bassOctave = 2, 4 do  -- C2 to C4 range for bass
        local bassNote = chord.root + (bassOctave * 12)

        if bassNote >= minNote and bassNote <= maxNote - 12 then
            -- For each bass note, try different voicing configurations
            for _, inversion in ipairs(intervals) do
                local voicing = {}

                -- Bass note (may be inverted)
                local bass = bassNote + inversion
                if bass < minNote then bass = bass + 12 end
                if bass > maxNote then break end

                table.insert(voicing, bass)

                -- Add remaining chord tones above bass
                for _, interval in ipairs(intervals) do
                    local note = chord.root + 12 * 3 + interval  -- Start from C3 area

                    -- Adjust octave to be above bass
                    while note <= bass do
                        note = note + 12
                    end

                    -- Keep in range
                    if note > maxNote then
                        note = note - 12
                    end

                    if note >= minNote and note <= maxNote and note ~= bass then
                        local alreadyHas = false
                        for _, existing in ipairs(voicing) do
                            if existing == note then
                                alreadyHas = true
                                break
                            end
                        end
                        if not alreadyHas then
                            table.insert(voicing, note)
                        end
                    end
                end

                -- Sort voicing low to high
                table.sort(voicing)

                -- Only keep voicings with 3+ notes
                if #voicing >= 3 then
                    table.insert(voicings, voicing)
                end
            end
        end
    end

    return voicings
end

-- Calculate voice leading cost between two voicings
local function calculateVoiceLeadingCost(voicing1, voicing2)
    if not voicing1 then return 0 end

    local cost = 0
    local numVoices = math.max(#voicing1, #voicing2)

    -- Calculate total semitone movement
    for i = 1, numVoices do
        local note1 = voicing1[i] or voicing1[#voicing1]
        local note2 = voicing2[i] or voicing2[#voicing2]
        local movement = math.abs(note2 - note1)

        -- Penalize large leaps
        if movement > 7 then
            cost = cost + movement * 2
        else
            cost = cost + movement
        end
    end

    -- Penalize spacing issues
    for i = 2, #voicing2 do
        local interval = voicing2[i] - voicing2[i-1]
        if interval < 2 then  -- Too close
            cost = cost + 10
        elseif interval > 12 and i < 3 then  -- Too wide in lower voices
            cost = cost + 5
        end
    end

    return cost
end

-- Find optimal voicing for chord given previous voicing
local function findOptimalVoicing(chord, previousVoicing, minNote, maxNote)
    local voicings = generateVoicings(chord, minNote, maxNote)

    if #voicings == 0 then
        -- Fallback: simple root position
        return {chord.root + 36, chord.root + 40, chord.root + 43}  -- C3 area
    end

    if not previousVoicing then
        -- First chord: use a balanced mid-range voicing
        local bestVoicing = voicings[1]
        local bestAvg = 999

        for _, voicing in ipairs(voicings) do
            local avg = 0
            for _, note in ipairs(voicing) do
                avg = avg + note
            end
            avg = avg / #voicing

            local targetAvg = (minNote + maxNote) / 2
            if math.abs(avg - targetAvg) < math.abs(bestAvg - targetAvg) then
                bestAvg = avg
                bestVoicing = voicing
            end
        end

        return bestVoicing
    end

    -- Find voicing with minimal voice leading cost
    local bestVoicing = voicings[1]
    local bestCost = calculateVoiceLeadingCost(previousVoicing, voicings[1])

    for i = 2, #voicings do
        local cost = calculateVoiceLeadingCost(previousVoicing, voicings[i])
        if cost < bestCost then
            bestCost = cost
            bestVoicing = voicings[i]
        end
    end

    return bestVoicing
end

-- ============================================================================
-- MIDI GENERATION
-- ============================================================================

-- Get note name from MIDI number
local function getNoteName(midiNote)
    local noteNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    return noteNames[(midiNote % 12) + 1]
end

-- Build chord name with note and quality
local function buildChordName(chord)
    local noteName = getNoteName(chord.root)
    local quality = ""

    if chord.quality == "minor" then
        quality = "m"
    elseif chord.quality == "diminished" then
        quality = "°"
    elseif chord.quality == "dominant7" then
        quality = "7"
    elseif chord.quality == "minor7" then
        quality = "m7"
    elseif chord.quality == "major7" then
        quality = "maj7"
    end

    return noteName .. quality
end

-- Create MIDI item with chord progression
local function createMIDIItem(track, progression, voicings, startTime, keyName, isMinor)
    -- Get time signature and calculate measure length
    local time_sig_num, time_sig_denom = reaper.TimeMap_GetTimeSigAtTime(0, startTime)
    local qn_per_measure = (4 / time_sig_denom) * time_sig_num
    local tempo = reaper.TimeMap2_GetDividedBpmAtTime(0, startTime)
    local measure_length = (60 / tempo) * qn_per_measure

    -- Calculate total item length
    local total_length = #progression * measure_length
    local item = reaper.CreateNewMIDIItemInProj(track, startTime, startTime + total_length)
    local take = reaper.GetActiveTake(item)

    if not take then return end

    -- Set item name
    local modeName = isMinor and " minor" or " major"
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", keyName .. modeName .. " progression", true)

    -- PPQ constant (standard MIDI resolution)
    local PPQ = 960
    local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, startTime)
    local measure_len_ppq = qn_per_measure * PPQ

    -- Add MIDI notes and take markers
    for i, voicing in ipairs(voicings) do
        local measure_start_ppq = start_ppq + (i - 1) * measure_len_ppq
        local measure_end_ppq = measure_start_ppq + measure_len_ppq
        local chordStartTime = startTime + (i - 1) * measure_length

        -- Add each note in the voicing
        for _, midiNote in ipairs(voicing) do
            reaper.MIDI_InsertNote(
                take,
                false,  -- selected
                false,  -- muted
                measure_start_ppq,
                measure_end_ppq,
                0,      -- channel
                midiNote,
                80,     -- velocity
                true    -- noSortIn
            )
        end
    end

    -- Add take markers for all chords after notes are inserted
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    for i, chord in ipairs(progression) do
        local measure_start_ppq = start_ppq + (i - 1) * measure_len_ppq
        local chordNoteName = buildChordName(chord)
        local markerName = chord.name .. ": " .. chordNoteName
        -- Convert PPQ to project time, then to take-relative seconds
        local projTime = reaper.MIDI_GetProjTimeFromPPQPos(take, measure_start_ppq)
        local takePosSeconds = projTime - itemStart
        if takePosSeconds < 0 then takePosSeconds = 0 end
        -- Append a new take marker at this position
        reaper.SetTakeMarker(take, -1, markerName, takePosSeconds, 0)
    end

    reaper.MIDI_Sort(take)
    reaper.UpdateItemInProject(item)

    return item
end-- ============================================================================
-- USER INTERFACE
-- ============================================================================

-- Dialog helpers (match Melody Generator style)
local NOTE_MENU_NAMES = {"C","C#/Db","D","D#/Eb","E","F","F#/Gb","G","G#/Ab","A","A#/Bb","B"}
local NOTE_DISPLAY_TO_PC = { ["C"]=0,["C#/Db"]=1,["D"]=2,["D#/Eb"]=3,["E"]=4,["F"]=5,["F#/Gb"]=6,["G"]=7,["G#/Ab"]=8,["A"]=9,["A#/Bb"]=10,["B"]=11 }

local function show_popup_menu(items, default_idx)
    local menu_str = ""
    for i, item in ipairs(items) do
        if i == default_idx then
            menu_str = menu_str .. "!" .. item .. "|"
        else
            menu_str = menu_str .. item .. "|"
        end
    end
    gfx.x, gfx.y = reaper.GetMousePosition()
    return gfx.showmenu(menu_str)
end

local function getUserInput()
    -- Defaults from ExtState
    local def_root_pc = tonumber(get_ext('root_pc', 0)) or 0
    local def_is_minor = get_ext('is_minor', '0') == '1'
    local def_length = tonumber(get_ext('length', 8)) or 8
    local def_adventure = tonumber(get_ext('adventure', 0.5)) or 0.5

    -- Step 0: Mode selection
    local mode_items = {"Auto (use last settings)", "Random (pick key + quality)", "Manual (configure settings)"}
    local mode_choice = show_popup_menu(mode_items, 1)
    if mode_choice == 0 then return nil end

    -- AUTO mode: use last settings
    if mode_choice == 1 then
        local keyRoot = def_root_pc
        local isMinor = def_is_minor
        local length = math.max(4, math.min(16, def_length))
        local adventure = math.max(0, math.min(1, def_adventure))
        local keyName = KEY_NAMES[(keyRoot % 12) + 1]

        return { keyRoot = keyRoot, isMinor = isMinor, keyName = keyName, length = length, adventure = adventure }
    end

    -- RANDOM mode: pick random key root and quality, then prompt for length/adventure
    if mode_choice == 2 then
        -- Seed RNG for better randomness
        if reaper and reaper.time_precise then math.randomseed(reaper.time_precise()) else math.randomseed(os.time()) end
        for _=1,3 do math.random() end

        local keyRoot = math.random(0, 11)
        local isMinor = (math.random() < 0.5)

        local retval, user_input = reaper.GetUserInputs(
            "jtp gen: Smart Chord Progression Generator",
            2,
            "Progression length (4-16),Adventure level (0.0-1.0),extrawidth=200",
            string.format("%d,%.2f", def_length, def_adventure)
        )
        if not retval then return nil end

        local lengthStr, adventureStr = user_input:match("([^,]+),([^,]+)")
        local length = tonumber(lengthStr) or def_length
        local adventure = tonumber(adventureStr) or def_adventure
        length = math.max(4, math.min(16, length))
        adventure = math.max(0, math.min(1, adventure))

        -- Persist selections for next Auto
        set_ext('root_pc', keyRoot)
        set_ext('is_minor', isMinor and '1' or '0')
        set_ext('length', length)
        set_ext('adventure', adventure)

        local keyName = KEY_NAMES[(keyRoot % 12) + 1]
        return { keyRoot = keyRoot, isMinor = isMinor, keyName = keyName, length = length, adventure = adventure }
    end

    -- MANUAL mode
    -- Step 1: Root note (pitch class only)
    local root_default_idx = (def_root_pc % 12) + 1
    local root_choice = show_popup_menu(NOTE_MENU_NAMES, root_default_idx)
    if root_choice == 0 then return nil end
    local root_name = NOTE_MENU_NAMES[root_choice]
    local keyRoot = NOTE_DISPLAY_TO_PC[root_name] or 0

    -- Step 2: Quality (Major/Minor)
    local qual_items = {"Major", "Minor"}
    local qual_default = def_is_minor and 2 or 1
    local qual_choice = show_popup_menu(qual_items, qual_default)
    if qual_choice == 0 then return nil end
    local isMinor = (qual_choice == 2)

    -- Step 3: Other params (length, adventure)
    local retval, user_input = reaper.GetUserInputs(
        "jtp gen: Smart Chord Progression Generator",
        2,
        "Progression length (4-16),Adventure level (0.0-1.0),extrawidth=200",
        string.format("%d,%.2f", def_length, def_adventure)
    )
    if not retval then return nil end

    local lengthStr, adventureStr = user_input:match("([^,]+),([^,]+)")
    local length = tonumber(lengthStr) or def_length
    local adventure = tonumber(adventureStr) or def_adventure
    length = math.max(4, math.min(16, length))
    adventure = math.max(0, math.min(1, adventure))

    -- Persist selections
    set_ext('root_pc', keyRoot)
    set_ext('is_minor', isMinor and '1' or '0')
    set_ext('length', length)
    set_ext('adventure', adventure)

    -- Choose display key name (prefer KEY_NAMES mapping)
    local keyName = KEY_NAMES[(keyRoot % 12) + 1]

    return { keyRoot = keyRoot, isMinor = isMinor, keyName = keyName, length = length, adventure = adventure }
end

-- ============================================================================
-- MAIN
-- ============================================================================

function main()
    -- Get user input
    local params = getUserInput()
    if not params then return end

    -- Seed random
    math.randomseed(os.time())

    -- Get selected track or create new one
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.InsertTrackAtIndex(0, true)
        track = reaper.GetTrack(0, 0)
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "Chord Progression", true)
    end

    reaper.Undo_BeginBlock()

    -- Generate progression
    local progression = generateProgression(
        params.keyRoot,
        params.isMinor,
        params.length,
        params.adventure
    )

    -- Generate voicings with voice leading
    local voicings = {}
    local previousVoicing = nil
    local minNote = 48  -- C3
    local maxNote = 72  -- C5

    for _, chord in ipairs(progression) do
        local voicing = findOptimalVoicing(chord, previousVoicing, minNote, maxNote)
        table.insert(voicings, voicing)
        previousVoicing = voicing
    end

    -- Create MIDI item
    local cursorPos = reaper.GetCursorPosition()
    createMIDIItem(track, progression, voicings, cursorPos, params.keyName, params.isMinor)

    -- Result: console output disabled as requested

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("jtp gen: Generate Smart Chord Progression", -1)
end

main()
