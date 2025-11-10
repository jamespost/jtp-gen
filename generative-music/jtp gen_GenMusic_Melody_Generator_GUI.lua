-- @description jtp gen: Advanced Melody Generator with GUI
-- @author James
-- @version 1.0
-- @about
--   # jtp gen: Advanced Melody Generator with GUI
--   Generates a MIDI melody with a user interface for controlling generation parameters.
--   Requires the js_ReaScriptAPI extension for the GUI.

-- Check for REAPER and js_ReaScriptAPI
if not reaper or not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("This script requires the 'js_ReaScriptAPI' extension.\nPlease install it to use this script.", "Missing Dependency", 0)
    return
end

local ImGui = reaper.ImGui_CreateContext('Melody Generator')

-- Default User Settings Table
local settings = {
    measures = 8,
    start_of_measure_note_chance = 0.4,
    beat_note_chance = 0.5,
    sub_beat_note_chance = 0.5,
    quarter_note_chance = 0.66,
    eighth_note_chance = 0.6,
    big_jump_chance = 0.1,
    big_jump_interval = 4,
    max_repeated_notes = 0,
    note_variety_threshold = 0.99,
    rest_probability = 0.8,
    legato_probability = 0.9,
    short_note_end_probability = 0.0,
    same_last_note_probability = 0.5,
    velocity_16th_min = 40,
    velocity_16th_max = 60,
    velocity_8th_min = 50,
    velocity_8th_max = 70,
    velocity_quarter_min = 60,
    velocity_quarter_max = 90,
    velocity_half_min = 80,
    velocity_half_max = 100,
    min_num_notes = 3,
    max_num_notes = 7,
    min_keep_notes = 12,
    max_keep_notes = 24,
    root_note = 60,
    scale_idx = 1,
    generate_button = false
}

-- Store settings as ImGui value holders
local vals = {
    reaper.ImGui_Int(settings.measures),
    reaper.ImGui_SliderFloat(settings.start_of_measure_note_chance, 0, 1),
    reaper.ImGui_SliderFloat(settings.beat_note_chance, 0, 1),
    reaper.ImGui_SliderFloat(settings.sub_beat_note_chance, 0, 1),
    reaper.ImGui_SliderFloat(settings.quarter_note_chance, 0, 1),
    reaper.ImGui_SliderFloat(settings.eighth_note_chance, 0, 1),
    reaper.ImGui_SliderFloat(settings.big_jump_chance, 0, 1),
    reaper.ImGui_Int(settings.big_jump_interval),
    reaper.ImGui_Int(settings.max_repeated_notes),
    reaper.ImGui_SliderFloat(settings.note_variety_threshold, 0, 1),
    reaper.ImGui_SliderFloat(settings.rest_probability, 0, 1),
    reaper.ImGui_SliderFloat(settings.legato_probability, 0, 1),
    reaper.ImGui_SliderFloat(settings.short_note_end_probability, 0, 1),
    reaper.ImGui_SliderFloat(settings.same_last_note_probability, 0, 1),
    reaper.ImGui_Int(settings.velocity_16th_min),
    reaper.ImGui_Int(settings.velocity_16th_max),
    reaper.ImGui_Int(settings.velocity_8th_min),
    reaper.ImGui_Int(settings.velocity_8th_max),
    reaper.ImGui_Int(settings.velocity_quarter_min),
    reaper.ImGui_Int(settings.velocity_quarter_max),
    reaper.ImGui_Int(settings.velocity_half_min),
    reaper.ImGui_Int(settings.velocity_half_max),
    reaper.ImGui_Int(settings.min_num_notes),
    reaper.ImGui_Int(settings.max_num_notes),
    reaper.ImGui_Int(settings.min_keep_notes),
    reaper.ImGui_Int(settings.max_keep_notes),
    reaper.ImGui_Int(settings.root_note),
    reaper.ImGui_Int(settings.scale_idx)
}

-- Scales table
local scales = {
    --3_note_scales = {},
    chromatic_trimirror = {0, 1, 2},
    do_re_mi = {0, 2, 4},
    flat_6_and_7 = {0, 10, 11},
    major_flat_6 = {0, 4, 8},
    major_triad_1 = {0, 3, 8},
    major_triad_2 = {0, 4, 7},
    major_triad_3 = {0, 5, 9},
    messiaen_3rd_mode = {0, 4, 8},
    minor_triad_1 = {0, 4, 9},
    minor_triad_2 = {0, 3, 7},
    minor_triad_3 = {0, 5, 8},
    minor_trichord = {0, 2, 3},
    phrygian_trichord = {0, 1, 3},
    sanagari_1 = {0, 5, 10},
    ute_tritone_1 = {0, 3, 10},
    --4_note_scales = {},
    alternating_tetramirror_1 = {0, 1, 3, 4},
    bi_yu = {0, 3, 7, 10},
    chromatic_tetramirror_1 = {0, 1, 2, 3},
    diminished_7th_chord = {0, 3, 6, 9},
    dorian_tetrachord = {0, 2, 3, 5},
    eskimo_tetratonic = {0, 2, 4, 7},
    genus_primum_inverse = {0, 5, 7, 10},
    har_minor_tetrachord_1 = {0, 2, 3, 6},
    major_tetrachord_1 = {0, 4, 7, 10},
    major_tetrachord_2 = {0, 4, 7, 11},
    major_tetrachord_3 = {0, 2, 5, 10},
    major_tetrachord_4 = {0, 5, 7, 9},
    major_tetrachord_5 = {0, 4, 7, 10},
    major_tetrachord_6 = {0, 2, 6, 9},
    major_tetrachord_7 = {0, 3, 5, 9},
    major_tetrachord_8 = {0, 5, 7, 10},
    major_tetrachord_9 = {0, 3, 6, 8},
    major_tetrachord_10 = {0, 2, 5, 7},
    major_tetrachord_11 = {0, 2, 4, 5},
    sixth_tetrachord_1 = {0, 4, 7, 9},
    sixth_tetrachord_2 = {0, 2, 5, 9},
    sixth_tetrachord_3 = {0, 3, 6, 9},
    minor_seventh_chord = {0, 3, 7, 10},
    phrygian_tetrachord = {0, 1, 3, 5},
    warao_minor_trichord = {0, 2, 3, 10},
    wholetone_tetramirror = {0, 2, 4, 6},
    --5_note_scales = {},
    sus_4_pentatonic = {0, 2, 5, 7, 10},
    m3_mj_pentatonic = {0, 3, 5, 8, 10},
    chinese_6_pentatonic = {0, 4, 6, 7, 11},
    han_kumoi = {0, 2, 5, 7, 8},
    inscale = {0, 1, 5, 7, 8},
    yo = {0, 2, 5, 7, 9},
    indonesian_2_pentatonic = {0, 1, 6, 7, 8},
    indonesian_3_pentatonic = {0, 4, 5, 7, 11},
    no_name = {0, 1, 4, 7, 9},
    altered_pentatonic = {0, 1, 5, 7, 9},
    balinese_pentachord_1 = {0, 1, 4, 6, 7},
    blues_sharpv = {0, 3, 5, 6, 11},
    blues_pentacluster_1 = {0, 1, 2, 3, 6},
    blues_pentacluster_3 = {0, 1, 2, 3, 5},
    blues_pentacluster_5 = {0, 1, 2, 3},
    bluessharpv_all_flats = {0, 3, 5, 6, 11},
    centercluster_pentamirror = {0, 3, 4, 5, 8},
    chaio_1 = {0, 2, 5, 8, 10},
    chromatic_pentamirror = {0, 1, 2, 3, 4},
    dominant_pentatonic = {0, 2, 4, 7, 10},
    half_diminished_plus_b8 = {0, 3, 6, 10, 11},
    hirajoshi = {0, 2, 3, 7, 8},
    iwato = {0, 1, 5, 6, 10},
    japanese_pentachord_1 = {0, 1, 3, 6, 7},
    kokin_joshi = {0, 1, 5, 7, 10},
    kumoi_scale = {0, 2, 3, 7, 9},
    kung = {0, 2, 4, 6, 9},
    locrian_pentamirror = {0, 1, 3, 5, 6},
    lydian_pentachord = {0, 2, 4, 6, 7},
    major_pentachord = {0, 2, 4, 5, 7},
    minor_6th_added = {0, 3, 5, 7, 9},
    minor_pentachord_chad_g = {0, 2, 3, 5, 7},
    mixolydian_pentatonic_1 = {0, 4, 5, 7, 10},
    oriental_pentacluster_1 = {0, 1, 2, 5, 6},
    oriental_raga_guhamano = {0, 2, 5, 9, 10},
    pelog = {0, 1, 3, 7, 8},
    romanian_bacovia_1 = {0, 4, 5, 8, 11},
    slendro = {0, 2, 5, 7, 9},
    spanish_pentacluster_1 = {0, 1, 3, 4, 5},
    major_pentatonic = {0, 2, 4, 7, 9},
    minor_pentatonic = {0, 3, 5, 7, 10},
    --6_note_scales = {},
    sus_4 = {0, 2, 5, 7, 9, 10},
    augmented_messiaen = {0, 3, 4, 7, 8, 11},
    blues_dorian_hexatonic_1 = {0, 2, 3, 4, 7, 9},
    blues_dorian_hexatonic_2 = {0, 1, 3, 4, 7, 9},
    blues_minor_all_flats = {0, 3, 5, 6, 7, 10},
    blues_minor_maj7 = {0, 3, 5, 6, 7, 11},
    chromatic_hexamirror_all_sharp = {0, 1, 2, 3, 4, 5},
    double_phrygian_hexatonic = {0, 1, 3, 5, 6, 9},
    eskimo_hexatonic_1 = {0, 2, 4, 6, 8, 9},
    genus_secundum = {0, 4, 5, 7, 9, 11},
    hawaiian = {0, 2, 3, 7, 9, 11},
    honchoshi_plagal_form = {0, 1, 3, 5, 6, 10},
    lydian_sharp2_hexatonic = {0, 3, 4, 7, 9, 11},
    lydian_hexatonic = {0, 2, 4, 7, 9, 11},
    major_bebop_hexatonic = {0, 2, 4, 7, 8, 9},
    major_blues_alternate = {0, 2, 3, 4, 7, 9},
    minor_hexatonic = {0, 2, 3, 5, 7, 10},
    phrygian_hexatonic = {0, 3, 5, 7, 8, 10},
    prometheus = {0, 2, 4, 6, 8, 10},
    prometheus_neopolitan = {0, 1, 4, 6, 8, 10},
    pyramid_hexatonic = {0, 2, 3, 5, 6, 9},
    ritsu = {0, 1, 3, 5, 8, 10},
    sixtone_mode_1 = {0, 3, 4, 7, 8, 11},
    scottish_hexatonic_arezzo = {0, 2, 4, 5, 7, 9},
    takemitsu_tree_line_mod_1 = {0, 2, 3, 6, 8, 10},
    whole_tone = {0, 2, 4, 6, 8, 10},
    blues = {0, 3, 5, 6, 7, 10},
    --7_note_scales = {},
    ionian_augmented = {0, 2, 4, 5, 8, 9, 11},
    dorian_sharp4 = {0, 2, 3, 6, 7, 9, 10},
    mixolydian_b9b13 = {0, 1, 4, 5, 7, 8, 10},
    lydian_sharp9 = {0, 3, 4, 6, 7, 9, 11},
    alt_dominant_bb7 = {0, 1, 3, 4, 5, 8, 9},
    dorian_b2 = {0, 1, 3, 5, 7, 9, 10},
    lydian_aug = {0, 2, 4, 6, 8, 9, 11},
    lydian_b7 = {0, 2, 4, 6, 7, 9, 10},
    mixolydian_b13 = {0, 2, 4, 5, 7, 8, 10},
    locrian_nat_9 = {0, 2, 3, 5, 6, 8, 10},
    alt_dominant = {0, 1, 3, 4, 6, 8, 10},
    locrian_nat_6 = {0, 1, 3, 5, 6, 9, 10},
    hungarian_folk = {0, 1, 4, 5, 7, 8, 11},
    purvi = {0, 1, 4, 6, 7, 8, 11},
    todi = {0, 1, 3, 6, 7, 8, 11},
    saba = {0, 2, 3, 4, 7, 8, 10},
    spanish_dominant = {0, 1, 3, 6, 7, 8, 10},
    smyrneiko = {0, 2, 3, 6, 7, 9, 11},
    mixolydian_b9 = {0, 1, 4, 5, 7, 9, 10},
    major_locrian = {0, 2, 4, 5, 6, 8, 10},
    lydian_minor = {0, 2, 4, 6, 7, 8, 10},
    leading_wholetone = {0, 2, 4, 6, 8, 10, 11},
    oriental_no1 = {0, 1, 4, 5, 6, 8, 10},
    neopolitan_major = {0, 1, 3, 5, 7, 9, 11},
    neopolitan_minor = {0, 1, 3, 5, 7, 8, 11},
    aeolian_2sharp_4sharp_sharp5 = {0, 3, 4, 6, 8, 9, 11},
    bhairubahar_thaat = {0, 1, 4, 5, 7, 9, 11},
    blues_heptatonic = {0, 3, 5, 6, 7, 9, 10},
    blues_modified = {0, 2, 3, 5, 6, 7, 10},
    blues_phrygian_1 = {0, 1, 3, 5, 6, 7, 10},
    blues_with_leading_tone = {0, 3, 5, 6, 7, 10, 11},
    chromatic_dorian = {0, 1, 2, 5, 7, 8, 9},
    chromatic_heptamirror = {0, 1, 2, 3, 4, 5, 6},
    chromatic_hypodorian_1 = {0, 2, 3, 4, 7, 8, 9},
    chromatic_hypophrygian = {0, 1, 2, 5, 6, 7, 9},
    chromatic_lydian = {0, 1, 4, 5, 6, 9, 11},
    chromatic_mixolydian_1 = {0, 1, 2, 4, 6, 7, 10},
    chromatic_phrygian = {0, 3, 4, 5, 8, 10, 11},
    composite_blues = {0, 3, 4, 5, 6, 7, 10},
    dorian_b5 = {0, 2, 3, 5, 6, 9, 10},
    enigmatic = {0, 1, 4, 6, 8, 10, 11},
    enigmatic_minor = {0, 1, 3, 6, 8, 10, 11},
    pelog_alternate = {0, 4, 6, 7, 8, 11},
    gipsy_hexatonic_1 = {0, 1, 5, 6, 8, 9, 10},
    gypsy_hexatonic_5 = {0, 1, 4, 5, 7, 8, 9},
    hindi_5_flats = {0, 1, 3, 4, 6, 8, 10},
    houzam = {0, 3, 4, 5, 7, 9, 11},
    hungarian_gypsy_1 = {0, 2, 3, 6, 7, 8, 10},
    hungarian_major = {0, 3, 4, 6, 7, 9, 10},
    phrygian_dim_4th = {0, 1, 3, 4, 7, 8, 10},
    jazz_minor_inverse = {0, 1, 3, 5, 7, 9, 10},
    locrian_2 = {0, 2, 3, 5, 6, 8, 11},
    locrian_bb7 = {0, 1, 3, 5, 6, 8, 9},
    lydian_augmented_2 = {0, 1, 3, 4, 6, 8, 10},
    marva_or_marvi = {0, 1, 4, 6, 7, 9, 11},
    major_bebop_heptatonic = {0, 2, 4, 5, 7, 8, 9},
    minor_bebop_1 = {0, 2, 3, 4, 7, 9, 10},
    mixolydian_augmented = {0, 2, 4, 5, 8, 9, 10},
    mixolydian_b5 = {0, 2, 4, 5, 6, 9, 10},
    neapolitan_minor_mode = {0, 1, 2, 4, 6, 8, 9},
    nohkan_1 = {0, 2, 5, 6, 8, 9, 11},
    persian = {0, 1, 4, 5, 6, 8, 11},
    rock_n_roll_1 = {0, 3, 4, 5, 7, 9, 10},
    romanian_major = {0, 1, 4, 6, 7, 9, 10},
    sabach_1 = {0, 2, 3, 4, 7, 8, 10},
    spanish_heptatonic_1 = {0, 3, 4, 5, 6, 8, 10},
    super_locrian_all_sharps = {0, 1, 3, 4, 6, 8, 10},
    todi_b7_1 = {0, 1, 3, 6, 7, 9, 10},
    ultra_locrian_1 = {0, 1, 3, 4, 6, 8, 9},
    major = {0, 2, 4, 5, 7, 9, 11},
    dorian = {0, 2, 3, 5, 7, 9, 10},
    phrygian = {0, 1, 3, 5, 7, 8, 10},
    lydian = {0, 2, 4, 6, 7, 9, 11},
    mixolydian = {0, 2, 4, 5, 7, 9, 10},
    minor = {0, 2, 3, 5, 7, 8, 10},
    locrian = {0, 1, 3, 5, 6, 8, 10},
    harmonic_minor = {0, 2, 3, 5, 7, 8, 11},
    harmonic_major = {0, 2, 4, 5, 7, 8, 11},
    melodic_minor = {0, 2, 3, 5, 7, 9, 11},
    --8_note_scales = {},
    dorian_bebop = {0, 2, 3, 4, 5, 7, 9, 11},
    adonai_malakh_1 = {0, 1, 2, 3, 5, 7, 9, 10},
    algerian = {0, 2, 3, 5, 6, 7, 8, 11},
    auxillary_diminished = {0, 2, 3, 5, 6, 8, 9, 11},
    blues_diminished = {0, 1, 3, 4, 6, 7, 9, 10},
    blues_octatonic = {0, 2, 3, 5, 6, 7, 9, 10},
    chromatic_octamirror = {0, 1, 2, 3, 4, 5, 6, 7},
    diminished = {0, 2, 3, 5, 6, 8, 9, 11},
    dorian_aeolian_1 = {0, 2, 3, 5, 7, 8, 9, 10},
    enigmatic_alternate_1 = {0, 1, 4, 5, 6, 8, 10, 11},
    half_dimiished_bebop = {0, 1, 3, 5, 6, 7, 8, 11},
    half_diminished_symmetrrical = {0, 1, 3, 4, 6, 7, 9, 10},
    half_whole_dim = {0, 1, 3, 4, 6, 7, 9, 10},
    harmonic_neapolitan_minor_1 = {0, 1, 2, 3, 5, 7, 8, 11},
    hungarian_minor_b2 = {0, 1, 2, 3, 6, 7, 8, 11},
    japanese = {0, 2, 4, 5, 6, 7, 9, 11},
    jg_octatonic = {0, 1, 3, 4, 5, 7, 9, 10},
    lydian_b3 = {0, 2, 3, 4, 6, 7, 9, 11},
    lydian_dim_b7 = {0, 2, 3, 4, 6, 7, 9, 10},
    lydian_dominant_alternate = {0, 2, 4, 6, 7, 9, 10, 11},
    magen_abot = {0, 1, 3, 4, 6, 8, 9, 11},
    major_bebop = {0, 2, 4, 5, 7, 8, 9, 11},
    maqam_hijaz = {0, 1, 4, 5, 7, 8, 10, 11},
    maqam_shadd_araban_1 = {0, 1, 3, 4, 5, 6, 9, 10},
    minor_bebop_1 = {0, 2, 3, 4, 5, 7, 9, 10},
    minor_gypsy = {0, 2, 3, 6, 7, 8, 10, 11},
    mixolydian_bebop_1 = {0, 2, 4, 5, 7, 9, 10, 11},
    neveseri_1 = {0, 1, 3, 6, 7, 8, 10, 11},
    oriental_2 = {0, 1, 4, 5, 6, 9, 10, 11},
    phrygian_aeolian_1 = {0, 1, 2, 3, 5, 7, 8, 10},
    phrygian_locrian_1 = {0, 1, 3, 5, 6, 7, 8, 10},
    phrygian_major_1 = {0, 1, 3, 4, 5, 7, 8, 10},
    prokofiev_1 = {0, 1, 3, 5, 6, 8, 10, 11},
    shostakovich_1 = {0, 1, 3, 4, 6, 7, 9, 11},
    spanish_8_tones_1 = {0, 1, 3, 4, 5, 6, 8, 10},
    utility_minor_1 = {0, 2, 3, 5, 7, 8, 10, 11},
    whole_half_dim = {0, 2, 3, 5, 6, 8, 9, 11},
    zirafkend = {0, 2, 3, 5, 7, 8, 9, 11},
    --9_note_scales = {},
    blues_enneatonic = {0, 2, 3, 4, 5, 6, 7, 9, 10},
    chromatic_bebop_1 = {0, 1, 2, 4, 5, 7, 9, 10, 11},
    chromatic_diatonic_dorian_1 = {0, 1, 2, 3, 5, 7, 8, 9, 10},
    chromatic_nonamirror = {0, 1, 2, 3, 4, 5, 6, 7, 8},
    chromatic_permuted_diatonic = {0, 1, 2, 4, 5, 7, 8, 9, 11},
    full_minor = {0, 2, 3, 5, 7, 8, 9, 10, 11},
    genus_chromaticum_1 = {0, 1, 3, 4, 5, 7, 8, 9, 11},
    houseini_1 = {0, 2, 3, 4, 5, 7, 9},
    kiourdi = {0, 2, 3, 5, 6, 7, 8, 9, 10},
    lydian_mixolydian_1 = {0, 2, 4, 5, 6, 7, 9, 10, 11},
    moorish_phrygian_1 = {0, 1, 4, 5, 7, 8, 10, 11},
    symmetrical_nonatonic_1 = {0, 1, 2, 4, 6, 7, 8, 10, 11},
    untitled_nonatonic_1 = {0, 1, 2, 3, 5, 6, 7, 8, 9},
    untitled_nonatonic_2 = {0, 1, 3, 4, 5, 6, 7, 9, 10},
    youlan_1 = {0, 1, 2, 4, 5, 6, 7, 9, 10},
    --10_note_scales = {},
    untitled_decatonic_1 = {0, 2, 3, 4, 5, 7, 8, 9, 10, 11},
    untitled_decatonic_2 = {0, 2, 3, 4, 5, 6, 7, 9, 10, 11},
    untitled_decatonic_3 = {0, 1, 3, 4, 5, 6, 7, 8, 10, 11},
    untitled_decatonic_4 = {0, 1, 2, 3, 5, 6, 7, 8, 10, 11},
    untitled_decatonic_5 = {0, 1, 2, 3, 5, 6, 7, 8, 9, 10},
    untitled_decatonic_6 = {0, 1, 2, 4, 5, 6, 7, 9, 10, 11},
    untitled_decatonic_7 = {0, 1, 2, 4, 5, 6, 7, 8, 9, 11},
    untitled_decatonic_8 = {0, 1, 2, 3, 4, 6, 7, 8, 9, 11},
    untitled_decatonic_9 = {0, 1, 2, 3, 4, 5, 7, 8, 9, 10},
    chromatic_decamirror_1 = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
    major__minor_mixed = {0, 2, 3, 4, 5, 7, 8, 9, 10, 11},
    minor_pentatonic_decatonic = {0, 2, 3, 4, 5, 6, 7, 9, 10, 11},
    pan_diminished_blues = {0, 1, 2, 3, 4, 6, 7, 9, 10, 11},
    pan_lydian = {0, 2, 3, 4, 5, 6, 7, 8, 9, 11},
    symmetrical_decatonic = {0, 1, 2, 4, 5, 6, 7, 8, 10, 11},
    --chords_1 = {},
    major_triad = {0, 4, 7},
    minor_triad = {0, 3, 7},
    diminished_triad = {0, 3, 6},
    augmented_triad = {0, 4, 8},
    sus_4_chord = {0, 5, 7},
    sus_2 = {0, 2, 7},
    flat_5 = {0, 4, 6},
    major_7 = {0, 4, 7, 11},
    major_7_sharp5 = {0, 4, 8, 11},
    major_7_b5 = {0, 4, 6, 11},
    dominant_7 = {0, 4, 7, 10},
    dominant_7_sharp5 = {0, 4, 8, 10},
    dominant_7_b5 = {0, 4, 6, 10},
    minor_major_7 = {0, 3, 7, 11},
    dim_major_7 = {0, 3, 6, 11},
    minor_7_b5_chord = {0, 3, 6, 10},
    diminished_7 = {0, 3, 6, 9},
    minor_7 = {0, 3, 7, 10},
    dominant_sus_4 = {0, 5, 7, 10},
    major_sus_4 = {0, 5, 7, 11},
    major_6 = {0, 4, 7, 9},
    minor_6 = {0, 3, 7, 9},
    min_6_and_9 = {0, 2, 3, 7, 9},
    maj_6_and_9 = {0, 2, 4, 7, 9},
    major_add_9 = {0, 2, 4, 7},
    minor_add_9 = {0, 2, 3, 7},
    major_9 = {0, 2, 4, 7, 11},
    min_9 = {0, 2, 3, 7, 10},
    dominant_9 = {0, 2, 4, 7, 10},
    --chords_2 = {},
    maj_9_sharp5 = {0, 2, 4, 8, 11},
    maj_9_b5 = {0, 2, 4, 6, 11},
    dom_9_b5 = {0, 2, 4, 6, 10},
    dom_9_sharp5 = {0, 2, 4, 8, 10},
    dom_7_sharp9 = {0, 3, 4, 7, 10},
    dom_7_b9 = {0, 1, 4, 7, 10},
    dom_7_sharp5_sharp9 = {0, 3, 4, 8, 10},
    dom_7_sharp5_b9 = {0, 1, 4, 8, 10},
    dom_7_b5_sharp9 = {0, 3, 4, 6, 10},
    dom_7_b5_b9 = {0, 1, 4, 6, 10},
    dom_9_sus_4 = {0, 2, 5, 7, 10},
    min_9_maj_7 = {0, 2, 3, 7, 11},
    dim_maj_9 = {0, 2, 3, 6, 11},
    min_9_b5 = {0, 2, 3, 6, 10},
    maj_6_and_11 = {0, 4, 6, 8},
    min_6_and_11 = {0, 3, 6, 8},
    maj_9_sharp11 = {0, 2, 4, 6, 10},
    maj_9_sharp5_sharp11 = {0, 2, 4, 7, 10},
    dom_9_sharp11 = {0, 2, 4, 6, 9},
    dom_7_sharp9_sharp11 = {0, 3, 4, 6, 9},
    dom_7_b9_sharp11 = {0, 1, 4, 6, 9},
    dom_7_chord = {0, 2, 6, 9},
    min_11 = {0, 2, 3, 6, 9},
    min_11_b5 = {0, 2, 3, 5, 9},
    maj_13_sharp11 = {0, 2, 4, 6, 9},
    dom_13_sharp11 = {0, 2, 4, 6, 8},
    dom_13_sus_4 = {0, 2, 5, 7, 9},
    dom_13_b9 = {0, 1, 4, 7, 9},
    dom_13 = {0, 2, 4, 7, 9},
    dom_13_b9_sus_4 = {0, 1, 5, 7, 9},
    min_13 = {0, 2, 3, 6, 8},
    jtp_drum_machine_1 = {0,1,2,3,4,5,6,7,8,9,10,11}
}

local scale_keys = {}
for k in pairs(scales) do table.insert(scale_keys, k) end
table.sort(scale_keys)
local scale_names_str = table.concat(scale_keys, '\0') .. '\0'


function generate_melody(p)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    -- Constants from GUI
    local MEASURES = p.measures
    local START_OF_MEASURE_NOTE_CHANCE = p.start_of_measure_note_chance
    local BEAT_NOTE_CHANCE = p.beat_note_chance
    local SUB_BEAT_NOTE_CHANCE = p.sub_beat_note_chance
    local QUARTER_NOTE_CHANCE = p.quarter_note_chance
    local EIGHTH_NOTE_CHANCE = p.eighth_note_chance
    local BIG_JUMP_CHANCE = p.big_jump_chance
    local BIG_JUMP_INTERVAL = p.big_jump_interval
    local MAX_REPEATED_NOTES = p.max_repeated_notes
    local NOTE_VARIETY_THRESHOLD = p.note_variety_threshold
    local REST_PROBABILITY = p.rest_probability
    local LEGATO_PROBABILITY = p.legato_probability
    local SHORT_NOTE_END_PROBABILITY = p.short_note_end_probability
    local SAME_LAST_NOTE_PROBABILITY = p.same_last_note_probability
    local VELOCITY_16TH_NOTE = {p.velocity_16th_min, p.velocity_16th_max}
    local VELOCITY_8TH_NOTE = {p.velocity_8th_min, p.velocity_8th_max}
    local VELOCITY_QUARTER_NOTE = {p.velocity_quarter_min, p.velocity_quarter_max}
    local VELOCITY_HALF_AND_LONGER_NOTE = {p.velocity_half_min, p.velocity_half_max}
    local MIN_NUM_NOTES = p.min_num_notes
    local MAX_NUM_NOTES = p.max_num_notes
    local NUM_NOTES = math.random(MIN_NUM_NOTES, MAX_NUM_NOTES)
    local MIN_KEEP_NOTES = p.min_keep_notes
    local MAX_KEEP_NOTES = p.max_keep_notes
    local notes_to_keep = math.random(MIN_KEEP_NOTES, MAX_KEEP_NOTES)
    local root_note = p.root_note

    -- Utility function to find an element in a table
    local function table_find(tab, element)
        for _, value in pairs(tab) do
            if value == element then return true end
        end
        return false
    end

    local bpm = reaper.Master_GetTempo()
    local start_time = reaper.GetCursorPosition()
    local end_time = start_time + (60 / bpm * 4 * MEASURES)
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("No track selected!", "Error", 0)
        reaper.PreventUIRefresh(-1)
        return
    end

    local midi_item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
    local midi_take = reaper.GetTake(midi_item, 0)

    local function timeToTicks(time) return reaper.MIDI_GetPPQPosFromProjTime(midi_take, time) end
    local function findIndex(tbl, item)
        for i, v in ipairs(tbl) do if v == item then return i end end
        return nil
    end

    local function getVelocityBasedOnDuration(duration)
        if duration <= (60/bpm / 4) then return math.random(VELOCITY_16TH_NOTE[1], VELOCITY_16TH_NOTE[2])
        elseif duration <= (60/bpm / 2) then return math.random(VELOCITY_8TH_NOTE[1], VELOCITY_8TH_NOTE[2])
        elseif duration <= (60/bpm) then return math.random(VELOCITY_QUARTER_NOTE[1], VELOCITY_QUARTER_NOTE[2])
        else return math.random(VELOCITY_HALF_AND_LONGER_NOTE[1], VELOCITY_HALF_AND_LONGER_NOTE[2]) end
    end

    local function pruneMidiNotes(midi_take, num_to_keep)
        local _, note_count = reaper.MIDI_CountEvts(midi_take)
        for i = note_count - 1, num_to_keep, -1 do
            reaper.MIDI_DeleteNote(midi_take, i)
        end
    end

    local function generateUniqueMotif(notes, length)
        local motif = {}
        local used_notes = {}
        for i = 1, length do
            local next_note
            repeat
                next_note = notes[math.random(#notes)]
            until not table_find(used_notes, next_note)
            table.insert(motif, next_note)
            table.insert(used_notes, next_note)
        end
        return motif
    end

    local chosen_scale_key = scale_keys[p.scale_idx]
    local chosen_scale = scales[chosen_scale_key]
    local notes = {}
    for _, interval in ipairs(chosen_scale) do
        table.insert(notes, root_note + interval)
    end

    local motif = generateUniqueMotif(notes, 3)
    local motif2 = generateUniqueMotif(notes, 3)
    local repeated_notes = 0
    local movement_direction = math.random(2) == 1 and 1 or -1

    local function getNewNote(prev_note, prev_duration)
        local move = 0
        if repeated_notes >= MAX_REPEATED_NOTES or math.random() < NOTE_VARIETY_THRESHOLD then
            move = movement_direction
            if math.random() > 0.7 then move = move * -1 end
            repeated_notes = 0
        else
            if math.random() < BIG_JUMP_CHANCE then
                move = (math.random(2) == 1 and -1 or 1) * math.random(1, BIG_JUMP_INTERVAL)
                repeated_notes = 0
            end
        end
        local idx = findIndex(notes, prev_note)
        local new_idx = math.max(1, math.min(#notes, idx + move))
        local velocity = getVelocityBasedOnDuration(prev_duration)
        return notes[new_idx], velocity
    end

    local duration_weights = {
        [60/bpm / 4] = 0, [60/bpm / 2] = 30, [60/bpm] = 20, [60/bpm * 2] = 15, [60/bpm * 4] = 7,
    }
    local function getDuration(prev_duration)
        local totalWeight = 0
        for _, weight in pairs(duration_weights) do totalWeight = totalWeight + weight end
        local choice = math.random() * totalWeight
        local cumulativeWeight = 0
        for duration, weight in pairs(duration_weights) do
            cumulativeWeight = cumulativeWeight + weight
            if choice <= cumulativeWeight then return duration end
        end
        return prev_duration
    end

    local prev_note = notes[math.random(1, #notes)]
    local prev_duration = getDuration(60/bpm)
    local note_start_time = start_time
    reaper.MIDI_InsertNote(midi_take, false, false, timeToTicks(note_start_time), timeToTicks(note_start_time + prev_duration), 0, prev_note, math.random(60, 100), false, false)

    local note_end_time = note_start_time + prev_duration
    for i = 2, NUM_NOTES do
        prev_note, velocity = getNewNote(prev_note, prev_duration)
        prev_duration = getDuration(prev_duration)
        note_start_time = note_end_time
        note_end_time = note_start_time + prev_duration
        reaper.MIDI_InsertNote(midi_take, false, false, timeToTicks(note_start_time), timeToTicks(note_end_time), 0, prev_note, velocity, false, false)
    end

    if notes_to_keep > 0 then
        pruneMidiNotes(midi_take, notes_to_keep)
    end

    local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local root_note_name = note_names[((root_note % 12) + 1)]
    local octave = math.floor(root_note / 12) - 1
    local take_name = root_note_name .. octave .. " " .. chosen_scale_key
    reaper.GetSetMediaItemTakeInfo_String(midi_take, "P_NAME", take_name, true)

    reaper.Undo_EndBlock("jtp gen: Generate Melody", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function loop()
    reaper.ImGui_NewFrame(ImGui)
    reaper.ImGui_SetNextWindowSize(ImGui, 500, 700, reaper.ImGui_Cond_FirstUseEver)

    local ok, open = reaper.ImGui_Begin(ImGui, 'Melody Generator', true)
    if ok then
        if reaper.ImGui_Button(ImGui, 'Generate Melody', -1, 0) then
            settings.generate_button = true
        end
        reaper.ImGui_Separator(ImGui)

        if reaper.ImGui_CollapsingHeader(ImGui, 'General Settings', reaper.ImGui_TreeNodeFlags_DefaultOpen) then
            reaper.ImGui_SliderInt(ImGui, 'Measures', vals[1], 1, 64)
            reaper.ImGui_SliderInt(ImGui, 'Root Note', vals[27], 0, 127)
            reaper.ImGui_Combo(ImGui, 'Scale', vals[28], scale_names_str)
        end

        if reaper.ImGui_CollapsingHeader(ImGui, 'Note Count') then
            reaper.ImGui_DragIntRange2(ImGui, 'Num Notes', vals[23], vals[24], 1, 1, 100)
            reaper.ImGui_DragIntRange2(ImGui, 'Keep Notes', vals[25], vals[26], 1, 0, 100)
        end

        if reaper.ImGui_CollapsingHeader(ImGui, 'Rhythmic Chances') then
            reaper.ImGui_SliderFloat(ImGui, 'Start of Measure', vals[2], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'On Beat', vals[3], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Sub Beat', vals[4], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Quarter Note', vals[5], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Eighth Note', vals[6], 0, 1)
        end

        if reaper.ImGui_CollapsingHeader(ImGui, 'Melodic Chances') then
            reaper.ImGui_SliderFloat(ImGui, 'Big Jump', vals[7], 0, 1)
            reaper.ImGui_SliderInt(ImGui, 'Big Jump Interval', vals[8], 1, 12)
            reaper.ImGui_SliderInt(ImGui, 'Max Repeated Notes', vals[9], 0, 10)
            reaper.ImGui_SliderFloat(ImGui, 'Note Variety', vals[10], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Rest', vals[11], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Legato', vals[12], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Short Last Note', vals[13], 0, 1)
            reaper.ImGui_SliderFloat(ImGui, 'Same Last Note', vals[14], 0, 1)
        end

        if reaper.ImGui_CollapsingHeader(ImGui, 'Velocity Ranges') then
            reaper.ImGui_DragIntRange2(ImGui, '16th', vals[15], vals[16], 1, 1, 127)
            reaper.ImGui_DragIntRange2(ImGui, '8th', vals[17], vals[18], 1, 1, 127)
            reaper.ImGui_DragIntRange2(ImGui, 'Quarter', vals[19], vals[20], 1, 1, 127)
            reaper.ImGui_DragIntRange2(ImGui, 'Half/Longer', vals[21], vals[22], 1, 1, 127)
        end

        reaper.ImGui_End(ImGui)
    end

    reaper.ImGui_Render(ImGui)

    if settings.generate_button then
        settings.generate_button = false
        local p = {
            measures = vals[1].value,
            start_of_measure_note_chance = vals[2].value,
            beat_note_chance = vals[3].value,
            sub_beat_note_chance = vals[4].value,
            quarter_note_chance = vals[5].value,
            eighth_note_chance = vals[6].value,
            big_jump_chance = vals[7].value,
            big_jump_interval = vals[8].value,
            max_repeated_notes = vals[9].value,
            note_variety_threshold = vals[10].value,
            rest_probability = vals[11].value,
            legato_probability = vals[12].value,
            short_note_end_probability = vals[13].value,
            same_last_note_probability = vals[14].value,
            velocity_16th_min = vals[15].value,
            velocity_16th_max = vals[16].value,
            velocity_8th_min = vals[17].value,
            velocity_8th_max = vals[18].value,
            velocity_quarter_min = vals[19].value,
            velocity_quarter_max = vals[20].value,
            velocity_half_min = vals[21].value,
            velocity_half_max = vals[22].value,
            min_num_notes = vals[23].value,
            max_num_notes = vals[24].value,
            min_keep_notes = vals[25].value,
            max_keep_notes = vals[26].value,
            root_note = vals[27].value,
            scale_idx = vals[28].value,
        }
        generate_melody(p)
    end

    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ImGui)
    end
end

reaper.defer(loop)
