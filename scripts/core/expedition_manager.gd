extends Node

signal inventory_changed(inventory: Dictionary)
signal expedition_started(seed: int)
signal expedition_ended(return_reason: String)
signal resource_shortage(resource_id: String)

const RULES_PATH := "res://data/levels/ashlands_survival_rules.json"

var rules: Dictionary = {}
var inventory: Dictionary = {}
var craft_resources: Dictionary = {}
var expedition_active := false
var expedition_seed := 0
var zones_entered_this_run: Array[String] = []

func _ready() -> void:
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
    expedition_started.emit(expedition_seed)

func return_to_hub(reason: String = "voluntary") -> void:
    expedition_active = false
    zones_entered_this_run.clear()
    reset_to_full_resupply()
    expedition_ended.emit(reason)

func on_zone_entered(zone_id: String) -> Dictionary:
    if not expedition_active:
        start_expedition()
    if not zones_entered_this_run.has(zone_id):
        zones_entered_this_run.append(zone_id)
        return consume_bundle(rules.get("zone_entry_cost", {}))
    return {"success": true, "missing": []}

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
    return {"success": true, "stress": int(ash_rules.get("stress_on_unlit_crossing", 0))}

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
        "zones_entered_this_run": zones_entered_this_run
    }

func deserialize(data: Dictionary) -> void:
    inventory = data.get("inventory", rules.get("expedition_inventory", {})).duplicate(true)
    craft_resources = data.get("craft_resources", {}).duplicate(true)
    expedition_active = bool(data.get("expedition_active", false))
    expedition_seed = int(data.get("expedition_seed", 0))
    zones_entered_this_run.assign(data.get("zones_entered_this_run", []))
    inventory_changed.emit(inventory.duplicate(true))
