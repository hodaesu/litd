extends RefCounted
class_name AshGuidancePolicy

const CONFIG_PATH := "res://data/ash_guidance.json"
const FIRST_VEIL_PATH := "res://data/roguelike/first_veil_rooms.json"

var config: Dictionary = {}
var rooms_by_id: Dictionary = {}
var boss_room_id: String = ""
var entry_room_id: String = ""
var _entry_boss_hops: int = 1

func _init() -> void:
    config = _load_dictionary(CONFIG_PATH)
    _load_first_veil_graph()

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _load_first_veil_graph() -> void:
    rooms_by_id.clear()
    boss_room_id = ""
    entry_room_id = ""
    var catalog: Dictionary = _load_dictionary(FIRST_VEIL_PATH)
    for room_value: Variant in catalog.get("rooms", []):
        if not room_value is Dictionary:
            continue
        var room: Dictionary = room_value
        var room_id: String = str(room.get("id", ""))
        if room_id == "":
            continue
        rooms_by_id[room_id] = room.duplicate(true)
        var room_type: String = str(room.get("type", ""))
        var room_role: String = str(room.get("room_role", ""))
        if room_role == "entry":
            entry_room_id = room_id
        if room_type == "boss" or room_role == "boss":
            boss_room_id = room_id
    var entry_path: Array[String] = shortest_public_path(entry_room_id, boss_room_id)
    _entry_boss_hops = maxi(1, entry_path.size() - 1)

func shortest_public_path(from_room_id: String, to_room_id: String, allowed_first_hops: Array[String] = []) -> Array[String]:
    var result: Array[String] = []
    if from_room_id == "" or to_room_id == "" or not rooms_by_id.has(from_room_id) or not rooms_by_id.has(to_room_id):
        return result
    if from_room_id == to_room_id:
        return [from_room_id]

    var queue: Array[String] = [from_room_id]
    var parents: Dictionary = {from_room_id: ""}
    var cursor: int = 0
    while cursor < queue.size():
        var current: String = queue[cursor]
        cursor += 1
        var room: Dictionary = rooms_by_id.get(current, {})
        var connections: Array = room.get("connections", [])
        for target_value: Variant in connections:
            var target_id: String = str(target_value)
            if current == from_room_id and not allowed_first_hops.is_empty() and not allowed_first_hops.has(target_id):
                continue
            if parents.has(target_id) or not rooms_by_id.has(target_id):
                continue
            var target_room: Dictionary = rooms_by_id.get(target_id, {})
            if bool(target_room.get("secret", false)):
                continue
            parents[target_id] = current
            if target_id == to_room_id:
                return _reconstruct_path(parents, from_room_id, to_room_id)
            queue.append(target_id)
    return result

func _reconstruct_path(parents: Dictionary, from_room_id: String, to_room_id: String) -> Array[String]:
    var reversed: Array[String] = []
    var current: String = to_room_id
    while current != "":
        reversed.append(current)
        if current == from_room_id:
            break
        current = str(parents.get(current, ""))
    reversed.reverse()
    return reversed

func route_to_boss(current_room_id: String, allowed_first_hops: Array[String] = []) -> Dictionary:
    var path: Array[String] = shortest_public_path(current_room_id, boss_room_id, allowed_first_hops)
    if path.is_empty():
        return {"found": false, "boss_room_id": boss_room_id, "next_room_id": "", "hops_remaining": -1, "proximity": 0.0}
    var hops_remaining: int = maxi(0, path.size() - 1)
    return {
        "found": true,
        "boss_room_id": boss_room_id,
        "next_room_id": path[1] if path.size() > 1 else boss_room_id,
        "hops_remaining": hops_remaining,
        "path": path,
        "proximity": boss_proximity_from_hops(hops_remaining)
    }

func boss_proximity(current_room_id: String) -> float:
    var path: Array[String] = shortest_public_path(current_room_id, boss_room_id)
    if path.is_empty():
        return 0.0
    return boss_proximity_from_hops(maxi(0, path.size() - 1))

func boss_proximity_from_hops(hops_remaining: int) -> float:
    if hops_remaining <= 0:
        return 1.0
    var linear: float = 1.0 - clampf(float(hops_remaining) / float(_entry_boss_hops), 0.0, 1.0)
    var distance_rules: Dictionary = config.get("distance", {})
    var curve: float = maxf(0.2, float(distance_rules.get("boss_route_curve", 1.35)))
    return clampf(pow(linear, curve), 0.0, 1.0)

func color_for(objective_kind: String, proximity: float) -> Color:
    var mode: Dictionary = (config.get("objective_modes", {}) as Dictionary).get(objective_kind, {})
    var far_color: Color = Color.from_string(str(mode.get("far_color", "#85888D")), Color(0.52, 0.53, 0.55))
    var near_fallback: String = "#FF3B1F" if objective_kind == "boss" else "#45A8FF"
    var near_color: Color = Color.from_string(str(mode.get("near_color", near_fallback)), Color.WHITE)
    return far_color.lerp(near_color, clampf(proximity, 0.0, 1.0))

func emission_color_for(objective_kind: String, proximity: float) -> Color:
    var mode: Dictionary = (config.get("objective_modes", {}) as Dictionary).get(objective_kind, {})
    var base: Color = color_for(objective_kind, proximity)
    var emission: Color = Color.from_string(str(mode.get("emission_color", base.to_html())), base)
    return base.lerp(emission, clampf(proximity * 1.15, 0.0, 1.0))

func proximity_for_distance(distance_m: float, max_distance_override: float = -1.0) -> float:
    var rules: Dictionary = config.get("distance", {})
    var near_m: float = maxf(0.1, float(rules.get("near_m", 3.0)))
    var far_m: float = maxf(near_m + 0.1, max_distance_override if max_distance_override > 0.0 else float(rules.get("far_m", 48.0)))
    var t: float = clampf((distance_m - near_m) / (far_m - near_m), 0.0, 1.0)
    var smooth: float = t * t * (3.0 - 2.0 * t)
    return 1.0 - smooth
