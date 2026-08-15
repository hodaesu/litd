extends Node3D
class_name AshlandsBlockoutBuilder

const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")

@export_file("*.json") var manifest_path := "res://data/levels/terre_des_cendres_blockout_manifest.json"
@export var zone_id := "zone_01_faubourg_cendreux"
@export var build_on_ready := true
@export var spawn_player_placeholder := true

var manifest: Dictionary = {}
var zone_data: Dictionary = {}

func _ready() -> void:
    if build_on_ready:
        build_zone()

func build_zone() -> void:
    _clear_generated()
    manifest = _load_json(manifest_path)
    zone_data = _find_zone(zone_id)
    if zone_data.is_empty():
        push_error("AshlandsBlockoutBuilder: zone introuvable: %s" % zone_id)
        return

    AshlandsRuntime.enter_zone(zone_id)
    _build_floor()
    _build_boundaries()
    _build_navigation_placeholder()
    _build_entry_and_exits()
    _build_ash_volumes()
    _build_encounter_slots()
    _build_resource_slots()
    _build_shortcut_slots()
    _build_campfire()
    _build_boss_slot()
    if spawn_player_placeholder:
        _build_player_placeholder()

func _clear_generated() -> void:
    var old := get_node_or_null("GeneratedBlockout")
    if old:
        remove_child(old)
        old.queue_free()

func _root() -> Node3D:
    var root := get_node_or_null("GeneratedBlockout") as Node3D
    if root == null:
        root = Node3D.new()
        root.name = "GeneratedBlockout"
        add_child(root)
    return root

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("AshlandsBlockoutBuilder: manifeste absent: %s" % path)
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _find_zone(id_value: String) -> Dictionary:
    for entry in manifest.get("zones", []):
        if str(entry.get("id", "")) == id_value:
            return entry
    return {}

func _build_floor() -> void:
    var size: Array = zone_data.get("size_m", [100, 100])
    var width := float(size[0])
    var depth := float(size[1])
    var body := StaticBody3D.new()
    body.name = "BlockoutFloor"
    _root().add_child(body)

    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(width, 0.5, depth)
    mesh.mesh = box
    mesh.position.y = -0.25
    body.add_child(mesh)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(width, 0.5, depth)
    collision.shape = shape
    collision.position.y = -0.25
    body.add_child(collision)

func _build_boundaries() -> void:
    var size: Array = zone_data.get("size_m", [100, 100])
    var w := float(size[0])
    var d := float(size[1])
    var thickness := 1.0
    var height := 2.0
    _build_wall(Vector3(0, height * 0.5, -d * 0.5), Vector3(w, height, thickness), "NorthBoundary")
    _build_wall(Vector3(0, height * 0.5, d * 0.5), Vector3(w, height, thickness), "SouthBoundary")
    _build_wall(Vector3(-w * 0.5, height * 0.5, 0), Vector3(thickness, height, d), "WestBoundary")
    _build_wall(Vector3(w * 0.5, height * 0.5, 0), Vector3(thickness, height, d), "EastBoundary")

func _build_wall(pos: Vector3, size: Vector3, node_name: String) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = pos
    _root().add_child(body)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

func _build_navigation_placeholder() -> void:
    var region := NavigationRegion3D.new()
    region.name = "NavigationPlaceholder"
    region.navigation_mesh = NavigationMesh.new()
    region.set_meta("requires_editor_bake_after_layout_polish", true)
    _root().add_child(region)

func _build_entry_and_exits() -> void:
    _build_marker("Entry", _array_to_vec3(zone_data.get("entry", [0, 0, 0])), "entry")
    var exits := Node3D.new()
    exits.name = "Exits"
    _root().add_child(exits)
    var i := 0
    for exit_data in zone_data.get("exits", []):
        var gate := ZoneTransitionGate.new()
        gate.name = "Exit_%02d_%s" % [i + 1, str(exit_data.get("to", "unknown"))]
        gate.position = _array_to_vec3(exit_data.get("position", [0, 0, 0]))
        gate.gate_id = "%s_to_%s" % [zone_id, str(exit_data.get("to", ""))]
        gate.from_zone = zone_id
        gate.to_zone = str(exit_data.get("to", ""))
        gate.secret = bool(exit_data.get("secret", false))
        gate.teleporter = bool(exit_data.get("teleporter", false))
        gate.required_obsidian_points = 1 if gate.teleporter else 0
        _add_box_area_collision(gate, Vector3(3.0, 2.5, 3.0))
        exits.add_child(gate)
        i += 1

func _build_ash_volumes() -> void:
    var parent := Node3D.new()
    parent.name = "AshVolumes"
    _root().add_child(parent)
    var count := int(zone_data.get("ash_volumes", 0))
    for i in count:
        var area := AshVolume.new()
        area.name = "AshVolume_%02d" % [i + 1]
        area.position = _slot_position(i, count, 0.23)
        area.density = 0.72 if i % 2 == 0 else 0.48
        _add_box_area_collision(area, Vector3(9.0, 3.0, 9.0))
        parent.add_child(area)

func _build_encounter_slots() -> void:
    var parent := Node3D.new()
    parent.name = "EncounterSlots"
    _root().add_child(parent)
    var count := int(zone_data.get("encounter_slots", 0))
    var miniboss := AshlandsMinibossDirector.get_assignment(zone_id)
    for i in count:
        var trigger := EncounterTrigger.new()
        trigger.name = "Encounter_%02d" % [i + 1]
        trigger.position = _slot_position(i, count, 0.31)
        trigger.encounter_id = "%s:encounter:%02d" % [zone_id, i + 1]
        trigger.encounter_type = "miniboss" if i == 0 and not miniboss.is_empty() else "normal"
        trigger.alternate_route_available = true
        if trigger.encounter_type == "miniboss":
            trigger.set_meta("miniboss", miniboss)
        _add_box_area_collision(trigger, Vector3(4.0, 2.0, 4.0))
        parent.add_child(trigger)

func _build_resource_slots() -> void:
    var parent := Node3D.new()
    parent.name = "ResourceSlots"
    _root().add_child(parent)
    var count := int(zone_data.get("resource_slots", 0))
    var resource_cycle := ["food", "bandages", "light", "craft_scrap"]
    for i in count:
        var node := ResourceNode.new()
        node.name = "Resource_%02d" % [i + 1]
        node.node_id = "%s:resource:%02d" % [zone_id, i + 1]
        node.resource_type = resource_cycle[i % resource_cycle.size()]
        node.amount_min = 1
        node.amount_max = 2
        node.position = _slot_position(i, count, 0.39) + Vector3(1.5, 0.0, -1.5)
        _add_box_area_collision(node, Vector3(1.6, 1.4, 1.6))
        node.sync_from_runtime()
        parent.add_child(node)

func _build_shortcut_slots() -> void:
    var parent := Node3D.new()
    parent.name = "ShortcutSlots"
    _root().add_child(parent)
    var ids: Array = zone_data.get("shortcut_slots", [])
    for i in ids.size():
        var gate := ShortcutGate.new()
        gate.name = str(ids[i])
        gate.shortcut_id = str(ids[i])
        gate.position = Vector3(-6 + i * 5, 0.0, 7)
        _add_box_area_collision(gate, Vector3(2.5, 2.5, 1.5))
        parent.add_child(gate)

func _build_campfire() -> void:
    if not bool(zone_data.get("campfire", false)):
        return
    var campfire := CampfireInteraction.new()
    campfire.name = "Campfire"
    campfire.zone_id = zone_id
    campfire.position = Vector3.ZERO
    _add_box_area_collision(campfire, Vector3(2.5, 2.0, 2.5))
    _root().add_child(campfire)

func _build_boss_slot() -> void:
    if not zone_data.has("boss"):
        return
    var trigger := EncounterTrigger.new()
    trigger.name = "BossSlot"
    trigger.encounter_id = str(zone_data.get("boss", "ashlands_boss"))
    trigger.encounter_type = "boss"
    trigger.position = Vector3(0, 0, -10)
    _add_box_area_collision(trigger, Vector3(7.0, 3.0, 7.0))
    _root().add_child(trigger)

func _build_player_placeholder() -> void:
    var party := PARTY_SCENE.instantiate()
    party.name = "ExplorationPartyRuntime"
    party.position = _array_to_vec3(zone_data.get("entry", [0, 0, 0])) + Vector3.UP * 0.1
    _root().add_child(party)

func _slot_position(index: int, count: int, radius_factor: float) -> Vector3:
    var zone_size: Array = zone_data.get("size_m", [100, 100])
    var w := float(zone_size[0])
    var d := float(zone_size[1])
    var angle := TAU * float(index) / max(1.0, float(count))
    return Vector3(cos(angle) * w * radius_factor, 0.0, sin(angle) * d * radius_factor)

func _add_box_area_collision(area: Area3D, size: Vector3) -> void:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    collision.position.y = size.y * 0.5
    area.add_child(collision)

func _build_marker(node_name: String, pos: Vector3, marker_type: String) -> void:
    var node := Marker3D.new()
    node.name = node_name
    node.position = pos
    node.set_meta("marker_type", marker_type)
    _root().add_child(node)

func _array_to_vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY or value.size() < 3:
        return Vector3.ZERO
    return Vector3(float(value[0]), float(value[1]), float(value[2]))
