extends RefCounted
class_name VeilleursRefugeRuntime

const DATA_PATH := "res://data/veilleurs/v06/refuge_economy.json"

var rules: Dictionary = {}
var v07_rules: Dictionary = {}
var resources := {"gold": 120, "materials": 0, "essence": 0}
var building_levels: Dictionary = {}
var recruits: Array = []
var expeditions_completed := 0
var emergency_cooldown := 0

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else {}
    rules = parsed if parsed is Dictionary else {}
    for value: Variant in rules.get("buildings", []):
        if value is Dictionary:
            building_levels[str((value as Dictionary).get("building_id", ""))] = 1

func configure_v07(value: Dictionary) -> void:
    v07_rules = value.duplicate(true)

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
    var upgrade_def := next_upgrade(building_id)
    if upgrade_def.is_empty() or not _dependencies_met(building_id):
        return false
    return int(resources.get("gold", 0)) >= int(upgrade_def.get("gold_cost", 0)) and int(resources.get("materials", 0)) >= int(upgrade_def.get("materials_cost", 0))

func upgrade(building_id: String) -> Dictionary:
    var upgrade_def := next_upgrade(building_id)
    if upgrade_def.is_empty():
        return {"ok": false, "reason": "max_level"}
    if not _dependencies_met(building_id):
        return {"ok": false, "reason": "dependency"}
    if not can_upgrade(building_id):
        return {"ok": false, "reason": "insufficient_resources", "required": upgrade_def}
    resources["gold"] = int(resources.get("gold", 0)) - int(upgrade_def.get("gold_cost", 0))
    resources["materials"] = int(resources.get("materials", 0)) - int(upgrade_def.get("materials_cost", 0))
    building_levels[building_id] = int(upgrade_def.get("level", current_level(building_id)))
    return {"ok": true, "building_id": building_id, "level": current_level(building_id), "unlocks": (upgrade_def.get("unlocks", {}) as Dictionary).duplicate(true)}

func recruit_slots() -> int:
    var quarters := level_definition("BUILDING_QUARTERS")
    return int((quarters.get("unlocks", {}) as Dictionary).get("recruit_slots", 6))

func recruit_slots_free() -> int:
    return maxi(0, recruit_slots() - recruits.size())

func can_add_recruit() -> bool:
    var hard_cap := 12 if v07_rules.is_empty() else 12
    return recruits.size() < mini(recruit_slots(), hard_cap)

func add_recruit(recruit: Dictionary) -> Dictionary:
    if not can_add_recruit():
        return {"ok":false, "reason":"recruit_capacity"}
    recruits.append(recruit.duplicate(true))
    return {"ok":true, "recruit_count":recruits.size(), "slots_free":recruit_slots_free()}

func add_rewards(gold: int, materials: int = 0, essence: int = 0) -> void:
    resources["gold"] = maxi(0, int(resources.get("gold", 0)) + gold)
    resources["materials"] = maxi(0, int(resources.get("materials", 0)) + materials)
    resources["essence"] = maxi(0, int(resources.get("essence", 0)) + essence)

func complete_expedition(gold: int, materials: int = 0, essence: int = 0) -> void:
    add_rewards(gold, materials, essence)
    expeditions_completed += 1
    emergency_cooldown = maxi(0, emergency_cooldown - 1)

func pay_service(service_id: String) -> Dictionary:
    var costs: Dictionary = rules.get("service_costs", {})
    if not costs.has(service_id):
        return {"ok":false, "reason":"unknown_service"}
    var cost := int(costs.get(service_id, 0))
    if int(resources.get("gold", 0)) < cost:
        return {"ok":false, "reason":"insufficient_resources", "required":cost}
    resources["gold"] = int(resources.get("gold", 0)) - cost
    return {"ok":true, "cost":cost}

func emergency_recovery(has_usable_common_gear: bool) -> Dictionary:
    if v07_rules.is_empty():
        return {"ok":false, "reason":"v07_rules_not_configured"}
    if emergency_cooldown > 0:
        return {"ok":false, "reason":"cooldown"}
    if int(resources.get("gold", 0)) >= 80 or has_usable_common_gear:
        return {"ok":false, "reason":"not_softlocked"}
    var emergency: Dictionary = v07_rules.get("emergency_reserve", {})
    var grant: Dictionary = emergency.get("grant", {})
    resources["gold"] = int(resources.get("gold", 0)) + int(grant.get("gold", 0))
    resources["materials"] = int(resources.get("materials", 0)) + int(grant.get("materials", 0))
    emergency_cooldown = int(emergency.get("cooldown_expeditions", 3))
    return {"ok":true, "grant":grant.duplicate(true), "cooldown":emergency_cooldown}

func available_unlocks() -> Dictionary:
    var result: Dictionary = {}
    for building_id_value: Variant in building_levels.keys():
        var definition := level_definition(str(building_id_value))
        for key_value: Variant in (definition.get("unlocks", {}) as Dictionary).keys():
            result[str(key_value)] = (definition.get("unlocks", {}) as Dictionary).get(key_value)
    return result

func serialize() -> Dictionary:
    return {
        "resources": resources.duplicate(true),
        "building_levels": building_levels.duplicate(true),
        "recruits": recruits.duplicate(true),
        "expeditions_completed": expeditions_completed,
        "emergency_cooldown": emergency_cooldown
    }

func deserialize(payload: Dictionary) -> void:
    resources = (payload.get("resources", resources) as Dictionary).duplicate(true)
    building_levels = (payload.get("building_levels", building_levels) as Dictionary).duplicate(true)
    recruits = (payload.get("recruits", recruits) as Array).duplicate(true)
    expeditions_completed = int(payload.get("expeditions_completed", expeditions_completed))
    emergency_cooldown = int(payload.get("emergency_cooldown", emergency_cooldown))

func _dependencies_met(building_id: String) -> bool:
    if v07_rules.is_empty():
        return true
    var dependencies: Array = (v07_rules.get("building_dependencies", {}) as Dictionary).get(building_id, [])
    for dependency_value: Variant in dependencies:
        var parts := str(dependency_value).split(":")
        var dependency_id := str(parts[0])
        var required_level := int(parts[1]) if parts.size() > 1 else 1
        if current_level(dependency_id) < required_level:
            return false
    return true
