extends Node

signal role_changed(role_id: String, hero_id: String)
signal perception_revealed(kind: String, target_id: String, result: Dictionary)
signal trap_state_changed(trap_id: String, state: String, result: Dictionary)
signal patrol_state_changed(patrol_id: String, state: String)
signal room_state_changed(room_id: String, state: Dictionary)
signal marker_changed(marker_id: String, removed: bool)
signal retreat_planned(plan: Dictionary)
signal retreat_resolved(result: Dictionary)
signal discovery_recorded(discovery: Dictionary)

const DATA_PATH := "res://data/exploration_systems.json"

var rules: Dictionary = {}
var roles: Dictionary = {}
var traps: Dictionary = {}
var patrols: Dictionary = {}
var rooms: Dictionary = {}
var markers: Array = []
var discoveries: Dictionary = {}
var landmarks: Dictionary = {}
var noise_level := 0.0
var light_level := 1.0
var depth := 0
var last_retreat_plan: Dictionary = {}

func _ready() -> void:
    _load_rules()

func _load_rules() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    rules = parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    roles.clear()
    traps.clear()
    patrols.clear()
    rooms.clear()
    markers.clear()
    discoveries.clear()
    landmarks.clear()
    noise_level = 0.0
    light_level = 1.0
    depth = 0
    last_retreat_plan.clear()

func begin_expedition() -> void:
    if roles.is_empty():
        auto_assign_roles()
    traps.clear()
    patrols.clear()
    rooms.clear()
    markers.clear()
    noise_level = 0.0
    light_level = 1.0
    depth = 0
    last_retreat_plan.clear()

func auto_assign_roles() -> Dictionary:
    var available: Array = GameState.alive_heroes().duplicate()
    var preferred: Array[String] = ["scout", "vanguard", "rearguard", "guide"]
    var healer := PersistentInjuryRuntime.available_healer(available)
    if not healer.is_empty():
        assign_role("field_healer", str(healer.get("id", "")))
        available.erase(healer)
        preferred = ["scout", "vanguard", "rearguard"]
    for role_id: String in preferred:
        if available.is_empty():
            break
        var hero: Dictionary = available.pop_front()
        assign_role(role_id, str(hero.get("id", "")))
    return roles.duplicate(true)

func assign_role(role_id: String, hero_id: String) -> Dictionary:
    if not rules.get("roles", {}).has(role_id):
        return {"success": false, "reason": "unknown_role"}
    if _hero_by_id(hero_id).is_empty():
        return {"success": false, "reason": "unknown_hero"}
    for existing_role: Variant in roles.keys():
        if str(roles.get(existing_role, "")) == hero_id:
            roles.erase(existing_role)
    roles[role_id] = hero_id
    role_changed.emit(role_id, hero_id)
    return {"success": true, "role": role_id, "hero_id": hero_id, "score": role_score(role_id)}

func role_score(role_id: String) -> int:
    var hero := _hero_by_id(str(roles.get(role_id, "")))
    if hero.is_empty():
        return 0
    var role: Dictionary = rules.get("roles", {}).get(role_id, {})
    var score := 50
    score += int(role.get("perception", 0))
    score += int(role.get("navigation", 0))
    score += int(role.get("trap_detection", 0))
    score += int(role.get("pursuit_detection", 0))
    var posture := PsychologyRuntime.psychological_posture_label(hero)
    score += int(rules.get("posture_modifiers", {}).get(posture, 0))
    score += int(CharacterTraitDirector.modifiers(hero).get("exploration", 0))
    for injury_value: Variant in hero.get("persistent_injuries", hero.get("injuries", [])):
        var injury_text := str(injury_value).to_lower()
        for body_part: Variant in rules.get("injury_penalties", {}).keys():
            if str(body_part) in injury_text:
                score += int(rules.get("injury_penalties", {}).get(body_part, 0))
    return clampi(score, 5, 95)

func perceive(kind: String, target_id: String, difficulty: int, context: Dictionary = {}) -> Dictionary:
    var role_id := _role_for_perception(kind)
    var score := role_score(role_id)
    var roll := _stable_roll("%d|%s|%s|%s|%d" % [ExpeditionManager.expedition_seed, AshlandsRuntime.current_zone_id, kind, target_id, depth])
    var success := roll <= clampi(score - difficulty + 50, 5, 95)
    var result := {
        "success": success,
        "kind": kind,
        "target_id": target_id,
        "role": role_id,
        "roll": roll,
        "score": score,
        "difficulty": difficulty,
        "world_cue_only": true
    }
    if success:
        var channels: Array = context.get("channels", ["sons", "traces", "architecture"])
        HUDDirector.request_world_guidance(target_id, channels, {"source": "exploration_perception", "kind": kind})
        perception_revealed.emit(kind, target_id, result.duplicate(true))
    return result

func register_trap(trap_id: String, trap_type: String, room_id: String, overrides: Dictionary = {}) -> Dictionary:
    var definition: Dictionary = rules.get("traps", {}).get(trap_type, {})
    if trap_id.is_empty() or definition.is_empty():
        return {}
    var trap := definition.duplicate(true)
    trap.merge(overrides, true)
    trap["id"] = trap_id
    trap["type"] = trap_type
    trap["room_id"] = room_id
    trap["state"] = "hidden"
    trap["detected_by"] = ""
    traps[trap_id] = trap
    return trap.duplicate(true)

func inspect_trap(trap_id: String) -> Dictionary:
    var trap: Dictionary = traps.get(trap_id, {})
    if trap.is_empty() or str(trap.get("state", "")) not in ["hidden", "detected"]:
        return {"success": false, "reason": "unavailable"}
    var result := perceive("trap", trap_id, int(trap.get("difficulty", 40)), {"channels": ["traces", "sons", "architecture"]})
    if bool(result.get("success", false)):
        trap["state"] = "detected"
        trap["detected_by"] = str(roles.get("scout", roles.get("vanguard", "")))
        traps[trap_id] = trap
        trap_state_changed.emit(trap_id, "detected", result)
    return result

func resolve_trap(trap_id: String, action_id: String) -> Dictionary:
    var trap: Dictionary = traps.get(trap_id, {})
    if trap.is_empty():
        return {"success": false, "reason": "unknown_trap"}
    if action_id not in trap.get("actions", []):
        return {"success": false, "reason": "invalid_action"}
    var difficulty := int(trap.get("difficulty", 40))
    var score := role_score("scout")
    if action_id in ["avoid", "bypass", "abandon"]:
        score = maxi(score, role_score("guide"))
    elif action_id in ["remote_trigger", "destroy"]:
        score = maxi(score, role_score("vanguard"))
    var roll := _stable_roll("%s|%s|%s|%d" % [trap_id, action_id, str(roles), ExpeditionManager.expedition_seed])
    var success := roll <= clampi(score - difficulty + 55, 10, 95)
    var result := {"success": success, "trap_id": trap_id, "action": action_id, "roll": roll}
    if success:
        trap["state"] = "neutralized" if action_id not in ["bypass", "avoid", "abandon"] else "bypassed"
        if action_id == "remote_trigger":
            trap["usable_against_enemies"] = true
    else:
        trap["state"] = "triggered"
        result["consequences"] = _apply_trap_failure(trap.get("failure", {}))
    traps[trap_id] = trap
    trap_state_changed.emit(trap_id, str(trap.get("state", "")), result.duplicate(true))
    return result

func emit_noise(amount: float, source: String, position_id: String = "") -> Dictionary:
    noise_level = clampf(noise_level + maxf(amount, 0.0), 0.0, 100.0)
    var alerted: Array[String] = []
    for patrol_id_value: Variant in patrols.keys():
        var patrol_id := str(patrol_id_value)
        var patrol: Dictionary = patrols[patrol_id]
        if str(patrol.get("state", "patrol")) == "defeated":
            continue
        if noise_level >= float(patrol.get("hearing_threshold", 35.0)):
            patrol["state"] = "investigate"
            patrol["target"] = position_id
            patrols[patrol_id] = patrol
            alerted.append(patrol_id)
            patrol_state_changed.emit(patrol_id, "investigate")
    return {"noise": noise_level, "source": source, "alerted": alerted}

func set_light_level(value: float, source: String = "") -> Dictionary:
    light_level = clampf(value, 0.0, 1.0)
    return {
        "light": light_level,
        "source": source,
        "visibility": light_level,
        "trace_reveal_bonus": 12 if light_level >= 0.65 else 0,
        "enemy_detection_risk": int(round(light_level * 25.0))
    }

func listen_at_door(door_id: String, difficulty: int = 35) -> Dictionary:
    emit_noise(2.0, "listen", door_id)
    return perceive("presence", door_id, difficulty, {"channels": ["sons"]})

func register_patrol(patrol_id: String, family_id: String, route: Array, overrides: Dictionary = {}) -> Dictionary:
    var patrol := {
        "id": patrol_id,
        "family_id": family_id,
        "route": route.duplicate(true),
        "route_index": 0,
        "state": "patrol",
        "hearing_threshold": 35.0,
        "fear_response": "avoid",
        "target": ""
    }
    patrol.merge(overrides, true)
    patrols[patrol_id] = patrol
    return patrol.duplicate(true)

func advance_patrols() -> Array:
    var changes: Array = []
    noise_level = maxf(0.0, noise_level - 8.0)
    for patrol_id_value: Variant in patrols.keys():
        var patrol_id := str(patrol_id_value)
        var patrol: Dictionary = patrols[patrol_id]
        var route: Array = patrol.get("route", [])
        if route.is_empty() or str(patrol.get("state", "")) in ["defeated", "flee"]:
            continue
        var index := posmod(int(patrol.get("route_index", 0)) + 1, route.size())
        patrol["route_index"] = index
        patrol["room_id"] = str(route[index])
        var renown := _party_renown()
        if renown >= int(patrol.get("fear_threshold", 5)) and str(patrol.get("fear_response", "")) == "avoid":
            patrol["state"] = "avoid"
        patrols[patrol_id] = patrol
        changes.append(patrol.duplicate(true))
        patrol_state_changed.emit(patrol_id, str(patrol.get("state", "patrol")))
    return changes

func enter_room(room_id: String) -> Dictionary:
    depth += 1
    var room: Dictionary = rooms.get(room_id, {"id": room_id, "visits": 0, "state": "quiet", "changes": []})
    room["visits"] = int(room.get("visits", 0)) + 1
    room["last_visit_depth"] = depth
    rooms[room_id] = room
    advance_patrols()
    room_state_changed.emit(room_id, room.duplicate(true))
    return room.duplicate(true)

func react_room(room_id: String, event_id: String, payload: Dictionary = {}) -> Dictionary:
    var room: Dictionary = rooms.get(room_id, {"id": room_id, "visits": 0, "state": "quiet", "changes": []})
    var changes: Array = room.get("changes", [])
    var change := {"event": event_id, "depth": depth, "payload": payload.duplicate(true)}
    changes.append(change)
    room["changes"] = changes
    match event_id:
        "collapse": room["state"] = "blocked"
        "fire": room["state"] = "burning"
        "gas": room["state"] = "toxic"
        "enemy_regroup": room["state"] = "reinforced"
        "secured": room["state"] = "safe"
        "corpse_consumed": room["state"] = "predator_evolved"
    rooms[room_id] = room
    room_state_changed.emit(room_id, room.duplicate(true))
    return room.duplicate(true)

func obstacle_options(obstacle_type: String, context: Dictionary = {}) -> Array:
    var result: Array = []
    for solution_value: Variant in rules.get("obstacles", {}).get(obstacle_type, {}).get("solutions", []):
        var solution := str(solution_value)
        var available := _solution_available(solution, context)
        result.append({"id": solution, "available": available})
    return result

func solve_obstacle(obstacle_id: String, obstacle_type: String, solution: String, context: Dictionary = {}) -> Dictionary:
    var options := obstacle_options(obstacle_type, context)
    for option_value: Variant in options:
        var option: Dictionary = option_value
        if str(option.get("id", "")) == solution:
            if not bool(option.get("available", false)):
                return {"success": false, "reason": "requirements", "solution": solution}
            return {"success": true, "obstacle_id": obstacle_id, "solution": solution, "world_changed": true}
    return {"success": false, "reason": "invalid_solution"}

func remember_landmark(landmark_id: String, room_id: String, cues: Dictionary) -> Dictionary:
    var landmark := {"id": landmark_id, "room_id": room_id, "cues": cues.duplicate(true), "discovered": true}
    landmarks[landmark_id] = landmark
    HUDDirector.request_world_guidance(landmark_id, ["architecture", "sons", "lumiere"], {"source": "landmark"})
    return landmark.duplicate(true)

func place_marker(marker_type: String, room_id: String, purpose: String = "") -> Dictionary:
    if marker_type not in rules.get("marker_types", []):
        return {"success": false, "reason": "unknown_marker"}
    var maximum := int(rules.get("max_markers", 8))
    if markers.size() >= maximum:
        return {"success": false, "reason": "marker_limit", "maximum": maximum}
    var marker := {
        "id": "marker_%d_%d" % [ExpeditionManager.expedition_seed, markers.size()],
        "type": marker_type,
        "room_id": room_id,
        "purpose": purpose,
        "intact": true
    }
    markers.append(marker)
    marker_changed.emit(str(marker.get("id", "")), false)
    return {"success": true, "marker": marker.duplicate(true)}

func disturb_marker(marker_id: String, destroy: bool = false) -> bool:
    for marker_value: Variant in markers:
        var marker: Dictionary = marker_value
        if str(marker.get("id", "")) != marker_id:
            continue
        marker["intact"] = not destroy
        marker["disturbed"] = true
        marker_changed.emit(marker_id, destroy)
        return true
    return false

func retreat_options(current_room: String = "") -> Array:
    var options: Array = []
    var retreat_rules: Dictionary = rules.get("retreat", {})
    options.append(_retreat_option("normal_exit", current_room, retreat_rules))
    if not AshlandsRuntime.unlocked_shortcuts.is_empty():
        options.append(_retreat_option("shortcut", current_room, retreat_rules))
    options.append(_retreat_option("emergency", current_room, retreat_rules))
    options.append(_retreat_option("rout", current_room, retreat_rules))
    return options

func plan_retreat(method: String, current_room: String = "") -> Dictionary:
    for option_value: Variant in retreat_options(current_room):
        var option: Dictionary = option_value
        if str(option.get("method", "")) == method:
            last_retreat_plan = option.duplicate(true)
            retreat_planned.emit(last_retreat_plan.duplicate(true))
            return last_retreat_plan.duplicate(true)
    return {"available": false, "reason": "unknown_method"}

func execute_retreat(method: String, current_room: String = "") -> Dictionary:
    var plan := plan_retreat(method, current_room)
    if not bool(plan.get("available", false)):
        return plan
    var pursuit_roll := _stable_roll("retreat|%s|%s|%d" % [method, current_room, ExpeditionManager.expedition_seed])
    var pursued := pursuit_roll <= int(plan.get("pursuit_risk", 0))
    var result := plan.duplicate(true)
    result["pursued"] = pursued
    result["retention"] = ExpeditionManager.apply_extraction_retention(float(plan.get("keep_ratio", 1.0)))
    result["result"] = ExpeditionManager.return_to_hub("retreat_" + method)
    retreat_resolved.emit(result.duplicate(true))
    return result

func camp_recovery() -> Dictionary:
    emit_noise(20.0, "campfire", AshlandsRuntime.current_zone_id)
    var healer := PersistentInjuryRuntime.available_healer(GameState.party)
    var treatment: Dictionary = {}
    if not healer.is_empty():
        treatment = PersistentInjuryRuntime.treat_all_party_injuries(GameState.party, healer)
    else:
        for hero_value: Variant in GameState.party:
            var hero: Dictionary = hero_value
            for injury_value: Variant in hero.get("persistent_injuries", []):
                var injury: Dictionary = injury_value
                PersistentInjuryRuntime.stabilize_in_field(hero, str(injury.get("id", "")))
    return {"healer": healer.get("id", ""), "treatment": treatment, "noise": noise_level}

func push_or_return_summary() -> Dictionary:
    var living := 0
    var wounded := 0
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) > 0:
            living += 1
        if not hero.get("persistent_injuries", hero.get("injuries", [])).is_empty():
            wounded += 1
    var risk := ExpeditionManager.current_risk_profile()
    return {
        "depth": depth,
        "living": living,
        "wounded": wounded,
        "supplies": ExpeditionManager.inventory.duplicate(true),
        "noise": noise_level,
        "light_state": "bright" if light_level >= 0.65 else ("dim" if light_level >= 0.30 else "dark"),
        "distance_to_exit": depth,
        "risk": risk,
        "recommendation": "return" if living < 2 or wounded >= living else "continue"
    }

func record_discovery(discovery_id: String, discovery_type: String, payload: Dictionary = {}) -> Dictionary:
    if discovery_type not in rules.get("discovery_types", []):
        return {"success": false, "reason": "unknown_discovery_type"}
    if discoveries.has(discovery_id):
        return {"success": false, "reason": "already_discovered"}
    var discovery := {
        "id": discovery_id,
        "type": discovery_type,
        "payload": payload.duplicate(true),
        "zone_id": AshlandsRuntime.current_zone_id,
        "depth": depth
    }
    discoveries[discovery_id] = discovery
    discovery_recorded.emit(discovery.duplicate(true))
    ExpeditionReportDirector.record_update("discoveries", "%s : %s" % [discovery_type, discovery_id])
    return {"success": true, "discovery": discovery.duplicate(true)}

func serialize() -> Dictionary:
    return {
        "roles": roles.duplicate(true),
        "traps": traps.duplicate(true),
        "patrols": patrols.duplicate(true),
        "rooms": rooms.duplicate(true),
        "markers": markers.duplicate(true),
        "discoveries": discoveries.duplicate(true),
        "landmarks": landmarks.duplicate(true),
        "noise_level": noise_level,
        "light_level": light_level,
        "depth": depth,
        "last_retreat_plan": last_retreat_plan.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    roles = payload.get("roles", {}).duplicate(true)
    traps = payload.get("traps", {}).duplicate(true)
    patrols = payload.get("patrols", {}).duplicate(true)
    rooms = payload.get("rooms", {}).duplicate(true)
    markers = payload.get("markers", []).duplicate(true)
    discoveries = payload.get("discoveries", {}).duplicate(true)
    landmarks = payload.get("landmarks", {}).duplicate(true)
    noise_level = float(payload.get("noise_level", 0.0))
    light_level = float(payload.get("light_level", 1.0))
    depth = int(payload.get("depth", 0))
    last_retreat_plan = payload.get("last_retreat_plan", {}).duplicate(true)

func _role_for_perception(kind: String) -> String:
    if kind == "pursuit":
        return "rearguard"
    if kind == "navigation":
        return "guide"
    return "scout" if roles.has("scout") else "vanguard"

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _apply_trap_failure(failure: Dictionary) -> Dictionary:
    var result := failure.duplicate(true)
    if failure.has("noise"):
        result["noise_result"] = emit_noise(float(failure.get("noise", 0)), "trap")
    if failure.has("pressure"):
        ExpeditionManager.apply_pressure(int(failure.get("pressure", 0)), "trap")
    if failure.has("injury"):
        var target := _hero_by_id(str(roles.get("vanguard", roles.get("scout", ""))))
        if target.is_empty() and not GameState.alive_heroes().is_empty():
            target = GameState.alive_heroes()[0]
        if not target.is_empty():
            var body_part := str(failure.get("injury", "torso"))
            var injury_id := {"leg": "sprain", "arm": "arm_injury", "head": "head_trauma", "torso": "deep_wound"}.get(body_part, "deep_wound")
            result["injury_result"] = PersistentInjuryRuntime.apply_injury(target, str(injury_id), "serious")
    return result

func _solution_available(solution: String, context: Dictionary) -> bool:
    var requirements: Dictionary = context.get("requirements", {})
    if requirements.has(solution):
        return bool(requirements.get(solution, false))
    if solution in ["abandon", "avoid", "detour", "rush", "fight"]:
        return true
    var tools: Array = context.get("tools", [])
    var skills: Array = context.get("skills", [])
    var traits: Array = context.get("traits", [])
    return solution in tools or solution in skills or solution in traits

func _retreat_option(method: String, current_room: String, retreat_rules: Dictionary) -> Dictionary:
    var rule: Dictionary = retreat_rules.get(method, {})
    var guide_bonus := int(rules.get("roles", {}).get("guide", {}).get("retreat_speed", 0)) if roles.has("guide") else 0
    return {
        "available": not rule.is_empty(),
        "method": method,
        "current_room": current_room,
        "keep_ratio": float(rule.get("keep_ratio", 1.0)),
        "pursuit_risk": maxi(0, int(rule.get("pursuit_risk", 0)) - guide_bonus),
        "distance": depth
    }

func _party_renown() -> int:
    var total := 0
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        total += int(hero.get("renown", 0))
        total += int(hero.get("dungeons_survived", 0))
    return total

func _stable_roll(key: String) -> int:
    var checksum := 19
    for index in range(key.length()):
        checksum = (checksum * 31 + key.unicode_at(index)) % 100000
    return checksum % 100 + 1
