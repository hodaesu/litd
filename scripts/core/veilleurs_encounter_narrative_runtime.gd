extends RefCounted
class_name VeilleursEncounterNarrativeRuntime

const CACHE_PATH := "res://data/veilleurs/generated/encounter_narrative_reward_64_v1.json"
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
    var cache := _load_dictionary(CACHE_PATH)
    if cache.is_empty():
        errors.append("missing_cache")
        return _finish(errors)
    if str(cache.get("source_pack_sha256", "")) != PACK_SHA:
        errors.append("source_pack_sha_mismatch")
    if int(cache.get("record_count", 0)) != 64:
        errors.append("cache_record_count:%d" % int(cache.get("record_count", 0)))
    var encoded := str(cache.get("payload", ""))
    if encoded.is_empty():
        errors.append("empty_payload")
        return _finish(errors)
    var compressed := Marshalls.base64_to_raw(encoded)
    var expected_bytes := int(cache.get("uncompressed_bytes", 0))
    var raw := compressed.decompress(expected_bytes, FileAccess.COMPRESSION_DEFLATE)
    if raw.size() != expected_bytes:
        errors.append("uncompressed_size:%d" % raw.size())
        return _finish(errors)
    if _sha256(raw) != str(cache.get("raw_json_sha256", "")):
        errors.append("raw_sha_mismatch")
        return _finish(errors)
    var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
    if not (decoded is Dictionary):
        errors.append("invalid_json")
        return _finish(errors)
    var payload: Dictionary = decoded
    if int(payload.get("count", 0)) != 64:
        errors.append("payload_count:%d" % int(payload.get("count", 0)))
    for value: Variant in payload.get("records", []):
        if not (value is Dictionary):
            errors.append("invalid_record")
            continue
        var record: Dictionary = (value as Dictionary).duplicate(true)
        var encounter_id := str(record.get("encounter_id", ""))
        var name := str(record.get("name", ""))
        if encounter_id.is_empty() or name.is_empty():
            errors.append("missing_identity")
            continue
        if by_id.has(encounter_id):
            errors.append("duplicate_id:%s" % encounter_id)
            continue
        if by_name.has(name):
            errors.append("duplicate_name:%s" % name)
            continue
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
    if records.size() != 64:
        errors.append("records:%d" % records.size())
    return _finish(errors)

func entry_by_id(encounter_id: String) -> Dictionary:
    return (by_id.get(encounter_id, {}) as Dictionary).duplicate(true)

func entry_by_name(encounter_name: String) -> Dictionary:
    return (by_name.get(encounter_name, {}) as Dictionary).duplicate(true)

func all_entries() -> Array[Dictionary]:
    return records.duplicate(true)

func _finish(errors: Array[String]) -> Dictionary:
    last_report = {
        "ok": errors.is_empty(),
        "errors": errors.duplicate(),
        "records": records.size(),
        "unique_ids": by_id.size(),
        "unique_names": by_name.size(),
        "source_pack_sha256": PACK_SHA,
        "runtime_binding": CACHE_PATH
    }
    return last_report.duplicate(true)

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
