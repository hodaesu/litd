extends Node3D
class_name AshlandsBlockoutBuilder

@export_file("*.json") var manifest_path := "res://data/levels/terre_des_cendres_blockout_manifest.json"
@export var zone_id := "zone_01_faubourg_cendreux"
@export var build_on_ready := true

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

    _build_floor()
    _build_boundaries()
    _build_entry_and_exits()
    _build_slots("AshVolumes", int(zone_data.get("ash_volumes", 0)), Vector3(8, 2.5, 8), "ash")
    _build_slots("EncounterSlots", int(zone_data.get("encounter_slots", 0)), Vector3(2, 1, 2), "encounter")
    _build_slots("ResourceSlots", int(zone_data.get("resource_slots", 0)), Vector3(1, 0.5, 1), "resource")
    _build_shortcut_slots()
    if bool(zone_data.get("campfire", false)):
        _build_marker("Campfire", Vector3.ZERO + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), "campfire")
    if zone_data.has("boss"):
        _build_marker("BossSlot", Vector3(0, 1, -10), Vector3(4, 2, 4), "boss")

func _clear_generated() -> void:
    var old := get_node_or_null("GeneratedBlockout")
    if old:
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
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
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

func _build_entry_and_exits() -> void:
    _build_marker("Entry", _array_to_vec3(zone_data.get("entry", [0,0,0])), Vector3(2,2,2), "entry")
    var exits := Node3D.new()
    exits.name = "Exits"
    _root().add_child(exits)
    var i := 0
    for exit_data in zone_data.get("exits", []):
        var marker := Marker3D.new()
        marker.name = "Exit_%02d_%s" % [i + 1, str(exit_data.get("to", "unknown"))]
        marker.position = _array_to_vec3(exit_data.get("position", [0,0,0]))
        marker.set_meta("target_zone", str(exit_data.get("to", "")))
        marker.set_meta("secret", bool(exit_data.get("secret", false)))
        marker.set_meta("teleporter", bool(exit_data.get("teleporter", false)))
        exits.add_child(marker)
        i += 1

func _build_slots(parent_name: String, count: int, size: Vector3, slot_type: String) -> void:
    var parent := Node3D.new()
    parent.name = parent_name
    _root().add_child(parent)
    var zone_size: Array = zone_data.get("size_m", [100,100])
    var w := float(zone_size[0]) * 0.7
    var d := float(zone_size[1]) * 0.7
    for i in count:
        var angle := TAU * float(i) / max(1.0, float(count))
        var pos := Vector3(cos(angle) * w * 0.35, 0.5, sin(angle) * d * 0.35)
        var marker := Node3D.new()
        marker.name = "%s_%02d" % [slot_type.capitalize(), i + 1]
        marker.position = pos
        marker.set_meta("slot_type", slot_type)
        parent.add_child(marker)

func _build_shortcut_slots() -> void:
    var parent := Node3D.new()
    parent.name = "ShortcutSlots"
    _root().add_child(parent)
    var i := 0
    for shortcut_id in zone_data.get("shortcut_slots", []):
        var marker := Marker3D.new()
        marker.name = str(shortcut_id)
        marker.position = Vector3(-6 + i * 4, 0.5, 6)
        marker.set_meta("persistent", true)
        parent.add_child(marker)
        i += 1

func _build_marker(node_name: String, pos: Vector3, size: Vector3, marker_type: String) -> void:
    var node := Node3D.new()
    node.name = node_name
    node.position = pos
    node.set_meta("marker_type", marker_type)
    _root().add_child(node)

func _array_to_vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY or value.size() < 3:
        return Vector3.ZERO
    return Vector3(float(value[0]), float(value[1]), float(value[2]))
