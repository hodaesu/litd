extends "res://scripts/core/content_db.gd"
class_name VeilleursContentDBV07

const V07_ROOT := "res://data/veilleurs/v07"
const ENEMY_TREE_PATH := V07_ROOT + "/enemy_tree_catalog.json"
const ENEMY_PROFILE_PATH := V07_ROOT + "/enemy_skill_profiles.json"
const BOSSES_PATH := V07_ROOT + "/bosses_5_definitions.json"
const BOSS_TREE_PATH := V07_ROOT + "/boss_tree_catalog.json"
const RECRUITMENT_PATH := V07_ROOT + "/recruitment_rules.json"
const PROGRESSION_PATH := V07_ROOT + "/progression_1_50.json"
const ARCHIVES_PATH := V07_ROOT + "/archives_system.json"
const ECONOMY_PATH := V07_ROOT + "/economy_refuge_rules.json"
const KHAR_SEN_PATH := V07_ROOT + "/dungeon_khar_sen_expanded.json"
const DUNGEON_ROADMAP_PATH := V07_ROOT + "/dungeon_roadmap.json"

var bosses_by_id: Dictionary = {}
var enemy_trees_by_id: Dictionary = {}
var boss_trees_by_id: Dictionary = {}
var production_skills_by_id: Dictionary = {}
var production_skills_by_entity: Dictionary = {}
var enemy_skill_profiles: Dictionary = {}
var recruitment: Dictionary = {}
var progression: Dictionary = {}
var archives: Dictionary = {}
var economy: Dictionary = {}
var khar_sen: Dictionary = {}
var dungeon_roadmap: Dictionary = {}
var production_load_errors: Array[String] = []

func reload() -> void:
    super.reload()
    _load_v07()

func boss(entity_id: String) -> Dictionary:
    return (bosses_by_id.get(entity_id, {}) as Dictionary).duplicate(true)

func production_skill(skill_id: String) -> Dictionary:
    return (production_skills_by_id.get(skill_id, {}) as Dictionary).duplicate(true)

func production_skills_for(entity_id: String) -> Array:
    return (production_skills_by_entity.get(entity_id, []) as Array).duplicate(true)

func enemy_tree(tree_id: String) -> Dictionary:
    return (enemy_trees_by_id.get(tree_id, {}) as Dictionary).duplicate(true)

func boss_tree(tree_id: String) -> Dictionary:
    return (boss_trees_by_id.get(tree_id, {}) as Dictionary).duplicate(true)

func production_summary() -> Dictionary:
    return {
        "watchers": watchers_by_id.size(),
        "standard_enemies": enemies_by_id.size(),
        "bosses": bosses_by_id.size(),
        "watcher_skills": skills_by_id.size(),
        "enemy_trees": enemy_trees_by_id.size(),
        "enemy_skills": _count_skills_for_prefix("ENT_ENEMY_"),
        "boss_trees": boss_trees_by_id.size(),
        "boss_skills": _count_skills_for_prefix("ENT_BOSS_"),
        "all_normal_skills": skills_by_id.size() + production_skills_by_id.size(),
        "khar_sen_nodes": (khar_sen.get("nodes", []) as Array).size(),
        "planned_dungeons": (dungeon_roadmap.get("dungeons", []) as Array).size(),
        "errors": production_load_errors.duplicate()
    }

func _load_v07() -> void:
    bosses_by_id.clear()
    enemy_trees_by_id.clear()
    boss_trees_by_id.clear()
    production_skills_by_id.clear()
    production_skills_by_entity.clear()
    production_load_errors.clear()

    var profiles_payload := _load_v07_dictionary(ENEMY_PROFILE_PATH)
    enemy_skill_profiles = (profiles_payload.get("profiles", {}) as Dictionary).duplicate(true)
    _index_v07_entities(_load_v07_dictionary(BOSSES_PATH).get("bosses", []), bosses_by_id)

    var enemy_tree_payload := _load_v07_dictionary(ENEMY_TREE_PATH)
    var enemy_unlocks: Array = enemy_tree_payload.get("unlock_levels", [])
    _load_production_trees(enemy_tree_payload.get("trees", []), enemy_unlocks, enemy_trees_by_id, false)

    var boss_tree_payload := _load_v07_dictionary(BOSS_TREE_PATH)
    var boss_unlocks: Array = boss_tree_payload.get("unlock_levels", [])
    _load_production_trees(boss_tree_payload.get("trees", []), boss_unlocks, boss_trees_by_id, true)

    recruitment = _load_v07_dictionary(RECRUITMENT_PATH)
    progression = _load_v07_dictionary(PROGRESSION_PATH)
    archives = _load_v07_dictionary(ARCHIVES_PATH)
    economy = _load_v07_dictionary(ECONOMY_PATH)
    khar_sen = _load_v07_dictionary(KHAR_SEN_PATH)
    dungeon_roadmap = _load_v07_dictionary(DUNGEON_ROADMAP_PATH)
    _validate_v07()

func _load_production_trees(values: Array, unlock_levels: Array, destination: Dictionary, boss_catalog: bool) -> void:
    if unlock_levels.size() != 15:
        production_load_errors.append("invalid_unlock_schedule")
        return
    for value: Variant in values:
        if not (value is Dictionary):
            production_load_errors.append("tree_not_dictionary")
            continue
        var tree: Dictionary = (value as Dictionary).duplicate(true)
        var tree_id := str(tree.get("tree_id", ""))
        var entity_id := str(tree.get("entity_id", ""))
        var profile_id := str(tree.get("profile", ""))
        var prefix := str(tree.get("prefix", ""))
        if tree_id == "" or entity_id == "" or profile_id == "" or prefix == "":
            production_load_errors.append("invalid_tree_identity:%s" % tree_id)
            continue
        if destination.has(tree_id):
            production_load_errors.append("duplicate_tree:%s" % tree_id)
            continue
        if boss_catalog and not bosses_by_id.has(entity_id):
            production_load_errors.append("unknown_boss_tree_owner:%s" % entity_id)
            continue
        if not boss_catalog and not enemies_by_id.has(entity_id):
            production_load_errors.append("unknown_enemy_tree_owner:%s" % entity_id)
            continue
        var profile: Dictionary = enemy_skill_profiles.get(profile_id, {})
        if profile.is_empty():
            production_load_errors.append("missing_profile:%s" % profile_id)
            continue
        var names: Array = profile.get("names", [])
        var activations: Array = profile.get("activation", [])
        var actions: Array = profile.get("action", [])
        if names.size() != 15 or activations.size() != 15 or actions.size() != 15:
            production_load_errors.append("invalid_profile_shape:%s" % profile_id)
            continue
        destination[tree_id] = tree
        for index in range(15):
            var skill := {
                "skill_id": "%s_%02d" % [prefix, index + 1],
                "entity_id": entity_id,
                "tree_id": tree_id,
                "skill_index": index + 1,
                "unlock_level": int(unlock_levels[index]),
                "name_fr": "%s — %s" % [str(names[index]), str(tree.get("name_fr", tree_id))],
                "mechanical_profile": profile_id,
                "activation_type": str(activations[index]),
                "action_type": str(actions[index]),
                "range": int(profile.get("range", 1)),
                "body_bias": str(profile.get("body_bias", "torso")),
                "ai_tags": (profile.get("ai_tags", []) as Array).duplicate(),
                "tier": 1 + int(index / 3),
                "effect_scale": 1.0 + float(index) / 20.0,
                "boss_skill": boss_catalog
            }
            _index_production_skill(skill)

func _index_production_skill(skill: Dictionary) -> void:
    var skill_id := str(skill.get("skill_id", ""))
    var entity_id := str(skill.get("entity_id", ""))
    if production_skills_by_id.has(skill_id):
        production_load_errors.append("duplicate_production_skill:%s" % skill_id)
        return
    production_skills_by_id[skill_id] = skill
    if not production_skills_by_entity.has(entity_id):
        production_skills_by_entity[entity_id] = []
    (production_skills_by_entity[entity_id] as Array).append(skill)

func _index_v07_entities(values: Array, destination: Dictionary) -> void:
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var entity_id := str(row.get("entity_id", ""))
        if entity_id == "" or destination.has(entity_id):
            production_load_errors.append("invalid_v07_entity:%s" % entity_id)
            continue
        destination[entity_id] = row

func _validate_v07() -> void:
    if bosses_by_id.size() != 5:
        production_load_errors.append("boss_count:%d" % bosses_by_id.size())
    if enemy_trees_by_id.size() != 72:
        production_load_errors.append("enemy_tree_count:%d" % enemy_trees_by_id.size())
    if boss_trees_by_id.size() != 15:
        production_load_errors.append("boss_tree_count:%d" % boss_trees_by_id.size())
    if _count_skills_for_prefix("ENT_ENEMY_") != 1080:
        production_load_errors.append("enemy_skill_count")
    if _count_skills_for_prefix("ENT_BOSS_") != 225:
        production_load_errors.append("boss_skill_count")
    for entity_id_value: Variant in enemies_by_id.keys():
        var entity_id := str(entity_id_value)
        if _tree_count_for(entity_id, enemy_trees_by_id) != 3:
            production_load_errors.append("enemy_tree_partition:%s" % entity_id)
        if (production_skills_by_entity.get(entity_id, []) as Array).size() != 45:
            production_load_errors.append("enemy_skill_partition:%s" % entity_id)
    for entity_id_value: Variant in bosses_by_id.keys():
        var entity_id := str(entity_id_value)
        if _tree_count_for(entity_id, boss_trees_by_id) != 3:
            production_load_errors.append("boss_tree_partition:%s" % entity_id)
        if (production_skills_by_entity.get(entity_id, []) as Array).size() != 45:
            production_load_errors.append("boss_skill_partition:%s" % entity_id)
        if bool((bosses_by_id[entity_id] as Dictionary).get("recruitable", true)):
            production_load_errors.append("boss_recruitable:%s" % entity_id)
    if int(progression.get("level_cap", 0)) != 50:
        production_load_errors.append("progression_level_cap")
    if int(recruitment.get("max_recruits_per_expedition", 0)) != 2:
        production_load_errors.append("recruitment_expedition_cap")
    if int(recruitment.get("refuge_recruit_cap", 0)) != 12:
        production_load_errors.append("recruitment_refuge_cap")
    if (khar_sen.get("nodes", []) as Array).size() != 18:
        production_load_errors.append("khar_sen_node_count")
    if (dungeon_roadmap.get("dungeons", []) as Array).size() != 6:
        production_load_errors.append("dungeon_roadmap_count")

func _tree_count_for(entity_id: String, trees: Dictionary) -> int:
    var count := 0
    for tree_value: Variant in trees.values():
        if tree_value is Dictionary and str((tree_value as Dictionary).get("entity_id", "")) == entity_id:
            count += 1
    return count

func _count_skills_for_prefix(prefix: String) -> int:
    var count := 0
    for entity_id_value: Variant in production_skills_by_entity.keys():
        if str(entity_id_value).begins_with(prefix):
            count += (production_skills_by_entity[entity_id_value] as Array).size()
    return count

func _load_v07_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        production_load_errors.append("missing:%s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        production_load_errors.append("invalid_json:%s" % path)
        return {}
    return parsed as Dictionary
