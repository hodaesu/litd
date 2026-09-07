extends Resource
class_name VeilleursEntityDefinition

@export var entity_id := ""
@export var name_fr := ""
@export var role_fr := ""
@export var family := ""
@export var threat_value := 1.0
@export var stats: Dictionary = {}
@export var body_integrity: Dictionary = {}
@export var tree_ids: Array[String] = []

static func from_dictionary(payload: Dictionary) -> VeilleursEntityDefinition:
    var result := VeilleursEntityDefinition.new()
    result.entity_id = str(payload.get("entity_id", ""))
    result.name_fr = str(payload.get("name_fr", result.entity_id))
    result.role_fr = str(payload.get("role_fr", payload.get("combat_role", "")))
    result.family = str(payload.get("family", ""))
    result.threat_value = float(payload.get("threat_value", 1.0))
    result.stats = (payload.get("stats", {}) as Dictionary).duplicate(true)
    result.body_integrity = (payload.get("body_integrity", {}) as Dictionary).duplicate(true)
    for value: Variant in payload.get("tree_ids", []):
        result.tree_ids.append(str(value))
    return result
