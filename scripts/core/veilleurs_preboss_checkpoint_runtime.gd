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
        if not values_equivalent(before.get(field, null), after.get(field, null)):
            differences.append(field)
    return {
        "identical": differences.is_empty(),
        "differences": differences,
        "checked_fields": REQUIRED_FIELDS.duplicate()
    }

func values_equivalent(left: Variant, right: Variant) -> bool:
    var left_type := typeof(left)
    var right_type := typeof(right)
    var numeric_types: Array[int] = [TYPE_INT, TYPE_FLOAT]
    if left_type in numeric_types and right_type in numeric_types:
        return is_equal_approx(float(left), float(right))
    if left_type != right_type:
        return false
    if left is Dictionary:
        var left_dict: Dictionary = left
        var right_dict: Dictionary = right
        if left_dict.size() != right_dict.size():
            return false
        for key: Variant in left_dict.keys():
            if not right_dict.has(key):
                return false
            if not values_equivalent(left_dict.get(key), right_dict.get(key)):
                return false
        return true
    if left is Array:
        var left_array: Array = left
        var right_array: Array = right
        if left_array.size() != right_array.size():
            return false
        for index in range(left_array.size()):
            if not values_equivalent(left_array[index], right_array[index]):
                return false
        return true
    return left == right

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
