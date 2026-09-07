extends RefCounted
class_name VeilleursEnemySkillRuntimeCatalog

const MANIFEST_PATH := "res://data/veilleurs/generated/enemy_skill_ai_catalog_manifest_v1.json"
const PACK_SHA := "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"
const FIELD_NAMES := [
    "runtime_skill_id",
    "source_skill_id",
    "entity_id",
    "tree",
    "skill_name",
    "skill_type",
    "node_role",
    "positions",
    "power_0_5",
    "precision_pct",
    "tags"
]

var manifest: Dictionary = {}
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
    loaded = false
    manifest = _load_dictionary(MANIFEST_PATH)
    var errors: Array[String] = []
    if manifest.is_empty():
        errors.append("missing_manifest")
        return _finish_report(errors)
    if str(manifest.get("source_pack_sha256", "")) != PACK_SHA:
        errors.append("manifest_pack_sha_mismatch")

    var act_entries: Array = manifest.get("acts", [])
    for act_value: Variant in act_entries:
        if not (act_value is Dictionary):
            errors.append("invalid_act_manifest_entry")
            continue
        var act_entry: Dictionary = act_value
        var act_records := _decode_act(act_entry, errors)
        for record: Dictionary in act_records:
            _index_record(record, errors)

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
    for skill: Dictionary in skills_for_entity(entity_id):
        var tree := str(skill.get("tree", ""))
        if not tree.is_empty() and not result.has(tree):
            result.append(tree)
    return result

func _decode_act(act_entry: Dictionary, errors: Array[String]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var path := str(act_entry.get("path", ""))
    var cache := _load_dictionary(path)
    if cache.is_empty():
        errors.append("missing_cache:%s" % path)
        return result
    var act := int(act_entry.get("act", 0))
    if int(cache.get("act", -1)) != act:
        errors.append("act_mismatch:%d" % act)
    if str(cache.get("source_pack_sha256", "")) != PACK_SHA:
        errors.append("cache_pack_sha_mismatch:%d" % act)
    var encoded := str(cache.get("payload", ""))
    if encoded.is_empty():
        errors.append("empty_payload:%d" % act)
        return result
    var compressed := Marshalls.base64_to_raw(encoded)
    var expected_bytes := int(cache.get("uncompressed_bytes", 0))
    var raw := compressed.decompress(expected_bytes, FileAccess.COMPRESSION_DEFLATE)
    if raw.is_empty():
        errors.append("decompress_failed:%d" % act)
        return result
    if raw.size() != expected_bytes:
        errors.append("uncompressed_size:%d:%d" % [act, raw.size()])
    var expected_hash := str(cache.get("raw_json_sha256", ""))
    if _sha256(raw) != expected_hash:
        errors.append("raw_sha_mismatch:%d" % act)
        return result
    if expected_hash != str(act_entry.get("raw_json_sha256", "")):
        errors.append("manifest_raw_sha_mismatch:%d" % act)
    var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
    if not (decoded is Dictionary):
        errors.append("invalid_json:%d" % act)
        return result
    var source: Dictionary = decoded
    var schema: Array = source.get("schema", [])
    if schema.size() != FIELD_NAMES.size():
        errors.append("schema_size:%d" % act)
        return result
    for index: int in range(FIELD_NAMES.size()):
        if str(schema[index]) != str(["rid", "sid", "entity", "tree", "name", "type", "node_role", "positions", "power", "precision", "tags"][index]):
            errors.append("schema_field:%d:%d" % [act, index])
            return result
    var rows: Array = source.get("records", [])
    if rows.size() != int(cache.get("record_count", -1)) or rows.size() != int(act_entry.get("count", -1)):
        errors.append("act_count:%d:%d" % [act, rows.size()])
    for row_value: Variant in rows:
        if not (row_value is Array):
            errors.append("invalid_row:%d" % act)
            continue
        var row: Array = row_value
        if row.size() != FIELD_NAMES.size():
            errors.append("row_size:%d:%d" % [act, row.size()])
            continue
        var record: Dictionary = {"act": act}
        for index: int in range(FIELD_NAMES.size()):
            record[FIELD_NAMES[index]] = row[index]
        record["tags"] = _tags(str(record.get("tags", "")))
        result.append(record)
    return result

func _index_record(record: Dictionary, errors: Array[String]) -> void:
    var runtime_id := str(record.get("runtime_skill_id", ""))
    var entity_id := str(record.get("entity_id", ""))
    var tree := str(record.get("tree", ""))
    if runtime_id.is_empty() or entity_id.is_empty() or tree.is_empty():
        errors.append("missing_identity:%s" % runtime_id)
        return
    if by_runtime_id.has(runtime_id):
        errors.append("duplicate_runtime_id:%s" % runtime_id)
        return
    by_runtime_id[runtime_id] = record
    if not by_entity.has(entity_id):
        by_entity[entity_id] = []
    (by_entity[entity_id] as Array).append(record)
    var tree_key := _tree_key(entity_id, tree)
    if not by_entity_tree.has(tree_key):
        by_entity_tree[tree_key] = []
    (by_entity_tree[tree_key] as Array).append(record)
    records.append(record)

func _validate_shape(errors: Array[String]) -> void:
    if records.size() != int(manifest.get("total_records", 1305)):
        errors.append("total_records:%d" % records.size())
    if by_runtime_id.size() != records.size():
        errors.append("runtime_id_uniqueness:%d" % by_runtime_id.size())
    if by_entity.size() != int(manifest.get("entity_count", 29)):
        errors.append("entity_count:%d" % by_entity.size())
    for entity_id_value: Variant in by_entity.keys():
        var entity_id := str(entity_id_value)
        var skills: Array = by_entity[entity_id]
        if skills.size() != int(manifest.get("skills_per_entity", 45)):
            errors.append("entity_skill_count:%s:%d" % [entity_id, skills.size()])
        var trees := trees_for_entity(entity_id)
        if trees.size() != int(manifest.get("trees_per_entity", 3)):
            errors.append("entity_tree_count:%s:%d" % [entity_id, trees.size()])
        for tree: String in trees:
            var tree_skills := skills_for_entity_tree(entity_id, tree)
            if tree_skills.size() != int(manifest.get("skills_per_tree", 15)):
                errors.append("tree_skill_count:%s:%s:%d" % [entity_id, tree, tree_skills.size()])

func _finish_report(errors: Array[String]) -> Dictionary:
    loaded = errors.is_empty()
    last_report = {
        "ok": loaded,
        "errors": errors.duplicate(),
        "records": records.size(),
        "runtime_ids": by_runtime_id.size(),
        "entities": by_entity.size(),
        "source_pack_sha256": str(manifest.get("source_pack_sha256", ""))
    }
    return last_report.duplicate(true)

func _tags(raw: String) -> Array[String]:
    var result: Array[String] = []
    for value: String in raw.split(";"):
        var tag := value.strip_edges()
        if not tag.is_empty():
            result.append(tag)
    return result

func _tree_key(entity_id: String, tree: String) -> String:
    return "%s|%s" % [entity_id, tree]

func _sha256(raw: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(raw)
    return context.finish().hex_encode()

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
