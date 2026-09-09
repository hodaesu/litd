extends RefCounted
class_name VeilleursGE01SessionRuntime

const DEF := preload("res://scripts/core/veilleurs_ge01_definition.gd")
const MAP_PATH := "res://data/dungeons/galeries_eteintes_map.json"

var map_data: Dictionary = {}
var state: Dictionary = {}

func _init() -> void:
    map_data = _load_json(MAP_PATH)
    reset()

func reset() -> void:
    state = {
        "active": false,
        "seed": DEF.EXPEDITION_ID,
        "current_room": "",
        "previous_room": "",
        "visited_rooms": {},
        "light": DEF.INITIAL_LIGHT,
        "objective_complete": false,
        "secret_unlocked": false,
        "persistent_candidates": {},
        "world_events": [],
        "extraction_reason": ""
    }

func start(seed_value: String = DEF.EXPEDITION_ID) -> Dictionary:
    reset()
    state["active"] = true
    state["seed"] = seed_value
    var entry_id := str(map_data.get("entry", "ge_01"))
    state["current_room"] = entry_id
    _record_visit(entry_id)
    _apply_room_light(entry_id)
    return snapshot()

func snapshot() -> Dictionary:
    var copy := state.duplicate(true)
    copy["light_state"] = DEF.light_state(int(copy.get("light", 0)))
    return copy

func current_room() -> String:
    return str(state.get("current_room", ""))

func available_neighbors() -> Array[String]:
    var result: Array[String] = []
    var current := current_room()
    for connection_value: Variant in map_data.get("connections", []):
        var connection: Dictionary = connection_value
        if bool(connection.get("hidden", false)) and not bool(state.get("secret_unlocked", false)):
            continue
        var a := str(connection.get("a", ""))
        var b := str(connection.get("b", ""))
        var candidate := ""
        if a == current:
            candidate = b
        elif b == current:
            candidate = a
        if not candidate.is_empty() and not result.has(candidate):
            result.append(candidate)
    result.sort()
    return result

func enter_room(room_id: String) -> Dictionary:
    if not bool(state.get("active", false)):
        return {"success": false, "reason": "session_not_active"}
    if room_id == current_room():
        return {"success": true, "moved": false, "state": snapshot()}
    if room_id not in available_neighbors():
        return {"success": false, "reason": "room_not_reachable", "room_id": room_id}
    state["previous_room"] = current_room()
    state["current_room"] = room_id
    _record_visit(room_id)
    _apply_room_light(room_id)
    return {"success": true, "moved": true, "room_id": room_id, "state": snapshot()}

func spend_light(action_id: String) -> Dictionary:
    var cost := int(DEF.ACTION_LIGHT_COSTS.get(action_id, 0))
    state["light"] = clampi(int(state.get("light", 0)) - cost, 0, 100)
    return {"success": true, "cost": cost, "state": snapshot()}

func resolve_refuge(choice: String) -> Dictionary:
    if current_room() != "ge_08":
        return {"success": false, "reason": "wrong_room"}
    match choice:
        "rekindle":
            state["light"] = clampi(int(state.get("light", 0)) + 10, 0, 100)
        "field_care":
            _record_world_event("REFUGE_FIELD_CARE", {"room_id": current_room()})
        "scout":
            _record_world_event("REFUGE_SCOUT", {"reveals": "ge_09_ge_10"})
        _:
            return {"success": false, "reason": "unknown_refuge_choice"}
    _record_world_event("REFUGE_CHOICE", {"choice": choice})
    return {"success": true, "choice": choice, "state": snapshot()}

func reveal_secret(source: String) -> Dictionary:
    state["secret_unlocked"] = true
    _record_world_event("SECRET_REVEALED", {"source": source})
    return {"success": true, "state": snapshot()}

func register_enemy_escape(entity_id: String, species: String, body_state: Dictionary = {}) -> Dictionary:
    if entity_id.is_empty():
        return {"success": false, "reason": "missing_entity_id"}
    var candidates: Dictionary = state.get("persistent_candidates", {})
    candidates[entity_id] = {
        "entity_id": entity_id,
        "species": species,
        "body_state": body_state.duplicate(true),
        "first_encounter_room": current_room(),
        "encounters_survived": 1,
        "escape_count": 1,
        "memory_rank": "NORMAL"
    }
    state["persistent_candidates"] = candidates
    _record_world_event("ENEMY_ESCAPE", {"entity_id": entity_id, "species": species, "room_id": current_room()})
    return {"success": true, "candidate": candidates[entity_id].duplicate(true), "state": snapshot()}

func encounter_for(room_id: String, roll_0_99: int) -> Dictionary:
    if room_id == "ge_11" and not (state.get("persistent_candidates", {}) as Dictionary).is_empty() and clampi(roll_0_99, 0, 99) < 50:
        var ids := (state.get("persistent_candidates", {}) as Dictionary).keys()
        ids.sort()
        return {"persistent": true, "entity_id": str(ids[0]), "candidate": (state.get("persistent_candidates", {}) as Dictionary)[ids[0]].duplicate(true)}
    return DEF.weighted_pick(DEF.ENCOUNTERS.get(room_id, []), roll_0_99)

func can_enemy_attempt_flee(species: String, health_ratio: float, important_limb_lost: bool, allies_dead: bool, has_exit: bool, immobilized: bool) -> bool:
    if not has_exit or immobilized or not DEF.FLEE_BASE_CHANCE.has(species):
        return false
    return health_ratio < 0.30 or important_limb_lost or allies_dead

func flee_succeeds(species: String, roll_0_99: int) -> bool:
    return clampi(roll_0_99, 0, 99) < int(DEF.FLEE_BASE_CHANCE.get(species, 0))

func mark_objective_complete(source: String = "corpse_examined") -> Dictionary:
    state["objective_complete"] = true
    _record_world_event("OBJECTIVE_COMPLETE", {"source": source})
    return {"success": true, "state": snapshot()}

func extract(reason: String = "voluntary") -> Dictionary:
    if not bool(state.get("active", false)):
        return {"success": false, "reason": "session_not_active"}
    state["active"] = false
    state["extraction_reason"] = reason
    _record_world_event("EXTRACTION", {"reason": reason})
    return {"success": true, "reason": reason, "objective_complete": bool(state.get("objective_complete", false)), "rooms_visited": (state.get("visited_rooms", {}) as Dictionary).size(), "ending_light": int(state.get("light", 0)), "persistent_candidates": (state.get("persistent_candidates", {}) as Dictionary).size(), "state": snapshot()}

func serialize() -> Dictionary:
    return state.duplicate(true)

func deserialize(data: Dictionary) -> bool:
    if data.is_empty():
        return false
    for key: String in ["seed", "current_room", "visited_rooms", "light"]:
        if not data.has(key):
            return false
    state = data.duplicate(true)
    state["light"] = clampi(int(state.get("light", 0)), 0, 100)
    return true

func _apply_room_light(room_id: String) -> void:
    state["light"] = clampi(int(state.get("light", 0)) + DEF.room_base_light_delta(room_id), 0, 100)

func _record_visit(room_id: String) -> void:
    var visits: Dictionary = state.get("visited_rooms", {})
    visits[room_id] = int(visits.get(room_id, 0)) + 1
    state["visited_rooms"] = visits

func _record_world_event(event_type: String, payload: Dictionary) -> void:
    var events: Array = state.get("world_events", [])
    events.append({"type": event_type, "payload": payload.duplicate(true), "room_id": current_room()})
    state["world_events"] = events

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Galeries Eteintes: missing data file %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
