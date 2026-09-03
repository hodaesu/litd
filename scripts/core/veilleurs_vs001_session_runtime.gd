extends RefCounted
class_name VeilleursVS001SessionRuntime

const VS001 := preload("res://scripts/core/veilleurs_vs001_runtime.gd")
const MAP_PATH := "res://data/dungeons/voices_under_sanctuary_map.json"
const EVENTS_PATH := "res://data/veilleurs/vs001_events.json"

var map_data: Dictionary = {}
var events_data: Dictionary = {}
var balance: Dictionary = {}
var state: Dictionary = {}

func _init() -> void:
    map_data = _load_json(MAP_PATH)
    events_data = _load_json(EVENTS_PATH)
    balance = VS001.load_balance()
    reset()

func reset() -> void:
    state = {
        "active": false,
        "seed": "WATCHERS_VERTICAL_001",
        "current_room": "",
        "previous_room": "",
        "visited_rooms": {},
        "pulse_index": 0,
        "light": int(balance.get("light", {}).get("initial", 82)),
        "noise": 0,
        "peak_noise": 0,
        "major_events": 0,
        "objective_complete": false,
        "s2_tripwire": "armed",
        "s6_outcome": "unresolved",
        "s6_state": balance.get("recruitment_s6", {}).get("initial", {}).duplicate(true),
        "s7_device": "intact",
        "s8_unlocked": false,
        "s8_discovered": false,
        "knowledge": {},
        "scars": {},
        "loot": [],
        "or_found": 0,
        "extraction_reason": "",
    }

func start(seed_value: String = "WATCHERS_VERTICAL_001") -> Dictionary:
    reset()
    state["active"] = true
    state["seed"] = seed_value
    var entry_id := str(map_data.get("entry", "s1_vestibule"))
    state["current_room"] = entry_id
    _record_visit(entry_id)
    return snapshot()

func snapshot() -> Dictionary:
    return state.duplicate(true)

func current_room() -> String:
    return str(state.get("current_room", ""))

func available_neighbors() -> Array[String]:
    var result: Array[String] = []
    var current := current_room()
    var connections: Array = map_data.get("connections", [])
    for connection_value: Variant in connections:
        var connection: Dictionary = connection_value
        var a := str(connection.get("a", ""))
        var b := str(connection.get("b", ""))
        var candidate := ""
        if a == current:
            candidate = b
        elif b == current:
            candidate = a
        if candidate.is_empty():
            continue
        if candidate == "s8_lower_archive" and not bool(state.get("s8_unlocked", false)):
            continue
        if not result.has(candidate):
            result.append(candidate)
    result.sort()
    return result

func can_enter_room(room_id: String) -> bool:
    if not bool(state.get("active", false)):
        return false
    if room_id == current_room():
        return true
    return room_id in available_neighbors()

func enter_room(room_id: String, movement_action: String = "normal_move") -> Dictionary:
    if not can_enter_room(room_id):
        return {"success": false, "reason": "room_not_reachable", "room_id": room_id}
    if room_id == current_room():
        return {"success": true, "room_id": room_id, "moved": false, "state": snapshot()}
    var previous := current_room()
    state["previous_room"] = previous
    state["current_room"] = room_id
    advance_pulse(movement_action, true)
    _record_visit(room_id)
    if room_id == "s8_lower_archive":
        state["s8_discovered"] = true
        _set_knowledge("KNOWLEDGE_THREE_PATHS_PRE_NAMING", "medium")
        _set_scar("voices.s8.archive", "discovered")
    return {"success": true, "room_id": room_id, "moved": true, "state": snapshot()}

func advance_pulse(action_id: String, calm_pulse: bool = true, explicit_pulse_cost: int = -1) -> Dictionary:
    var pulse_cost := explicit_pulse_cost
    if pulse_cost < 0:
        var action_costs: Dictionary = balance.get("exploration_pulse", {}).get("action_costs", {})
        pulse_cost = int(action_costs.get(action_id, 1))
    pulse_cost = maxi(0, pulse_cost)
    if pulse_cost == 0:
        return {"pulses": 0, "state": snapshot()}

    for _index: int in range(pulse_cost):
        state["pulse_index"] = int(state.get("pulse_index", 0)) + 1
        state["light"] = VS001.apply_light(int(state.get("light", 0)), action_id)
        state["noise"] = VS001.apply_noise(int(state.get("noise", 0)), action_id, calm_pulse)
        state["peak_noise"] = maxi(int(state.get("peak_noise", 0)), int(state.get("noise", 0)))
    return {"pulses": pulse_cost, "state": snapshot()}

func resolve_combat(rounds: int, violent: bool = true) -> Dictionary:
    var safe_rounds := maxi(0, rounds)
    if safe_rounds <= 0:
        return {"success": true, "rounds": 0, "state": snapshot()}
    state["pulse_index"] = int(state.get("pulse_index", 0)) + 1
    state["light"] = VS001.apply_light(int(state.get("light", 0)), "", safe_rounds)
    var noise_action := "violent_combat" if violent else "short_combat"
    state["noise"] = VS001.apply_noise(int(state.get("noise", 0)), noise_action, false)
    state["peak_noise"] = maxi(int(state.get("peak_noise", 0)), int(state.get("noise", 0)))
    return {"success": true, "rounds": safe_rounds, "state": snapshot()}

func set_tripwire_state(next_state: String) -> Dictionary:
    if current_room() != "s2_rope_gallery":
        return {"success": false, "reason": "wrong_room"}
    if next_state not in ["detected", "disarmed", "triggered", "salvaged"]:
        return {"success": false, "reason": "invalid_tripwire_state"}
    var previous := str(state.get("s2_tripwire", "armed"))
    if previous in ["triggered", "salvaged"]:
        return {"success": false, "reason": "tripwire_terminal"}
    state["s2_tripwire"] = next_state
    if next_state == "triggered":
        advance_pulse("sound_trap", false, 1)
        _set_scar("voices.s2.tripwire", "triggered")
    elif next_state == "disarmed":
        advance_pulse("disarm_trap", true, 1)
        _set_scar("voices.s2.tripwire", "disarmed")
    elif next_state == "salvaged":
        _set_scar("voices.s2.tripwire", "salvaged")
    return {"success": true, "previous": previous, "state": snapshot()}

func recruitment_action(action_id: String) -> Dictionary:
    if current_room() != "s6_survivor":
        return {"success": false, "reason": "wrong_room"}
    if str(state.get("s6_outcome", "unresolved")) != "unresolved":
        return {"success": false, "reason": "recruitment_resolved"}
    var actions: Dictionary = balance.get("recruitment_s6", {}).get("actions", {})
    if not actions.has(action_id):
        return {"success": false, "reason": "unknown_recruitment_action"}

    var action: Dictionary = actions.get(action_id, {})
    var s6_state: Dictionary = state.get("s6_state", {}).duplicate(true)
    for field_id: String in ["fear", "trust", "pain", "aggression", "stability", "restraint"]:
        if action.has(field_id):
            s6_state[field_id] = clampi(int(s6_state.get(field_id, 0)) + int(action.get(field_id, 0)), 0, 100)
    if action.has("health_ratio_delta"):
        s6_state["health_ratio"] = clampf(
            float(s6_state.get("health_ratio", 0.0)) + float(action.get("health_ratio_delta", 0.0)),
            0.0,
            1.0
        )
    state["s6_state"] = s6_state

    var pulse_cost := int(action.get("pulse", 0))
    if pulse_cost > 0:
        advance_pulse("complex_treatment" if action_id == "aisha_treat" else "brief_inspect", true, pulse_cost)

    if action_id == "leave":
        state["s6_outcome"] = "left_alive"
        _set_scar("voices.s6.recruit_history", "left_alive")
    elif action_id == "kill":
        state["s6_outcome"] = "killed"
        _set_scar("voices.s6.recruit_history", "killed")

    return {"success": true, "action_id": action_id, "s6_state": s6_state.duplicate(true), "state": snapshot()}

func resolve_recruitment(actor_id: String, roll_value: int) -> Dictionary:
    if current_room() != "s6_survivor":
        return {"success": false, "reason": "wrong_room"}
    if str(state.get("s6_outcome", "unresolved")) != "unresolved":
        return {"success": false, "reason": "recruitment_resolved"}

    var preview := _capture_preview_from_state(actor_id)
    var low := int(preview.get("roll_range", [-20, 20])[0])
    var high := int(preview.get("roll_range", [-20, 20])[1])
    var roll := clampi(roll_value, low, high)
    var score := int(preview.get("score_before_roll", 0))
    var threshold := int(preview.get("success_threshold", 60))
    var recruited := score + roll >= threshold
    if recruited:
        state["s6_outcome"] = "recruited"
        _set_scar("voices.s6.recruit_history", "recruited")
    else:
        var s6_state: Dictionary = state.get("s6_state", {}).duplicate(true)
        var failure: Dictionary = balance.get("recruitment_s6", {}).get("capture_check", {}).get("on_fail", {})
        for field_id: String in ["fear", "trust", "aggression"]:
            if failure.has(field_id):
                s6_state[field_id] = clampi(int(s6_state.get(field_id, 0)) + int(failure.get(field_id, 0)), 0, 100)
        state["s6_state"] = s6_state
    return {
        "success": recruited,
        "roll": roll,
        "score": score,
        "total": score + roll,
        "threshold": threshold,
        "outcome": state.get("s6_outcome", "unresolved"),
        "state": snapshot()
    }

func resolve_device(choice: String, check_success: bool = true) -> Dictionary:
    if current_room() != "s7_voice_chamber":
        return {"success": false, "reason": "wrong_room"}
    if str(state.get("s7_device", "intact")) != "intact":
        return {"success": false, "reason": "device_already_resolved"}
    if choice not in ["destroy", "disable", "study"]:
        return {"success": false, "reason": "invalid_device_choice"}

    advance_pulse("heavy_manipulation", false, 2)
    if choice == "study" and not check_success:
        return {"success": false, "reason": "study_check_failed", "state": snapshot()}

    state["objective_complete"] = true
    if choice == "destroy":
        state["s7_device"] = "destroyed"
        _set_scar("voices.s7.device", "destroyed")
    elif choice == "disable":
        state["s7_device"] = "disabled"
        _set_scar("voices.s7.device", "disabled")
    else:
        state["s7_device"] = "studied"
        state["s8_unlocked"] = true
        _set_knowledge("KNOWLEDGE_ACOUSTIC_DEVICE", "high")
        _set_scar("voices.s7.device", "studied")
    return {"success": true, "choice": choice, "state": snapshot()}

func acquire_room_loot(room_key: String) -> Dictionary:
    var loot_rules: Dictionary = balance.get("loot_vs001", {}).get("rooms", {})
    if not loot_rules.has(room_key):
        return {"success": false, "reason": "unknown_loot_room"}
    var room_loot: Dictionary = loot_rules.get(room_key, {})
    if room_key == "s6":
        var outcome := str(state.get("s6_outcome", "unresolved"))
        var path_key := "kill_path" if outcome == "killed" else ("recruit_path" if outcome == "recruited" else "leave_path")
        room_loot = room_loot.get(path_key, {})

    var acquired: Array = []
    for key: String in ["guaranteed", "seed_result", "materials"]:
        var items: Array = room_loot.get(key, [])
        for item_value: Variant in items:
            var item_id := str(item_value)
            acquired.append(item_id)
            var cargo: Array = state.get("loot", [])
            cargo.append(item_id)
            state["loot"] = cargo
    var or_delta := int(room_loot.get("or", 0))
    state["or_found"] = int(state.get("or_found", 0)) + or_delta
    return {"success": true, "items": acquired, "or_delta": or_delta, "state": snapshot()}

func extract(reason: String = "voluntary") -> Dictionary:
    if not bool(state.get("active", false)):
        return {"success": false, "reason": "session_not_active"}
    state["active"] = false
    state["extraction_reason"] = reason
    return {
        "success": true,
        "reason": reason,
        "objective_complete": bool(state.get("objective_complete", false)),
        "rooms_visited": (state.get("visited_rooms", {}) as Dictionary).size(),
        "s6_outcome": str(state.get("s6_outcome", "unresolved")),
        "s8_discovered": bool(state.get("s8_discovered", false)),
        "ending_light": int(state.get("light", 0)),
        "peak_noise": int(state.get("peak_noise", 0)),
        "or_found": int(state.get("or_found", 0)),
        "loot_count": (state.get("loot", []) as Array).size(),
        "state": snapshot()
    }

func serialize() -> Dictionary:
    return state.duplicate(true)

func deserialize(data: Dictionary) -> bool:
    if data.is_empty():
        return false
    var required: Array[String] = ["seed", "current_room", "pulse_index", "light", "noise", "visited_rooms"]
    for key: String in required:
        if not data.has(key):
            return false
    state = data.duplicate(true)
    state["light"] = clampi(int(state.get("light", 0)), 0, 100)
    state["noise"] = clampi(int(state.get("noise", 0)), 0, 100)
    state["peak_noise"] = clampi(int(state.get("peak_noise", state.get("noise", 0))), 0, 100)
    return true

func _record_visit(room_id: String) -> void:
    var visits: Dictionary = state.get("visited_rooms", {})
    visits[room_id] = int(visits.get(room_id, 0)) + 1
    state["visited_rooms"] = visits

func _set_knowledge(knowledge_id: String, certainty: String) -> void:
    var knowledge: Dictionary = state.get("knowledge", {})
    knowledge[knowledge_id] = certainty
    state["knowledge"] = knowledge

func _set_scar(anchor_id: String, anchor_state: String) -> void:
    var scars: Dictionary = state.get("scars", {})
    scars[anchor_id] = anchor_state
    state["scars"] = scars

func _capture_preview_from_state(actor_id: String) -> Dictionary:
    var check: Dictionary = balance.get("recruitment_s6", {}).get("capture_check", {})
    var wounds := VS001.load_capture_wounds()
    var s6_state: Dictionary = state.get("s6_state", {})
    var wound_bonus := 0
    if bool(check.get("wound_bonus_from_existing_contract", false)):
        wound_bonus = mini(
            int(wounds.get("capture_bonus_cap", 20)),
            int(s6_state.get("lost_parts", 0)) * int(wounds.get("capture_bonus_per_lost_part", 0))
            + int(s6_state.get("critical_injuries", 0)) * int(wounds.get("capture_bonus_per_critical_injury", 0))
        )
    var actor_bonus: Dictionary = check.get("actor_bonus", {})
    var trust_multiplier := _formula_multiplier(str(check.get("trust_bonus_formula", "")), 0.20)
    var fear_multiplier := _formula_multiplier(str(check.get("fear_penalty_formula", "")), 0.25)
    var restraint_multiplier := _formula_multiplier(str(check.get("restraint_bonus_formula", "")), 0.15)
    var stability_multiplier := _formula_multiplier(str(check.get("stability_bonus_formula", "")), 0.10)
    var score := (
        int(check.get("base", 0))
        - int(check.get("creature_resistance", 0))
        + wound_bonus
        + int(actor_bonus.get(actor_id, 0))
        + int(floor(float(s6_state.get("trust", 0)) * trust_multiplier))
        - int(floor(float(maxi(int(s6_state.get("fear", 0)) - 60, 0)) * fear_multiplier))
        + int(floor(float(s6_state.get("restraint", 0)) * restraint_multiplier))
        + int(floor(float(s6_state.get("stability", 0)) * stability_multiplier))
    )
    return {
        "score_before_roll": score,
        "roll_range": check.get("deterministic_roll_range", [-20, 20]),
        "success_threshold": int(check.get("success_threshold", 60))
    }

func _formula_multiplier(formula: String, fallback: float) -> float:
    var star_index := formula.find("*")
    if star_index < 0:
        return fallback
    var tail := formula.substr(star_index + 1).strip_edges()
    var close_index := tail.find(")")
    if close_index >= 0:
        tail = tail.substr(0, close_index).strip_edges()
    return tail.to_float() if tail.is_valid_float() else fallback

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
