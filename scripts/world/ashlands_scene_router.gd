extends Node

signal zone_load_started(zone_id: String)
signal zone_load_finished(zone_id: String)
signal zone_load_failed(zone_id: String, reason: String)

const BASE_PATH := "res://scenes/world/terre_des_cendres/"
const CHAPTER_02_PATH := "res://scenes/world/chapter_02/"
const CHAPTER_03_PATH := "res://scenes/world/chapter_03/"
const CHAPTER_04_PATH := "res://scenes/world/chapter_04/"
const CHAPTER_05_PATH := "res://scenes/world/chapter_05/"
const CHAPTER_06_PATH := "res://scenes/world/chapter_06/"
const CHAPTER_07_PATH := "res://scenes/world/chapter_07/"
const CHAPTER_08_PATH := "res://scenes/world/chapter_08/"
const CHAPTER_09_PATH := "res://scenes/world/chapter_09/"
const DEEP_VESTIGE_PATH := "res://scenes/world/deep_vestiges/"
const GENERIC_DEEP_VESTIGE_SCENE := DEEP_VESTIGE_PATH + "generic_deep_vestige.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"

var zone_scene_paths := {
    "zone_01_faubourg_cendreux": BASE_PATH + "zone_01_faubourg_cendreux.tscn", "zone_02_village_ravage": BASE_PATH + "zone_02_village_ravage.tscn", "zone_03_moulin_calcine": BASE_PATH + "zone_03_moulin_calcine.tscn", "zone_04_foret_morte": BASE_PATH + "zone_04_foret_morte.tscn", "zone_05_ravin_des_pendus": BASE_PATH + "zone_05_ravin_des_pendus.tscn", "zone_06_chapelle_effondree": BASE_PATH + "zone_06_chapelle_effondree.tscn", "zone_07_cimetiere": BASE_PATH + "zone_07_cimetiere_blockout.tscn", "zone_08_catacombes": BASE_PATH + "zone_08_catacombes.tscn", "zone_09_ossuaire": BASE_PATH + "zone_09_ossuaire.tscn", "zone_10_hameau_deserte": BASE_PATH + "zone_10_hameau_deserte.tscn", "zone_11_route_des_penitents": BASE_PATH + "zone_11_route_des_penitents.tscn", "zone_12_abbaye": BASE_PATH + "zone_12_abbaye.tscn", "zone_13_clocher_boss": BASE_PATH + "zone_13_clocher_boss.tscn", "zone_14_clairiere_des_corbeaux": BASE_PATH + "zone_14_clairiere_des_corbeaux.tscn", "zone_15_crypte_du_sans_nom": BASE_PATH + "zone_15_crypte_du_sans_nom.tscn",
    "c02_old_road": CHAPTER_02_PATH + "c02_old_road.tscn", "c02_watchpost": CHAPTER_02_PATH + "c02_watchpost.tscn", "c02_quarry_camp": CHAPTER_02_PATH + "c02_quarry_camp.tscn", "c02_buried_archive": CHAPTER_02_PATH + "c02_buried_archive.tscn", "c02_resonance_station": CHAPTER_02_PATH + "c02_resonance_station.tscn",
    "c03_abandoned_relay": CHAPTER_03_PATH + "c03_abandoned_relay.tscn", "c03_korem_lab": CHAPTER_03_PATH + "c03_korem_lab.tscn", "c03_diplomatic_post": CHAPTER_03_PATH + "c03_diplomatic_post.tscn", "c03_threshold_complex": CHAPTER_03_PATH + "c03_threshold_complex.tscn", "c03_abort_chamber": CHAPTER_03_PATH + "c03_abort_chamber.tscn", "c03_ritual_core": CHAPTER_03_PATH + "c03_ritual_core.tscn",
    "c04_buried_city": CHAPTER_04_PATH + "c04_buried_city.tscn", "c04_resonance_halls": CHAPTER_04_PATH + "c04_resonance_halls.tscn", "c04_seven_silences": CHAPTER_04_PATH + "c04_seven_silences.tscn", "c04_echo_camp": CHAPTER_04_PATH + "c04_echo_camp.tscn", "c04_broken_observatory": CHAPTER_04_PATH + "c04_broken_observatory.tscn", "c04_chorus_chamber": CHAPTER_04_PATH + "c04_chorus_chamber.tscn",
    "c05_black_glass_crypts": CHAPTER_05_PATH + "c05_black_glass_crypts.tscn", "c05_war_forge": CHAPTER_05_PATH + "c05_war_forge.tscn", "c05_silex_bastion": CHAPTER_05_PATH + "c05_silex_bastion.tscn", "c05_saan_well": CHAPTER_05_PATH + "c05_saan_well.tscn", "c05_last_watch_camp": CHAPTER_05_PATH + "c05_last_watch_camp.tscn", "c05_closure_chamber": CHAPTER_05_PATH + "c05_closure_chamber.tscn", "c05_command_vault": CHAPTER_05_PATH + "c05_command_vault.tscn",
    "c06_timeless_garden": CHAPTER_06_PATH + "c06_timeless_garden.tscn", "c06_echo_shore": CHAPTER_06_PATH + "c06_echo_shore.tscn", "c06_mute_doors": CHAPTER_06_PATH + "c06_mute_doors.tscn", "c06_overlap_hamlet": CHAPTER_06_PATH + "c06_overlap_hamlet.tscn", "c06_creature_hollow": CHAPTER_06_PATH + "c06_creature_hollow.tscn", "c06_saen_contact": CHAPTER_06_PATH + "c06_saen_contact.tscn", "c06_walking_boundary": CHAPTER_06_PATH + "c06_walking_boundary.tscn",
    "c07_engineer_refuge": CHAPTER_07_PATH + "c07_engineer_refuge.tscn", "c07_bram_workshop": CHAPTER_07_PATH + "c07_bram_workshop.tscn", "c07_fractured_monastery": CHAPTER_07_PATH + "c07_fractured_monastery.tscn", "c07_veyra_laboratory": CHAPTER_07_PATH + "c07_veyra_laboratory.tscn", "c07_relay_camp": CHAPTER_07_PATH + "c07_relay_camp.tscn", "c07_relay_palace": CHAPTER_07_PATH + "c07_relay_palace.tscn", "c07_edras_aperture": CHAPTER_07_PATH + "c07_edras_aperture.tscn",
    "c08_varkhane_border": CHAPTER_08_PATH + "c08_varkhane_border.tscn", "c08_varkhane_archive": CHAPTER_08_PATH + "c08_varkhane_archive.tscn", "c08_namar_refuge_port": CHAPTER_08_PATH + "c08_namar_refuge_port.tscn", "c08_namar_ledger_vault": CHAPTER_08_PATH + "c08_namar_ledger_vault.tscn", "c08_azravel_shelter_temple": CHAPTER_08_PATH + "c08_azravel_shelter_temple.tscn", "c08_azravel_dogma_court": CHAPTER_08_PATH + "c08_azravel_dogma_court.tscn", "c08_korem_fortified_academy": CHAPTER_08_PATH + "c08_korem_fortified_academy.tscn", "c08_korem_protocol_archive": CHAPTER_08_PATH + "c08_korem_protocol_archive.tscn",
    "c09_tree_node": CHAPTER_09_PATH + "c09_tree_node.tscn", "c09_seven_lenses": CHAPTER_09_PATH + "c09_seven_lenses.tscn", "c09_living_resonance": CHAPTER_09_PATH + "c09_living_resonance.tscn", "c09_saan_network": CHAPTER_09_PATH + "c09_saan_network.tscn", "c09_fear_basin": CHAPTER_09_PATH + "c09_fear_basin.tscn", "c09_deep_overlap": CHAPTER_09_PATH + "c09_deep_overlap.tscn", "c09_consensus_chamber": CHAPTER_09_PATH + "c09_consensus_chamber.tscn",
    "va01_threshold_gallery": DEEP_VESTIGE_PATH + "va01_threshold_gallery.tscn", "va02_singing_well": DEEP_VESTIGE_PATH + "va02_singing_well.tscn", "va03_hall_of_pairs": DEEP_VESTIGE_PATH + "va03_hall_of_pairs.tscn", "va04_silent_cloister": DEEP_VESTIGE_PATH + "va04_silent_cloister.tscn", "va05_memory_organ": DEEP_VESTIGE_PATH + "va05_memory_organ.tscn", "va06_seventh_chamber": DEEP_VESTIGE_PATH + "va06_seventh_chamber.tscn",
    "vs01_gate_of_doctrine": DEEP_VESTIGE_PATH + "vs01_gate_of_doctrine.tscn", "vs02_countermeasure_hall": DEEP_VESTIGE_PATH + "vs02_countermeasure_hall.tscn", "vs03_black_arsenal": DEEP_VESTIGE_PATH + "vs03_black_arsenal.tscn", "vs04_civilian_foundry": DEEP_VESTIGE_PATH + "vs04_civilian_foundry.tscn", "vs05_last_strategy": DEEP_VESTIGE_PATH + "vs05_last_strategy.tscn", "vs06_war_table": DEEP_VESTIGE_PATH + "vs06_war_table.tscn",
    "vn01_outer_cloister": DEEP_VESTIGE_PATH + "vn01_outer_cloister.tscn", "vn02_silent_archive": DEEP_VESTIGE_PATH + "vn02_silent_archive.tscn", "vn03_sealed_dormitory": DEEP_VESTIGE_PATH + "vn03_sealed_dormitory.tscn", "vn04_watchers_well": DEEP_VESTIGE_PATH + "vn04_watchers_well.tscn", "vn05_last_vigil": DEEP_VESTIGE_PATH + "vn05_last_vigil.tscn", "vn06_seal_heart": DEEP_VESTIGE_PATH + "vn06_seal_heart.tscn"
}

func _ready() -> void:
    _register_dynamic_deep_vestige_zones()
    AshlandsRuntime.transition_requested.connect(load_zone)

func _register_dynamic_deep_vestige_zones() -> void:
    for vestige_id in DeepVestigeRuntime.vestige_data.keys():
        var data: Dictionary = DeepVestigeRuntime.data_for(String(vestige_id))
        for value in data.get("zones", []):
            var zone_id := String((value as Dictionary).get("id", ""))
            if zone_id != "" and not zone_scene_paths.has(zone_id): zone_scene_paths[zone_id] = GENERIC_DEEP_VESTIGE_SCENE

func has_zone(zone_id: String) -> bool: return zone_scene_paths.has(zone_id) and ResourceLoader.exists(zone_scene_paths[zone_id])
func load_zone(zone_id: String) -> bool:
    zone_load_started.emit(zone_id)
    if not has_zone(zone_id): zone_load_failed.emit(zone_id,"scene_missing"); return false
    if DeepVestigeRuntime.has_zone(zone_id): DeepVestigeRuntime.prepare_zone(zone_id)
    var error := get_tree().change_scene_to_file(zone_scene_paths[zone_id])
    if error != OK: zone_load_failed.emit(zone_id,"change_scene_error_%s" % error); return false
    AshlandsRuntime.enter_zone(zone_id); zone_load_finished.emit(zone_id); return true
func _start_exp(start_zone: String) -> bool:
    if not ExpeditionManager.expedition_active: ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition(); GameState.request_screen("exploration"); return load_zone(start_zone)
func start_ashlands() -> bool:
    if not ExpeditionManager.expedition_active: ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition(); AshlandsMinibossDirector.roll_for_expedition(ExpeditionManager.expedition_seed); return load_zone("zone_01_faubourg_cendreux")
func start_chapter_02() -> bool: return CampaignState.current_chapter_id == "chapter_02_before_fall" and _start_exp("c02_old_road")
func start_chapter_03() -> bool: return CampaignState.current_chapter_id == "chapter_03_threshold" and _start_exp("c03_abandoned_relay")
func start_chapter_04() -> bool: return CampaignState.current_chapter_id == "chapter_04_first_rupture" and _start_exp("c04_buried_city")
func start_chapter_05() -> bool: return CampaignState.current_chapter_id == "chapter_05_great_closure" and _start_exp("c05_black_glass_crypts")
func start_chapter_06() -> bool: return CampaignState.current_chapter_id == "chapter_06_absent" and _start_exp("c06_timeless_garden")
func start_chapter_07() -> bool: return CampaignState.current_chapter_id == "chapter_07_living_responsible" and _start_exp("c07_engineer_refuge")
func start_chapter_08() -> bool: return CampaignState.current_chapter_id == "chapter_08_outer_world" and _start_exp("c08_varkhane_border")
func start_chapter_09() -> bool: return CampaignState.current_chapter_id == "chapter_09_veil_nature" and _start_exp("c09_tree_node")
func start_deep_vestige(vestige_id: String) -> bool:
    if not DeepVestigeRuntime.is_unlocked(vestige_id): return false
    var entry_zone := DeepVestigeRuntime.entry_zone_for(vestige_id)
    return entry_zone != "" and _start_exp(entry_zone)
func start_ashai_deep_vestige() -> bool: return start_deep_vestige("vestige_ashai_seven_resonances")
func start_or_silex_deep_vestige() -> bool: return start_deep_vestige("vestige_or_silex_black_glass")
func start_saan_deep_vestige() -> bool: return start_deep_vestige("vestige_saan_last_seal")
func return_to_hub(reason: String = "voluntary") -> void:
    ExpeditionManager.return_to_hub(reason); GameState.current_screen = "sanctuary"; var error := get_tree().change_scene_to_file(MAIN_SCENE); if error == OK: call_deferred("_show_sanctuary_after_load")
func _show_sanctuary_after_load() -> void:
    await get_tree().process_frame; GameState.request_screen("sanctuary")