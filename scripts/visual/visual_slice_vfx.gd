class_name VisualSliceVFX
extends Node3D

signal effect_spawned(effect_id: String, world_position: Vector3)

const EFFECT_IDS := [
    "sword_impact",
    "ash_step_puff",
    "subtle_attack_trail",
    "metal_sparks",
    "restrained_blood",
    "lantern_light"
]

func spawn(effect_id: String, world_position: Vector3, direction: Vector3 = Vector3.UP) -> Node3D:
    if effect_id not in EFFECT_IDS:
        return null
    var root := Node3D.new()
    root.name = "VFX_" + effect_id
    root.global_position = world_position
    add_child(root)
    match effect_id:
        "lantern_light":
            _build_lantern(root)
        "ash_step_puff":
            _build_particles(root, Color(0.26, 0.24, 0.22, 0.45), 0.09, 14, 0.45, direction)
        "sword_impact":
            _build_particles(root, Color(0.75, 0.55, 0.34, 0.85), 0.055, 16, 0.3, direction)
        "metal_sparks":
            _build_particles(root, Color(0.95, 0.64, 0.28, 0.9), 0.025, 22, 0.28, direction)
        "restrained_blood":
            _build_particles(root, Color(0.28, 0.025, 0.02, 0.75), 0.045, 10, 0.34, direction)
        "subtle_attack_trail":
            _build_trail(root, direction)
    effect_spawned.emit(effect_id, world_position)
    if effect_id != "lantern_light":
        get_tree().create_timer(0.8).timeout.connect(root.queue_free)
    return root

func _build_particles(root: Node3D, color: Color, size: float, amount: int, lifetime: float, direction: Vector3) -> void:
    var particles := GPUParticles3D.new()
    particles.amount = amount
    particles.lifetime = lifetime
    particles.one_shot = true
    particles.explosiveness = 0.88
    var draw_mesh := SphereMesh.new()
    draw_mesh.radius = size
    draw_mesh.height = size * 2.0
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    draw_mesh.material = mat
    particles.draw_pass_1 = draw_mesh
    var process := ParticleProcessMaterial.new()
    process.direction = direction.normalized()
    process.spread = 48.0
    process.initial_velocity_min = 0.7
    process.initial_velocity_max = 2.3
    process.gravity = Vector3(0, -3.4, 0)
    process.scale_min = 0.6
    process.scale_max = 1.2
    particles.process_material = process
    root.add_child(particles)
    particles.emitting = true

func _build_trail(root: Node3D, direction: Vector3) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := QuadMesh.new()
    mesh.size = Vector2(0.55, 0.08)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.7, 0.62, 0.5, 0.22)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mesh.material = mat
    mesh_instance.mesh = mesh
    mesh_instance.look_at_from_position(Vector3.ZERO, direction.normalized(), Vector3.UP)
    root.add_child(mesh_instance)

func _build_lantern(root: Node3D) -> void:
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.42, 0.16)
    light.light_energy = 0.75
    light.omni_range = 2.8
    light.shadow_enabled = false
    root.add_child(light)
