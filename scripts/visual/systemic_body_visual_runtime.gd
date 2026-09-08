class_name SystemicBodyVisualRuntime
extends RefCounted

const CONTRACT_PATH := "res://data/body_visual_runtime_v42.json"

var contract: Dictionary = {}

func version() -> int:
    _ensure_contract()
    return int(contract.get("version", 0))

func apply(actor_root: Node3D, character: Dictionary, animation_tree: AnimationTree = null) -> Dictionary:
    _ensure_contract()
    var morphology_key := _morphology_key(character)
    var morphology_contract := _resolved_morphology_contract(morphology_key)
    var states := _resolve_functional_states(character, morphology_contract)
    _propagate_dependencies(states, morphology_contract)

    if actor_root == null:
        return {
            "version": version(),
            "morphology": morphology_key,
            "functional_states": states,
            "actor_found": false,
            "removed_segments": [],
            "disabled_segments": [],
            "missing_affected_markers": [],
            "weapon": {"status": "no_actor"}
        }

    var markers := _collect_markers(actor_root, morphology_contract)
    var removed_segments: Array[String] = []
    var disabled_segments: Array[String] = []
    var missing_affected_markers: Array[String] = []
    var affected_equipment: Array[String] = []

    var parts_to_apply: Dictionary = {}
    var segment_table: Dictionary = markers.get("segments", {})
    var stump_table: Dictionary = markers.get("stumps", {})
    var f3_pose_table: Dictionary = markers.get("f3_poses", {})
    for key_value: Variant in segment_table.keys():
        parts_to_apply[str(key_value)] = true
    for key_value: Variant in stump_table.keys():
        parts_to_apply[str(key_value)] = true
    for key_value: Variant in f3_pose_table.keys():
        parts_to_apply[str(key_value)] = true
    for key_value: Variant in states.keys():
        parts_to_apply[str(key_value)] = true

    for key_value: Variant in parts_to_apply.keys():
        var part := str(key_value)
        var state := str(states.get(part, "F0"))
        var segments: Array = segment_table.get(part, [])
        var stumps: Array = stump_table.get(part, [])
        var f3_poses: Array = f3_pose_table.get(part, [])
        _set_nodes_visible(segments, state != "F4")
        _set_nodes_visible(stumps, state == "F4")
        _set_nodes_visible(f3_poses, state == "F3")
        _set_nodes_state_meta(segments, state)
        _set_nodes_state_meta(stumps, state)
        _set_nodes_state_meta(f3_poses, state)

        if state == "F3":
            disabled_segments.append(part)
        elif state == "F4":
            removed_segments.append(part)

        if state in ["F3", "F4"] and segments.is_empty():
            missing_affected_markers.append(part)

        if state == "F4":
            var equipment_table: Dictionary = markers.get("equipment", {})
            var equipment_nodes: Array = equipment_table.get(part, [])
            _set_nodes_visible(equipment_nodes, false)
            for node_value: Variant in equipment_nodes:
                if node_value is Node:
                    affected_equipment.append(str((node_value as Node).name))
        elif state != "F4":
            var equipment_table_restore: Dictionary = markers.get("equipment", {})
            _set_nodes_visible(equipment_table_restore.get(part, []), true)

        _apply_animation_state(animation_tree, part, state)

    var weapon_result := _apply_weapon_presentation(markers, states, morphology_contract, character)
    return {
        "version": version(),
        "morphology": morphology_key,
        "functional_states": states,
        "actor_found": true,
        "removed_segments": removed_segments,
        "disabled_segments": disabled_segments,
        "missing_affected_markers": missing_affected_markers,
        "affected_equipment": affected_equipment,
        "weapon": weapon_result,
        "marker_counts": {
            "segments": _table_node_count(segment_table),
            "stumps": _table_node_count(stump_table),
            "f3_poses": _table_node_count(f3_pose_table),
            "equipment": _table_node_count(markers.get("equipment", {})),
            "weapons": (markers.get("weapon_nodes", []) as Array).size()
        },
        "gameplay_untouched": true
    }

func _ensure_contract() -> void:
    if not contract.is_empty():
        return
    if not FileAccess.file_exists(CONTRACT_PATH):
        push_error("SystemicBodyVisualRuntime: missing contract: %s" % CONTRACT_PATH)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    if parsed is Dictionary:
        contract = (parsed as Dictionary).duplicate(true)
    else:
        push_error("SystemicBodyVisualRuntime: invalid v42 contract")

func _morphology_key(character: Dictionary) -> String:
    _ensure_contract()
    var morphologies: Dictionary = contract.get("morphologies", {})
    for key in ["morphology", "anatomy_profile", "body_profile", "anatomy_type"]:
        var value := str(character.get(key, "")).strip_edges().to_upper()
        if value == "":
            continue
        if morphologies.has(value):
            return value
        if value.contains("HUMANOID"):
            return "HUMANOID"
        return "BOSS_CUSTOM"
    return "HUMANOID"

func _resolved_morphology_contract(morphology_key: String) -> Dictionary:
    var morphologies: Dictionary = contract.get("morphologies", {})
    var raw: Dictionary = (morphologies.get(morphology_key, morphologies.get("BOSS_CUSTOM", {})) as Dictionary).duplicate(true)
    var inherited := str(raw.get("inherit", ""))
    if inherited == "":
        return raw
    var base: Dictionary = _resolved_morphology_contract(inherited)
    base.merge(raw, true)
    base.erase("inherit")
    return base

func _resolve_functional_states(character: Dictionary, morphology_contract: Dictionary) -> Dictionary:
    var states: Dictionary = {}
    for field in ["functional_body_states", "body_function_states", "functional_states"]:
        var explicit_value: Variant = character.get(field, {})
        if explicit_value is Dictionary:
            var explicit: Dictionary = explicit_value
            for part_value: Variant in explicit.keys():
                var part := _canonical_part(str(part_value), morphology_contract)
                if part != "":
                    _set_stronger_state(states, part, _normalize_state(explicit.get(part_value, "F0")))

    var injury_value: Variant = character.get("applied_injury_states", {})
    if injury_value is Dictionary:
        var injuries: Dictionary = injury_value
        for part_value: Variant in injuries.keys():
            var part := _canonical_part(str(part_value), morphology_contract)
            if part != "":
                _set_stronger_state(states, part, _state_from_injury(injuries.get(part_value)))

    for field in ["disabled_parts", "unusable_parts", "critically_disabled_parts"]:
        _merge_part_array(states, character.get(field, []), "F3", morphology_contract)
    for field in ["dismembered_parts", "amputated_parts", "destroyed_parts", "severed_parts", "missing_parts"]:
        _merge_part_array(states, character.get(field, []), "F4", morphology_contract)

    return states

func _merge_part_array(states: Dictionary, values: Variant, state: String, morphology_contract: Dictionary) -> void:
    if not values is Array:
        return
    for value: Variant in values:
        var part := _canonical_part(str(value), morphology_contract)
        if part != "":
            _set_stronger_state(states, part, state)

func _state_from_injury(value: Variant) -> String:
    if value is Dictionary:
        var injury: Dictionary = value
        for field in ["functional_state", "state", "severity"]:
            if injury.has(field):
                return _normalize_state(injury.get(field))
        return "F1"
    return _normalize_state(value)

func _normalize_state(value: Variant) -> String:
    if value is int or value is float:
        var rank := clampi(int(value), 0, 4)
        return "F%d" % rank
    var raw := str(value).strip_edges()
    var upper := raw.to_upper()
    if upper in ["F0", "F1", "F2", "F3", "F4"]:
        return upper
    var mapped := str((contract.get("injury_state_map", {}) as Dictionary).get(raw.to_lower(), "F1"))
    return mapped if mapped in ["F0", "F1", "F2", "F3", "F4"] else "F1"

func _set_stronger_state(states: Dictionary, part: String, state: String) -> void:
    var current := str(states.get(part, "F0"))
    if _state_rank(state) >= _state_rank(current):
        states[part] = state

func _state_rank(state: String) -> int:
    match state:
        "F1": return 1
        "F2": return 2
        "F3": return 3
        "F4": return 4
        _: return 0

func _propagate_dependencies(states: Dictionary, morphology_contract: Dictionary) -> void:
    var dependencies: Dictionary = morphology_contract.get("dependencies", {})
    for parent_value: Variant in dependencies.keys():
        var parent := str(parent_value)
        var parent_state := str(states.get(parent, "F0"))
        if _state_rank(parent_state) < 3:
            continue
        var children_value: Variant = dependencies.get(parent_value, [])
        if not children_value is Array:
            continue
        for child_value: Variant in children_value:
            var child := str(child_value)
            _set_stronger_state(states, child, parent_state)

func _canonical_part(raw_value: String, morphology_contract: Dictionary) -> String:
    var normalized := _normalize_part_token(raw_value)
    if normalized == "":
        return ""
    var parts_value: Variant = morphology_contract.get("parts", [])
    if parts_value is Array:
        for part_value: Variant in parts_value:
            if _normalize_part_token(str(part_value)) == normalized:
                return str(part_value)
    var aliases: Dictionary = morphology_contract.get("aliases", {})
    for canonical_value: Variant in aliases.keys():
        var canonical := str(canonical_value)
        var alias_values: Variant = aliases.get(canonical_value, [])
        if alias_values is Array:
            for alias_value: Variant in alias_values:
                if _normalize_part_token(str(alias_value)) == normalized:
                    return canonical
    return normalized

func _normalize_part_token(value: String) -> String:
    var result := value.strip_edges().to_lower()
    for separator in [" ", "-", ".", "/", "\\", ":"]:
        result = result.replace(separator, "_")
    while result.contains("__"):
        result = result.replace("__", "_")
    return result.trim_prefix("body_").trim_prefix("stump_").trim_prefix("pose_f3_")

func _collect_markers(root: Node, morphology_contract: Dictionary) -> Dictionary:
    var markers := {
        "segments": {},
        "stumps": {},
        "f3_poses": {},
        "equipment": {},
        "weapon_nodes": [],
        "sockets": {}
    }
    _scan_marker_node(root, markers, morphology_contract)
    _collect_socket_children_as_weapon_fallback(markers)
    return markers

func _scan_marker_node(node: Node, markers: Dictionary, morphology_contract: Dictionary) -> void:
    var marker_contract: Dictionary = contract.get("marker_contract", {})
    var node_name := str(node.name)
    var segment_prefix := str(marker_contract.get("segment_prefix", "BODY_"))
    var stump_prefix := str(marker_contract.get("stump_prefix", "STUMP_"))
    var f3_pose_prefix := str(marker_contract.get("f3_pose_prefix", "POSE_F3_"))
    var equipment_prefix := str(marker_contract.get("equipment_prefix", "EQUIP_"))
    var segment_meta := str(marker_contract.get("segment_meta", "litd_body_part"))
    var stump_meta := str(marker_contract.get("stump_meta", "litd_stump_for"))
    var equipment_part_meta := str(marker_contract.get("equipment_part_meta", "litd_equipment_for"))
    var equipment_role_meta := str(marker_contract.get("equipment_role_meta", "litd_equipment_role"))
    var weapon_role := str(marker_contract.get("weapon_role", "weapon"))

    var segment_raw := ""
    if node.has_meta(segment_meta):
        segment_raw = str(node.get_meta(segment_meta))
    elif node_name.begins_with(segment_prefix):
        segment_raw = node_name.substr(segment_prefix.length())
    if segment_raw != "":
        _append_table_node(markers["segments"], _canonical_part(segment_raw, morphology_contract), node)

    var stump_raw := ""
    if node.has_meta(stump_meta):
        stump_raw = str(node.get_meta(stump_meta))
    elif node_name.begins_with(stump_prefix):
        stump_raw = node_name.substr(stump_prefix.length())
    if stump_raw != "":
        _append_table_node(markers["stumps"], _canonical_part(stump_raw, morphology_contract), node)

    if node_name.begins_with(f3_pose_prefix):
        var pose_raw := node_name.substr(f3_pose_prefix.length())
        _append_table_node(markers["f3_poses"], _canonical_part(pose_raw, morphology_contract), node)

    if node.has_meta(equipment_part_meta):
        var equipment_part := _canonical_part(str(node.get_meta(equipment_part_meta)), morphology_contract)
        _append_table_node(markers["equipment"], equipment_part, node)

    var equipment_role := str(node.get_meta(equipment_role_meta, "")) if node.has_meta(equipment_role_meta) else ""
    if equipment_role == weapon_role or node_name.begins_with(equipment_prefix + "weapon"):
        (markers["weapon_nodes"] as Array).append(node)

    var socket_names: Dictionary = marker_contract.get("weapon_sockets", {})
    for side_value: Variant in socket_names.keys():
        var side := str(side_value)
        if node_name == str(socket_names.get(side_value, "")):
            (markers["sockets"] as Dictionary)[side] = node

    for child: Node in node.get_children():
        _scan_marker_node(child, markers, morphology_contract)

func _collect_socket_children_as_weapon_fallback(markers: Dictionary) -> void:
    var weapons: Array = markers.get("weapon_nodes", [])
    if not weapons.is_empty():
        return
    var sockets: Dictionary = markers.get("sockets", {})
    for socket_value: Variant in sockets.values():
        if not socket_value is Node:
            continue
        var socket := socket_value as Node
        for child: Node in socket.get_children():
            if child is Node3D:
                weapons.append(child)
    markers["weapon_nodes"] = weapons

func _append_table_node(table_value: Variant, key: String, node: Node) -> void:
    if key == "" or not table_value is Dictionary:
        return
    var table: Dictionary = table_value
    var bucket: Array = table.get(key, [])
    bucket.append(node)
    table[key] = bucket

func _set_nodes_visible(nodes: Array, visible: bool) -> void:
    for node_value: Variant in nodes:
        if node_value is Node3D:
            (node_value as Node3D).visible = visible
        elif node_value is CanvasItem:
            (node_value as CanvasItem).visible = visible

func _set_nodes_state_meta(nodes: Array, state: String) -> void:
    for node_value: Variant in nodes:
        if node_value is Node:
            (node_value as Node).set_meta("litd_visual_functional_state", state)

func _apply_animation_state(animation_tree: AnimationTree, part: String, state: String) -> void:
    if animation_tree == null:
        return
    _set_tree_parameter(animation_tree, "parameters/body_state/%s_disabled" % part, 1.0 if state == "F3" else 0.0)
    _set_tree_parameter(animation_tree, "parameters/body_state/%s_missing" % part, 1.0 if state == "F4" else 0.0)
    _set_tree_parameter(animation_tree, "parameters/body_state/%s_degradation" % part, float(_state_rank(state)) / 4.0)

func _set_tree_parameter(animation_tree: AnimationTree, path: String, value: Variant) -> void:
    for property_value: Variant in animation_tree.get_property_list():
        if property_value is Dictionary and str(property_value.get("name", "")) == path:
            animation_tree.set(path, value)
            return

func _apply_weapon_presentation(markers: Dictionary, states: Dictionary, morphology_contract: Dictionary, character: Dictionary) -> Dictionary:
    var weapon_nodes: Array = markers.get("weapon_nodes", [])
    if weapon_nodes.is_empty():
        return {"status": "no_weapon_visual", "reassigned": false, "visible": false}

    var sockets: Dictionary = markers.get("sockets", {})
    var preferred_side := _preferred_weapon_side(character)
    var transfer_rule := str(character.get("visual_weapon_transfer", morphology_contract.get("weapon_transfer", "none")))
    var requirements: Dictionary = morphology_contract.get("weapon_side_requirements", {})
    var custom_requirements: Variant = character.get("visual_weapon_requirements", {})
    if custom_requirements is Dictionary and not (custom_requirements as Dictionary).is_empty():
        requirements = (custom_requirements as Dictionary).duplicate(true)
    var mode := str(morphology_contract.get("weapon_side_mode", "all"))
    var current_side := _current_weapon_side(weapon_nodes, sockets, preferred_side)
    var preferred_usable := _side_usable(preferred_side, states, requirements, mode)
    var opposite_side := "left" if preferred_side == "right" else "right"
    var opposite_usable := _side_usable(opposite_side, states, requirements, mode)
    var desired_side := ""

    if preferred_usable:
        desired_side = preferred_side
    elif transfer_rule != "none" and opposite_usable:
        desired_side = opposite_side

    if desired_side == "":
        _set_nodes_visible(weapon_nodes, false)
        return {
            "status": "no_functional_manipulator",
            "preferred_side": preferred_side,
            "side_before": current_side,
            "side_after": "",
            "reassigned": false,
            "visible": false,
            "transfer_rule": transfer_rule
        }

    var target_socket_value: Variant = sockets.get(desired_side)
    if not target_socket_value is Node:
        _set_nodes_visible(weapon_nodes, true)
        return {
            "status": "target_socket_missing",
            "preferred_side": preferred_side,
            "side_before": current_side,
            "side_after": current_side,
            "reassigned": false,
            "visible": true,
            "transfer_rule": transfer_rule,
            "missing_socket": desired_side
        }

    var target_socket := target_socket_value as Node
    for weapon_value: Variant in weapon_nodes:
        if not weapon_value is Node:
            continue
        var weapon := weapon_value as Node
        if weapon.get_parent() != target_socket:
            weapon.reparent(target_socket, false)
            if weapon is Node3D:
                (weapon as Node3D).transform = Transform3D.IDENTITY
        if weapon is Node3D:
            (weapon as Node3D).visible = true
        elif weapon is CanvasItem:
            (weapon as CanvasItem).visible = true

    return {
        "status": "reassigned" if desired_side != preferred_side else "preferred_side",
        "preferred_side": preferred_side,
        "side_before": current_side,
        "side_after": desired_side,
        "reassigned": desired_side != preferred_side,
        "visible": true,
        "transfer_rule": transfer_rule
    }

func _preferred_weapon_side(character: Dictionary) -> String:
    for key in ["weapon_hand", "dominant_hand", "preferred_hand"]:
        var value := str(character.get(key, "")).strip_edges().to_lower()
        if value in ["left", "l", "gauche", "g"]:
            return "left"
        if value in ["right", "r", "droite", "d"]:
            return "right"
    return "right"

func _side_usable(side: String, states: Dictionary, requirements: Dictionary, mode: String) -> bool:
    var values: Variant = requirements.get(side, [])
    if not values is Array or (values as Array).is_empty():
        return false
    var parts: Array = values
    if mode == "any":
        for part_value: Variant in parts:
            if _state_rank(str(states.get(str(part_value), "F0"))) < 3:
                return true
        return false
    for part_value: Variant in parts:
        if _state_rank(str(states.get(str(part_value), "F0"))) >= 3:
            return false
    return true

func _current_weapon_side(weapon_nodes: Array, sockets: Dictionary, fallback: String) -> String:
    for side in ["left", "right"]:
        var socket_value: Variant = sockets.get(side)
        if not socket_value is Node:
            continue
        var socket := socket_value as Node
        for weapon_value: Variant in weapon_nodes:
            if weapon_value is Node and _is_descendant_of(weapon_value as Node, socket):
                return side
    return fallback

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
    var cursor := node.get_parent()
    while cursor != null:
        if cursor == ancestor:
            return true
        cursor = cursor.get_parent()
    return false

func _table_node_count(table_value: Variant) -> int:
    if not table_value is Dictionary:
        return 0
    var total := 0
    var table: Dictionary = table_value
    for value: Variant in table.values():
        if value is Array:
            total += (value as Array).size()
    return total
