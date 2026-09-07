extends RefCounted
class_name VeilleursVerticalSliceSaveV09

const SAVE_PATH := "user://veilleurs_v09_vertical_slice.json"
const SAVE_VERSION := "0.9.0"

func save_slice(slice: Variant) -> bool:
    if slice == null or not slice.has_method("serialize"):
        return false
    var payload := {
        "version":SAVE_VERSION,
        "timestamp":Time.get_datetime_string_from_system(),
        "slice":slice.call("serialize"),
        "remanence":RemanenceRuntime.serialize() if RemanenceRuntime != null else {}
    }
    var body := JSON.stringify(payload)
    var envelope := {"checksum":body.sha256_text(), "body":body}
    var tmp_path := SAVE_PATH + ".tmp"
    var file := FileAccess.open(tmp_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(envelope))
    file.flush()
    file.close()
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(SAVE_PATH)) == OK

func load_into(slice: Variant) -> bool:
    if slice == null or not slice.has_method("deserialize") or not FileAccess.file_exists(SAVE_PATH):
        return false
    var envelope_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not (envelope_value is Dictionary):
        return false
    var envelope: Dictionary = envelope_value
    var body := str(envelope.get("body", ""))
    if body == "" or str(envelope.get("checksum", "")) != body.sha256_text():
        return false
    var payload_value: Variant = JSON.parse_string(body)
    if not (payload_value is Dictionary):
        return false
    var payload: Dictionary = payload_value
    if str(payload.get("version", "")) != SAVE_VERSION:
        return false
    if RemanenceRuntime != null:
        RemanenceRuntime.deserialize(payload.get("remanence", {}))
    return bool(slice.call("deserialize", payload.get("slice", {})))

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func clear() -> bool:
    var removed := false
    for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
        if FileAccess.file_exists(path):
            removed = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK or removed
    return removed
