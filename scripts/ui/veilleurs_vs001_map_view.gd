extends Control
class_name VeilleursVS001MapView

var map_data: Dictionary = {}
var state: Dictionary = {}

func set_map_state(map_value: Dictionary, state_value: Dictionary) -> void:
    map_data = map_value.duplicate(true)
    state = state_value.duplicate(true)
    queue_redraw()

func _draw() -> void:
    if map_data.is_empty():
        return
    var rooms: Array = map_data.get("rooms", [])
    var connections: Array = map_data.get("connections", [])
    var visited: Dictionary = state.get("visited_rooms", {})
    var current_room := str(state.get("current_room", ""))
    var show_secret := bool(state.get("s8_unlocked", false)) or bool(state.get("s8_discovered", false))
    var bounds := _bounds(rooms, show_secret)
    var positions: Dictionary = {}
    for room_value: Variant in rooms:
        if not (room_value is Dictionary):
            continue
        var room: Dictionary = room_value
        var room_id := str(room.get("id", ""))
        if room_id == "s8_lower_archive" and not show_secret:
            continue
        positions[room_id] = _to_canvas(room.get("center", [0.0, 0.0, 0.0]), bounds)

    for connection_value: Variant in connections:
        if not (connection_value is Dictionary):
            continue
        var connection: Dictionary = connection_value
        var a := str(connection.get("a", ""))
        var b := str(connection.get("b", ""))
        if not positions.has(a) or not positions.has(b):
            continue
        if not visited.has(a) and not visited.has(b):
            continue
        draw_line(positions[a], positions[b], Color(0.50, 0.48, 0.44, 0.75), 3.0, true)

    var font: Font = ThemeDB.fallback_font
    for room_value: Variant in rooms:
        if not (room_value is Dictionary):
            continue
        var room: Dictionary = room_value
        var room_id := str(room.get("id", ""))
        if not positions.has(room_id):
            continue
        var known := visited.has(room_id)
        var pos: Vector2 = positions[room_id]
        var radius := 17.0 if room_id == current_room else 13.0
        var fill := Color(0.82, 0.69, 0.42, 0.95) if room_id == current_room else (Color(0.62, 0.61, 0.57, 0.90) if known else Color(0.25, 0.25, 0.27, 0.75))
        draw_circle(pos, radius, fill)
        draw_circle(pos, radius, Color(0.08, 0.08, 0.09, 0.95), false, 2.0, true)
        var label := str(room.get("display_name", room_id)) if known else "?"
        draw_string(font, pos + Vector2(-55.0, 36.0), label, HORIZONTAL_ALIGNMENT_CENTER, 110.0, 14, Color(0.92, 0.90, 0.85, 1.0))

func known_room_count() -> int:
    return (state.get("visited_rooms", {}) as Dictionary).size()

func secret_visible() -> bool:
    return bool(state.get("s8_unlocked", false)) or bool(state.get("s8_discovered", false))

func _bounds(rooms: Array, show_secret: bool) -> Rect2:
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for room_value: Variant in rooms:
        if not (room_value is Dictionary):
            continue
        var room: Dictionary = room_value
        if str(room.get("id", "")) == "s8_lower_archive" and not show_secret:
            continue
        var center: Array = room.get("center", [0.0, 0.0, 0.0])
        var x := float(center[0])
        var z := float(center[2])
        min_x = minf(min_x, x)
        max_x = maxf(max_x, x)
        min_z = minf(min_z, z)
        max_z = maxf(max_z, z)
    if min_x == INF:
        return Rect2(0.0, 0.0, 1.0, 1.0)
    return Rect2(min_x, min_z, maxf(1.0, max_x - min_x), maxf(1.0, max_z - min_z))

func _to_canvas(center_value: Variant, bounds: Rect2) -> Vector2:
    var center: Array = center_value if center_value is Array else [0.0, 0.0, 0.0]
    var normalized_x := (float(center[0]) - bounds.position.x) / maxf(1.0, bounds.size.x)
    var normalized_z := (float(center[2]) - bounds.position.y) / maxf(1.0, bounds.size.y)
    var margin := 72.0
    return Vector2(
        lerpf(margin, maxf(margin, size.x - margin), normalized_x),
        lerpf(margin, maxf(margin, size.y - margin), normalized_z)
    )
