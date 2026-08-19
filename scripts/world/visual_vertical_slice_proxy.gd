extends Node3D

const CONTRACT_PATH := "res://data/visual_vertical_slice.json"
const CEL_SHADER_PATH := "res://shaders/litd_cel.gdshader"

var contract: Dictionary = {}
var _cel_shader: Shader
var _headless_rendering: bool = false

func _ready() -> void:
    contract = _load_json(CONTRACT_PATH)
    _cel_shader = load(CEL_SHADER_PATH) as Shader
    _headless_rendering = DisplayServer.get_name() == "headless"
    _build_arena()
    _build_darius_proxy()
    _build_ghoul_proxy()
    _build_lighting()
    _build_camera()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("VisualVerticalSliceProxy: missing contract " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed is Dictionary:
        return parsed
    push_error("VisualVerticalSliceProxy: invalid JSON contract")
    return {}

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.85, rim: float = 0.16) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = _cel_shader
    material.set_shader_parameter("base_color", color)
    material.set_shader_parameter("metallic_value", metallic)
    material.set_shader_parameter("roughness_value", roughness)
    material.set_shader_parameter("rim_amount", rim)
    material.set_shader_parameter("rim_tint", 0.7)
    return material

func _semantic_part(parent: Node3D, part_name: String, local_position: Vector3, rotation_deg: Vector3) -> Node3D:
    var marker := Node3D.new()
    marker.name = part_name
    marker.position = local_position
    marker.rotation_degrees = rotation_deg
    parent.add_child(marker)
    return marker

func _box_part(parent: Node3D, part_name: String, size: Vector3, local_position: Vector3, material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> Node3D:
    if _headless_rendering:
        return _semantic_part(parent, part_name, local_position, rotation_deg)
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var box := BoxMesh.new()
    box.size = size
    instance.mesh = box
    instance.position = local_position
    instance.rotation_degrees = rotation_deg
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _sphere_part(parent: Node3D, part_name: String, radius: float, local_position: Vector3, material: Material) -> Node3D:
    if _headless_rendering:
        return _semantic_part(parent, part_name, local_position, Vector3.ZERO)
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var sphere := SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    instance.mesh = sphere
    instance.position = local_position
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _capsule_part(parent: Node3D, part_name: String, radius: float, height: float, local_position: Vector3, material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> Node3D:
    if _headless_rendering:
        return _semantic_part(parent, part_name, local_position, rotation_deg)
    var instance := MeshInstance3D.new()
    instance.name = part_name
    var capsule := CapsuleMesh.new()
    capsule.radius = radius
    capsule.height = height
    instance.mesh = capsule
    instance.position = local_position
    instance.rotation_degrees = rotation_deg
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _build_darius_proxy() -> void:
    var root := Node3D.new()
    root.name = "DariusProxy"
    root.position = Vector3(-2.0, 0.0, 0.0)
    add_child(root)

    var cloth := _material(Color(0.075, 0.07, 0.08), 0.0, 0.94, 0.2)
    var metal := _material(Color(0.15, 0.16, 0.17), 0.62, 0.6, 0.24)
    var skin := _material(Color(0.38, 0.29, 0.26), 0.0, 0.82, 0.14)
    var warm := _material(Color(0.45, 0.16, 0.045), 0.15, 0.62, 0.3)

    _capsule_part(root, "BodyMass", 0.34, 1.34, Vector3(0, 1.02, 0), cloth)
    _box_part(root, "LamellarChest", Vector3(0.82, 0.78, 0.36), Vector3(0, 1.18, 0), metal)
    _sphere_part(root, "Head", 0.22, Vector3(0, 1.82, 0), skin)
    _box_part(root, "Helmet", Vector3(0.5, 0.22, 0.48), Vector3(0, 1.99, 0), metal)
    _box_part(root, "Shield", Vector3(0.12, 1.12, 0.78), Vector3(-0.58, 1.03, 0.05), metal, Vector3(0, 0, -5))
    _box_part(root, "SwordBlade", Vector3(0.08, 0.92, 0.07), Vector3(0.56, 0.91, 0.02), metal, Vector3(0, 0, -12))
    _box_part(root, "SwordHilt", Vector3(0.3, 0.07, 0.08), Vector3(0.47, 0.52, 0.02), warm)
    _box_part(root, "Lantern", Vector3(0.22, 0.3, 0.22), Vector3(0.42, 0.92, 0.34), warm)
    _box_part(root, "LayeredCloth", Vector3(0.62, 0.72, 0.18), Vector3(0, 0.42, 0.08), cloth)

func _build_ghoul_proxy() -> void:
    var root := Node3D.new()
    root.name = "HungryGhoulProxy"
    root.position = Vector3(2.0, 0.0, 0.3)
    root.rotation_degrees = Vector3(0, -12, 0)
    add_child(root)

    var skin := _material(Color(0.31, 0.29, 0.25), 0.0, 0.92, 0.1)
    var cloth := _material(Color(0.065, 0.06, 0.065), 0.0, 0.98, 0.14)
    var bone := _material(Color(0.48, 0.43, 0.32), 0.0, 0.84, 0.12)

    _capsule_part(root, "HunchedTorso", 0.27, 1.05, Vector3(0, 0.92, 0), skin, Vector3(18, 0, 0))
    _sphere_part(root, "ForwardHead", 0.2, Vector3(0, 1.43, -0.18), skin)
    _capsule_part(root, "ArmLeft", 0.095, 0.92, Vector3(-0.38, 0.85, -0.08), skin, Vector3(12, 0, -18))
    _capsule_part(root, "ArmRight", 0.095, 0.92, Vector3(0.38, 0.85, -0.08), skin, Vector3(12, 0, 18))
    _box_part(root, "ClawLeft", Vector3(0.12, 0.32, 0.18), Vector3(-0.5, 0.42, -0.12), bone, Vector3(12, 0, -18))
    _box_part(root, "ClawRight", Vector3(0.12, 0.32, 0.18), Vector3(0.5, 0.42, -0.12), bone, Vector3(12, 0, 18))
    _box_part(root, "RaggedCloth", Vector3(0.5, 0.5, 0.16), Vector3(0, 0.46, 0.05), cloth)

func _build_arena() -> void:
    var arena := Node3D.new()
    arena.name = "AshlandsArenaProxy"
    add_child(arena)

    var ash := _material(Color(0.085, 0.08, 0.085), 0.0, 1.0, 0.08)
    var stone := _material(Color(0.16, 0.15, 0.145), 0.0, 0.96, 0.11)
    var wood := _material(Color(0.09, 0.055, 0.035), 0.0, 0.94, 0.08)

    _box_part(arena, "AshGround", Vector3(20.0, 0.18, 30.0), Vector3(0, -0.1, 0), ash)
    _box_part(arena, "BrokenStepA", Vector3(4.2, 0.25, 1.4), Vector3(0, 0.12, -5.8), stone)
    _box_part(arena, "BrokenStepB", Vector3(3.4, 0.22, 1.1), Vector3(0.6, 0.33, -6.5), stone)
    _box_part(arena, "RuinedGateTop", Vector3(6.4, 0.6, 0.7), Vector3(0, 4.2, -9.0), wood)
    _box_part(arena, "RuinedGateLeft", Vector3(0.65, 4.2, 0.65), Vector3(-2.6, 2.05, -9.0), wood)
    _box_part(arena, "RuinedGateRight", Vector3(0.65, 3.25, 0.65), Vector3(2.6, 1.6, -9.0), wood, Vector3(0, 0, 5))
    _box_part(arena, "PillarLeft", Vector3(0.58, 3.1, 0.58), Vector3(-5.6, 1.5, -1.8), stone, Vector3(0, 0, -4))
    _box_part(arena, "PillarRight", Vector3(0.58, 2.7, 0.58), Vector3(5.5, 1.3, -1.0), stone, Vector3(0, 0, 7))
    _box_part(arena, "BannerMass", Vector3(0.9, 2.1, 0.06), Vector3(-2.4, 2.6, -8.6), _material(Color(0.19, 0.045, 0.035), 0.0, 0.95, 0.1), Vector3(0, 0, 3))

func _build_lighting() -> void:
    var moon := DirectionalLight3D.new()
    moon.name = "CoolMoonKey"
    moon.light_color = Color(0.48, 0.57, 0.68)
    moon.light_energy = 1.25
    moon.rotation_degrees = Vector3(-52, -28, 0)
    moon.shadow_enabled = true
    add_child(moon)

    var warm := OmniLight3D.new()
    warm.name = "WarmLanternAccent"
    warm.light_color = Color(1.0, 0.42, 0.16)
    warm.light_energy = 2.2
    warm.omni_range = 5.5
    warm.position = Vector3(-1.45, 1.25, 0.5)
    add_child(warm)

func _build_camera() -> void:
    var camera := Camera3D.new()
    camera.name = "CombatCamera"
    var camera_data: Dictionary = contract.get("camera", {})
    camera.fov = float(camera_data.get("fov_degrees", 42.0))
    camera.position = Vector3(8.5, 7.2, 10.5)
    add_child(camera)
    camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
