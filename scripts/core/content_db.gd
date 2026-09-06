extends Node

const ROOT := "res://data/veilleurs/v06"
const WATCHERS_PATH := ROOT + "/watchers.json"
const ENEMIES_PATH := ROOT + "/enemies_24_definitions.json"
const CONSTANTS_PATH := ROOT + "/combat_constants.json"
const LOADOUTS_PATH := ROOT + "/starter_loadouts_watchers.json"
const SKILL_PATHS: Array[String] = [
    ROOT + "/sahen_skills.json",
    ROOT + "/mira_skills.json",
    ROOT + "/narem_skills.json",
    ROOT + "/ysra_skills.json"
]

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
    for path: String in SKILL_PATHS:
        var payload := _load_dictionary(path)
        for value: Variant in payload.get("skills", []):
            if not (value is Dictionary):
                continue
            var skill: Dictionary = (value as Dictionary).duplicate(true)
            var skill_id := str(skill.get("skill_id", ""))
            var entity_id := str(skill.get("entity_id", ""))
            if skill_id == "" or entity_id == "":
                load_errors.append("invalid_skill:%s" % path)
                continue
            if skills_by_id.has(skill_id):
                load_errors.append("duplicate_skill:%s" % skill_id)
                continue
            skills_by_id[skill_id] = skill
            if not skills_by_entity.has(entity_id):
                skills_by_entity[entity_id] = []
            (skills_by_entity[entity_id] as Array).append(skill)
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
