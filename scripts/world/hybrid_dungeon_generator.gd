extends RefCounted
class_name HybridDungeonGenerator

const RULES_PATH := "res://data/dungeons/hybrid_generation_rules.json"

static func generate_graph(config: Dictionary, run_state: Dictionary = {}) -> Dictionary:
    var rules := _load_json(RULES_PATH)
    if rules.is_empty():
        return {"ok": false, "error": "hybrid_rules_missing"}

    var generation: Dictionary = rules.get("generation", {})
    var max_attempts := int(generation.get("max_attempts", 12))
    for attempt_index in max_attempts:
        var seed_value := _compose_seed(config, run_state, attempt_index)
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_value
        var candidate := _build_candidate(config, rules, rng, attempt_index)
        var validation := validate_graph(candidate, config, rules)
        if bool(validation.get("ok", false)):
            candidate["ok"] = true
            candidate["seed"] = seed_value
            candidate["attempt_index"] = attempt_index
            candidate["validation"] = validation
            return candidate

    return {
        "ok": false,
        "error": "generation_failed",
        "fallback_to_authored": bool(generation.get("fallback_to_authored", true))
    }

static func validate_graph(graph: Dictionary, config: Dictionary, rules: Dictionary = {}) -> Dictionary:
    if graph.is_empty():
        return {"ok": false, "errors": ["empty_graph"]}

    var errors: Array[String] = []
    var nodes: Array = graph.get("nodes", [])
    var edges: Array = graph.get("edges", [])
    if nodes.is_empty():
        errors.append("no_nodes")
        return {"ok": false, "errors": errors}

    var entry_id := str(graph.get("entry_id", ""))
    var objective_id := str(graph.get("objective_id", ""))
    if entry_id == "" or objective_id == "":
        errors.append("missing_entry_or_objective")
    elif not _reachable(entry_id, objective_id, edges, false):
        errors.append("objective_unreachable")

    for mandatory_id in config.get("mandatory_room_ids", []):
        if not _has_node(nodes, str(mandatory_id)):
            errors.append("mandatory_room_missing:%s" % str(mandatory_id))

    var secret_ids: Array[String] = []
    for node in nodes:
        if str(node.get("role", "")) == "secret":
            secret_ids.append(str(node.get("id", "")))
    if objective_id in secret_ids:
        errors.append("objective_cannot_be_secret")

    var profile: Dictionary = _resolve_profile(config, rules)
    var room_range: Array = profile.get("room_count", [1, 999])
    if nodes.size() < int(room_range[0]) or nodes.size() > int(room_range[1]):
        errors.append("room_count_out_of_bounds")

    var loop_range: Array = profile.get("loop_target", [0, 999])
    var loop_count := int(graph.get("loop_count", 0))
    if loop_count < int(loop_range[0]) or loop_count > int(loop_range[1]):
        errors.append("loop_count_out_of_bounds")

    if bool(rules.get("global_constraints", {}).get("physical_retreat_required", true)):
        if int(graph.get("retreat_count", 0)) <= 0:
            errors.append("no_retreat")

    return {"ok": errors.is_empty(), "errors": errors}

static func apply_remanence(graph: Dictionary, scars: Array) -> Dictionary:
    var copy := graph.duplicate(true)
    var known_anchors: Dictionary = {}
    for node in copy.get("nodes", []):
        for anchor_id in node.get("scar_anchors", []):
            known_anchors[str(anchor_id)] = true

    var applied: Array = []
    var deferred: Array = []
    for scar in scars:
        var anchor_id := str(scar.get("anchor_id", ""))
        if known_anchors.has(anchor_id):
            applied.append(scar)
        else:
            deferred.append(scar)
    copy["remanence"] = {"applied": applied, "deferred": deferred}
    return copy

static func _build_candidate(config: Dictionary, rules: Dictionary, rng: RandomNumberGenerator, attempt_index: int) -> Dictionary:
    var profile := _resolve_profile(config, rules)
    var critical_range: Array = profile.get("critical_length", [5, 7])
    var critical_length := rng.randi_range(int(critical_range[0]), int(critical_range[1]))
    critical_length = maxi(3, critical_length)

    var nodes: Array = []
    var edges: Array = []

    var entry_id := "room_entry"
    nodes.append(_node(entry_id, "entry", true, 0))

    var previous_id := entry_id
    for i in range(1, critical_length - 1):
        var role := _critical_role_for_index(i, critical_length)
        var node_id := "room_critical_%02d" % i
        nodes.append(_node(node_id, role, true, i))
        edges.append(_edge(previous_id, node_id, "critical"))
        previous_id = node_id

    var objective_id := "room_objective"
    var objective_role := str(config.get("objective_role", "boss"))
    nodes.append(_node(objective_id, objective_role, true, critical_length - 1))
    edges.append(_edge(previous_id, objective_id, "critical"))

    _inject_mandatory_rooms(nodes, edges, config)

    var branch_range: Array = profile.get("branching_target", [1, 2])
    var branch_count := rng.randi_range(int(branch_range[0]), int(branch_range[1]))
    _add_branches(nodes, edges, branch_count, rng)

    var loop_range: Array = profile.get("loop_target", [0, 1])
    var loop_target := rng.randi_range(int(loop_range[0]), int(loop_range[1]))
    var loop_count := _add_loops(nodes, edges, loop_target, rng)

    var secret_range: Array = profile.get("secret_target", [0, 1])
    var secret_count := rng.randi_range(int(secret_range[0]), int(secret_range[1]))
    _add_secrets(nodes, edges, secret_count, rng)

    var room_range: Array = profile.get("room_count", [nodes.size(), nodes.size()])
    _fill_to_minimum_room_count(nodes, edges, int(room_range[0]), rng)

    var retreat_range: Array = profile.get("retreat_points", [1, 2])
    var retreat_count := rng.randi_range(int(retreat_range[0]), int(retreat_range[1]))
    _assign_retreats(nodes, retreat_count)

    return {
        "version": 1,
        "system_id": "les_veilleurs_hybrid_dungeon_v1",
        "dungeon_id": str(config.get("dungeon_id", "unknown_dungeon")),
        "profile": str(config.get("profile", "medium")),
        "attempt_index": attempt_index,
        "entry_id": entry_id,
        "objective_id": objective_id,
        "nodes": nodes,
        "edges": edges,
        "loop_count": loop_count,
        "retreat_count": _count_flag(nodes, "retreat")
    }

static func _add_branches(nodes: Array, edges: Array, count: int, rng: RandomNumberGenerator) -> void:
    for i in count:
        var anchors := _critical_nodes(nodes, false)
        if anchors.is_empty():
            return
        var anchor: Dictionary = anchors[rng.randi_range(0, anchors.size() - 1)]
        var role_pool := ["combat", "resource", "narrative", "hazard", "choice", "elite"]
        var role := str(role_pool[rng.randi_range(0, role_pool.size() - 1)])
        var node_id := "room_branch_%02d" % (i + 1)
        nodes.append(_node(node_id, role, false, int(anchor.get("depth", 0)) + 1))
        edges.append(_edge(str(anchor.get("id", "")), node_id, "branch"))

static func _add_loops(nodes: Array, edges: Array, target: int, rng: RandomNumberGenerator) -> int:
    var added := 0
    for _i in target:
        var optional_nodes: Array = []
        for node in nodes:
            if not bool(node.get("critical", false)) and str(node.get("role", "")) != "secret":
                optional_nodes.append(node)
        var critical_nodes := _critical_nodes(nodes, true)
        if optional_nodes.is_empty() or critical_nodes.size() < 3:
            continue
        var from_node: Dictionary = optional_nodes[rng.randi_range(0, optional_nodes.size() - 1)]
        var from_depth := int(from_node.get("depth", 0))
        var candidates: Array = []
        for candidate in critical_nodes:
            if int(candidate.get("depth", 0)) > from_depth:
                candidates.append(candidate)
        if candidates.is_empty():
            continue
        var to_node: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
        if not _edge_exists(edges, str(from_node.get("id", "")), str(to_node.get("id", ""))):
            edges.append(_edge(str(from_node.get("id", "")), str(to_node.get("id", "")), "loop"))
            added += 1
    return added

static func _add_secrets(nodes: Array, edges: Array, count: int, rng: RandomNumberGenerator) -> void:
    for i in count:
        var anchors := _critical_nodes(nodes, false)
        if anchors.is_empty():
            return
        var anchor: Dictionary = anchors[rng.randi_range(0, anchors.size() - 1)]
        var node_id := "room_secret_%02d" % (i + 1)
        nodes.append(_node(node_id, "secret", false, int(anchor.get("depth", 0)) + 1))
        var edge := _edge(str(anchor.get("id", "")), node_id, "secret")
        edge["hidden"] = true
        edges.append(edge)

static func _fill_to_minimum_room_count(nodes: Array, edges: Array, minimum: int, rng: RandomNumberGenerator) -> void:
    var serial := 1
    while nodes.size() < minimum:
        var anchors := _critical_nodes(nodes, false)
        if anchors.is_empty():
            return
        var anchor: Dictionary = anchors[rng.randi_range(0, anchors.size() - 1)]
        var node_id := "room_filler_%02d" % serial
        serial += 1
        var role_pool := ["transit", "combat", "resource", "narrative", "hazard"]
        var role := str(role_pool[rng.randi_range(0, role_pool.size() - 1)])
        nodes.append(_node(node_id, role, false, int(anchor.get("depth", 0)) + 1))
        edges.append(_edge(str(anchor.get("id", "")), node_id, "branch"))

static func _assign_retreats(nodes: Array, count: int) -> void:
    var eligible: Array = []
    for node in nodes:
        if str(node.get("role", "")) not in ["boss", "secret"]:
            eligible.append(node)
    eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("depth", 0)) < int(b.get("depth", 0)))
    if eligible.is_empty():
        return
    var stride := maxf(1.0, float(eligible.size()) / float(maxi(1, count)))
    for i in count:
        var index := mini(eligible.size() - 1, int(round(float(i) * stride)))
        eligible[index]["retreat"] = true

static func _inject_mandatory_rooms(nodes: Array, _edges: Array, config: Dictionary) -> void:
    for mandatory in config.get("mandatory_rooms", []):
        var room_id := str(mandatory.get("id", ""))
        if room_id == "" or _has_node(nodes, room_id):
            continue
        var role := str(mandatory.get("role", "narrative"))
        var depth := int(mandatory.get("preferred_depth", 1))
        nodes.append(_node(room_id, role, true, depth))

static func _critical_role_for_index(index: int, length: int) -> String:
    var ratio := float(index) / float(maxi(1, length - 1))
    if ratio < 0.20:
        return "transit"
    if ratio < 0.40:
        return "combat"
    if ratio < 0.55:
        return "choice"
    if ratio < 0.75:
        return "hazard"
    return "elite"

static func _node(id_value: String, role: String, critical: bool, depth: int) -> Dictionary:
    return {
        "id": id_value,
        "role": role,
        "critical": critical,
        "depth": depth,
        "retreat": false,
        "module_id": "",
        "scar_anchors": [],
        "variation_seed": 0
    }

static func _edge(from_id: String, to_id: String, kind: String) -> Dictionary:
    return {
        "from": from_id,
        "to": to_id,
        "kind": kind,
        "hidden": false,
        "requires": ""
    }

static func _critical_nodes(nodes: Array, include_objective: bool) -> Array:
    var result: Array = []
    for node in nodes:
        if not bool(node.get("critical", false)):
            continue
        if not include_objective and str(node.get("role", "")) == "boss":
            continue
        result.append(node)
    return result

static func _has_node(nodes: Array, id_value: String) -> bool:
    for node in nodes:
        if str(node.get("id", "")) == id_value:
            return true
    return false

static func _edge_exists(edges: Array, from_id: String, to_id: String) -> bool:
    for edge in edges:
        if str(edge.get("from", "")) == from_id and str(edge.get("to", "")) == to_id:
            return true
    return false

static func _reachable(start_id: String, goal_id: String, edges: Array, include_hidden: bool) -> bool:
    if start_id == goal_id:
        return true
    var visited: Dictionary = {start_id: true}
    var queue: Array[String] = [start_id]
    while not queue.is_empty():
        var current := queue.pop_front()
        for edge in edges:
            if not include_hidden and bool(edge.get("hidden", false)):
                continue
            if str(edge.get("from", "")) != current:
                continue
            var next_id := str(edge.get("to", ""))
            if next_id == goal_id:
                return true
            if not visited.has(next_id):
                visited[next_id] = true
                queue.append(next_id)
    return false

static func _count_flag(nodes: Array, flag: String) -> int:
    var result := 0
    for node in nodes:
        if bool(node.get(flag, false)):
            result += 1
    return result

static func _resolve_profile(config: Dictionary, rules: Dictionary) -> Dictionary:
    var profile_id := str(config.get("profile", "medium"))
    return rules.get("default_profiles", {}).get(profile_id, rules.get("default_profiles", {}).get("medium", {}))

static func _compose_seed(config: Dictionary, run_state: Dictionary, attempt_index: int) -> int:
    var parts := [
        str(run_state.get("campaign_seed", config.get("campaign_seed", 0))),
        str(config.get("dungeon_id", "unknown_dungeon")),
        str(run_state.get("visit_index", config.get("visit_index", 0))),
        str(run_state.get("difficulty_band", config.get("difficulty_band", "normal"))),
        str(run_state.get("story_epoch", config.get("story_epoch", 0))),
        str(attempt_index)
    ]
    return "|".join(parts).hash()

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
