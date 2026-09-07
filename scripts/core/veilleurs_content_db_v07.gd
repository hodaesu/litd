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
const ULTIMATES_PATH := V07_ROOT + "/ultimates_99.json"
const DUNGEON_ROADMAP_PATH := V07_ROOT + "/dungeon_roadmap.json"
const DUNGEON_PATHS: Array[String] = [
    V07_ROOT + "/dungeon_khar_sen_expanded.json",
    V07_ROOT + "/dungeon_02_seuil_erode.json",
    V07_ROOT + "/dungeon_03_cloitre_voix.json",
    V07_ROOT + "/dungeon_04_jardin_mues.json",
    V07_ROOT + "/dungeon_tribunal_cendres.json",
    V07_ROOT + "/dungeon_archives_aveugles.json"
]

var bosses_by_id: Dictionary = {}
var enemy_trees_by_id: Dictionary = {}
var boss_trees_by_id: Dictionary = {}
var production_skills_by_id: Dictionary = {}
var production_skills_by_entity: Dictionary = {}
var enemy_skill_profiles: Dictionary = {}
var ultimates_by_id: Dictionary = {}
var ultimates_by_entity: Dictionary = {}
var dungeons_by_id: Dictionary = {}
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

func ultimate(ultimate_id: String) -> Dictionary:
    return (ultimates_by_id.get(ultimate_id, {}) as Dictionary).duplicate(true)

func ultimates_for(entity_id: String) -> Array:
    return (ultimates_by_entity.get(entity_id, []) as Array).duplicate(true)

func dungeon(dungeon_id: String) -> Dictionary:
    return (dungeons_by_id.get(dungeon_id, {}) as Dictionary).duplicate(true)

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
        "ultimates": ultimates_by_id.size(),
        "dungeons": dungeons_by_id.size(),
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
    ultimates_by_id.clear()
    ultimates_by_entity.clear()
    dungeons_by_id.clear()
    production_load_errors.clear()

    var profiles_payload: Dictionary = _load_v07_dictionary(ENEMY_PROFILE_PATH)
    enemy_skill_profiles = (profiles_payload.get("profiles", {}) as Dictionary).duplicate(true)
    _index_v07_entities(_load_v07_dictionary(BOSSES_PATH).get("bosses", []), bosses_by_id)

    var enemy_tree_payload: Dictionary = _load_v07_dictionary(ENEMY_TREE_PATH)
    var enemy_unlocks: Array = enemy_tree_payload.get("unlock_levels", [])
    _load_production_trees(enemy_tree_payload.get("trees", []), enemy_unlocks, enemy_trees_by_id, false)

    var boss_tree_payload: Dictionary = _load_v07_dictionary(BOSS_TREE_PATH)
    var boss_unlocks: Array = boss_tree_payload.get("unlock_levels", [])
    _load_production_trees(boss_tree_payload.get("trees", []), boss_unlocks, boss_trees_by_id, true)

    recruitment = _load_v07_dictionary(RECRUITMENT_PATH)
    progression = _load_v07_dictionary(PROGRESSION_PATH)
    archives = _load_v07_dictionary(ARCHIVES_PATH)
    economy = _load_v07_dictionary(ECONOMY_PATH)
    dungeon_roadmap = _load_v07_dictionary(DUNGEON_ROADMAP_PATH)
    _load_ultimates()
    _load_dungeons()
    khar_sen = dungeon("DUNGEON_KHAR_SEN")
    _validate_v07()

func _load_ultimates() -> void:
    var payload: Dictionary = _load_v07_dictionary(ULTIMATES_PATH)
    for value: Variant in payload.get("ultimates", []):
        if not (value is Dictionary):
            production_load_errors.append("ultimate_not_dictionary")
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var ultimate_id: String = str(row.get("ultimate_id", ""))
        var entity_id: String = str(row.get("entity_id", ""))
        var slot: int = int(row.get("tree_slot", 0))
        if ultimate_id == "" or entity_id == "" or slot < 1 or slot > 3:
            production_load_errors.append("invalid_ultimate:%s" % ultimate_id)
            continue
        if ultimates_by_id.has(ultimate_id):
            production_load_errors.append("duplicate_ultimate:%s" % ultimate_id)
            continue
        if not watchers_by_id.has(entity_id) and not enemies_by_id.has(entity_id) and not bosses_by_id.has(entity_id):
            production_load_errors.append("unknown_ultimate_owner:%s" % entity_id)
            continue
        ultimates_by_id[ultimate_id] = row
        if not ultimates_by_entity.has(entity_id):
            ultimates_by_entity[entity_id] = []
        (ultimates_by_entity[entity_id] as Array).append(row)

func _load_dungeons() -> void:
    for path: String in DUNGEON_PATHS:
        var payload: Dictionary = _load_v07_dictionary(path)
        var dungeon_id: String = str(payload.get("dungeon_id", ""))
        if dungeon_id == "":
            production_load_errors.append("dungeon_without_id:%s" % path)
            continue
        if dungeons_by_id.has(dungeon_id):
            production_load_errors.append("duplicate_dungeon:%s" % dungeon_id)
            continue
        dungeons_by_id[dungeon_id] = payload

func _load_production_trees(values: Array, unlock_levels: Array, destination: Dictionary, boss_catalog: bool) -> void:
    if unlock_levels.size() != 15:
        production_load_errors.append("invalid_unlock_schedule")
        return
    for value: Variant in values:
        if not (value is Dictionary):
            production_load_errors.append("tree_not_dictionary")
            continue
        var tree: Dictionary = (value as Dictionary).duplicate(true)
        var tree_id: String = str(tree.get("tree_id", ""))
        var entity_id: String = str(tree.get("entity_id", ""))
        var profile_id: String = str(tree.get("profile", ""))
        var prefix: String = str(tree.get("prefix", ""))
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
        for index: int in range(15):
            var skill: Dictionary = {
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
    var skill_id: String = str(skill.get("skill_id", ""))
    var entity_id: String = str(skill.get("entity_id", ""))
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
        var entity_id: String = str(row.get("entity_id", ""))
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
    if ultimates_by_id.size() != 99:
        production_load_errors.append("ultimate_count:%d" % ultimates_by_id.size())
    if dungeons_by_id.size() != 6:
        production_load_errors.append("dungeon_count:%d" % dungeons_by_id.size())

    for entity_id_value: Variant in enemies_by_id.keys():
        var entity_id: String = str(entity_id_value)
        if _tree_count_for(entity_id, enemy_trees_by_id) != 3:
            production_load_errors.append("enemy_tree_partition:%s" % entity_id)
        if (production_skills_by_entity.get(entity_id, []) as Array).size() != 45:
            production_load_errors.append("enemy_skill_partition:%s" % entity_id)
        _validate_entity_ultimates(entity_id, true)

    for entity_id_value: Variant in bosses_by_id.keys():
        var entity_id: String = str(entity_id_value)
        if _tree_count_for(entity_id, boss_trees_by_id) != 3:
            production_load_errors.append("boss_tree_partition:%s" % entity_id)
        if (production_skills_by_entity.get(entity_id, []) as Array).size() != 45:
            production_load_errors.append("boss_skill_partition:%s" % entity_id)
        if bool((bosses_by_id[entity_id] as Dictionary).get("recruitable", true)):
            production_load_errors.append("boss_recruitable:%s" % entity_id)
        _validate_entity_ultimates(entity_id, true)

    for entity_id_value: Variant in watchers_by_id.keys():
        _validate_entity_ultimates(str(entity_id_value), false)

    for dungeon_value: Variant in dungeons_by_id.values():
        if dungeon_value is Dictionary:
            _validate_dungeon_graph(dungeon_value as Dictionary)

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

func _validate_entity_ultimates(entity_id: String, must_telegraph: bool) -> void:
    var values: Array = ultimates_by_entity.get(entity_id, [])
    if values.size() != 3:
        production_load_errors.append("ultimate_partition:%s" % entity_id)
        return
    var slots: Array[int] = []
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var row: Dictionary = value
        slots.append(int(row.get("tree_slot", 0)))
        if int(row.get("unlock_level", 0)) != 16:
            production_load_errors.append("ultimate_unlock:%s" % str(row.get("ultimate_id", "")))
        if must_telegraph and not bool(row.get("telegraph_required", false)):
            production_load_errors.append("ultimate_not_telegraphed:%s" % str(row.get("ultimate_id", "")))
        if must_telegraph and not bool(row.get("counterplay_required", false)):
            production_load_errors.append("ultimate_without_counterplay:%s" % str(row.get("ultimate_id", "")))
    slots.sort()
    if slots != [1, 2, 3]:
        production_load_errors.append("ultimate_slots:%s" % entity_id)

func _validate_dungeon_graph(payload: Dictionary) -> void:
    var dungeon_id: String = str(payload.get("dungeon_id", ""))
    var entry_node: String = str(payload.get("entry_node", ""))
    var nodes: Array = payload.get("nodes", [])
    var node_ids: Dictionary = {}
    var allowed_bands: Array[String] = ["LOW", "STANDARD", "HIGH", "SEVERE"]
    for value: Variant in nodes:
        if not (value is Dictionary):
            production_load_errors.append("dungeon_node_invalid:%s" % dungeon_id)
            continue
        var node: Dictionary = value
        var node_id: String = str(node.get("node_id", ""))
        if node_id == "" or node_ids.has(node_id):
            production_load_errors.append("dungeon_node_id:%s:%s" % [dungeon_id, node_id])
            continue
        node_ids[node_id] = true
        if bool(node.get("encounter", false)) and str(node.get("kind", "")) != "boss":
            var band: String = str(node.get("band", ""))
            var variant: int = int(node.get("variant", 0))
            if not allowed_bands.has(band):
                production_load_errors.append("dungeon_band:%s:%s" % [dungeon_id, node_id])
            if variant < 1 or variant > 2:
                production_load_errors.append("dungeon_variant:%s:%s" % [dungeon_id, node_id])
    if entry_node == "" or not node_ids.has(entry_node):
        production_load_errors.append("dungeon_entry:%s" % dungeon_id)
    for value: Variant in nodes:
        if not (value is Dictionary):
            continue
        var node: Dictionary = value
        for next_value: Variant in node.get("next", []):
            var next_id: String = str(next_value)
            if not node_ids.has(next_id):
                production_load_errors.append("dungeon_orphan_link:%s:%s" % [dungeon_id, next_id])
        if str(node.get("kind", "")) == "boss":
            var boss_id: String = str(node.get("boss_id", payload.get("boss_id", "")))
            if boss_id == "" or not bosses_by_id.has(boss_id):
                production_load_errors.append("dungeon_boss_ref:%s" % dungeon_id)

func _tree_count_for(entity_id: String, trees: Dictionary) -> int:
    var count: int = 0
    for tree_value: Variant in trees.values():
        if tree_value is Dictionary and str((tree_value as Dictionary).get("entity_id", "")) == entity_id:
            count += 1
    return count

func _count_skills_for_prefix(prefix: String) -> int:
    var count: int = 0
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
