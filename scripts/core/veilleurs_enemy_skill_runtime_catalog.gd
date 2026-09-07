extends RefCounted
class_name VeilleursEnemySkillRuntimeCatalog

const CATALOG_PATH := "res://data/veilleurs/skills/enemy_skill_runtime_catalog_v1.json"
const PACK_SHA := "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"

var catalog: Dictionary = {}
var node_schema: Dictionary = {}
var records: Array[Dictionary] = []
var by_runtime_id: Dictionary = {}
var by_entity: Dictionary = {}
var by_entity_tree: Dictionary = {}
var loaded := false
var last_report: Dictionary = {}

func _init() -> void:
    reload()

func reload() -> Dictionary:
    records.clear()
    by_runtime_id.clear()
    by_entity.clear()
    by_entity_tree.clear()
    node_schema.clear()
    loaded = false
    catalog = _load_dictionary(CATALOG_PATH)
    var errors: Array[String] = []
    if catalog.is_empty():
        errors.append("missing_catalog")
        return _finish_report(errors)
    var canonical_source: Dictionary = catalog.get("canonical_source", {})
    if str(canonical_source.get("pack_sha256", "")) != PACK_SHA:
        errors.append("catalog_pack_sha_mismatch")

    for file_value: Variant in canonical_source.get("tree_files", []):
        if not (file_value is Dictionary):
            errors.append("invalid_tree_file_entry")
            continue
        var file_entry: Dictionary = file_value
        var path := str(file_entry.get("path", ""))
        var source := _load_dictionary(path)
        if source.is_empty():
            errors.append("missing_tree_file:%s" % path)
            continue
        if node_schema.is_empty():
            node_schema = (source.get("node_schema", {}) as Dictionary).duplicate(true)
        var source_tree_count := 0
        var source_skill_count := 0
        for tree_value: Variant in source.get("trees", []):
            if not (tree_value is Dictionary):
                errors.append("invalid_tree:%s" % path)
                continue
            source_tree_count += 1
            source_skill_count += _register_tree(tree_value as Dictionary, errors)
        if source_tree_count != int(file_entry.get("trees", source_tree_count)):
            errors.append("tree_file_count:%s:%d" % [path, source_tree_count])
        if source_skill_count != int(file_entry.get("skills", source_skill_count)):
            errors.append("skill_file_count:%s:%d" % [path, source_skill_count])

    _validate_shape(errors)
    return _finish_report(errors)

func all_skills() -> Array[Dictionary]:
    return records.duplicate(true)

func skill_by_runtime_id(runtime_skill_id: String) -> Dictionary:
    return (by_runtime_id.get(runtime_skill_id, {}) as Dictionary).duplicate(true)

func skills_for_entity(entity_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in by_entity.get(entity_id, []):
        if value is Dictionary:
            result.append((value as Dictionary).duplicate(true))
    return result

func skills_for_entity_tree(entity_id: String, tree: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in by_entity_tree.get(_tree_key(entity_id, tree), []):
        if value is Dictionary:
            result.append((value as Dictionary).duplicate(true))
    return result

func trees_for_entity(entity_id: String) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in by_entity_tree.keys():
        var key := str(value)
        var prefix := "%s|" % entity_id
        if key.begins_with(prefix):
            result.append(key.substr(prefix.length()))
    result.sort()
    return result

func _register_tree(tree_source: Dictionary, errors: Array[String]) -> int:
    var entity_id := str(tree_source.get("entity_id", ""))
    var tree_name := str(tree_source.get("tree", ""))
    if entity_id.is_empty() or tree_name.is_empty():
        errors.append("tree_missing_identity")
        return 0
    var source_ids: Array = tree_source.get("source_skill_ids", [])
    var names: Array = tree_source.get("names", [])
    var powers: Array = tree_source.get("power_0_5", [])
    var precisions: Array = tree_source.get("precision_pct", [])
    var levels: Array = node_schema.get("levels", [])
    var types: Array = node_schema.get("types", [])
    var roles: Array = node_schema.get("roles", [])
    if source_ids.size() != 15 or names.size() != 15 or powers.size() != 15 or precisions.size() != 15:
        errors.append("tree_shape:%s:%s" % [entity_id, tree_name])
        return 0
    var tags := _split_tags(str(tree_source.get("tags", "")))
    var tree_records: Array[Dictionary] = []
    for index: int in range(15):
        var source_id := str(source_ids[index])
        var runtime_id := "%s:%s" % [entity_id, source_id]
        if by_runtime_id.has(runtime_id):
            errors.append("duplicate_runtime_id:%s" % runtime_id)
            continue
        var record := {
            "runtime_skill_id": runtime_id,
            "source_skill_id": source_id,
            "entity_id": entity_id,
            "tree": tree_name,
            "skill_name": str(names[index]),
            "skill_type": str(types[index]) if index < types.size() else "",
            "node_role": str(roles[index]) if index < roles.size() else "",
            "positions": str(tree_source.get("positions", "")),
            "power_0_5": float(powers[index]),
            "precision_pct": int(precisions[index]),
            "tags": tags.duplicate(),
            "level": int(levels[index]) if index < levels.size() else 0,
            "node": index + 1,
            "source_backed": true
        }
        by_runtime_id[runtime_id] = record
        records.append(record)
        tree_records.append(record)
        if not by_entity.has(entity_id):
            by_entity[entity_id] = []
        (by_entity[entity_id] as Array).append(record)
    by_entity_tree[_tree_key(entity_id, tree_name)] = tree_records
    return tree_records.size()

func _validate_shape(errors: Array[String]) -> void:
    var expected: Dictionary = catalog.get("counts", {})
    if records.size() != int(expected.get("skills", 1305)):
        errors.append("total_records:%d" % records.size())
    if by_runtime_id.size() != records.size():
        errors.append("runtime_id_uniqueness:%d" % by_runtime_id.size())
    if by_entity.size() != int(expected.get("entities", 29)):
        errors.append("entity_count:%d" % by_entity.size())
    var total_trees := 0
    for entity_id_value: Variant in by_entity.keys():
        var entity_id := str(entity_id_value)
        var skills: Array = by_entity[entity_id]
        if skills.size() != int(expected.get("skills_per_entity", 45)):
            errors.append("entity_skill_count:%s:%d" % [entity_id, skills.size()])
        var trees := trees_for_entity(entity_id)
        total_trees += trees.size()
        if trees.size() != 3:
            errors.append("entity_tree_count:%s:%d" % [entity_id, trees.size()])
        for tree: String in trees:
            var tree_skills := skills_for_entity_tree(entity_id, tree)
            if tree_skills.size() != int(expected.get("skills_per_tree", 15)):
                errors.append("tree_skill_count:%s:%s:%d" % [entity_id, tree, tree_skills.size()])
    if total_trees != int(expected.get("trees", 87)):
        errors.append("total_trees:%d" % total_trees)

func _finish_report(errors: Array[String]) -> Dictionary:
    loaded = errors.is_empty()
    last_report = {
        "ok": loaded,
        "errors": errors.duplicate(),
        "records": records.size(),
        "runtime_ids": by_runtime_id.size(),
        "entities": by_entity.size(),
        "source_pack_sha256": str((catalog.get("canonical_source", {}) as Dictionary).get("pack_sha256", "")),
        "source_mode": "canonical_uncompressed_tree_files"
    }
    return last_report.duplicate(true)

func _split_tags(text: String) -> Array[String]:
    var result: Array[String] = []
    for part: String in text.split(";"):
        var value := part.strip_edges()
        if not value.is_empty():
            result.append(value)
    return result

func _tree_key(entity_id: String, tree: String) -> String:
    return "%s|%s" % [entity_id, tree]

func _load_dictionary(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
