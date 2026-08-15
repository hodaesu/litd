extends RefCounted
class_name AshlandsLayoutGenerator

const PROFILE_PATH := "res://data/levels/ashlands_layout_profiles.json"

static func generate(parent: Node3D, zone_id: String, zone_data: Dictionary) -> void:
    var data := _load_json(PROFILE_PATH)
    var zone_profiles: Dictionary = data.get("zones", {})
    if not zone_profiles.has(zone_id):
        return
    var zone_profile: Dictionary = zone_profiles[zone_id]
    var profile_name := str(zone_profile.get("profile", "settlement_edge"))
    var rules: Dictionary = data.get("profile_rules", {}).get(profile_name, {})
    var root := Node3D.new()
    root.name = "LayoutProfile"
    root.set_meta("profile", profile_name)
    root.set_meta("landmark", str(zone_profile.get("landmark", "")))
    parent.add_child(root)

    var rng := RandomNumberGenerator.new()
    rng.seed = zone_id.hash()
    var size: Array = zone_data.get("size_m", [100, 100])
    var w := float(size[0])
    var d := float(size[1])

    _generate_buildings(root, int(rules.get("building_count", 0)), w, d, rng)
    _generate_walls(root, int(rules.get("wall_count", 0)), w, d, profile_name, rng)
    _generate_platforms(root, int(rules.get("platform_count", 0)), w, d, int(zone_profile.get("levels", 1)), profile_name, rng)
    _generate_landmark(root, str(zone_profile.get("landmark", "")), profile_name)

static func _generate_buildings(root: Node3D, count: int, w: float, d: float, rng: RandomNumberGenerator) -> void:
    for i in count:
        var sx := rng.randf_range(5.0, 11.0)
        var sz := rng.randf_range(5.0, 11.0)
        var sy := rng.randf_range(3.0, 7.0)
        var x := rng.randf_range(-w * 0.38, w * 0.38)
        var z := rng.randf_range(-d * 0.38, d * 0.38)
        if abs(x) < 8.0:
            x += 14.0 if x >= 0.0 else -14.0
        _box(root, "Building_%02d" % [i + 1], Vector3(x, sy * 0.5, z), Vector3(sx, sy, sz), true)

static func _generate_walls(root: Node3D, count: int, w: float, d: float, profile: String, rng: RandomNumberGenerator) -> void:
    if profile == "ravine":
        for i in count:
            var side := -1.0 if i % 2 == 0 else 1.0
            var z := lerp(-d * 0.38, d * 0.38, float(i) / max(1.0, float(count - 1)))
            _box(root, "Cliff_%02d" % [i + 1], Vector3(side * w * 0.30, 3.5, z), Vector3(w * 0.32, 7.0, 6.0), true)
        return
    if profile in ["underground_maze", "secret_crypt", "underground_chambers"]:
        for i in count:
            var horizontal := i % 2 == 0
            var x := rng.randf_range(-w * 0.34, w * 0.34)
            var z := rng.randf_range(-d * 0.34, d * 0.34)
            var dims := Vector3(rng.randf_range(8.0, 18.0), 3.0, 1.0) if horizontal else Vector3(1.0, 3.0, rng.randf_range(8.0, 18.0))
            _box(root, "MazeWall_%02d" % [i + 1], Vector3(x, 1.5, z), dims, true)
        return
    if profile in ["forest_paths", "secret_clearing", "open_graveyard"]:
        for i in count:
            var angle := TAU * float(i) / max(1.0, float(count)) + rng.randf_range(-0.12, 0.12)
            var radius := min(w, d) * rng.randf_range(0.22, 0.38)
            var pos := Vector3(cos(angle) * radius, 1.5, sin(angle) * radius)
            var dims := Vector3(rng.randf_range(2.0, 5.0), rng.randf_range(2.5, 6.0), rng.randf_range(2.0, 5.0))
            _box(root, "NaturalBlock_%02d" % [i + 1], pos, dims, true)
        return
    for i in count:
        var x := rng.randf_range(-w * 0.36, w * 0.36)
        var z := rng.randf_range(-d * 0.36, d * 0.36)
        var horizontal := rng.randf() > 0.5
        var dims := Vector3(rng.randf_range(5.0, 13.0), rng.randf_range(1.5, 3.0), 1.0) if horizontal else Vector3(1.0, rng.randf_range(1.5, 3.0), rng.randf_range(5.0, 13.0))
        _box(root, "RuinedWall_%02d" % [i + 1], Vector3(x, dims.y * 0.5, z), dims, true)

static func _generate_platforms(root: Node3D, count: int, w: float, d: float, levels: int, profile: String, rng: RandomNumberGenerator) -> void:
    for i in count:
        var level := 1 + (i % max(1, levels - 1))
        var y := float(level) * 2.5
        var x := rng.randf_range(-w * 0.28, w * 0.28)
        var z := rng.randf_range(-d * 0.28, d * 0.28)
        if profile in ["boss_ascent", "vertical_landmark"]:
            x = rng.randf_range(-7.0, 7.0)
            z = lerp(d * 0.26, -d * 0.26, float(i) / max(1.0, float(count - 1)))
        _box(root, "Platform_%02d" % [i + 1], Vector3(x, y, z), Vector3(rng.randf_range(6.0, 12.0), 0.6, rng.randf_range(5.0, 10.0)), true)

static func _generate_landmark(root: Node3D, landmark: String, profile: String) -> void:
    if landmark == "":
        return
    var dims := Vector3(8.0, 8.0, 8.0)
    if profile in ["vertical_landmark", "boss_ascent"]:
        dims = Vector3(9.0, 16.0, 9.0)
    elif profile in ["large_interior", "ruined_interior"]:
        dims = Vector3(14.0, 8.0, 10.0)
    elif profile in ["secret_clearing", "open_graveyard"]:
        dims = Vector3(6.0, 5.0, 6.0)
    _box(root, "Landmark_%s" % landmark, Vector3(0.0, dims.y * 0.5, -4.0), dims, false)

static func _box(parent: Node3D, name_value: String, pos: Vector3, size: Vector3, collision_enabled: bool) -> void:
    var root := Node3D.new()
    root.name = name_value
    root.position = pos
    parent.add_child(root)
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

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
