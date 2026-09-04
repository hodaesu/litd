extends Node

const PERSISTENCE_SCRIPT := preload("res://scripts/world/veilleurs_vs001_persistence_bridge.gd")

const WATCHER_DEFS: Array[Dictionary] = [
    {"id": "nayra_orun", "name": "Nayra Orun", "role": "La Garde", "template_index": 3},
    {"id": "tarek_senn", "name": "Tarek Senn", "role": "Le Pisteur", "template_index": 1},
    {"id": "aisha_maren", "name": "Aïsha Maren", "role": "L’Anatomiste", "template_index": 2},
    {"id": "idris_vael", "name": "Idris Vael", "role": "Le Médiateur", "template_index": 0}
]

var previous_party: Array = []
var watchers_active := false
var persistence_bridge: VeilleursVS001PersistenceBridge = null
var launch_canvas: CanvasLayer = null
var launch_button: Button = null

func _ready() -> void:
    AshlandsSceneRouter.zone_scene_paths[VeilleursVS001WorldRuntime.ZONE_ID] = VeilleursVS001WorldRuntime.SCENE_PATH
    persistence_bridge = PERSISTENCE_SCRIPT.new() as VeilleursVS001PersistenceBridge
    persistence_bridge.name = "VS001PersistenceBridge"
    add_child(persistence_bridge)
    if not VeilleursVS001WorldRuntime.session_started.is_connected(_on_session_started):
        VeilleursVS001WorldRuntime.session_started.connect(_on_session_started)
    if not VeilleursVS001WorldRuntime.session_changed.is_connected(_on_session_changed):
        VeilleursVS001WorldRuntime.session_changed.connect(_on_session_changed)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not SaveManager.save_finished.is_connected(_on_save_finished):
        SaveManager.save_finished.connect(_on_save_finished)
    call_deferred("_install_launch_ui")

func start_playable() -> bool:
    activate_watchers_party()
    VeilleursVS001WorldRuntime.start_new_session()
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition()
    _sync_launch_button()
    return AshlandsSceneRouter.load_zone(VeilleursVS001WorldRuntime.ZONE_ID)

func resume_playable() -> bool:
    if not VeilleursVS001WorldRuntime.is_active():
        return false
    if not _party_matches_watchers(GameState.party):
        var saved_previous := previous_party.duplicate(true)
        activate_watchers_party()
        if not saved_previous.is_empty():
            previous_party = saved_previous
    else:
        watchers_active = true
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition()
    _sync_launch_button()
    return AshlandsSceneRouter.load_zone(VeilleursVS001WorldRuntime.ZONE_ID)

func watcher_ids() -> Array[String]:
    var ids: Array[String] = []
    for watcher_def: Dictionary in WATCHER_DEFS:
        ids.append(str(watcher_def.get("id", "")))
    return ids

func watcher_names() -> Array[String]:
    var names: Array[String] = []
    for watcher_def: Dictionary in WATCHER_DEFS:
        names.append(str(watcher_def.get("name", "")))
    return names

func activate_watchers_party() -> Array:
    if not watchers_active:
        previous_party = GameState.party.duplicate(true)
    var watchers: Array = _build_watchers_party()
    GameState.party = watchers
    GameState.selected_hero = 0
    GameState.battle_enemies = []
    GameState.battle_rounds = 0
    watchers_active = true
    GameState.state_changed.emit()
    _sync_launch_button()
    return GameState.party

func restore_previous_party() -> Array:
    if not watchers_active:
        return GameState.party
    GameState.party = previous_party.duplicate(true)
    GameState.selected_hero = 0
    GameState.battle_enemies = []
    GameState.battle_rounds = 0
    previous_party.clear()
    watchers_active = false
    GameState.state_changed.emit()
    _sync_launch_button()
    return GameState.party

func is_watcher_party_active() -> bool:
    return watchers_active and _party_matches_watchers(GameState.party)

func serialize() -> Dictionary:
    var session_state: Dictionary = VeilleursVS001WorldRuntime.session.call("serialize")
    return {
        "schema_version": 1,
        "watchers_active": watchers_active,
        "previous_party": previous_party.duplicate(true),
        "world_runtime": {
            "session": session_state,
            "pending_combat": VeilleursVS001WorldRuntime.pending_combat.duplicate(true),
            "cleared_encounters": VeilleursVS001WorldRuntime.cleared_encounters.duplicate(true),
            "claimed_loot": VeilleursVS001WorldRuntime.claimed_loot.duplicate(true),
            "last_interaction": VeilleursVS001WorldRuntime.last_interaction.duplicate(true)
        },
        "persistence": persistence_bridge.serialize() if persistence_bridge != null else {}
    }

func deserialize(payload: Dictionary) -> void:
    if payload.is_empty():
        previous_party.clear()
        watchers_active = false
        if persistence_bridge != null:
            persistence_bridge.reset()
        _sync_launch_button()
        return
    previous_party = payload.get("previous_party", []).duplicate(true)
    watchers_active = bool(payload.get("watchers_active", false))
    var world: Dictionary = payload.get("world_runtime", {})
    var session_payload: Dictionary = world.get("session", {})
    if not session_payload.is_empty():
        VeilleursVS001WorldRuntime.session.call("deserialize", session_payload)
    VeilleursVS001WorldRuntime.pending_combat = world.get("pending_combat", {}).duplicate(true)
    VeilleursVS001WorldRuntime.cleared_encounters = world.get("cleared_encounters", {}).duplicate(true)
    VeilleursVS001WorldRuntime.claimed_loot = world.get("claimed_loot", {}).duplicate(true)
    VeilleursVS001WorldRuntime.last_interaction = world.get("last_interaction", {}).duplicate(true)
    if persistence_bridge != null:
        persistence_bridge.deserialize(payload.get("persistence", {}))
    if watchers_active and not _party_matches_watchers(GameState.party):
        GameState.party = _build_watchers_party()
        GameState.selected_hero = 0
    var state_value: Dictionary = VeilleursVS001WorldRuntime.snapshot()
    VeilleursVS001WorldRuntime.session_changed.emit(state_value.duplicate(true))
    GameState.state_changed.emit()
    _sync_launch_button()

func _build_watchers_party() -> Array:
    var watchers: Array = []
    for watcher_def: Dictionary in WATCHER_DEFS:
        var template_index := int(watcher_def.get("template_index", -1))
        if template_index < 0 or template_index >= DataLoader.heroes.size():
            push_error("VeilleursVS001PlayableBridge: missing combat shell for %s" % str(watcher_def.get("id", "watcher")))
            continue
        var raw_value: Variant = DataLoader.heroes[template_index]
        if not (raw_value is Dictionary):
            continue
        var watcher: Dictionary = (raw_value as Dictionary).duplicate(true)
        watcher["id"] = str(watcher_def.get("id", "watcher"))
        watcher["name"] = str(watcher_def.get("name", "Veilleur"))
        watcher["display_name"] = str(watcher_def.get("name", "Veilleur"))
        watcher["race_id"] = "human"
        watcher["player_owned"] = true
        watcher["vs001_watcher"] = true
        watcher["vs001_role"] = str(watcher_def.get("role", "Veilleur"))
        watcher["canon_status"] = "veilleurs_canon_identity_provisional_combat_shell"
        watcher["identity_note"] = "Canonical Les Veilleurs identity using a temporary compatible combat shell until dedicated assets and trees are connected."
        watcher.erase("positive_traits")
        watcher.erase("negative_traits")
        watcher.erase("trait_progress")
        HeroSkillManager.prepare_hero(watcher)
        CharacterTraitDirector.prepare_character(watcher, str(watcher.get("id", "")), false)
        EnemyFearDirector.prepare_hero(watcher)
        PersistentInjuryRuntime.prepare_character(watcher)
        watchers.append(watcher)
    return watchers

func _party_matches_watchers(party_value: Array) -> bool:
    if party_value.size() != WATCHER_DEFS.size():
        return false
    var expected: Array[String] = watcher_ids()
    var actual: Array[String] = []
    for hero_value: Variant in party_value:
        if not (hero_value is Dictionary):
            return false
        actual.append(str((hero_value as Dictionary).get("id", "")))
    return actual == expected

func _install_launch_ui() -> void:
    if launch_canvas != null:
        return
    launch_canvas = CanvasLayer.new()
    launch_canvas.name = "VeilleursVS001LaunchUI"
    launch_canvas.layer = 90
    add_child(launch_canvas)
    launch_button = Button.new()
    launch_button.name = "LaunchVeilleursVS001"
    launch_button.text = "LES VEILLEURS · VS001"
    launch_button.custom_minimum_size = Vector2(220.0, 54.0)
    launch_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    launch_button.position = Vector2(-244.0, 82.0)
    launch_button.pressed.connect(_on_launch_pressed)
    launch_canvas.add_child(launch_button)
    _sync_launch_button()

func _sync_launch_button() -> void:
    if launch_button == null:
        return
    launch_button.visible = GameState.current_screen in ["title", "sanctuary"] and not watchers_active

func _on_launch_pressed() -> void:
    start_playable()

func _on_session_started(_snapshot: Dictionary) -> void:
    if not is_watcher_party_active():
        activate_watchers_party()

func _on_session_changed(snapshot_value: Dictionary) -> void:
    if watchers_active and not bool(snapshot_value.get("active", false)):
        restore_previous_party()

func _on_screen_requested(_screen_name: String) -> void:
    call_deferred("_sync_launch_button")

func _on_save_finished(_slot: int, success: bool, _recovered: bool) -> void:
    if success and GameState.current_screen == "title" and VeilleursVS001WorldRuntime.is_active():
        call_deferred("_resume_after_load")

func _resume_after_load() -> void:
    if VeilleursVS001WorldRuntime.is_active():
        resume_playable()

func _on_new_game_reset() -> void:
    previous_party.clear()
    watchers_active = false
    if persistence_bridge != null:
        persistence_bridge.reset()
    _sync_launch_button()
