extends RefCounted
class_name VeilleursRefugeRuntime

const DATA_PATH := "res://data/veilleurs/v06/refuge_economy.json"

var rules: Dictionary = {}
var resources := {"gold": 120, "materials": 0, "essence": 0}
var building_levels: Dictionary = {}

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else {}
    rules = parsed if parsed is Dictionary else {}
    for value: Variant in rules.get("buildings", []):
        if value is Dictionary:
            building_levels[str((value as Dictionary).get("building_id", ""))] = 1

func building(building_id: String) -> Dictionary:
    for value: Variant in rules.get("buildings", []):
        if value is Dictionary and str((value as Dictionary).get("building_id", "")) == building_id:
            return (value as Dictionary).duplicate(true)
    return {}

func current_level(building_id: String) -> int:
    return int(building_levels.get(building_id, 0))

func level_definition(building_id: String, level: int = -1) -> Dictionary:
    var target_level := current_level(building_id) if level < 0 else level
    for value: Variant in building(building_id).get("levels", []):
        if value is Dictionary and int((value as Dictionary).get("level", 0)) == target_level:
            return (value as Dictionary).duplicate(true)
    return {}

func next_upgrade(building_id: String) -> Dictionary:
    return level_definition(building_id, current_level(building_id) + 1)

func can_upgrade(building_id: String) -> bool:
    var upgrade := next_upgrade(building_id)
    if upgrade.is_empty():
        return false
    return int(resources.get("gold", 0)) >= int(upgrade.get("gold_cost", 0)) and int(resources.get("materials", 0)) >= int(upgrade.get("materials_cost", 0))

func upgrade(building_id: String) -> Dictionary:
    var upgrade_def := next_upgrade(building_id)
    if upgrade_def.is_empty():
        return {"ok": false, "reason": "max_level"}
    if not can_upgrade(building_id):
        return {"ok": false, "reason": "insufficient_resources", "required": upgrade_def}
    resources["gold"] = int(resources.get("gold", 0)) - int(upgrade_def.get("gold_cost", 0))
    resources["materials"] = int(resources.get("materials", 0)) - int(upgrade_def.get("materials_cost", 0))
    building_levels[building_id] = int(upgrade_def.get("level", current_level(building_id)))
    return {"ok": true, "building_id": building_id, "level": current_level(building_id), "unlocks": (upgrade_def.get("unlocks", {}) as Dictionary).duplicate(true)}

func recruit_slots() -> int:
    var quarters := level_definition("BUILDING_QUARTERS")
    return int((quarters.get("unlocks", {}) as Dictionary).get("recruit_slots", 6))

func add_rewards(gold: int, materials: int = 0, essence: int = 0) -> void:
    resources["gold"] = maxi(0, int(resources.get("gold", 0)) + gold)
    resources["materials"] = maxi(0, int(resources.get("materials", 0)) + materials)
    resources["essence"] = maxi(0, int(resources.get("essence", 0)) + essence)

func available_unlocks() -> Dictionary:
    var result: Dictionary = {}
    for building_id_value: Variant in building_levels.keys():
        var definition := level_definition(str(building_id_value))
        for key_value: Variant in (definition.get("unlocks", {}) as Dictionary).keys():
            result[str(key_value)] = (definition.get("unlocks", {}) as Dictionary).get(key_value)
    return result

func serialize() -> Dictionary:
    return {"resources": resources.duplicate(true), "building_levels": building_levels.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    resources = (payload.get("resources", resources) as Dictionary).duplicate(true)
    building_levels = (payload.get("building_levels", building_levels) as Dictionary).duplicate(true)
