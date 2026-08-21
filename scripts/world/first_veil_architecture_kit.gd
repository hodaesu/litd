extends RefCounted

const KIT_PATH := "res://data/roguelike/first_veil_architecture_kit.json"

var kit: Dictionary = {}

func _init() -> void:
    _load_kit()

func _load_kit() -> void:
    kit = {}
    if not FileAccess.file_exists(KIT_PATH):
        push_error("FirstVeilArchitectureKit: kit introuvable")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        kit = parsed
    else:
        push_error("FirstVeilArchitectureKit: kit invalide")

func decorate(parent: Node3D, room_spec: Dictionary) -> Dictionary:
    if parent == null or room_spec.is_empty() or kit.is_empty():
        return {}
    var dimensions: Vector3 = room_spec.get("dimensions_m", Vector3(12.0, 5.0, 10.0))
    var proxy: Dictionary = room_spec.get("proxy", {})
    var role: String = str(proxy.get("role", "support"))
    var palier: int = int(room_spec.get("palier", room_spec.get("depth", 1)))
    var recipe: Dictionary = (kit.get("role_recipes", {}) as Dictionary).get(role, {}).duplicate(true)
    if recipe.is_empty():
        recipe = (kit.get("role_recipes", {}) as Dictionary).get("support", {}).duplicate(true)

    var root := Node3D.new()
    root.name = "ArchitectureKit"
    root.set_meta("room_module", str(room_spec.get("blender_module_id", "")))
    root.set_meta("kit_version", int(kit.get("version", 1)))
    parent.add_child(root)

    _add_perimeter_language(root, dimensions, role)
    _add_role_props(root, dimensions, role, recipe)
    _add_room_lighting(root, dimensions, role, palier, recipe)
    _add_variant_landmark(root, room_spec, dimensions)

    return {
        "role": role,
        "module": str(room_spec.get("blender_module_id", "")),
        "prop_count": root.get_child_count(),
        "palier": palier,
        "kit_version": int(kit.get("version", 1))
    }

func _add_perimeter_language(root: Node3D, dimensions: Vector3, role: String) -> void:
    var pillar_count: int = 4 if role in ["elite", "preboss", "boss"] else 2
    for i in range(pillar_count):
        var x_sign: float = -1.0 if i % 2 == 0 else 1.0
        var z_sign: float = -1.0 if i < 2 else 1.0
        var position_value := Vector3(
            x_sign * maxf(1.5, dimensions.x * 0.34),
            1.4,
            z_sign * maxf(1.5, dimensions.z * 0.32)
        )
        _add_cylinder(root, "Pillar_%d" % i, 0.42 if role != "boss" else 0.65, 2.8 if role != "boss" else 4.2, position_value, true, "stone")

    # Lintel/relief slabs make the room read as architecture rather than a grey box.
    _add_box(root, "Relief_North", Vector3(minf(6.0, dimensions.x * 0.55), 0.65, 0.28), Vector3(0.0, dimensions.y * 0.68, -dimensions.z * 0.5 + 0.3), false, "ritual")
    _add_box(root, "Relief_South", Vector3(minf(6.0, dimensions.x * 0.55), 0.65, 0.28), Vector3(0.0, dimensions.y * 0.68, dimensions.z * 0.5 - 0.3), false, "stone")

func _add_role_props(root: Node3D, dimensions: Vector3, role: String, recipe: Dictionary) -> void:
    var tombs: int = int(recipe.get("tombs", 0))
    for i in range(tombs):
        var x: float = (-1.0 if i % 2 == 0 else 1.0) * dimensions.x * 0.28
        var z: float = -dimensions.z * 0.08 + float(i / 2) * 2.2
        _add_box(root, "Sarcophagus_%d" % i, Vector3(2.3, 0.8, 1.1), Vector3(x, 0.4, z), true, "bone")

    var chains: int = int(recipe.get("chains", 0))
    for i in range(chains):
        var ratio: float = (float(i + 1) / float(chains + 1)) - 0.5
        _add_cylinder(root, "Chain_%d" % i, 0.08, maxf(1.8, dimensions.y * 0.55), Vector3(ratio * dimensions.x * 0.7, dimensions.y * 0.7, dimensions.z * 0.1), false, "metal")

    var altars: int = int(recipe.get("altars", 0))
    for i in range(altars):
        _add_box(root, "Altar_%d" % i, Vector3(2.5, 1.0, 1.4), Vector3(0.0, 0.5, dimensions.z * 0.24 + float(i) * 1.8), true, "ritual")

    var traps: int = int(recipe.get("traps", 0))
    for i in range(traps):
        var lane: float = (float(i) - float(traps - 1) * 0.5) * 1.6
        _add_box(root, "TrapPlate_%d" % i, Vector3(1.2, 0.08, 1.2), Vector3(lane, 0.04, 0.4), false, "metal")

    var furniture: int = int(recipe.get("furniture", 0))
    for i in range(furniture):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var z_value: float = -dimensions.z * 0.18 + float(i / 2) * 2.0
        _add_box(root, "Furniture_%d" % i, Vector3(1.8, 0.8, 0.8), Vector3(side * dimensions.x * 0.27, 0.4, z_value), true, "cloth" if role == "support" else "stone")

    var debris: int = int(recipe.get("debris", 0))
    for i in range(debris):
        var x_pos: float = -dimensions.x * 0.3 + float(i) * 1.35
        _add_box(root, "Debris_%d" % i, Vector3(0.7 + 0.15 * (i % 2), 0.35, 0.55), Vector3(x_pos, 0.18, -dimensions.z * 0.28), false, "ash")

    if role == "hazard":
        _add_box(root, "HazardChannel", Vector3(maxf(2.5, dimensions.x * 0.35), 0.12, maxf(3.0, dimensions.z * 0.45)), Vector3(0.0, 0.06, 0.0), false, "ritual")
    elif role == "boss":
        _add_box(root, "BossDais", Vector3(7.0, 0.65, 4.5), Vector3(0.0, 0.32, dimensions.z * 0.22), true, "ritual")
        _add_box(root, "BossAltar", Vector3(3.6, 1.5, 1.8), Vector3(0.0, 0.75, dimensions.z * 0.28), true, "bone")
    elif role == "preboss":
        _add_box(root, "GateThreshold", Vector3(5.0, 0.25, 2.0), Vector3(0.0, 0.12, dimensions.z * 0.24), false, "ritual")

func _add_room_lighting(root: Node3D, dimensions: Vector3, role: String, palier: int, recipe: Dictionary) -> void:
    var tuning: Dictionary = (kit.get("depth_tuning", {}) as Dictionary).get(str(clampi(palier, 0, 4)), {})
    var multiplier: float = float(tuning.get("light_count_multiplier", 1.0))
    var target_count: int = maxi(1, int(round(float(recipe.get("lights", 2)) * multiplier)))
    for i in range(target_count):
        var angle: float = TAU * float(i) / float(target_count)
        var radius_x: float = maxf(2.0, dimensions.x * 0.32)
        var radius_z: float = maxf(2.0, dimensions.z * 0.3)
        var position_value := Vector3(cos(angle) * radius_x, minf(2.7, dimensions.y * 0.55), sin(angle) * radius_z)
        var lamp_root := Node3D.new()
        lamp_root.name = "Lamp_%d" % i
        lamp_root.position = position_value
        root.add_child(lamp_root)
        _add_box(lamp_root, "Fixture", Vector3(0.32, 0.55, 0.32), Vector3.ZERO, false, "metal")
        var light := OmniLight3D.new()
        light.name = "Light"
        light.omni_range = 6.5 if role != "boss" else 9.0
        light.light_energy = 1.25 if palier <= 1 else 0.9
        light.shadow_enabled = i < 2
        lamp_root.add_child(light)

func _add_variant_landmark(root: Node3D, room_spec: Dictionary, dimensions: Vector3) -> void:
    var variant: String = str(room_spec.get("variant", "standard"))
    var landmark := Node3D.new()
    landmark.name = "Variant_%s" % variant
    landmark.set_meta("variant_id", variant)
    root.add_child(landmark)
    if "chain" in variant or "chaine" in variant:
        _add_cylinder(landmark, "VariantChain", 0.12, maxf(2.0, dimensions.y * 0.65), Vector3(0.0, dimensions.y * 0.65, 0.0), false, "metal")
    elif "autel" in variant or "altar" in variant:
        _add_box(landmark, "VariantAltar", Vector3(3.0, 1.2, 1.6), Vector3(0.0, 0.6, 1.0), true, "ritual")
    elif "coffre" in variant or "chest" in variant:
        _add_box(landmark, "VariantChest", Vector3(1.5, 0.9, 0.9), Vector3(0.0, 0.45, 1.3), true, "bone")
    elif "statue" in variant:
        _add_cylinder(landmark, "VariantStatue", 0.55, 3.2, Vector3(0.0, 1.6, dimensions.z * 0.25), true, "stone")
    else:
        _add_box(landmark, "VariantLandmark", Vector3(2.0, 0.45, 1.0), Vector3(0.0, 0.22, dimensions.z * 0.18), false, "ash")

func _add_box(parent: Node3D, node_name: String, size: Vector3, position_value: Vector3, collidable: bool, material_key: String) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.position = position_value
    parent.add_child(root)
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _material(material_key)
    root.add_child(mesh_instance)
    if collidable:
        var body := StaticBody3D.new()
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
        root.add_child(body)
    return root

func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position_value: Vector3, collidable: bool, material_key: String) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.position = position_value
    parent.add_child(root)
    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _material(material_key)
    root.add_child(mesh_instance)
    if collidable:
        var body := StaticBody3D.new()
        var collision := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        collision.shape = shape
        body.add_child(collision)
        root.add_child(body)
    return root

func _material(key: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    var palette: Dictionary = kit.get("palette", {})
    var raw: Array = palette.get(key, [0.4, 0.4, 0.4, 1.0])
    if raw.size() >= 4:
        material.albedo_color = Color(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
    material.roughness = 0.84 if key != "metal" else 0.46
    material.metallic = 0.75 if key == "metal" else 0.05
    return material

func blender_contract() -> Dictionary:
    return (kit.get("blender_contract", {}) as Dictionary).duplicate(true)

func role_recipe(role: String) -> Dictionary:
    return ((kit.get("role_recipes", {}) as Dictionary).get(role, {}) as Dictionary).duplicate(true)
