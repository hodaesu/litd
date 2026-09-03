extends Node3D
class_name VeilleursVS001BlockoutBuilder

const PHYSICAL_MAP_PATH := "res://data/dungeons/voices_under_sanctuary_physical_map.json"

@export var build_on_ready: bool = true

var physical_map: Dictionary = {}

func _ready() -> void:
    if build_on_ready:
        build_blockout()

func build_blockout() -> void:
    _clear_generated()
    physical_map = _load_json(PHYSICAL_MAP_PATH)
    if physical_map.is_empty():
        push_error("VeilleursVS001BlockoutBuilder: physical map missing")
        return

    var generated := Node3D.new()
    generated.name = "VS001PhysicalBlockout"
    generated.set_meta("layout_id", str(physical_map.get("layout_id", "")))
    generated.set_meta("seed", str(physical_map.get("seed", "")))
    generated.set_meta("mobile_first", bool(physical_map.get("design_rules", {}).get("mobile_first", false)))
    add_child(generated)

    var rooms: Array = physical_map.get("rooms", [])
    var connections: Array = physical_map.get("connections", [])
    var anchors: Array = physical_map.get("gameplay_anchors", [])
    _build_rooms(generated, rooms)
    _build_connections(generated, connections)
    _build_gameplay_anchors(generated, anchors)
    _build_navigation_contract(generated)
    set_secret_connection_open(false)

func room_count() -> int:
    return (physical_map.get("rooms", []) as Array).size()

func connection_count() -> int:
    return (physical_map.get("connections", []) as Array).size()

func marker_count() -> int:
    return (physical_map.get("gameplay_anchors", []) as Array).size()

func room_node(room_id: String) -> Node3D:
    var root: Node3D = _generated_root()
    if root == null:
        return null
    var rooms_root: Node = root.get_node_or_null("Rooms")
    if rooms_root == null:
        return null
    return rooms_root.find_child(room_id, true, false) as Node3D

func marker_node(marker_id: String) -> Marker3D:
    var root: Node3D = _generated_root()
    if root == null:
        return null
    var anchors_root: Node = root.get_node_or_null("GameplayAnchors")
    if anchors_root == null:
        return null
    return anchors_root.find_child(marker_id, true, false) as Marker3D

func connection_node(connection_id: String) -> Node3D:
    var root: Node3D = _generated_root()
    if root == null:
        return null
    var connections_root: Node = root.get_node_or_null("Connections")
    if connections_root == null:
        return null
    return connections_root.find_child(connection_id, true, false) as Node3D

func path_exists(start_id: String, goal_id: String, include_secrets: bool = false) -> bool:
    if start_id == goal_id:
        return true
    var visited: Dictionary = {start_id: true}
    var queue: Array[String] = [start_id]
    var connections: Array = physical_map.get("connections", [])
    while not queue.is_empty():
        var current: String = queue.pop_front()
        for connection_value: Variant in connections:
            var connection: Dictionary = connection_value
            if not include_secrets and bool(connection.get("secret", false)):
                continue
            var a: String = str(connection.get("a", ""))
            var b: String = str(connection.get("b", ""))
            var next_id := ""
            if a == current:
                next_id = b
            elif b == current:
                next_id = a
            else:
                continue
            if next_id == goal_id:
                return true
            if not visited.has(next_id):
                visited[next_id] = true
                queue.append(next_id)
    return false

func set_secret_connection_open(is_open: bool) -> void:
    var secret: Node3D = connection_node("c_s7_s8")
    if secret == null:
        return
    secret.visible = is_open
    secret.set_meta("physically_open", is_open)
    _set_collision_enabled_recursive(secret, is_open)

func secret_connection_open() -> bool:
    var secret: Node3D = connection_node("c_s7_s8")
    return secret != null and secret.visible and bool(secret.get_meta("physically_open", false)) and _all_collisions_enabled(secret)

func secret_connection_locked() -> bool:
    var secret: Node3D = connection_node("c_s7_s8")
    return secret != null and not secret.visible and not bool(secret.get_meta("physically_open", true)) and _all_collisions_disabled(secret)

func layout_summary() -> Dictionary:
    var root: Node3D = _generated_root()
    if root == null:
        return {"ready": false}
    return {
        "ready": true,
        "rooms": room_count(),
        "connections": connection_count(),
        "anchors": marker_count(),
        "mesh_instances": _count_type(root, "MeshInstance3D"),
        "collision_shapes": _count_type(root, "CollisionShape3D"),
        "secret_connection_hidden": _secret_connection_hidden(),
        "secret_connection_physically_locked": secret_connection_locked(),
        "physical_retreat_s7_to_s1": path_exists("s7_voice_chamber", "s1_vestibule", false)
    }

func _clear_generated() -> void:
    var old: Node = get_node_or_null("VS001PhysicalBlockout")
    if old != null:
        remove_child(old)
        old.queue_free()

func _generated_root() -> Node3D:
    return get_node_or_null("VS001PhysicalBlockout") as Node3D

func _build_rooms(root: Node3D, rooms: Array) -> void:
    var rooms_root := Node3D.new()
    rooms_root.name = "Rooms"
    root.add_child(rooms_root)
    for room_value: Variant in rooms:
        var room_data: Dictionary = room_value
        _build_room(rooms_root, room_data)

func _build_room(parent: Node3D, room_data: Dictionary) -> void:
    var room := Node3D.new()
    var room_id: String = str(room_data.get("id", "room"))
    var center: Vector3 = _vec3(room_data.get("center", [0.0, 0.0, 0.0]))
    var size: Vector3 = _vec3(room_data.get("size", [10.0, 4.0, 10.0]))
    var openings: Array = room_data.get("openings", [])
    room.name = room_id
    room.position = center
    room.add_to_group("veilleurs_vs001_room")
    room.set_meta("display_name", str(room_data.get("display_name", room_id)))
    room.set_meta("role", str(room_data.get("role", "unknown")))
    room.set_meta("critical", bool(room_data.get("critical", false)))
    room.set_meta("optional", bool(room_data.get("optional", false)))
    room.set_meta("secret", bool(room_data.get("secret", false)))
    room.set_meta("dimensions_m", size)
    room.set_meta("blender_asset_slot", str(room_data.get("blender_asset_slot", "")))
    parent.add_child(room)

    _box(room, "Floor", Vector3(0.0, -0.2, 0.0), Vector3(size.x, 0.4, size.z), true, "floor")
    _build_room_walls(room, size, openings)

func _build_room_walls(room: Node3D, size: Vector3, openings: Array) -> void:
    var height: float = size.y
    var thickness := 0.6
    var door_width := 2.4
    _build_horizontal_wall(room, "NorthWall", -size.z * 0.5, size.x, height, thickness, door_width, _has_opening(openings, "north"))
    _build_horizontal_wall(room, "SouthWall", size.z * 0.5, size.x, height, thickness, door_width, _has_opening(openings, "south"))
    _build_vertical_wall(room, "WestWall", -size.x * 0.5, size.z, height, thickness, door_width, _has_opening(openings, "west"))
    _build_vertical_wall(room, "EastWall", size.x * 0.5, size.z, height, thickness, door_width, _has_opening(openings, "east"))

func _build_horizontal_wall(parent: Node3D, prefix: String, z: float, length: float, height: float, thickness: float, door_width: float, has_opening: bool) -> void:
    if not has_opening:
        _box(parent, prefix, Vector3(0.0, height * 0.5, z), Vector3(length, height, thickness), true, "wall")
        return
    var side: float = maxf(0.8, (length - door_width) * 0.5)
    var offset: float = (door_width + side) * 0.5
    _box(parent, prefix + "Left", Vector3(-offset, height * 0.5, z), Vector3(side, height, thickness), true, "wall")
    _box(parent, prefix + "Right", Vector3(offset, height * 0.5, z), Vector3(side, height, thickness), true, "wall")

func _build_vertical_wall(parent: Node3D, prefix: String, x: float, length: float, height: float, thickness: float, door_width: float, has_opening: bool) -> void:
    if not has_opening:
        _box(parent, prefix, Vector3(x, height * 0.5, 0.0), Vector3(thickness, height, length), true, "wall")
        return
    var side: float = maxf(0.8, (length - door_width) * 0.5)
    var offset: float = (door_width + side) * 0.5
    _box(parent, prefix + "North", Vector3(x, height * 0.5, -offset), Vector3(thickness, height, side), true, "wall")
    _box(parent, prefix + "South", Vector3(x, height * 0.5, offset), Vector3(thickness, height, side), true, "wall")

func _build_connections(root: Node3D, connections: Array) -> void:
    var connections_root := Node3D.new()
    connections_root.name = "Connections"
    root.add_child(connections_root)
    for connection_value: Variant in connections:
        var connection: Dictionary = connection_value
        var corridor := Node3D.new()
        corridor.name = str(connection.get("id", "connection"))
        corridor.set_meta("from_room", str(connection.get("a", "")))
        corridor.set_meta("to_room", str(connection.get("b", "")))
        corridor.set_meta("connection_type", str(connection.get("type", "corridor")))
        corridor.set_meta("secret", bool(connection.get("secret", false)))
        corridor.set_meta("optional", bool(connection.get("optional", false)))
        corridor.set_meta("locked_by", str(connection.get("locked_by", "")))
        corridor.add_to_group("veilleurs_vs001_connection")
        if bool(connection.get("secret", false)):
            corridor.add_to_group("veilleurs_vs001_secret_connection")
            corridor.visible = false
        connections_root.add_child(corridor)

        var points: Array = connection.get("waypoints", [])
        var width: float = float(connection.get("width", 2.4))
        for index: int in range(points.size()):
            var point: Vector3 = _vec3(points[index])
            var marker := Marker3D.new()
            marker.name = "Waypoint_%02d" % [index + 1]
            marker.position = point
            marker.set_meta("route_index", index)
            corridor.add_child(marker)
            if index > 0:
                var previous: Vector3 = _vec3(points[index - 1])
                _build_path_tiles(corridor, previous, point, width, index)

func _build_path_tiles(parent: Node3D, start: Vector3, finish: Vector3, width: float, segment_index: int) -> void:
    var distance: float = start.distance_to(finish)
    var tile_count: int = maxi(1, int(ceil(distance / 1.2)))
    for tile_index: int in range(tile_count + 1):
        var ratio: float = float(tile_index) / float(tile_count)
        var point: Vector3 = start.lerp(finish, ratio)
        _box(
            parent,
            "Path_%02d_%02d" % [segment_index, tile_index],
            point + Vector3(0.0, -0.16, 0.0),
            Vector3(width, 0.32, width),
            true,
            "corridor_floor"
        )

func _build_gameplay_anchors(root: Node3D, anchors: Array) -> void:
    var anchors_root := Node3D.new()
    anchors_root.name = "GameplayAnchors"
    root.add_child(anchors_root)
    for anchor_value: Variant in anchors:
        var anchor: Dictionary = anchor_value
        var marker := Marker3D.new()
        marker.name = str(anchor.get("id", "anchor"))
        marker.position = _vec3(anchor.get("position", [0.0, 0.0, 0.0]))
        marker.add_to_group("veilleurs_vs001_gameplay_anchor")
        marker.set_meta("room_id", str(anchor.get("room", "")))
        marker.set_meta("gameplay_role", str(anchor.get("role", "")))
        marker.set_meta("source_anchor", str(anchor.get("source_anchor", "")))
        anchors_root.add_child(marker)

func _build_navigation_contract(root: Node3D) -> void:
    var navigation := NavigationRegion3D.new()
    navigation.name = "NavigationProxy"
    var nav_mesh := NavigationMesh.new()
    nav_mesh.agent_radius = 0.55
    nav_mesh.agent_height = 1.8
    nav_mesh.agent_max_climb = 0.45
    nav_mesh.agent_max_slope = 46.0
    nav_mesh.cell_size = 0.25
    nav_mesh.cell_height = 0.2
    nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
    navigation.navigation_mesh = nav_mesh
    navigation.set_meta("requires_bake_after_art_pass", true)
    navigation.set_meta("proxy_only", true)
    root.add_child(navigation)

func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, collision_enabled: bool, role: String) -> void:
    var proxy := Node3D.new()
    proxy.name = node_name
    proxy.position = pos
    proxy.set_meta("blockout_role", role)
    proxy.set_meta("blockout_size_m", size)

    var mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh.mesh = box_mesh
    proxy.add_child(mesh)

    if collision_enabled:
        var body := StaticBody3D.new()
        body.name = "StaticBody"
        proxy.add_child(body)
        var collision := CollisionShape3D.new()
        collision.name = "CollisionShape"
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)

    parent.add_child(proxy)

func _has_opening(openings: Array, direction: String) -> bool:
    return openings.has(direction)

func _secret_connection_hidden() -> bool:
    var secret: Node3D = connection_node("c_s7_s8")
    return secret != null and not secret.visible and bool(secret.get_meta("secret", false))

func _set_collision_enabled_recursive(node: Node, enabled: bool) -> void:
    if node is CollisionShape3D:
        (node as CollisionShape3D).disabled = not enabled
    for child: Node in node.get_children():
        _set_collision_enabled_recursive(child, enabled)

func _all_collisions_disabled(node: Node) -> bool:
    var found := false
    var all_disabled := true
    if node is CollisionShape3D:
        found = true
        all_disabled = (node as CollisionShape3D).disabled
    for child: Node in node.get_children():
        if _contains_collision(child):
            found = true
            if not _all_collisions_disabled(child):
                all_disabled = false
    return found and all_disabled

func _all_collisions_enabled(node: Node) -> bool:
    var found := false
    var all_enabled := true
    if node is CollisionShape3D:
        found = true
        all_enabled = not (node as CollisionShape3D).disabled
    for child: Node in node.get_children():
        if _contains_collision(child):
            found = true
            if not _all_collisions_enabled(child):
                all_enabled = false
    return found and all_enabled

func _contains_collision(node: Node) -> bool:
    if node is CollisionShape3D:
        return true
    for child: Node in node.get_children():
        if _contains_collision(child):
            return true
    return false

func _count_type(root: Node, class_name_value: String) -> int:
    var count := 0
    if root.is_class(class_name_value):
        count += 1
    for child: Node in root.get_children():
        count += _count_type(child, class_name_value)
    return count

func _vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY:
        return Vector3.ZERO
    var values: Array = value
    if values.size() < 3:
        return Vector3.ZERO
    return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
