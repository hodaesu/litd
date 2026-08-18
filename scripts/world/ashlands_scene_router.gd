extends Node

signal zone_load_started(zone_id: String)
signal zone_load_finished(zone_id: String)
signal zone_load_failed(zone_id: String, reason: String)

const BASE_PATH := "res://scenes/world/terre_des_cendres/"
const CHAPTER_02_PATH := "res://scenes/world/chapter_02/"
const CHAPTER_03_PATH := "res://scenes/world/chapter_03/"
const CHAPTER_04_PATH := "res://scenes/world/chapter_04/"
const MAIN_SCENE := "res://scenes/Main.tscn"

var zone_scene_paths := {
    "zone_01_faubourg_cendreux": BASE_PATH + "zone_01_faubourg_cendreux.tscn",
    "zone_02_village_ravage": BASE_PATH + "zone_02_village_ravage.tscn",
    "zone_03_moulin_calcine": BASE_PATH + "zone_03_moulin_calcine.tscn",
    "zone_04_foret_morte": BASE_PATH + "zone_04_foret_morte.tscn",
    "zone_05_ravin_des_pendus": BASE_PATH + "zone_05_ravin_des_pendus.tscn",
    "zone_06_chapelle_effondree": BASE_PATH + "zone_06_chapelle_effondree.tscn",
    "zone_07_cimetiere": BASE_PATH + "zone_07_cimetiere_blockout.tscn",
    "zone_08_catacombes": BASE_PATH + "zone_08_catacombes.tscn",
    "zone_09_ossuaire": BASE_PATH + "zone_09_ossuaire.tscn",
    "zone_10_hameau_deserte": BASE_PATH + "zone_10_hameau_deserte.tscn",
    "zone_11_route_des_penitents": BASE_PATH + "zone_11_route_des_penitents.tscn",
    "zone_12_abbaye": BASE_PATH + "zone_12_abbaye.tscn",
    "zone_13_clocher_boss": BASE_PATH + "zone_13_clocher_boss.tscn",
    "zone_14_clairiere_des_corbeaux": BASE_PATH + "zone_14_clairiere_des_corbeaux.tscn",
    "zone_15_crypte_du_sans_nom": BASE_PATH + "zone_15_crypte_du_sans_nom.tscn",
    "c02_old_road": CHAPTER_02_PATH + "c02_old_road.tscn",
    "c02_watchpost": CHAPTER_02_PATH + "c02_watchpost.tscn",
    "c02_quarry_camp": CHAPTER_02_PATH + "c02_quarry_camp.tscn",
    "c02_buried_archive": CHAPTER_02_PATH + "c02_buried_archive.tscn",
    "c02_resonance_station": CHAPTER_02_PATH + "c02_resonance_station.tscn",
    "c03_abandoned_relay": CHAPTER_03_PATH + "c03_abandoned_relay.tscn",
    "c03_korem_lab": CHAPTER_03_PATH + "c03_korem_lab.tscn",
    "c03_diplomatic_post": CHAPTER_03_PATH + "c03_diplomatic_post.tscn",
    "c03_threshold_complex": CHAPTER_03_PATH + "c03_threshold_complex.tscn",
    "c03_abort_chamber": CHAPTER_03_PATH + "c03_abort_chamber.tscn",
    "c03_ritual_core": CHAPTER_03_PATH + "c03_ritual_core.tscn",
    "c04_buried_city": CHAPTER_04_PATH + "c04_buried_city.tscn",
    "c04_resonance_halls": CHAPTER_04_PATH + "c04_resonance_halls.tscn",
    "c04_seven_silences": CHAPTER_04_PATH + "c04_seven_silences.tscn",
    "c04_echo_camp": CHAPTER_04_PATH + "c04_echo_camp.tscn",
    "c04_broken_observatory": CHAPTER_04_PATH + "c04_broken_observatory.tscn",
    "c04_chorus_chamber": CHAPTER_04_PATH + "c04_chorus_chamber.tscn"
}

func _ready() -> void:
    AshlandsRuntime.transition_requested.connect(load_zone)

func has_zone(zone_id: String) -> bool:
    return zone_scene_paths.has(zone_id) and ResourceLoader.exists(zone_scene_paths[zone_id])

func load_zone(zone_id: String) -> bool:
    zone_load_started.emit(zone_id)
    if not has_zone(zone_id):
        zone_load_failed.emit(zone_id, "scene_missing")
        return false
    var error := get_tree().change_scene_to_file(zone_scene_paths[zone_id])
    if error != OK:
        zone_load_failed.emit(zone_id, "change_scene_error_%s" % error)
        return false
    AshlandsRuntime.enter_zone(zone_id)
    zone_load_finished.emit(zone_id)
    return true

func start_ashlands() -> bool:
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition()
    AshlandsMinibossDirector.roll_for_expedition(ExpeditionManager.expedition_seed)
    return load_zone("zone_01_faubourg_cendreux")

func start_chapter_02() -> bool:
    if CampaignState.current_chapter_id != "chapter_02_before_fall": return false
    if not ExpeditionManager.expedition_active: ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition(); GameState.request_screen("exploration")
    return load_zone("c02_old_road")

func start_chapter_03() -> bool:
    if CampaignState.current_chapter_id != "chapter_03_threshold": return false
    if not ExpeditionManager.expedition_active: ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition(); GameState.request_screen("exploration")
    return load_zone("c03_abandoned_relay")

func start_chapter_04() -> bool:
    if CampaignState.current_chapter_id != "chapter_04_first_rupture": return false
    if not ExpeditionManager.expedition_active: ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition(); GameState.request_screen("exploration")
    return load_zone("c04_buried_city")

func return_to_hub(reason: String = "voluntary") -> void:
    ExpeditionManager.return_to_hub(reason)
    GameState.current_screen = "sanctuary"
    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    if error == OK: call_deferred("_show_sanctuary_after_load")

func _show_sanctuary_after_load() -> void:
    await get_tree().process_frame
    GameState.request_screen("sanctuary")
