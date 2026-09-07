extends RefCounted
class_name VeilleursKharSenFlowBridge

const PENDING_PATH := "user://veilleurs_khar_sen_pending.json"
const RESULT_PATH := "user://veilleurs_khar_sen_result.json"
const VERSION := "0.6.1"

func begin_combat(dungeon_state: Dictionary, encounter: Dictionary, node_id: String) -> bool:
    if dungeon_state.is_empty() or encounter.is_empty() or node_id == "":
        return false
    var payload := {
        "version": VERSION,
        "node_id": node_id,
        "dungeon_state": dungeon_state.duplicate(true),
        "encounter": encounter.duplicate(true)
    }
    if not _write_json(PENDING_PATH, payload):
        return false
    _delete(RESULT_PATH)
    return true

func pending() -> Dictionary:
    return _read_json(PENDING_PATH)

func has_pending() -> bool:
    return not pending().is_empty()

func finish_combat(outcome: String, summary: Dictionary, combat_snapshot: Dictionary, watcher_aftermath: Dictionary) -> bool:
    var source := pending()
    if source.is_empty():
        return false
    var payload := {
        "version": VERSION,
        "node_id": str(source.get("node_id", "")),
        "dungeon_state": (source.get("dungeon_state", {}) as Dictionary).duplicate(true),
        "encounter": (source.get("encounter", {}) as Dictionary).duplicate(true),
        "outcome": outcome,
        "summary": summary.duplicate(true),
        "combat_snapshot": combat_snapshot.duplicate(true),
        "watcher_aftermath": watcher_aftermath.duplicate(true)
    }
    if not _write_json(RESULT_PATH, payload):
        return false
    _delete(PENDING_PATH)
    return true

func consume_result() -> Dictionary:
    var payload := _read_json(RESULT_PATH)
    if not payload.is_empty():
        _delete(RESULT_PATH)
    return payload

func clear() -> void:
    _delete(PENDING_PATH)
    _delete(RESULT_PATH)

func _write_json(path: String, payload: Dictionary) -> bool:
    var body := JSON.stringify(payload)
    var envelope := JSON.stringify({"checksum":body.sha256_text(), "body":body})
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(envelope)
    file.flush()
    file.close()
    return true

func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var envelope_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (envelope_value is Dictionary):
        return {}
    var envelope: Dictionary = envelope_value
    var body := str(envelope.get("body", ""))
    if body == "" or str(envelope.get("checksum", "")) != body.sha256_text():
        return {}
    var payload_value: Variant = JSON.parse_string(body)
    if not (payload_value is Dictionary):
        return {}
    var payload: Dictionary = payload_value
    if str(payload.get("version", "")) != VERSION:
        return {}
    return payload

func _delete(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
