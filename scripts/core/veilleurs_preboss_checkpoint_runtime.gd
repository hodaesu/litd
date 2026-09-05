extends RefCounted

const CHECKPOINT_VERSION := 1
const REQUIRED_FIELDS: Array[String] = [
    "seed",
    "room_id",
    "injuries",
    "corpse_states",
    "terrain_state",
    "memorial_entities",
    "species_knowledge"
]

func capture(source: Dictionary) -> Dictionary:
    var payload := {
        "version": CHECKPOINT_VERSION,
        "seed": source.get("seed", ""),
        "room_id": source.get("room_id", ""),
        "injuries": _dictionary(source.get("injuries", {})),
        "corpse_states": _dictionary(source.get("corpse_states", {})),
        "terrain_state": _dictionary(source.get("terrain_state", {})),
        "memorial_entities": _dictionary(source.get("memorial_entities", {})),
        "species_knowledge": _dictionary(source.get("species_knowledge", {}))
    }
    return payload.duplicate(true)

func encode(checkpoint: Dictionary) -> String:
    if not validate(checkpoint):
        return ""
    return JSON.stringify(checkpoint)

func decode(text: String) -> Dictionary:
    if text == "":
        return {}
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        return {}
    var checkpoint: Dictionary = parsed
    if not validate(checkpoint):
        return {}
    return checkpoint.duplicate(true)

func validate(checkpoint: Dictionary) -> bool:
    if int(checkpoint.get("version", -1)) != CHECKPOINT_VERSION:
        return false
    for field: String in REQUIRED_FIELDS:
        if not checkpoint.has(field):
            return false
    if not (checkpoint.get("injuries", null) is Dictionary):
        return false
    if not (checkpoint.get("corpse_states", null) is Dictionary):
        return false
    if not (checkpoint.get("terrain_state", null) is Dictionary):
        return false
    if not (checkpoint.get("memorial_entities", null) is Dictionary):
        return false
    if not (checkpoint.get("species_knowledge", null) is Dictionary):
        return false
    return true

func critical_fields_identical(before: Dictionary, after: Dictionary) -> Dictionary:
    var differences: Array[String] = []
    for field: String in REQUIRED_FIELDS:
        if before.get(field, null) != after.get(field, null):
            differences.append(field)
    return {
        "identical": differences.is_empty(),
        "differences": differences,
        "checked_fields": REQUIRED_FIELDS.duplicate()
    }

func round_trip(source: Dictionary) -> Dictionary:
    var captured := capture(source)
    var body := encode(captured)
    var restored := decode(body)
    var comparison := critical_fields_identical(captured, restored)
    return {
        "captured": captured,
        "encoded": body,
        "restored": restored,
        "identical": bool(comparison.get("identical", false)),
        "differences": comparison.get("differences", [])
    }

func _dictionary(value: Variant) -> Dictionary:
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}
