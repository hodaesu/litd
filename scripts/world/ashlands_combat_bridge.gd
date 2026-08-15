extends Node

signal ashlands_combat_started(encounter_id: String, encounter_type: String)
signal ashlands_combat_finished(encounter_id: String, victory: bool, loot: Dictionary)

const MAIN_SCENE := "res://scenes/Main.tscn"

var active := false
var encounter_id := ""
var encounter_type := ""
var return_zone_id := ""
var miniboss_data: Dictionary = {}
var pending_loot: Dictionary = {}
var _resolving := false

func _ready() -> void:
    GameState.screen_requested.connect(_on_screen_requested)

func begin(encounter_id_value: String, encounter_type_value: String, miniboss: Dictionary = {}) -> void:
    if active:
        return
    active = true
    _resolving = false
    encounter_id = encounter_id_value
    encounter_type = encounter_type_value
    return_zone_id = AshlandsRuntime.current_zone_id
    miniboss_data = miniboss.duplicate(true)
    pending_loot = {}
    _prepare_placeholder_enemies()
    GameState.current_screen = "combat"
    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    if error == OK:
        call_deferred("_show_combat_after_load")
    ashlands_combat_started.emit(encounter_id, encounter_type)

func _show_combat_after_load() -> void:
    await get_tree().process_frame
    GameState.request_screen("combat")

func _on_screen_requested(screen_name: String) -> void:
    if not active or _resolving:
        return
    if screen_name == "rewards":
        _resolving = true
        call_deferred("resolve_victory")
    elif screen_name == "sanctuary":
        _resolving = true
        call_deferred("resolve_defeat")

func _prepare_placeholder_enemies() -> void:
    GameState.battle_enemies = []
    var ids: Array[int] = [1, 8, 10]
    if encounter_type == "miniboss":
        ids = [30]
    elif encounter_type == "boss":
        ids = [38]
    for enemy_id in ids:
        var e := DataLoader.find_by_id(DataLoader.enemies, enemy_id).duplicate(true)
        if e.is_empty():
            continue
        e["max_hp"] = int(e.get("hp", 1))
        e["guarding"] = false
        if encounter_type == "miniboss" and not miniboss_data.is_empty():
            e["name"] = str(miniboss_data.get("name", e.get("name", "Mini-boss")))
            e["recruitable"] = false
            e["is_miniboss"] = true
        if encounter_type == "boss":
            e["recruitable"] = false
            e["is_boss"] = true
        GameState.battle_enemies.append(e)

func resolve_victory() -> Dictionary:
    if not active:
        return {}
    AshlandsRuntime.mark_encounter_cleared(encounter_id)
    pending_loot = _roll_loot()
    _apply_loot(pending_loot)
    var finished_id := encounter_id
    ashlands_combat_finished.emit(finished_id, true, pending_loot.duplicate(true))
    _return_to_exploration()
    return pending_loot.duplicate(true)

func resolve_defeat() -> void:
    if not active:
        return
    var finished_id := encounter_id
    ashlands_combat_finished.emit(finished_id, false, {})
    active = false
    _resolving = false
    encounter_id = ""
    encounter_type = ""
    miniboss_data = {}
    AshlandsSceneRouter.return_to_hub("defeat")

func _roll_loot() -> Dictionary:
    if encounter_type != "miniboss":
        return {"gold": 18, "essence": 2}
    var tier := str(miniboss_data.get("loot_tier", "major"))
    var table := AshlandsMinibossDirector.get_loot_table(tier)
    return {
        "gold": 45,
        "essence": 8,
        "tier": tier,
        "guaranteed": table.get("guaranteed", []),
        "possible": table.get("possible", []),
        "rolls": int(table.get("rolls", 0))
    }

func _apply_loot(loot: Dictionary) -> void:
    GameState.gold += int(loot.get("gold", 0))
    GameState.essence += int(loot.get("essence", 0))
    for item in loot.get("guaranteed", []):
        ExpeditionManager.add_resource(str(item), 1)
    var possible: Array = loot.get("possible", [])
    var rolls := int(loot.get("rolls", 0))
    if not possible.is_empty() and rolls > 0:
        var rng := RandomNumberGenerator.new()
        rng.seed = ExpeditionManager.expedition_seed + encounter_id.hash()
        for _i in rolls:
            var item := str(possible[rng.randi_range(0, possible.size() - 1)])
            ExpeditionManager.add_resource(item, 1)

func _return_to_exploration() -> void:
    var target := return_zone_id
    active = false
    _resolving = false
    encounter_id = ""
    encounter_type = ""
    miniboss_data = {}
    if target != "":
        AshlandsSceneRouter.load_zone(target)

func serialize() -> Dictionary:
    return {
        "active": active,
        "encounter_id": encounter_id,
        "encounter_type": encounter_type,
        "return_zone_id": return_zone_id,
        "miniboss_data": miniboss_data,
        "pending_loot": pending_loot
    }

func deserialize(data: Dictionary) -> void:
    active = bool(data.get("active", false))
    _resolving = false
    encounter_id = str(data.get("encounter_id", ""))
    encounter_type = str(data.get("encounter_type", ""))
    return_zone_id = str(data.get("return_zone_id", ""))
    miniboss_data = data.get("miniboss_data", {}).duplicate(true)
    pending_loot = data.get("pending_loot", {}).duplicate(true)
