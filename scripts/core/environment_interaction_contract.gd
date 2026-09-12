extends RefCounted
class_name EnvironmentInteractionContract

# P1 interaction contract.
# This class normalizes discovery and results only. Specialized world objects
# remain the owners of their gameplay effects, persistence and narrative rules.

const KIND_GENERIC := "environment"
const KIND_DOOR := "door"
const KIND_RESOURCE := "resource"
const KIND_CURIOSITY := "curiosity"
const KIND_CORPSE := "corpse"
const KIND_MECHANISM := "mechanism"

# Presentation hierarchy is deliberately small. It guides which nearby object
# gets attention first; it never changes whether an interaction is reachable.
const SALIENCE_IMMEDIATE := "immediate"
const SALIENCE_CONTEXTUAL := "contextual"
const SALIENCE_INSPECT := "inspect"
const VALID_SALIENCE := [SALIENCE_IMMEDIATE, SALIENCE_CONTEXTUAL, SALIENCE_INSPECT]

static func descriptor(
    interaction_id: String,
    kind: String,
    label: String,
    verb: String,
    available: bool = true,
    blocked_reason: String = "",
    consumed: bool = false,
    inspect: Dictionary = {},
    salience: String = ""
) -> Dictionary:
    var normalized_kind := kind if not kind.is_empty() else KIND_GENERIC
    return {
        "interaction_id": interaction_id,
        "kind": normalized_kind,
        "label": label if not label.is_empty() else "Interaction",
        "verb": verb if not verb.is_empty() else "INTERAGIR",
        "available": available,
        "blocked_reason": "" if available else blocked_reason,
        "consumed": consumed,
        "inspect": inspect.duplicate(true),
        "salience": normalize_salience(salience, normalized_kind),
    }

static func default_salience(kind: String) -> String:
    match kind:
        KIND_DOOR, KIND_MECHANISM:
            return SALIENCE_IMMEDIATE
        KIND_CURIOSITY:
            return SALIENCE_INSPECT
        _:
            return SALIENCE_CONTEXTUAL

static func normalize_salience(value: String, kind: String = KIND_GENERIC) -> String:
    var normalized := value.strip_edges().to_lower()
    if normalized in VALID_SALIENCE:
        return normalized
    return default_salience(kind)

static func supports(target: Object) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    return (
        target.has_method("perform_interaction")
        or target.has_method("interaction_descriptor")
        or target.has_method("interact")
        or target.has_method("harvest")
        or target.has_method("rest")
    )

static func describe(target: Object, actor: Object = null) -> Dictionary:
    if target == null or not is_instance_valid(target):
        return descriptor("missing", KIND_GENERIC, "Interaction", "INTERAGIR", false, "missing_target")
    if target.has_method("interaction_descriptor"):
        var authored: Variant = target.call("interaction_descriptor", actor)
        if authored is Dictionary:
            return _normalize_descriptor(authored as Dictionary, target)
    return _legacy_descriptor(target)

static func perform(target: Object, actor: Object = null) -> Dictionary:
    var current := describe(target, actor)
    if not bool(current.get("available", false)):
        return result(current, false, "blocked", str(current.get("blocked_reason", "unavailable")))

    if target.has_method("perform_interaction"):
        return _normalize_result(target.call("perform_interaction", actor), current)
    if target.has_method("interact"):
        return _normalize_result(target.call("interact"), current)
    if target.has_method("harvest"):
        return _normalize_result(target.call("harvest"), current)
    if target.has_method("rest"):
        return _normalize_result(target.call("rest"), current)
    return result(current, false, "blocked", "unsupported_interaction")

static func result(
    source_descriptor: Dictionary,
    success: bool,
    outcome: String = "completed",
    reason: String = "",
    payload: Dictionary = {}
) -> Dictionary:
    return {
        "interaction_id": str(source_descriptor.get("interaction_id", "unknown")),
        "kind": str(source_descriptor.get("kind", KIND_GENERIC)),
        "success": success,
        "outcome": outcome if not outcome.is_empty() else ("completed" if success else "blocked"),
        "reason": "" if success else reason,
        "payload": payload.duplicate(true),
    }

static func _normalize_descriptor(value: Dictionary, target: Object) -> Dictionary:
    var interaction_id := str(value.get("interaction_id", ""))
    if interaction_id.is_empty():
        interaction_id = _legacy_id(target)
    var available := bool(value.get("available", true))
    return descriptor(
        interaction_id,
        str(value.get("kind", KIND_GENERIC)),
        str(value.get("label", _legacy_label(target))),
        str(value.get("verb", _legacy_verb(target))),
        available,
        str(value.get("blocked_reason", "unavailable" if not available else "")),
        bool(value.get("consumed", false)),
        value.get("inspect", {}) as Dictionary if value.get("inspect", {}) is Dictionary else {},
        str(value.get("salience", ""))
    )

static func _legacy_descriptor(target: Object) -> Dictionary:
    var available := true
    var blocked_reason := ""
    if target.has_method("can_interact"):
        available = bool(target.call("can_interact"))
        blocked_reason = "unavailable" if not available else ""
    elif target.has_method("can_rest"):
        available = bool(target.call("can_rest"))
        blocked_reason = "unavailable" if not available else ""
    return descriptor(
        _legacy_id(target),
        KIND_GENERIC,
        _legacy_label(target),
        _legacy_verb(target),
        available,
        blocked_reason,
        false,
        {"legacy_adapter": true}
    )

static func _normalize_result(raw: Variant, source_descriptor: Dictionary) -> Dictionary:
    if raw is Dictionary:
        var raw_dictionary := raw as Dictionary
        if raw_dictionary.has("interaction_id") and raw_dictionary.has("success"):
            var normalized := raw_dictionary.duplicate(true)
            normalized["interaction_id"] = str(normalized.get("interaction_id", source_descriptor.get("interaction_id", "unknown")))
            normalized["kind"] = str(normalized.get("kind", source_descriptor.get("kind", KIND_GENERIC)))
            normalized["outcome"] = str(normalized.get("outcome", "completed" if bool(normalized.get("success", false)) else "blocked"))
            normalized["reason"] = str(normalized.get("reason", ""))
            if not normalized.has("payload") or not normalized["payload"] is Dictionary:
                normalized["payload"] = {}
            return normalized
        var success := bool(raw_dictionary.get("success", raw_dictionary.get("ok", true)))
        var reason := str(raw_dictionary.get("reason", "" if success else "interaction_failed"))
        return result(source_descriptor, success, "completed" if success else "blocked", reason, raw_dictionary)
    if raw is bool:
        return result(source_descriptor, bool(raw), "completed" if bool(raw) else "blocked", "interaction_failed")
    if raw is Array:
        return result(source_descriptor, true, "completed", "", {"items": (raw as Array).duplicate(true)})
    if raw == null:
        return result(source_descriptor, true)
    return result(source_descriptor, true, "completed", "", {"value": raw})

static func _legacy_id(target: Object) -> String:
    if target.has_meta("interaction_id"):
        return str(target.get_meta("interaction_id"))
    if target is Node:
        var node := target as Node
        return "legacy:%s" % str(node.get_path())
    return "legacy:%s" % target.get_class()

static func _legacy_label(target: Object) -> String:
    if target.has_meta("interaction_label"):
        return str(target.get_meta("interaction_label"))
    if target is Node:
        return str((target as Node).name).replace("_", " ")
    return target.get_class()

static func _legacy_verb(target: Object) -> String:
    if target.has_meta("interaction_prompt"):
        return str(target.get_meta("interaction_prompt"))
    if target.has_method("harvest"):
        return "RÉCOLTER"
    if target.has_method("rest"):
        return "SE REPOSER"
    return "INTERAGIR"
