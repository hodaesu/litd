extends RefCounted
class_name VeilleursEncounterNarrativeRuntime

const MANIFEST_PATH := "res://data/veilleurs/generated/encounter_narrative_reward_64_manifest_v1.json"
const PACK_SHA := "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"

var records: Array[Dictionary] = []
var by_id: Dictionary = {}
var by_name: Dictionary = {}
var last_report: Dictionary = {}

func _init() -> void:
    reload()

func reload() -> Dictionary:
    records.clear()
    by_id.clear()
    by_name.clear()
    var errors: Array[String] = []
    var manifest := _load_dictionary(MANIFEST_PATH)
    if manifest.is_empty():
        errors.append("missing_manifest")
        return _finish(errors)
    if str(manifest.get("source_pack_sha256", "")) != PACK_SHA:
        errors.append("source_pack_sha_mismatch")
    if int(manifest.get("count", 0)) != 64:
        errors.append("manifest_count:%d" % int(manifest.get("count", 0)))

    var total_declared := 0
    for chunk_value: Variant in manifest.get("chunks", []):
        if not (chunk_value is Dictionary):
            errors.append("invalid_chunk_manifest")
            continue
        var chunk_ref: Dictionary = chunk_value
        var path := str(chunk_ref.get("path", ""))
        var declared_count := int(chunk_ref.get("count", 0))
        total_declared += declared_count
        if path.is_empty() or not FileAccess.file_exists(path):
            errors.append("missing_chunk:%s" % path)
            continue
        var raw := FileAccess.get_file_as_bytes(path)
        var expected_sha := str(chunk_ref.get("sha256", ""))
        if not expected_sha.is_empty() and _sha256(raw) != expected_sha:
            errors.append("chunk_sha_mismatch:%s" % path)
            continue
        var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
        if not (parsed is Dictionary):
            errors.append("invalid_chunk_json:%s" % path)
            continue
        var chunk: Dictionary = parsed
        var chunk_records: Array = chunk.get("records", [])
        if int(chunk.get("count", -1)) != declared_count or chunk_records.size() != declared_count:
            errors.append("chunk_count:%s:%d" % [path, chunk_records.size()])
        for value: Variant in chunk_records:
            if value is Dictionary:
                _index_record((value as Dictionary).duplicate(true), errors)
            else:
                errors.append("invalid_record:%s" % path)

    if total_declared != 64:
        errors.append("declared_total:%d" % total_declared)
    if records.size() != 64:
        errors.append("records:%d" % records.size())
    if by_id.size() != 64:
        errors.append("unique_ids:%d" % by_id.size())
    if by_name.size() != 64:
        errors.append("unique_names:%d" % by_name.size())
    return _finish(errors)

func entry_by_id(encounter_id: String) -> Dictionary:
    return (by_id.get(encounter_id, {}) as Dictionary).duplicate(true)

func entry_by_name(encounter_name: String) -> Dictionary:
    return (by_name.get(encounter_name, {}) as Dictionary).duplicate(true)

func all_entries() -> Array[Dictionary]:
    return records.duplicate(true)

func _index_record(record: Dictionary, errors: Array[String]) -> void:
    var encounter_id := str(record.get("encounter_id", ""))
    var name := str(record.get("name", ""))
    if encounter_id.is_empty() or name.is_empty():
        errors.append("missing_identity")
        return
    if by_id.has(encounter_id):
        errors.append("duplicate_id:%s" % encounter_id)
        return
    if by_name.has(name):
        errors.append("duplicate_name:%s" % name)
        return
    var narrative: Dictionary = record.get("narrative", {})
    var reward: Dictionary = record.get("reward", {})
    for key: String in ["intro", "combat_beat", "victory", "retreat", "remanence_hint"]:
        if str(narrative.get(key, "")).is_empty():
            errors.append("missing_narrative:%s:%s" % [encounter_id, key])
    for key: String in ["loot", "capture_rule", "knowledge_bonus"]:
        if str(reward.get(key, "")).is_empty():
            errors.append("missing_reward:%s:%s" % [encounter_id, key])
    by_id[encounter_id] = record
    by_name[name] = record
    records.append(record)

func _finish(errors: Array[String]) -> Dictionary:
    last_report = {
        "ok": errors.is_empty(),
        "errors": errors.duplicate(),
        "records": records.size(),
        "unique_ids": by_id.size(),
        "unique_names": by_name.size(),
        "source_pack_sha256": PACK_SHA,
        "runtime_binding": MANIFEST_PATH,
        "source_mode": "canonical_uncompressed_chunks"
    }
    return last_report.duplicate(true)

func _sha256(raw: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(raw)
    return context.finish().hex_encode()

func _load_dictionary(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
