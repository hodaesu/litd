extends RefCounted
class_name FirstAccordDungeonMapBuilder

const MAP_PATH := "res://data/dungeons/first_map_hall_of_first_accord_map.json"
const OCCLUDABLE_SCRIPT := preload("res://scripts/world/isometric_occludable.gd")

static func generate(parent: Node3D) -> void:
    var map_data := _load_json(MAP_PATH)
    if map_data.is_empty():
        push_error("FirstAccordDungeonMapBuilder: carte absente")
        return
    var root := Node3D.new()
    root.name = "AuthoredDungeonMap"
    root.set_meta("map_id", str(map_data.get("id", "")))
    root.set_meta("ash_guidance", str(map_data.get("design_rules", {}).get("ash_guidance", "only_on_request")))
    parent.add_child(root)
    _build_rooms(root, map_data.get("floors", []))
    _build_connections(root, map_data.get("connections", []))
    _build_gameplay_markers(root, "Hazards", map_data.get("hazards", []), "dungeon_hazard")
    _build_gameplay_markers(root, "RetreatPoints", map_data.get("retreat_points", []), "physical_retreat")
    _build_gameplay_markers(root, "Discoveries", map_data.get("discoveries", []), "lore_discovery")
    _build_ash_route(root, map_data)

static func _build_rooms(root: Node3D, floors: Array) -> void:
    var floors_root := Node3D.new()
    floors_root.name = "Floors"
    root.add_child(floors_root)
    for floor_data in floors:
        var floor_root := Node3D.new()
        floor_root.name = str(floor_data.get("id", "floor"))
        floor_root.set_meta("display_name", str(floor_data.get("name", "")))
        floor_root.set_meta("physical_retreat_available", true)
        floors_root.add_child(floor_root)
        for room_data in floor_data.get("rooms", []):
            _build_room(floor_root, room_data)

static func _build_room(parent: Node3D, room_data: Dictionary) -> void:
    var center := _vec3(room_data.get("center", [0, 0, 0]))
    var size := _vec3(room_data.get("size", [10, 1, 10]))
    var room := Node3D.new()
    room.name = str(room_data.get("id", "room"))
    room.position = center
    room.set_meta("display_name", str(room_data.get("name", "")))
    room.set_meta("room_kind", str(room_data.get("kind", "critical")))
    room.set_meta("encounter_id", str(room_data.get("encounter", "")))
    room.set_meta("lock", str(room_data.get("lock", "")))
    room.set_meta("reward", str(room_data.get("reward", "")))
    parent.add_child(room)
    _box(room, "Floor", Vector3(0.0, -0.3, 0.0), Vector3(size.x, 0.6, size.z), true, "architecture/dungeon_floor")
    var wall_height := 4.0
    var door_gap: float = minf(5.0, size.x * 0.35)
    var side_width: float = maxf(1.0, (size.x - door_gap) * 0.5)
    _box(room, "NorthWallLeft", Vector3(-(door_gap + side_width) * 0.25, wall_height * 0.5, -size.z * 0.5), Vector3(side_width, wall_height, 0.8), true, "architecture/dungeon_wall")
    _box(room, "NorthWallRight", Vector3((door_gap + side_width) * 0.25, wall_height * 0.5, -size.z * 0.5), Vector3(side_width, wall_height, 0.8), true, "architecture/dungeon_wall")
    _box(room, "SouthWallLeft", Vector3(-(door_gap + side_width) * 0.25, wall_height * 0.5, size.z * 0.5), Vector3(side_width, wall_height, 0.8), true, "architecture/dungeon_wall")
    _box(room, "SouthWallRight", Vector3((door_gap + side_width) * 0.25, wall_height * 0.5, size.z * 0.5), Vector3(side_width, wall_height, 0.8), true, "architecture/dungeon_wall")
    var side_depth: float = maxf(1.0, (size.z - door_gap) * 0.5)
    _box(room, "WestWallNorth", Vector3(-size.x * 0.5, wall_height * 0.5, -(door_gap + side_depth) * 0.25), Vector3(0.8, wall_height, side_depth), true, "architecture/dungeon_wall")
    _box(room, "WestWallSouth", Vector3(-size.x * 0.5, wall_height * 0.5, (door_gap + side_depth) * 0.25), Vector3(0.8, wall_height, side_depth), true, "architecture/dungeon_wall")
    _box(room, "EastWallNorth", Vector3(size.x * 0.5, wall_height * 0.5, -(door_gap + side_depth) * 0.25), Vector3(0.8, wall_height, side_depth), true, "architecture/dungeon_wall")
    _box(room, "EastWallSouth", Vector3(size.x * 0.5, wall_height * 0.5, (door_gap + side_depth) * 0.25), Vector3(0.8, wall_height, side_depth), true, "architecture/dungeon_wall")

static func _build_connections(root: Node3D, connections: Array) -> void:
    var connections_root := Node3D.new()
    connections_root.name = "Connections"
    root.add_child(connections_root)
    for connection in connections:
        var corridor := Node3D.new()
        corridor.name = str(connection.get("id", "connection"))
        corridor.set_meta("from_room", str(connection.get("from", "")))
        corridor.set_meta("to_room", str(connection.get("to", "")))
        corridor.set_meta("connection_kind", str(connection.get("kind", "corridor")))
        corridor.set_meta("hidden", bool(connection.get("hidden", false)))
        corridor.set_meta("requires", str(connection.get("requires", "")))
        corridor.set_meta("shortcut_id", str(connection.get("shortcut_id", "")))
        connections_root.add_child(corridor)
        var points: Array = connection.get("waypoints", [])
        var width := float(connection.get("width", 3.0))
        for index in points.size():
            var point := _vec3(points[index])
            var marker := Marker3D.new()
            marker.name = "Waypoint_%02d" % [index + 1]
            marker.position = point
            marker.set_meta("route_index", index)
            corridor.add_child(marker)
            if index > 0:
                _build_path_tiles(corridor, _vec3(points[index - 1]), point, width, index)

static func _build_path_tiles(parent: Node3D, start: Vector3, finish: Vector3, width: float, segment_index: int) -> void:
    var distance := start.distance_to(finish)
    var tile_count := maxi(1, int(ceil(distance / 1.5)))
    for tile_index in tile_count + 1:
        var ratio := float(tile_index) / float(tile_count)
        var point := start.lerp(finish, ratio)
        _box(parent, "Path_%02d_%02d" % [segment_index, tile_index], point + Vector3(0.0, -0.22, 0.0), Vector3(width, 0.45, width), true, "architecture/dungeon_path")

static func _build_gameplay_markers(root: Node3D, root_name: String, entries: Array, role: String) -> void:
    var marker_root := Node3D.new()
    marker_root.name = root_name
    root.add_child(marker_root)
    for entry in entries:
        var marker := Marker3D.new()
        marker.name = str(entry.get("id", entry.get("room", role)))
        marker.position = _vec3(entry.get("position", [0, 0, 0]))
        marker.set_meta("gameplay_role", role)
        marker.set_meta("data", entry)
        marker_root.add_child(marker)

static func _build_ash_route(root: Node3D, map_data: Dictionary) -> void:
    var ash_route := Node3D.new()
    ash_route.name = "AshGuidanceGraph"
    ash_route.set_meta("only_on_request", true)
    ash_route.set_meta("never_points_through_walls", true)
    ash_route.set_meta("objective_order", map_data.get("ash_routes", {}).get("objective_order", []))
    root.add_child(ash_route)
    for connection in map_data.get("connections", []):
        var edge := Node3D.new()
        edge.name = str(connection.get("id", "edge"))
        edge.set_meta("from_room", str(connection.get("from", "")))
        edge.set_meta("to_room", str(connection.get("to", "")))
        edge.set_meta("waypoints", connection.get("waypoints", []))
        edge.set_meta("hidden", bool(connection.get("hidden", false)))
        edge.set_meta("requires", str(connection.get("requires", "")))
        ash_route.add_child(edge)

static func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, collision_enabled: bool, asset_slot: String) -> void:
    var root := OCCLUDABLE_SCRIPT.new() as Node3D
    root.name = node_name
    root.position = pos
    root.set_meta("blender_asset_slot", asset_slot)
    root.set_meta("blockout_size_m", size)
    var mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh.mesh = box_mesh
    root.add_child(mesh)
    if collision_enabled:
        var body := StaticBody3D.new()
        root.add_child(body)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    parent.add_child(root)

static func _vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY or value.size() < 3:
        return Vector3.ZERO
    return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
