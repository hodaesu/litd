extends Node
class_name VeilleursContentDB

const ROOT := "res://data/veilleurs/v06"
const WATCHERS_PATH := ROOT + "/watchers.json"
const ENEMIES_PATH := ROOT + "/enemies_24_definitions.json"
const CONSTANTS_PATH := ROOT + "/combat_constants.json"
const LOADOUTS_PATH := ROOT + "/starter_loadouts_watchers.json"
const SKILL_CATALOG_PATH := ROOT + "/watcher_tree_catalog.json"

var watchers_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var skills_by_id: Dictionary = {}
var skills_by_entity: Dictionary = {}
var combat_constants: Dictionary = {}
var starter_loadouts: Dictionary = {}
var load_errors: Array[String] = []

func _ready() -> void:
    reload()

func reload() -> void:
    watchers_by_id.clear()
    enemies_by_id.clear()
    skills_by_id.clear()
    skills_by_entity.clear()
    load_errors.clear()
    combat_constants = _load_dictionary(CONSTANTS_PATH)
    starter_loadouts = _load_dictionary(LOADOUTS_PATH)
    _index_entities(_load_dictionary(WATCHERS_PATH).get("watchers", []), watchers_by_id)
    _index_entities(_load_dictionary(ENEMIES_PATH).get("enemies", []), enemies_by_id)
    _load_skill_catalog()
    _validate()

func watcher(entity_id: String) -> Dictionary:
    return (watchers_by_id.get(entity_id, {}) as Dictionary).duplicate(true)

func enemy(entity_id: String) -> Dictionary:
    return (enemies_by_id.get(entity_id, {}) as Dictionary).duplicate(true)

func entity(entity_id: String) -> Dictionary:
    if watchers_by_id.has(entity_id):
        return watcher(entity_id)
    return enemy(entity_id)

func skill(skill_id: String) -> Dictionary:
    return (skills_by_id.get(skill_id, {}) as Dictionary).duplicate(true)

func skills_for(entity_id: String) -> Array:
    return (skills_by_entity.get(entity_id, []) as Array).duplicate(true)

func starter_loadout(entity_id: String) -> Dictionary:
    return (starter_loadouts.get(entity_id, {}) as Dictionary).duplicate(true)

func summary() -> Dictionary:
    return {
        "watchers": watchers_by_id.size(),
        "enemies": enemies_by_id.size(),
        "skills": skills_by_id.size(),
        "watcher_skill_counts": _watcher_skill_counts(),
        "grid": combat_constants.get("grid", {}),
        "load_errors": load_errors.duplicate()
    }

func _load_skill_catalog() -> void:
    var payload := _load_dictionary(SKILL_CATALOG_PATH)
    var unlock_levels: Array = payload.get("unlock_levels", [])
    for tree_value: Variant in payload.get("trees", []):
        if not (tree_value is Dictionary):
            continue
        var tree: Dictionary = tree_value
        var entity_id := str(tree.get("entity_id", ""))
        var tree_id := str(tree.get("tree_id", ""))
        var prefix := str(tree.get("prefix", ""))
        var profile := str(tree.get("profile", "assault"))
        var names: Array = tree.get("names", [])
        var activations: Array = tree.get("activation", [])
        var actions: Array = tree.get("action", [])
        if names.size() != 15 or unlock_levels.size() != 15:
            load_errors.append("invalid_tree:%s" % tree_id)
            continue
        for index in range(15):
            var activation := str(activations[index]) if index < activations.size() else "active"
            var action := str(actions[index]) if index < actions.size() else "attack"
            var skill := {
                "skill_id": "%s_%02d" % [prefix, index + 1],
                "entity_id": entity_id,
                "tree_id": tree_id,
                "skill_index": index + 1,
                "unlock_level": int(unlock_levels[index]),
                "name_fr": str(names[index]),
                "mechanical_profile": profile,
                "activation_type": activation,
                "action_type": action,
                "target_type": _target_for(action),
                "precision_mod": _precision_for(profile, index),
                "dismemberment_rules": _dismemberment_for(profile, index),
                "effect_spec": _effect_for(profile, index)
            }
            _index_skill(skill)

func _index_skill(skill: Dictionary) -> void:
    var skill_id := str(skill.get("skill_id", ""))
    var entity_id := str(skill.get("entity_id", ""))
    if skill_id == "" or entity_id == "":
        load_errors.append("invalid_skill")
        return
    if skills_by_id.has(skill_id):
        load_errors.append("duplicate_skill:%s" % skill_id)
        return
    skills_by_id[skill_id] = skill
    if not skills_by_entity.has(entity_id):
        skills_by_entity[entity_id] = []
    (skills_by_entity[entity_id] as Array).append(skill)

func _target_for(action: String) -> String:
    if action in ["guard", "heal"]:
        return "self"
    if action == "support":
        return "ally_single"
    if action == "passive_modifier":
        return "none"
    return "enemy_single"

func _precision_for(profile: String, index: int) -> int:
    var tier: int = 1 + int(index / 3)
    match profile:
        "impact": return -4 + tier
        "anatomy": return 7 + tier
        "observe": return 3 + tier * 2
        "mobility": return 4 + tier
        "psych": return 5 + tier
        _: return 0

func _dismemberment_for(profile: String, index: int) -> Dictionary:
    var allowed := profile == "anatomy" and index >= 11
    return {"allowed": allowed, "min_body_state": "L4" if allowed else "", "power": 2 + int(index >= 12) + int(index >= 14) if allowed else 0}

func _effect_for(profile: String, index: int) -> Dictionary:
    var tier: int = 1 + int(index / 3)
    var scale := float(index) / 14.0
    var result := {"damage_multiplier": 0.0, "trauma_multiplier": 0.0, "forced_move": 0, "knowledge_reveal": 0, "guard_delta": 0, "resolve_delta": 0}
    match profile:
        "impact":
            result["damage_multiplier"] = 0.85 + 0.65 * scale
            result["trauma_multiplier"] = 1.15 + 0.65 * scale
            result["forced_move"] = 0 if index < 3 else (1 if index < 9 else 2)
        "anatomy":
            result["damage_multiplier"] = 0.65 + 0.45 * scale
            result["trauma_multiplier"] = 1.0 + 0.70 * scale
        "mobility":
            result["damage_multiplier"] = 0.65 + 0.50 * scale
            result["trauma_multiplier"] = 0.65 + 0.25 * scale
        "guard":
            result["guard_delta"] = 10 + tier * 5
        "sustain":
            result["guard_delta"] = 3 + tier * 2
        "support":
            result["guard_delta"] = 4 + tier * 2
            result["resolve_delta"] = 4 + tier * 2
        "observe":
            result["knowledge_reveal"] = mini(3, 1 + int(index >= 7) + int(index >= 12))
        "psych":
            result["resolve_delta"] = -(5 + tier * 3)
        _:
            result["damage_multiplier"] = 0.8 + 0.55 * scale
            result["trauma_multiplier"] = 0.85 + 0.40 * scale
    return result

func _index_entities(values: Array, destination: Dictionary) -> void:
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var entity_id := str(row.get("entity_id", ""))
        if entity_id == "":
            load_errors.append("entity_without_id")
            continue
        if destination.has(entity_id):
            load_errors.append("duplicate_entity:%s" % entity_id)
            continue
        destination[entity_id] = row

func _watcher_skill_counts() -> Dictionary:
    var result: Dictionary = {}
    for entity_id_value: Variant in watchers_by_id.keys():
        var entity_id := str(entity_id_value)
        result[entity_id] = (skills_by_entity.get(entity_id, []) as Array).size()
    return result

func _validate() -> void:
    if watchers_by_id.size() != 4:
        load_errors.append("watcher_count:%d" % watchers_by_id.size())
    if enemies_by_id.size() != 24:
        load_errors.append("enemy_count:%d" % enemies_by_id.size())
    if skills_by_id.size() != 180:
        load_errors.append("watcher_skill_count:%d" % skills_by_id.size())
    for entity_id_value: Variant in watchers_by_id.keys():
        var entity_id := str(entity_id_value)
        if (skills_by_entity.get(entity_id, []) as Array).size() != 45:
            load_errors.append("watcher_skill_partition:%s" % entity_id)
    var grid: Dictionary = combat_constants.get("grid", {})
    if int(grid.get("width", 0)) != 6 or int(grid.get("height", 0)) != 5:
        load_errors.append("grid_contract")

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        load_errors.append("missing:%s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        load_errors.append("invalid_json:%s" % path)
        return {}
    return parsed as Dictionary
