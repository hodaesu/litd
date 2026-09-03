extends Node

const WATCHER_DEFS: Array[Dictionary] = [
    {"id": "nayra_orun", "name": "Nayra Orun", "role": "La Garde", "template_index": 3},
    {"id": "tarek_senn", "name": "Tarek Senn", "role": "Le Pisteur", "template_index": 1},
    {"id": "aisha_maren", "name": "Aïsha Maren", "role": "L’Anatomiste", "template_index": 2},
    {"id": "idris_vael", "name": "Idris Vael", "role": "Le Médiateur", "template_index": 0}
]

var previous_party: Array = []
var watchers_active := false

func _ready() -> void:
    AshlandsSceneRouter.zone_scene_paths[VeilleursVS001WorldRuntime.ZONE_ID] = VeilleursVS001WorldRuntime.SCENE_PATH
    if not VeilleursVS001WorldRuntime.session_started.is_connected(_on_session_started):
        VeilleursVS001WorldRuntime.session_started.connect(_on_session_started)
    if not VeilleursVS001WorldRuntime.session_changed.is_connected(_on_session_changed):
        VeilleursVS001WorldRuntime.session_changed.connect(_on_session_changed)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)

func start_playable() -> bool:
    activate_watchers_party()
    VeilleursVS001WorldRuntime.start_new_session()
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition()
    AshlandsRuntime.begin_new_expedition()
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
    return GameState.party

func is_watcher_party_active() -> bool:
    return watchers_active and _party_matches_watchers(GameState.party)

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

func _on_session_started(_snapshot: Dictionary) -> void:
    if not is_watcher_party_active():
        activate_watchers_party()

func _on_session_changed(snapshot_value: Dictionary) -> void:
    if watchers_active and not bool(snapshot_value.get("active", false)):
        restore_previous_party()

func _on_new_game_reset() -> void:
    previous_party.clear()
    watchers_active = false
