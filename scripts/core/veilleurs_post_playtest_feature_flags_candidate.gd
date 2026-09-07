extends RefCounted
class_name VeilleursPostPlaytestFeatureFlagsCandidate

const CONTRACT_PATH := "res://data/veilleurs/parallel_content/post_playtest_feature_flags_v1.json"

var contract: Dictionary = {}
var resolved_flags: Dictionary = {}
var validation_errors: Array[String] = []

func _init() -> void:
    contract = _load_dictionary(CONTRACT_PATH)
    reset()

func validation_report() -> Dictionary:
    _validate_contract()
    return {
        "ok": validation_errors.is_empty(),
        "errors": validation_errors.duplicate(),
        "flag_count": resolved_flags.size(),
        "all_disabled": _all_disabled()
    }

func reset() -> void:
    resolved_flags.clear()
    var master: Dictionary = contract.get("master_flag", {})
    var master_id := str(master.get("id", ""))
    if not master_id.is_empty():
        resolved_flags[master_id] = false
    for value: Variant in contract.get("flags", []):
        if value is Dictionary:
            var flag_id := str((value as Dictionary).get("id", ""))
            if not flag_id.is_empty():
                resolved_flags[flag_id] = false
    validation_errors.clear()
    _validate_contract()

func configure_overrides(overrides: Dictionary, developer_authorized: bool = false) -> Dictionary:
    reset()
    if overrides.is_empty():
        return {"ok": true, "activated": [], "rejected": [], "snapshot": snapshot()}
    if not developer_authorized:
        return {
            "ok": false,
            "reason": "explicit_developer_authorization_required",
            "activated": [],
            "rejected": overrides.keys(),
            "snapshot": snapshot()
        }

    var rejected: Array[String] = []
    var requested: Array[String] = []
    for key_value: Variant in overrides.keys():
        var flag_id := str(key_value)
        if not resolved_flags.has(flag_id):
            rejected.append(flag_id)
            continue
        if bool(overrides.get(key_value, false)):
            requested.append(flag_id)

    var activation_order: Array = contract.get("activation_order", [])
    for value: Variant in activation_order:
        var flag_id := str(value)
        if flag_id in requested and _parents_enabled_or_requested(flag_id, requested):
            resolved_flags[flag_id] = true
        elif flag_id in requested:
            rejected.append(flag_id)

    var master_id := str((contract.get("master_flag", {}) as Dictionary).get("id", ""))
    if master_id in requested:
        resolved_flags[master_id] = true

    var activated: Array[String] = []
    for key_value: Variant in resolved_flags.keys():
        var flag_id := str(key_value)
        if bool(resolved_flags.get(flag_id, false)):
            activated.append(flag_id)
    activated.sort()
    rejected.sort()
    return {
        "ok": rejected.is_empty(),
        "activated": activated,
        "rejected": rejected,
        "snapshot": snapshot()
    }

func enabled(flag_id: String) -> bool:
    if not resolved_flags.has(flag_id):
        return false
    if not bool(resolved_flags.get(flag_id, false)):
        return false
    var master_id := str((contract.get("master_flag", {}) as Dictionary).get("id", ""))
    if flag_id == master_id:
        return true
    return bool(resolved_flags.get(master_id, false)) and _all_required_parents_enabled(flag_id)

func snapshot() -> Dictionary:
    return {
        "flags": resolved_flags.duplicate(true),
        "all_disabled": _all_disabled(),
        "developer_configuration_only": true
    }

func _all_disabled() -> bool:
    for value: Variant in resolved_flags.values():
        if bool(value):
            return false
    return true

func _parents_enabled_or_requested(flag_id: String, requested: Array[String]) -> bool:
    var definition := _flag_definition(flag_id)
    for value: Variant in definition.get("requires", []):
        var parent := str(value)
        if not bool(resolved_flags.get(parent, false)) and not parent in requested:
            return false
    return true

func _all_required_parents_enabled(flag_id: String) -> bool:
    var definition := _flag_definition(flag_id)
    for value: Variant in definition.get("requires", []):
        if not bool(resolved_flags.get(str(value), false)):
            return false
    return true

func _flag_definition(flag_id: String) -> Dictionary:
    var master: Dictionary = contract.get("master_flag", {})
    if str(master.get("id", "")) == flag_id:
        return master.duplicate(true)
    for value: Variant in contract.get("flags", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == flag_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _validate_contract() -> void:
    validation_errors.clear()
    if bool(contract.get("enabled_by_default", true)):
        validation_errors.append("contract_must_be_inactive")
    var master: Dictionary = contract.get("master_flag", {})
    var master_id := str(master.get("id", ""))
    if master_id.is_empty():
        validation_errors.append("missing_master_flag")
    if bool(master.get("default", true)):
        validation_errors.append("master_default_must_be_false")
    for value: Variant in contract.get("flags", []):
        if not (value is Dictionary):
            validation_errors.append("invalid_flag_definition")
            continue
        var definition: Dictionary = value
        var flag_id := str(definition.get("id", ""))
        if flag_id.is_empty():
            validation_errors.append("empty_flag_id")
        if bool(definition.get("default", true)):
            validation_errors.append("flag_default_true:%s" % flag_id)
        for parent_value: Variant in definition.get("requires", []):
            var parent := str(parent_value)
            if not resolved_flags.has(parent):
                validation_errors.append("unknown_parent:%s->%s" % [flag_id, parent])

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
