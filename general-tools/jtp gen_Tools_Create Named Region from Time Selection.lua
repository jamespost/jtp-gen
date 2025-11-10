-- @description jtp gen: Create Named Region from Time Selection
-- @author James
-- @version 1.0
-- @about
--   # Create Named Region from Time Selection
--
--   ## Description
--   Creates a region from the current time selection with a procedurally
--   generated unique name and color. The name is composed of an adjective,
--   a noun, and a number. Each region gets a unique color based
--   on a seeded random algorithm.
--
--   ## Usage
--   1. Make a time selection in the REAPER timeline
--   2. Run this script
--   3. A region will be created with a unique name and color
--
--   ## Notes
--   - Requires a time selection to be active
--   - Region names follow the pattern: [Adjective] [Noun] [Number]
--   - Colors are generated using HSV color space for visual variety

-- Check if reaper API is available
if not reaper then
    return
end

-- Configuration
local CONFIG = {
    debug = false,  -- Set to true to enable console logging
    adjectives = {
        "Ancient", "Azure", "Blazing", "Broken", "Buried", "Burning",
        "Cascading", "Celestial", "Coiled", "Crimson", "Crystal", "Drifting",
        "Echo", "Ember", "Endless", "Fading", "Flickering", "Floating",
        "Forgotten", "Fractured", "Frozen", "Ghost", "Gilded", "Glass",
        "Golden", "Hollow", "Horizon", "Infinite", "Iron", "Jade",
        "Liquid", "Lost", "Lunar", "Marble", "Mirrored", "Misty",
        "Molten", "Neon", "Obsidian", "Pale", "Paper", "Phantom",
        "Prismatic", "Quantum", "Radiant", "Rusted", "Sacred", "Scarlet",
        "Shadow", "Shattered", "Shifting", "Silent", "Silver", "Smoke",
        "Soft", "Solar", "Spectral", "Spiral", "Static", "Steel",
        "Stone", "Temporal", "Tilted", "Torn", "Twisted", "Vapor",
        "Velvet", "Violet", "Void", "Waning", "Woven", "Zenith"
    },
    nouns = {
        "Abyss", "Altar", "Anchor", "Archive", "Atlas", "Beacon",
        "Bloom", "Canyon", "Canvas", "Chamber", "Cipher", "Circuit",
        "Citadel", "Cloud", "Comet", "Compass", "Constellation", "Corridor",
        "Crest", "Crown", "Cube", "Current", "Dawn", "Delta",
        "Dune", "Eclipse", "Edge", "Epoch", "Fable", "Forge",
        "Fragment", "Garden", "Gate", "Glacier", "Glyph", "Grid",
        "Harbor", "Helix", "Horizon", "Island", "Labyrinth", "Lattice",
        "Lens", "Lighthouse", "Mantle", "Maze", "Mesa", "Mirror",
        "Monument", "Nebula", "Nexus", "Obelisk", "Ocean", "Oracle",
        "Orbit", "Palace", "Paradox", "Peak", "Pendulum", "Pillar",
        "Pinnacle", "Plateau", "Portal", "Prism", "Pyramid", "Reef",
        "Relic", "Ridge", "River", "Sanctum", "Shard", "Shrine",
        "Singularity", "Spire", "Summit", "Temple", "Threshold", "Tower",
        "Trail", "Vault", "Veil", "Vertex", "Vessel", "Vista",
        "Vortex", "Wave", "Well", "Window", "Zenith", "Zone"
    }
}

-- Helper functions
local function log(message)
    if CONFIG.debug then
        reaper.ShowConsoleMsg(tostring(message) .. "\n")
    end
end

-- Generate a seed from the current timestamp and project state
local function generateSeed()
    local time = reaper.time_precise()
    local num_regions = reaper.CountProjectMarkers(0)
    -- Combine time with project state for unique seed
    return math.floor((time * 1000000) % 2147483647) + num_regions
end

-- Simple random number generator using seed
local function seededRandom(seed, min, max)
    -- Linear congruential generator
    seed = (seed * 1103515245 + 12345) % 2147483648
    local normalized = seed / 2147483648
    if min and max then
        return math.floor(normalized * (max - min + 1)) + min, seed
    end
    return normalized, seed
end

-- Convert HSV to RGB
local function hsvToRgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end

    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- Generate a unique color using HSV color space
local function generateUniqueColor(seed)
    -- Use golden ratio for hue to get visually distinct colors
    local golden_ratio = 0.618033988749895
    local hue, new_seed = seededRandom(seed, 0, 1000)
    hue = (hue / 1000 + golden_ratio) % 1.0

    -- Keep saturation and value high for vibrant colors
    local saturation = 0.7 + (seededRandom(new_seed, 0, 30) / 100)
    local value = 0.85 + (seededRandom(new_seed * 2, 0, 15) / 100)

    local r, g, b = hsvToRgb(hue, saturation, value)
    return reaper.ColorToNative(r, g, b) | 0x1000000
end

-- Generate a unique name
local function generateUniqueName(seed)
    local adj_index, new_seed = seededRandom(seed, 1, #CONFIG.adjectives)
    local noun_index, newer_seed = seededRandom(new_seed, 1, #CONFIG.nouns)

    local adjective = CONFIG.adjectives[adj_index]
    local noun = CONFIG.nouns[noun_index]

    -- Get count of existing regions for numbering
    local num_regions = 0
    local num_markers, num_regions_count = reaper.CountProjectMarkers(0)

    -- Count actual regions (not markers)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if isrgn then
            num_regions = num_regions + 1
        end
    end

    local number = num_regions + 1

    return string.format("%s %s %02d", adjective, noun, number)
end

-- Main script logic
function main()
    -- Check if there's a time selection
    local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    if start_time == end_time then
        reaper.ShowMessageBox(
            "Please make a time selection first.",
            "jtp gen: No Time Selection",
            0
        )
        return
    end

    -- Begin undo block
    reaper.Undo_BeginBlock()

    -- Generate unique seed
    local seed = generateSeed()

    -- Generate unique name and color
    local region_name = generateUniqueName(seed)
    local region_color = generateUniqueColor(seed * 2)

    -- Create the region
    local region_index = reaper.AddProjectMarker2(
        0,              -- project
        true,           -- isrgn (true for region)
        start_time,     -- pos
        end_time,       -- rgnend
        region_name,    -- name
        -1,             -- wantidx (-1 = auto-assign)
        region_color    -- color
    )

    log("Created region: " .. region_name)
    log("Time range: " .. string.format("%.3f - %.3f", start_time, end_time))

    -- Update the arrange view
    reaper.UpdateArrange()

    -- End undo block with descriptive name
    reaper.Undo_EndBlock("jtp gen: Create Named Region", -1)
end

-- Run the script
main()
