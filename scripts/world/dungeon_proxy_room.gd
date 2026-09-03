extends Node3D

signal exit_reached(target_room_id: String)
signal remanence_interaction(scar_id: String, result: Dictionary)

const EXPLORER_SCENE := preload("res://scenes/dungeon/DungeonProxyExplorer.tscn")
const ASH_GUIDANCE_POLICY_SCRIPT := preload("res://scripts/core/ash_guidance_policy.gd")

var room_spec: Dictionary = {}
var exits_enabled: bool = false
var visible_targets: Array[String] = []
var explorer: CharacterBody3D = null

func configure(resolved_room: Dictionary, allowed_target_ids: Array[String], allow_exits: bool) -> void:
    room_spec = resolved_room.duplicate(true)
    visible_targets = allowed_target_ids.duplicate()
    exits_enabled = allow_exits
    _rebuild()

func _rebuild() -> void:
    for child in get_children():
        child.queue_free()
    if room_spec.is_empty():
        return
    var dimensions: Vector3 = room_spec.get("dimensions_m", Vector3(12.0, 5.0, 10.0))
    var proxy: Dictionary = room_spec.get("proxy", {})
    var ports: Array = room_spec.get("ports", [])
    var geometry: Dictionary = _global_geometry()
    var wall_thickness: float = float(geometry.get("wall", 0.4))
    var floor_thickness: float = float(geometry.get("floor", 0.25))
    var door_values: Array = geometry.get("door", [2.4, 3.2])
    var door_width: float = float(door_values[0]) if door_values.size() > 0 else 2.4
    var wall_height: float = dimensions.y

    _add_box("Floor", Vector3(dimensions.x, floor_thickness, dimensions.z), Vector3(0.0, -floor_thickness * 0.5, 0.0), true)
    _add_box("Ceiling", Vector3(dimensions.x, floor_thickness, dimensions.z), Vector3(0.0, wall_height + floor_thickness * 0.5, 0.0), false)

    var open_sides: Array[String] = []
    for port_value in ports:
        var port: Dictionary = port_value
        var target_id: String = str(port.get("target_room_id", ""))
        if visible_targets.has(target_id):
            var side: String = str(port.get("side", "north"))
            if not open_sides.has(side):
                open_sides.append(side)

    _build_wall("north", dimensions, wall_thickness, wall_height, door_width, open_sides.has("north"))
    _build_wall("south", dimensions, wall_thickness, wall_height, door_width, open_sides.has("south"))
    _build_wall("east", dimensions, wall_thickness, wall_height, door_width, open_sides.has("east"))
    _build_wall("west", dimensions, wall_thickness, wall_height, door_width, open_sides.has("west"))

    _add_anchor_markers(room_spec.get("anchors", {}))
    _add_interaction_markers(room_spec.get("interaction_points", []))
    _add_remanence_proxies(room_spec.get("remanence_scars", []), dimensions)
    _add_obstacle_proxies(str(proxy.get("role", "generic")), dimensions)

    for port_value in ports:
        var port: Dictionary = port_value
        var target_id: String = str(port.get("target_room_id", ""))
        if not visible_targets.has(target_id):
            continue
        _add_portal(port, dimensions)
        _add_connector_preview(port, dimensions)

    explorer = EXPLORER_SCENE.instantiate() as CharacterBody3D
    if explorer != null:
        var anchors: Dictionary = room_spec.get("anchors", {})
        explorer.position = anchors.get("hero_spawn", Vector3(0.0, 0.2, -2.0))
        explorer.name = "Explorer"
        add_child(explorer)
        if explorer.has_signal("interaction_requested") and not explorer.is_connected("interaction_requested", _on_explorer_interaction):
            explorer.connect("interaction_requested", _on_explorer_interaction)
        _configure_boss_guidance(dimensions, ports)

func _configure_boss_guidance(dimensions: Vector3, ports: Array) -> void:
    if explorer == null or not explorer.has_method("set_boss_guidance_position"):
        return
    var proxy: Dictionary = room_spec.get("proxy", {})
    var role: String = str(proxy.get("role", "generic"))
    if role == "boss":
        var anchors: Dictionary = room_spec.get("anchors", {})
        var boss_anchor: Vector3 = anchors.get("enemy_spawn_center", Vector3(0.0, 0.7, 3.5))
        explorer.call("set_boss_guidance_position", to_global(boss_anchor), 1.0)
        return

    var policy: AshGuidancePolicy = ASH_GUIDANCE_POLICY_SCRIPT.new() as AshGuidancePolicy
    if policy == null:
        return
    var room_id: String = str(room_spec.get("id", ""))
    var route: Dictionary = policy.route_to_boss(room_id, visible_targets)
    if not bool(route.get("found", false)):
        if explorer.has_method("clear_ash_guidance"):
            explorer.call("clear_ash_guidance")
        return
    var next_room_id: String = str(route.get("next_room_id", ""))
    var target_local: Vector3 = Vector3.ZERO
    var found_port: bool = false
    for port_value: Variant in ports:
        if typeof(port_value) != TYPE_DICTIONARY:
            continue
        var port: Dictionary = port_value
        if str(port.get("target_room_id", "")) != next_room_id:
            continue
        target_local = _portal_position(str(port.get("side", "north")), dimensions) + Vector3(0.0, 1.0, 0.0)
        found_port = true
        break
    if found_port:
        explorer.call("set_boss_guidance_position", to_global(target_local), float(route.get("proximity", 0.0)))

func _global_geometry() -> Dictionary:
    return room_spec.get("global_geometry", {})

func _build_wall(side: String, dimensions: Vector3, thickness: float, height: float, door_width: float, has_opening: bool) -> void:
    var y: float = height * 0.5
    if not has_opening:
        if side in ["north", "south"]:
            var z: float = -dimensions.z * 0.5 if side == "north" else dimensions.z * 0.5
            _add_box("Wall_%s" % side, Vector3(dimensions.x, height, thickness), Vector3(0.0, y, z), true)
        else:
            var x: float = dimensions.x * 0.5 if side == "east" else -dimensions.x * 0.5
            _add_box("Wall_%s" % side, Vector3(thickness, height, dimensions.z), Vector3(x, y, 0.0), true)
        return

    if side in ["north", "south"]:
        var segment: float = maxf(0.5, (dimensions.x - door_width) * 0.5)
        var z_open: float = -dimensions.z * 0.5 if side == "north" else dimensions.z * 0.5
        _add_box("Wall_%s_L" % side, Vector3(segment, height, thickness), Vector3(-(door_width + segment) * 0.5, y, z_open), true)
        _add_box("Wall_%s_R" % side, Vector3(segment, height, thickness), Vector3((door_width + segment) * 0.5, y, z_open), true)
    else:
        var segment_z: float = maxf(0.5, (dimensions.z - door_width) * 0.5)
        var x_open: float = dimensions.x * 0.5 if side == "east" else -dimensions.x * 0.5
        _add_box("Wall_%s_L" % side, Vector3(thickness, height, segment_z), Vector3(x_open, y, -(door_width + segment_z) * 0.5), true)
        _add_box("Wall_%s_R" % side, Vector3(thickness, height, segment_z), Vector3(x_open, y, (door_width + segment_z) * 0.5), true)

func _add_box(node_name: String, size: Vector3, position_value: Vector3, collidable: bool) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.position = position_value
    add_child(root)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.name = "Mesh"
    root.add_child(mesh_instance)

    if collidable:
        var body := StaticBody3D.new()
        body.name = "Collision"
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        root.add_child(body)
    return root

func _add_anchor_markers(anchors: Dictionary) -> void:
    var anchor_root := Node3D.new()
    anchor_root.name = "GameplayAnchors"
    add_child(anchor_root)
    for key_value in anchors.keys():
        var key: String = str(key_value)
        var marker := Marker3D.new()
        marker.name = key
        marker.position = anchors.get(key, Vector3.ZERO)
        marker.set_meta("anchor_id", key)
        anchor_root.add_child(marker)

func _add_interaction_markers(points: Array) -> void:
    var root := Node3D.new()
    root.name = "InteractionAnchors"
    add_child(root)
    for point_value in points:
        var point: Dictionary = point_value
        var marker := Marker3D.new()
        marker.name = str(point.get("id", "interaction"))
        marker.position = point.get("position", Vector3.ZERO)
        marker.set_meta("interaction_id", str(point.get("id", "interaction")))
        marker.set_meta("interaction_label", str(point.get("label", "")))
        root.add_child(marker)
        var visual := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.35, 0.35, 0.35)
        visual.mesh = mesh
        visual.position = marker.position
        visual.name = "POI_%s" % marker.name
        root.add_child(visual)

func _add_remanence_proxies(scars: Array, dimensions: Vector3) -> void:
    var root := Node3D.new()
    root.name = "RemanenceScars"
    add_child(root)
    var usable_x := maxf(2.0, dimensions.x * 0.55)
    var usable_z := maxf(2.0, dimensions.z * 0.45)
    for index in range(scars.size()):
        var scar_value: Variant = scars[index]
        if not (scar_value is Dictionary):
            continue
        var scar: Dictionary = scar_value
        var scar_id := str(scar.get("id", ""))
        if scar_id == "":
            continue
        var scar_type := str(scar.get("type", "trace"))
        var seed := absi(scar_id.hash())
        var x_ratio := float(seed % 1000) / 999.0
        var z_ratio := float((seed / 1000) % 1000) / 999.0
        var position_value := Vector3((x_ratio - 0.5) * usable_x, 0.0, (z_ratio - 0.5) * usable_z)
        var marker := Marker3D.new()
        marker.name = "Scar_%03d" % index
        marker.position = position_value
        marker.set_meta("scar_id", scar_id)
        marker.set_meta("scar_type", scar_type)
        marker.set_meta("interaction_id", scar_id)
        marker.set_meta("interaction_label", _scar_interaction_label(scar))
        marker.set_meta("summary", str(scar.get("summary", "")))
        root.add_child(marker)

        var visual := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        match scar_type:
            "persistent_corpse":
                mesh.size = Vector3(1.6, 0.24, 0.58)
                visual.position = position_value + Vector3(0.0, 0.12, 0.0)
                visual.set_meta("blender_asset_slot", "remanence/persistent_corpse")
            "nemesis_mark":
                mesh.size = Vector3(0.34, 1.55, 0.34)
                visual.position = position_value + Vector3(0.0, 0.78, 0.0)
                visual.set_meta("blender_asset_slot", "remanence/nemesis_mark")
            _:
                mesh.size = Vector3(1.1, 0.06, 0.8)
                visual.position = position_value + Vector3(0.0, 0.03, 0.0)
                visual.set_meta("blender_asset_slot", "remanence/%s" % scar_type)
        visual.mesh = mesh
        visual.name = "Visual_%03d" % index
        visual.set_meta("scar_id", scar_id)
        visual.set_meta("scar_type", scar_type)
        root.add_child(visual)

func _scar_interaction_label(scar: Dictionary) -> String:
    var scar_type := str(scar.get("type", "trace"))
    var payload: Dictionary = scar.get("payload", {})
    match scar_type:
        "persistent_corpse": return "Examiner le corps de %s" % str(payload.get("owner_name", "l'inconnu"))
        "nemesis_mark": return "Examiner la marque du Némésis"
        _:
            var effect: Dictionary = {}
            if RemanenceCombatBridge.world_director != null:
                effect = RemanenceCombatBridge.world_director.rules.get("scar_effects", {}).get(scar_type, {})
            return "Examiner la Rémanence" if bool(effect.get("interaction", false)) else ""

func nearest_interaction_for(world_position: Vector3, radius: float) -> Dictionary:
    var best: Dictionary = {}
    var best_distance := maxf(0.0, radius)
    for root_name in ["InteractionAnchors", "RemanenceScars"]:
        var root := get_node_or_null(root_name)
        if root == null:
            continue
        for child_value: Node in root.get_children():
            if not (child_value is Node3D):
                continue
            var child := child_value as Node3D
            var label := str(child.get_meta("interaction_label", ""))
            if label == "":
                continue
            var distance := child.global_position.distance_to(world_position)
            if distance > best_distance:
                continue
            best_distance = distance
            best = {
                "id": str(child.get_meta("interaction_id", child.name)),
                "label": label,
                "distance": distance
            }
    return best

func _on_explorer_interaction(interaction_id: String, _label: String) -> void:
    if not interaction_id.begins_with("scar:"):
        return
    if RemanenceCombatBridge.world_director == null or not RemanenceCombatBridge.world_director.has_method("visit_scar"):
        return
    var result_value: Variant = RemanenceCombatBridge.world_director.call("visit_scar", interaction_id)
    if not (result_value is Dictionary):
        return
    var result: Dictionary = result_value
    if not bool(result.get("ok", false)):
        return
    GameState.add_log(str(result.get("text", "Le monde se souvient.")))
    remanence_interaction.emit(interaction_id, result.duplicate(true))

func _add_obstacle_proxies(role: String, dimensions: Vector3) -> void:
    var root := Node3D.new()
    root.name = "ObstacleProxies"
    add_child(root)
    var positions: Array[Vector3] = []
    match role:
        "combat", "elite":
            positions = [Vector3(-dimensions.x * 0.22, 0.65, 0.0), Vector3(dimensions.x * 0.22, 0.65, 0.0)]
        "hazard":
            positions = [Vector3(0.0, 0.2, 0.0)]
        "puzzle":
            positions = [Vector3(-1.4, 0.8, 1.0), Vector3(1.4, 0.8, 1.0)]
        "boss":
            positions = [Vector3(-4.0, 1.5, 1.5), Vector3(4.0, 1.5, 1.5), Vector3(0.0, 0.7, 3.5)]
        "preboss":
            positions = [Vector3(0.0, 1.4, 2.0)]
        _:
            positions = [Vector3(-1.2, 0.5, 0.8), Vector3(1.2, 0.5, 0.8)]
    for index in range(positions.size()):
        var position_value: Vector3 = positions[index]
        var obstacle := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(1.1, 1.3, 1.1) if role not in ["hazard", "boss"] else Vector3(1.4, 0.4 if role == "hazard" else 3.0, 1.4)
        obstacle.mesh = mesh
        obstacle.position = position_value
        obstacle.name = "Obstacle_%d" % index
        root.add_child(obstacle)

func _add_portal(port: Dictionary, dimensions: Vector3) -> void:
    var target_id: String = str(port.get("target_room_id", ""))
    var side: String = str(port.get("side", "north"))
    var portal := Area3D.new()
    portal.name = "Exit_%s" % target_id
    portal.position = _portal_position(side, dimensions)
    portal.set_meta("target_room_id", target_id)
    portal.set_meta("connector_type", str(port.get("connector_type", "standard_corridor")))
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.3, 2.3, 1.0) if side in ["north", "south"] else Vector3(1.0, 2.3, 2.3)
    collision.shape = shape
    collision.position = Vector3(0.0, 1.15, 0.0)
    portal.add_child(collision)
    portal.monitoring = exits_enabled
    if exits_enabled:
        portal.body_entered.connect(func(body: Node3D) -> void:
            if body == explorer:
                exit_reached.emit(target_id)
        )
    add_child(portal)

func _portal_position(side: String, dimensions: Vector3) -> Vector3:
    match side:
        "north": return Vector3(0.0, 0.0, -dimensions.z * 0.5 - 0.35)
        "south": return Vector3(0.0, 0.0, dimensions.z * 0.5 + 0.35)
        "east": return Vector3(dimensions.x * 0.5 + 0.35, 0.0, 0.0)
        "west": return Vector3(-dimensions.x * 0.5 - 0.35, 0.0, 0.0)
        _: return Vector3.ZERO

func _add_connector_preview(port: Dictionary, dimensions: Vector3) -> void:
    var side: String = str(port.get("side", "north"))
    var connector_type: String = str(port.get("connector_type", "standard_corridor"))
    var width: float = 3.0
    var length: float = 3.5
    if connector_type == "secret_passage":
        width = 1.8
        length = 2.5
    elif connector_type == "boss_gate":
        width = 4.0
        length = 3.0
    elif connector_type == "stairwell":
        width = 3.2
        length = 4.5
    var size: Vector3 = Vector3(width, 0.18, length)
    var position_value: Vector3 = Vector3.ZERO
    if side == "north":
        position_value = Vector3(0.0, -0.05, -dimensions.z * 0.5 - length * 0.5)
    elif side == "south":
        position_value = Vector3(0.0, -0.05, dimensions.z * 0.5 + length * 0.5)
    elif side == "east":
        size = Vector3(length, 0.18, width)
        position_value = Vector3(dimensions.x * 0.5 + length * 0.5, -0.05, 0.0)
    elif side == "west":
        size = Vector3(length, 0.18, width)
        position_value = Vector3(-dimensions.x * 0.5 - length * 0.5, -0.05, 0.0)
    var preview: Node3D = _add_box("Connector_%s_%s" % [connector_type, str(port.get("target_room_id", "target"))], size, position_value, true)
    preview.set_meta("connector_type", connector_type)
    preview.set_meta("target_room_id", str(port.get("target_room_id", "")))

func room_summary() -> Dictionary:
    return {
        "room_id": str(room_spec.get("id", "")),
        "dimensions": room_spec.get("dimensions_m", Vector3.ZERO),
        "port_count": (room_spec.get("ports", []) as Array).size(),
        "visible_exit_count": visible_targets.size(),
        "has_explorer": explorer != null,
        "exits_enabled": exits_enabled,
        "remanence_scar_count": (room_spec.get("remanence_scars", []) as Array).size(),
        "nemesis_entity_id": str(room_spec.get("nemesis_entity_id", ""))
    }
