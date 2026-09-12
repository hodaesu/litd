extends Node

signal catalog_loaded(success: bool, report: Dictionary)

const MASTER_PATH := "res://data/veilleurs/v07/knowledge/master_knowledge_catalog_29.json"
const ENEMY_DEFINITIONS_PATH := "res://data/veilleurs/v06/enemies_24_definitions.json"
const BOSS_DEFINITIONS_PATH := "res://data/veilleurs/v07/bosses_5_definitions.json"
const ENEMY_TREE_CATALOG_PATH := "res://data/veilleurs/v07/enemy_tree_catalog.json"
const BOSS_TREE_CATALOG_PATH := "res://data/veilleurs/v07/boss_tree_catalog.json"

const EXPECTED_SCHEMA := "1.0.0-knowledge-phase-a"
const ACTIVE_ENTITY_ID := "ENT_ENEMY_GOULE_AFFAMEE"
const ACTIVE_FACT_ID := "FACT_GOULE_AFFAMEE_ODEUR_SANG"
const ACTIVE_HYPOTHESIS_ID := "HYP_GOULE_AFFAMEE_01"
const ACTIVE_POLICY_ID := "POLICY_GOULE_AFFAMEE_ODEUR_SANG"

var catalog: Dictionary = {}
var profiles_by_entity_id: Dictionary = {}
var fact_to_entity_id: Dictionary = {}
var unlock_to_entity_id: Dictionary = {}
var event_to_entities: Dictionary = {}
var validation_errors: Array[String] = []
var loaded := false

func _ready() -> void:
    load_catalog()

func load_catalog(force_reload: bool = false) -> bool:
    if loaded and not force_reload:
        return true
    _clear()
    var master_value: Variant = DataLoader.load_json(MASTER_PATH)
    var enemies_value: Variant = DataLoader.load_json(ENEMY_DEFINITIONS_PATH)
    var bosses_value: Variant = DataLoader.load_json(BOSS_DEFINITIONS_PATH)
    var enemy_trees_value: Variant = DataLoader.load_json(ENEMY_TREE_CATALOG_PATH)
    var boss_trees_value: Variant = DataLoader.load_json(BOSS_TREE_CATALOG_PATH)
    if not (master_value is Dictionary and enemies_value is Dictionary and bosses_value is Dictionary and enemy_trees_value is Dictionary and boss_trees_value is Dictionary):
        validation_errors.append("supporting_catalog_load_failed")
        catalog_loaded.emit(false, validation_report())
        return false
    catalog = (master_value as Dictionary).duplicate(true)
    validation_errors = validate_payloads(
        catalog,
        enemies_value as Dictionary,
        bosses_value as Dictionary,
        enemy_trees_value as Dictionary,
        boss_trees_value as Dictionary
    )
    if not validation_errors.is_empty():
        catalog_loaded.emit(false, validation_report())
        return false
    _build_indexes()
    loaded = true
    catalog_loaded.emit(true, validation_report())
    return true

func reload_catalog() -> bool:
    return load_catalog(true)

func validate_payloads(
    master: Dictionary,
    enemy_defs: Dictionary,
    boss_defs: Dictionary,
    enemy_trees: Dictionary,
    boss_trees: Dictionary
) -> Array[String]:
    var errors: Array[String] = []
    if str(master.get("schema_version", "")) != EXPECTED_SCHEMA:
        errors.append("unsupported_schema")
    var profiles: Array = master.get("profiles", []) if master.get("profiles", []) is Array else []
    if profiles.size() != 29:
        errors.append("wrong_profile_count:%d" % profiles.size())

    var enemy_ids := _id_set(enemy_defs.get("enemies", []), "entity_id")
    var boss_ids := _id_set(boss_defs.get("bosses", []), "entity_id")
    var enemy_tree_ids := _id_set(enemy_trees.get("trees", []), "tree_id")
    var boss_tree_ids := _id_set(boss_trees.get("trees", []), "tree_id")
    if enemy_ids.size() != 24:
        errors.append("wrong_enemy_count:%d" % enemy_ids.size())
    if boss_ids.size() != 5:
        errors.append("wrong_boss_count:%d" % boss_ids.size())

    var seen_entities: Dictionary = {}
    var seen_facts: Dictionary = {}
    var seen_unlocks: Dictionary = {}
    var active_count := 0
    for value: Variant in profiles:
        if not (value is Dictionary):
            errors.append("profile_not_dictionary")
            continue
        var p: Dictionary = value
        var entity_id := str(p.get("entity_id", ""))
        var entity_type := str(p.get("entity_type", ""))
        var fact_id := str(p.get("fact_id", ""))
        var unlock_id := str(p.get("unlock_id", ""))
        _unique(seen_entities, entity_id, "entity", errors)
        _unique(seen_facts, fact_id, "fact", errors)
        _unique(seen_unlocks, unlock_id, "unlock", errors)
        if entity_type == "enemy":
            if not enemy_ids.has(entity_id):
                errors.append("unknown_enemy:%s" % entity_id)
        elif entity_type == "boss":
            if not boss_ids.has(entity_id):
                errors.append("unknown_boss:%s" % entity_id)
        else:
            errors.append("invalid_entity_type:%s" % entity_id)

        var trees: Array = p.get("tree_ids", []) if p.get("tree_ids", []) is Array else []
        if trees.size() != 3:
            errors.append("wrong_tree_count:%s" % entity_id)
        for tree_value: Variant in trees:
            var tree_id := str(tree_value)
            if entity_type == "boss":
                if not boss_tree_ids.has(tree_id):
                    errors.append("unknown_boss_tree:%s" % tree_id)
            elif not enemy_tree_ids.has(tree_id):
                errors.append("unknown_enemy_tree:%s" % tree_id)

        if str(p.get("implementation_status", "")) == "ACTIVE_PHASE_A":
            active_count += 1
            if entity_id != ACTIVE_ENTITY_ID:
                errors.append("unexpected_active_entity:%s" % entity_id)
            if fact_id != ACTIVE_FACT_ID:
                errors.append("active_fact_mismatch")
            if str(p.get("hypothesis_id", "")) != ACTIVE_HYPOTHESIS_ID:
                errors.append("active_hypothesis_mismatch")
            if str(p.get("policy_id", "")) != ACTIVE_POLICY_ID:
                errors.append("active_policy_mismatch")
            if not (p.get("observable_events", []) as Array).has("combat.target_selected"):
                errors.append("active_event_missing")
            var extractors: Array = p.get("required_extractors", []) if p.get("required_extractors", []) is Array else []
            if not extractors.has("EXTRACT_TARGET_CONTEXT") or not extractors.has("EXTRACT_WOUND_BLOOD_CONTEXT"):
                errors.append("active_extractors_missing")
    if active_count != 1:
        errors.append("wrong_active_profile_count:%d" % active_count)
    return errors

func is_ready() -> bool:
    return loaded and validation_errors.is_empty()

func profile(entity_id: String) -> Dictionary:
    return (profiles_by_entity_id.get(entity_id, {}) as Dictionary).duplicate(true)

func fact_owner(fact_id: String) -> String:
    return str(fact_to_entity_id.get(fact_id, ""))

func unlock_owner(unlock_id: String) -> String:
    return str(unlock_to_entity_id.get(unlock_id, ""))

func entities_for_event(event_id: String) -> Array[String]:
    return _string_array(event_to_entities.get(event_id, []))

func extractors_for_entity(entity_id: String) -> Array[String]:
    var p := profile(entity_id)
    return _string_array(p.get("required_extractors", []))

func catalog_summary() -> Dictionary:
    return {
        "loaded": loaded,
        "profiles": profiles_by_entity_id.size(),
        "facts": fact_to_entity_id.size(),
        "unlocks": unlock_to_entity_id.size(),
        "errors": validation_errors.duplicate()
    }

func validation_report() -> Dictionary:
    return {"ok": is_ready(), "errors": validation_errors.duplicate(), "summary": catalog_summary()}

func _build_indexes() -> void:
    for value: Variant in catalog.get("profiles", []):
        var p: Dictionary = value
        var entity_id := str(p.get("entity_id", ""))
        profiles_by_entity_id[entity_id] = p.duplicate(true)
        fact_to_entity_id[str(p.get("fact_id", ""))] = entity_id
        unlock_to_entity_id[str(p.get("unlock_id", ""))] = entity_id
        for event_value: Variant in p.get("observable_events", []):
            var event_id := str(event_value)
            var ids: Array = event_to_entities.get(event_id, []) if event_to_entities.get(event_id, []) is Array else []
            if not ids.has(entity_id):
                ids.append(entity_id)
            event_to_entities[event_id] = ids

func _id_set(values_value: Variant, field: String) -> Dictionary:
    var result: Dictionary = {}
    var values: Array = values_value if values_value is Array else []
    for value: Variant in values:
        if value is Dictionary:
            var id_value := str((value as Dictionary).get(field, ""))
            if id_value != "":
                result[id_value] = true
    return result

func _unique(seen: Dictionary, value: String, label: String, errors: Array[String]) -> void:
    if value == "":
        errors.append("missing_%s_id" % label)
    elif seen.has(value):
        errors.append("duplicate_%s_id:%s" % [label, value])
    else:
        seen[value] = true

func _string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    var rows: Array = value if value is Array else []
    for item: Variant in rows:
        result.append(str(item))
    return result

func _clear() -> void:
    loaded = false
    catalog = {}
    profiles_by_entity_id = {}
    fact_to_entity_id = {}
    unlock_to_entity_id = {}
    event_to_entities = {}
    validation_errors = []
