extends Node

signal inventory_changed(inventory: Dictionary)
signal expedition_started(seed: int)
signal expedition_ended(return_reason: String)
signal resource_shortage(resource_id: String)
signal pressure_applied(amount: int, source: String)

const RULES_PATH := "res://data/levels/ashlands_survival_rules.json"
const ROGUELIKE_RUNTIME_SCRIPT := preload("res://scripts/core/roguelike_runtime.gd")

var rules: Dictionary = {}
var inventory: Dictionary = {}
var craft_resources: Dictionary = {}
var expedition_active := false
var expedition_seed := 0
var zones_entered_this_run: Array[String] = []
var roguelike_runtime

func _ready() -> void:
    roguelike_runtime = ROGUELIKE_RUNTIME_SCRIPT.new()
    roguelike_runtime.name = "RoguelikeRuntime"
    add_child(roguelike_runtime)
    _load_rules()
    if inventory.is_empty():
        reset_to_full_resupply()

func _load_rules() -> void:
    if not FileAccess.file_exists(RULES_PATH):
        push_error("ExpeditionManager: missing survival rules")
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        rules = parsed

func reset_to_full_resupply() -> void:
    inventory = rules.get("expedition_inventory", {}).duplicate(true)
    craft_resources = {}
    inventory_changed.emit(inventory.duplicate(true))

func start_expedition(seed_value: int = 0) -> void:
    expedition_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
    expedition_active = true
    zones_entered_this_run.clear()
    if roguelike_runtime != null:
        roguelike_runtime.start_run(expedition_seed)
    expedition_started.emit(expedition_seed)

func return_to_hub(reason: String = "voluntary") -> void:
    if roguelike_runtime != null and expedition_active:
        roguelike_runtime.commit_party_deaths(reason)
        roguelike_runtime.finish_run(reason)
    expedition_active = false
    zones_entered_this_run.clear()
    reset_to_full_resupply()
    expedition_ended.emit(reason)

func on_zone_entered(zone_id: String) -> Dictionary:
    if not expedition_active:
        start_expedition()
    if not zones_entered_this_run.has(zone_id):
        zones_entered_this_run.append(zone_id)
        var result := consume_bundle(rules.get("zone_entry_cost", {}))
        if not bool(result.get("success", true)):
            apply_pressure(5 * result.get("missing", []).size(), "resource_shortage")
        return result
    return {"success": true, "missing": []}

func enter_dungeon_room(room_id: String) -> Dictionary:
    if roguelike_runtime == null:
        return {"success": false, "reason": "roguelike_runtime_unavailable"}
    return roguelike_runtime.enter_room(room_id)

func dungeon_layout() -> Array:
    if roguelike_runtime == null:
        return []
    return roguelike_runtime.active_run.get("dungeon", []).duplicate(true)

func current_risk_profile() -> Dictionary:
    if roguelike_runtime == null:
        return {"light": int(inventory.get("light", 0)), "danger_multiplier": 1.0, "loot_multiplier": 1.0}
    return roguelike_runtime.current_risk_profile()

func deliberately_dim_light(amount: int = 1) -> Dictionary:
    if roguelike_runtime == null:
        return current_risk_profile()
    return roguelike_runtime.dim_light(amount)

func generate_roguelike_loot(depth: int, source: String = "room", seed_salt: int = 0) -> Dictionary:
    if roguelike_runtime == null:
        return {}
    return roguelike_runtime.generate_loot(depth, source, seed_salt)

func add_loot_to_expedition(item: Dictionary) -> bool:
    return roguelike_runtime != null and roguelike_runtime.add_cargo(item)

func inventory_slots_used() -> int:
    if roguelike_runtime == null:
        return 0
    return roguelike_runtime.inventory_slots_used()

func inventory_capacity() -> int:
    if roguelike_runtime == null:
        return 20
    return roguelike_runtime.inventory_capacity()

func capture_check(enemy: Dictionary, zone_id: String) -> Dictionary:
    if roguelike_runtime == null:
        return {"allowed": false, "reason": "roguelike_runtime_unavailable"}
    return roguelike_runtime.can_capture(enemy, zone_id)

func register_roguelike_capture(enemy: Dictionary, zone_id: String) -> Dictionary:
    if roguelike_runtime == null:
        return {"allowed": false, "reason": "roguelike_runtime_unavailable"}
    return roguelike_runtime.register_capture(enemy, zone_id)

func record_enemy_knowledge(enemy_id: String, killed: bool = false) -> Dictionary:
    if roguelike_runtime == null:
        return {}
    return roguelike_runtime.record_enemy_knowledge(enemy_id, killed)

func archive_expedition_lore(entry_id: String, payload: Dictionary) -> bool:
    return roguelike_runtime != null and roguelike_runtime.archive_lore(entry_id, payload)

func unlock_horizontal_meta(unlock_id: String, payload: Dictionary = {}) -> bool:
    return roguelike_runtime != null and roguelike_runtime.unlock_meta(unlock_id, payload)

func ultimate_uses_for_level(level: int) -> int:
    if roguelike_runtime == null:
        return 0
    return roguelike_runtime.ultimate_uses_for_level(level)

func hazard_interactions(hazard_id: String) -> Array:
    if roguelike_runtime == null:
        return []
    return roguelike_runtime.hazard_interactions(hazard_id)

func extraction_summary() -> Dictionary:
    if roguelike_runtime == null:
        return {}
    return roguelike_runtime.extraction_summary()

func can_pay(bundle: Dictionary) -> bool:
    for key in bundle.keys():
        if int(inventory.get(key, 0)) < int(bundle[key]):
            return false
    return true

func consume_bundle(bundle: Dictionary) -> Dictionary:
    var missing: Array[String] = []
    for key in bundle.keys():
        var need := int(bundle[key])
        var have := int(inventory.get(key, 0))
        if have < need:
            missing.append(str(key))
            inventory[key] = 0
            resource_shortage.emit(str(key))
        else:
            inventory[key] = have - need
    inventory_changed.emit(inventory.duplicate(true))
    return {"success": missing.is_empty(), "missing": missing}

func add_resource(resource_id: String, amount: int) -> int:
    if amount <= 0:
        return int(inventory.get(resource_id, craft_resources.get(resource_id, 0)))
    var maxima: Dictionary = rules.get("maxima", {})
    if maxima.has(resource_id):
        inventory[resource_id] = min(int(maxima[resource_id]), int(inventory.get(resource_id, 0)) + amount)
        inventory_changed.emit(inventory.duplicate(true))
        return int(inventory[resource_id])
    craft_resources[resource_id] = int(craft_resources.get(resource_id, 0)) + amount
    return int(craft_resources[resource_id])

func use_campfire() -> Dictionary:
    var cost: Dictionary = rules.get("campfire_cost", {})
    if not can_pay(cost):
        return {"success": false, "reason": "insufficient_resources", "missing": _missing_for(cost)}
    consume_bundle(cost)
    var light_restore := int(rules.get("campfire_effects", {}).get("light_restore", 0))
    if light_restore > 0:
        add_resource("light", light_restore)
    return {"success": true, "effects": rules.get("campfire_effects", {}).duplicate(true)}

func cross_dense_ash() -> Dictionary:
    var ash_rules: Dictionary = rules.get("ash_pressure", {})
    var cost := int(ash_rules.get("light_cost_on_dense_crossing", 0))
    if cost <= 0:
        return {"success": true, "stress": 0}
    if int(inventory.get("light", 0)) >= cost:
        inventory["light"] = int(inventory.get("light", 0)) - cost
        inventory_changed.emit(inventory.duplicate(true))
        return {"success": true, "stress": 0}
    var stress := int(ash_rules.get("stress_on_unlit_crossing", 0))
    apply_pressure(stress, "dense_ash_without_light")
    return {"success": true, "stress": stress}

func apply_pressure(amount: int, source: String) -> void:
    if amount <= 0:
        return
    for hero in GameState.party:
        if int(hero.get("hp", 0)) <= 0:
            continue
        var bonuses: Dictionary = EquipmentManager.bonuses_for_hero(str(hero.get("id", "")))
        var fear_amount: int = maxi(0, amount - int(bonuses.get("fear_resistance", 0)))
        if hero.has("fear"):
            hero["fear"] = min(100, int(hero.get("fear", 0)) + fear_amount)
        if hero.has("madness") and int(hero.get("fear", 0)) >= 80:
            var madness_cap: int = 100 + int(bonuses.get("max_madness", 0))
            var madness_amount: int = maxi(0, max(1, amount / 2) - int(bonuses.get("madness_resistance", 0)))
            hero["madness"] = min(madness_cap, int(hero.get("madness", 0)) + madness_amount)
    pressure_applied.emit(amount, source)
    GameState.state_changed.emit()

func reduce_pressure(amount: int) -> void:
    if amount <= 0:
        return
    for hero in GameState.party:
        if hero.has("fear"):
            hero["fear"] = max(0, int(hero.get("fear", 0)) - amount)
        if hero.has("madness"):
            hero["madness"] = max(0, int(hero.get("madness", 0)) - max(1, amount / 3))
    GameState.state_changed.emit()

func harvest_corpse(corpse_type: String, rng: RandomNumberGenerator = null) -> Array:
    var tables: Dictionary = rules.get("corpse_harvest", {})
    if not tables.has(corpse_type):
        return []
    var local_rng := rng
    if local_rng == null:
        local_rng = RandomNumberGenerator.new()
        local_rng.randomize()
    var drops: Array = []
    for drop in tables[corpse_type]:
        var amount := local_rng.randi_range(int(drop.get("min", 0)), int(drop.get("max", 0)))
        if amount <= 0:
            continue
        var item_id := str(drop.get("item", ""))
        add_resource(item_id, amount)
        drops.append({"item": item_id, "amount": amount, "label": str(drop.get("label", item_id))})
    return drops

func _missing_for(bundle: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for key in bundle.keys():
        if int(inventory.get(key, 0)) < int(bundle[key]):
            result.append(str(key))
    return result

func serialize() -> Dictionary:
    return {
        "inventory": inventory,
        "craft_resources": craft_resources,
        "expedition_active": expedition_active,
        "expedition_seed": expedition_seed,
        "zones_entered_this_run": zones_entered_this_run,
        "roguelike": roguelike_runtime.serialize() if roguelike_runtime != null else {}
    }

func deserialize(data: Dictionary) -> void:
    inventory = data.get("inventory", rules.get("expedition_inventory", {})).duplicate(true)
    craft_resources = data.get("craft_resources", {}).duplicate(true)
    expedition_active = bool(data.get("expedition_active", false))
    expedition_seed = int(data.get("expedition_seed", 0))
    zones_entered_this_run.assign(data.get("zones_entered_this_run", []))
    if roguelike_runtime != null:
        roguelike_runtime.deserialize(data.get("roguelike", {}))
    inventory_changed.emit(inventory.duplicate(true))
