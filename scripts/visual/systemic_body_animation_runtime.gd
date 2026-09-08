class_name SystemicBodyAnimationRuntime
extends RefCounted

const CONTRACT_PATH := "res://data/blender/systemic_animation_v44.json"

var contract: Dictionary = {}
var body_runtime := SystemicBodyVisualRuntime.new()

func version() -> int:
    _ensure_contract()
    return int(contract.get("version", 0))

func build_plan(character: Dictionary) -> Dictionary:
    _ensure_contract()
    var body_snapshot := body_runtime.apply(null, character)
    var states: Dictionary = (body_snapshot.get("functional_states", {}) as Dictionary).duplicate(true)
    var morphology := str(body_snapshot.get("morphology", "HUMANOID"))
    var severity := 0
    var f3_parts: Array[String] = []
    var f4_parts: Array[String] = []
    var locomotion_damage := 0.0
    var upper_body_damage := 0.0
    var left_available := true
    var right_available := true

    for key_value: Variant in states.keys():
        var part := str(key_value)
        var state := str(states.get(key_value, "F0"))
        var rank := _state_rank(state)
        severity = maxi(severity, rank)
        if state == "F3":
            f3_parts.append(part)
        elif state == "F4":
            f4_parts.append(part)
        if _is_locomotion_part(part):
            locomotion_damage = maxf(locomotion_damage, float(rank) / 4.0)
        if _is_manipulator_part(part):
            upper_body_damage = maxf(upper_body_damage, float(rank) / 4.0)
            var side := _side_of(part)
            if rank >= 3 and side == "left":
                left_available = false
            elif rank >= 3 and side == "right":
                right_available = false

    var global_state := "F%d" % severity
    var action_requests: Array[String] = []
    if severity <= 2:
        action_requests.append(str((contract.get("state_contract", {}) as Dictionary).get(global_state, {}).get("global_clip", "body_f0")))
    for part: String in f3_parts:
        action_requests.append(_state_action("F3", part))
        if _is_locomotion_part(part):
            action_requests.append("move_f3_%s" % part)
    for part: String in f4_parts:
        action_requests.append(_state_action("F4", part))
        if _is_locomotion_part(part):
            action_requests.append("move_f4_%s" % part)

    var attack_profile := "default"
    if left_available and not right_available:
        attack_profile = "one_hand_left"
        action_requests.append("combat_idle_1h_left")
    elif right_available and not left_available:
        attack_profile = "one_hand_right"
        action_requests.append("combat_idle_1h_right")
    elif not left_available and not right_available:
        attack_profile = "no_compatible_manipulator"

    var morphology_mode: Dictionary = _resolved_morphology_mode(morphology)
    return {
        "version": version(),
        "morphology": morphology,
        "functional_states": states,
        "severity": severity,
        "global_state": global_state,
        "f3_parts": f3_parts,
        "f4_parts": f4_parts,
        "locomotion_damage": locomotion_damage,
        "upper_body_damage": upper_body_damage,
        "left_manipulator_available": left_available,
        "right_manipulator_available": right_available,
        "attack_profile": attack_profile,
        "action_requests": action_requests,
        "locomotion_mode": str(morphology_mode.get("locomotion", "declared_parts_only")),
        "upper_body_mode": str(morphology_mode.get("upper_body", "declared_parts_only")),
        "equipment_adaptation": contract.get("equipment_adaptation", {}),
        "gameplay_untouched": true
    }

func apply(animation_tree: AnimationTree, character: Dictionary) -> Dictionary:
    var plan := build_plan(character)
    if animation_tree == null:
        plan["animation_tree_found"] = false
        return plan
    var parameters: Dictionary = contract.get("animation_tree_parameters", {})
    _set_tree_parameter(animation_tree, str(parameters.get("severity", "")), float(plan.get("severity", 0)) / 4.0)
    _set_tree_parameter(animation_tree, str(parameters.get("asymmetry", "")), 1.0 if int(plan.get("severity", 0)) >= 2 else 0.0)
    _set_tree_parameter(animation_tree, str(parameters.get("locomotion_damage", "")), float(plan.get("locomotion_damage", 0.0)))
    _set_tree_parameter(animation_tree, str(parameters.get("upper_body_damage", "")), float(plan.get("upper_body_damage", 0.0)))
    _set_tree_parameter(animation_tree, str(parameters.get("left_manipulator_available", "")), 1.0 if bool(plan.get("left_manipulator_available", true)) else 0.0)
    _set_tree_parameter(animation_tree, str(parameters.get("right_manipulator_available", "")), 1.0 if bool(plan.get("right_manipulator_available", true)) else 0.0)
    plan["animation_tree_found"] = true
    return plan

func _ensure_contract() -> void:
    if not contract.is_empty():
        return
    if not FileAccess.file_exists(CONTRACT_PATH):
        push_error("SystemicBodyAnimationRuntime: missing contract: %s" % CONTRACT_PATH)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    if parsed is Dictionary:
        contract = (parsed as Dictionary).duplicate(true)
    else:
        push_error("SystemicBodyAnimationRuntime: invalid v44 contract")

func _state_action(state: String, part: String) -> String:
    var states: Dictionary = contract.get("state_contract", {})
    var spec: Dictionary = states.get(state, {})
    return str(spec.get("per_part_pattern", "body_%s_{part}" % state.to_lower())).format({"part": part})

func _is_locomotion_part(part: String) -> bool:
    var lower := part.to_lower()
    for token_value: Variant in contract.get("locomotion_part_keywords", []):
        if str(token_value).to_lower() in lower:
            return true
    return false

func _is_manipulator_part(part: String) -> bool:
    var lower := part.to_lower()
    for token_value: Variant in contract.get("manipulator_part_keywords", []):
        if str(token_value).to_lower() in lower:
            return true
    return false

func _side_of(part: String) -> String:
    var lower := part.to_lower()
    if "left" in lower or lower.ends_with("_l"):
        return "left"
    if "right" in lower or lower.ends_with("_r"):
        return "right"
    return ""

func _resolved_morphology_mode(morphology: String) -> Dictionary:
    var modes: Dictionary = contract.get("morphology_modes", {})
    var raw: Dictionary = (modes.get(morphology, modes.get("BOSS_CUSTOM", {})) as Dictionary).duplicate(true)
    var parent := str(raw.get("inherit", ""))
    if parent == "":
        return raw
    var base := _resolved_morphology_mode(parent)
    base.merge(raw, true)
    base.erase("inherit")
    return base

func _state_rank(state: String) -> int:
    match state:
        "F1": return 1
        "F2": return 2
        "F3": return 3
        "F4": return 4
        _: return 0

func _set_tree_parameter(tree: AnimationTree, path: String, value: Variant) -> void:
    if path == "":
        return
    for property_info: Dictionary in tree.get_property_list():
        if str(property_info.get("name", "")) == path:
            tree.set(path, value)
            return
