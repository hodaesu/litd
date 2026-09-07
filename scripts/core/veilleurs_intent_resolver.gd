extends RefCounted
class_name VeilleursIntentResolver

const CONTRACT_PATH := "res://data/veilleurs/enemy_skill_intent_contract_v1.json"

var contract: Dictionary = {}
var tree_bindings: Dictionary = {}
var family_labels: Dictionary = {}

func _init() -> void:
    contract = _load_dictionary(CONTRACT_PATH)
    for family_value: Variant in contract.get("intent_families", []):
        if family_value is Dictionary:
            var family: Dictionary = family_value
            family_labels[str(family.get("id", ""))] = str(family.get("label", ""))
    for binding_value: Variant in contract.get("tree_bindings", []):
        if not (binding_value is Array):
            continue
        var binding: Array = binding_value
        if binding.size() < 4:
            continue
        tree_bindings[_tree_key(str(binding[0]), str(binding[1]))] = {
            "primary": str(binding[2]),
            "secondary": null if binding[3] == null else str(binding[3])
        }

func resolve_skill_intent(entity_id: String, skill: Dictionary) -> Dictionary:
    var tree := str(skill.get("tree", skill.get("Arbre", "")))
    var binding: Dictionary = tree_bindings.get(_tree_key(entity_id, tree), {})
    if binding.is_empty():
        return {"ok": false, "reason": "unbound_entity_tree", "entity_id": entity_id, "tree": tree}

    var node_role := str(skill.get("node_role", skill.get("Rôle du nœud", skill.get("Rôle nœud", ""))))
    var overrides: Dictionary = contract.get("node_role_overrides", {})
    var primary := str(overrides.get(node_role, binding.get("primary", "")))
    var secondary_variant: Variant = binding.get("secondary", null)
    var secondary := "" if secondary_variant == null else str(secondary_variant)
    var skill_type := str(skill.get("skill_type", skill.get("Type", "")))
    var channels: Dictionary = contract.get("action_channels", {})
    if not channels.has(skill_type):
        return {"ok": false, "reason": "unknown_action_channel", "skill_type": skill_type}

    var action_channel := str(channels.get(skill_type, ""))
    return {
        "ok": true,
        "entity_id": entity_id,
        "tree": tree,
        "skill_name": str(skill.get("skill_name", skill.get("Compétence", ""))),
        "skill_type": skill_type,
        "node_role": node_role,
        "intent_family": primary,
        "intent_label": str(family_labels.get(primary, primary)),
        "secondary_intent": secondary,
        "action_channel": action_channel,
        "queued": action_channel in ["queued", "environment_interaction", "posture", "major_telegraphed", "transformation_telegraphed"],
        "positions": str(skill.get("positions", skill.get("Positions", ""))),
        "power_0_5": float(skill.get("power_0_5", skill.get("Puissance 0-5", 0.0))),
        "precision_pct": int(skill.get("precision_pct", skill.get("Précision %", 0))),
        "tags": _tags(skill.get("tags", skill.get("Tags", []))),
        "effect": str(skill.get("effect", skill.get("Effet", ""))),
        "counterplay": str(skill.get("counterplay", ""))
    }

func resolve_state_intent(state_intent: String, payload: Dictionary = {}) -> Dictionary:
    if state_intent != "fuite_cession_recrutement":
        return {"ok": false, "reason": "unsupported_state_intent"}
    return {
        "ok": true,
        "intent_family": state_intent,
        "intent_label": str(family_labels.get(state_intent, "Fuite/Cession/Recrutement")),
        "queued": true,
        "state_machine_intent": true,
        "payload": payload.duplicate(true)
    }

func telegraph(intent: Dictionary, stored_detail: int, perception: String = "clear") -> Dictionary:
    if not bool(intent.get("ok", false)):
        return {"visible": false, "detail_level": 0, "reason": intent.get("reason", "invalid_intent")}
    var penalties: Dictionary = (contract.get("knowledge_projection", {}) as Dictionary).get("perception_penalties", {})
    var penalty := int(penalties.get(perception, 0))
    var level := clampi(stored_detail - penalty, 0, 5)
    var result := {
        "visible": level > 0,
        "detail_level": level,
        "stored_detail": clampi(stored_detail, 0, 5),
        "perception": perception,
        "perception_penalty": penalty,
        "queued": bool(intent.get("queued", false))
    }
    if level == 0:
        return result

    result["intent_family"] = str(intent.get("intent_family", ""))
    result["intent_label"] = str(intent.get("intent_label", ""))
    if level >= 2:
        result["positions"] = str(intent.get("positions", ""))
    if level >= 3:
        result["power_0_5"] = float(intent.get("power_0_5", 0.0))
        result["precision_pct"] = int(intent.get("precision_pct", 0))
    if level >= 4:
        result["skill_name"] = str(intent.get("skill_name", ""))
        result["tags"] = (intent.get("tags", []) as Array).duplicate()
        result["likely_effect"] = str(intent.get("effect", ""))
    if level >= 5:
        result["effect"] = str(intent.get("effect", ""))
        var counterplay := str(intent.get("counterplay", ""))
        if not counterplay.is_empty():
            result["counterplay"] = counterplay
    return result

func family_label(family_id: String) -> String:
    return str(family_labels.get(family_id, family_id))

func _tree_key(entity_id: String, tree: String) -> String:
    return "%s|%s" % [entity_id, tree]

func _tags(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for item: Variant in value:
            var tag := str(item)
            if not tag.is_empty():
                result.append(tag)
    else:
        for item: String in str(value).split(";"):
            if not item.is_empty():
                result.append(item)
    return result

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
