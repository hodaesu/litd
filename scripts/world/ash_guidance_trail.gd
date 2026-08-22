extends Node3D
class_name AshGuidanceTrail

signal guidance_changed(snapshot: Dictionary)

const POLICY_SCRIPT := preload("res://scripts/core/ash_guidance_policy.gd")

var objective_kind: String = ""
var target_node: Node3D = null
var target_world_position: Vector3 = Vector3.ZERO
var has_position_target: bool = false
var max_distance_m: float = -1.0
var proximity_override: float = -1.0
var current_proximity: float = 0.0
var current_color: Color = Color(0.52, 0.53, 0.55)
var current_direction: Vector3 = Vector3(0.0, 0.0, -1.0)

var _policy: AshGuidancePolicy
var _config: Dictionary = {}
var _wisps: GPUParticles3D = null
var _motes: GPUParticles3D = null
var _wisp_process: ParticleProcessMaterial = null
var _mote_process: ParticleProcessMaterial = null
var _wisp_material: StandardMaterial3D = null
var _mote_material: StandardMaterial3D = null

func _ready() -> void:
    _policy = POLICY_SCRIPT.new() as AshGuidancePolicy
    _config = _policy.config if _policy != null else {}
    _build_particle_layers()
    set_process(true)
    _set_emitting(false)

func guide_to_node(node: Node3D, kind: String, distance_override: float = -1.0, route_proximity: float = -1.0) -> void:
    target_node = node
    has_position_target = false
    objective_kind = _sanitize_kind(kind)
    max_distance_m = distance_override
    proximity_override = route_proximity
    _set_emitting(target_node != null and objective_kind != "")
    guidance_changed.emit(snapshot())

func guide_to_world_position(world_position: Vector3, kind: String, distance_override: float = -1.0, route_proximity: float = -1.0) -> void:
    target_node = null
    target_world_position = world_position
    has_position_target = true
    objective_kind = _sanitize_kind(kind)
    max_distance_m = distance_override
    proximity_override = route_proximity
    _set_emitting(objective_kind != "")
    guidance_changed.emit(snapshot())

func clear_guidance() -> void:
    target_node = null
    has_position_target = false
    objective_kind = ""
    proximity_override = -1.0
    current_proximity = 0.0
    _set_emitting(false)
    guidance_changed.emit(snapshot())

func _sanitize_kind(kind: String) -> String:
    return kind if kind in ["boss", "quest"] else ""

func _process(delta: float) -> void:
    if objective_kind == "" or (target_node == null and not has_position_target):
        _set_emitting(false)
        return
    if target_node != null and not is_instance_valid(target_node):
        clear_guidance()
        return

    var target: Vector3 = target_node.global_position if target_node != null else target_world_position
    var offset: Vector3 = target - global_position
    var flat_direction := Vector3(offset.x, 0.0, offset.z)
    var particle_rules: Dictionary = _config.get("particles", {})
    var minimum_distance: float = float(particle_rules.get("minimum_direction_distance", 0.25))
    if flat_direction.length() > minimum_distance:
        var desired: Vector3 = flat_direction.normalized()
        var direction_speed: float = maxf(0.1, float(particle_rules.get("direction_smoothing", 8.0)))
        current_direction = current_direction.slerp(desired, clampf(delta * direction_speed, 0.0, 1.0)).normalized()
        look_at(global_position + current_direction, Vector3.UP)

    var raw_proximity: float = proximity_override
    if raw_proximity < 0.0 and _policy != null:
        raw_proximity = _policy.proximity_for_distance(offset.length(), max_distance_m)
    raw_proximity = clampf(raw_proximity, 0.0, 1.0)
    current_proximity = lerpf(current_proximity, raw_proximity, clampf(delta * float(particle_rules.get("color_smoothing", 5.0)), 0.0, 1.0))
    _apply_visual_state()
    _set_emitting(true)

func _build_particle_layers() -> void:
    var particle_rules: Dictionary = _config.get("particles", {})
    var spawn_height: float = float(particle_rules.get("spawn_height", 0.55))
    var lifetime: float = float(particle_rules.get("lifetime_s", 1.8))

    _wisp_process = ParticleProcessMaterial.new()
    _wisp_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    _wisp_process.emission_box_extents = Vector3(0.65, 0.30, 0.45)
    _wisp_process.direction = Vector3(0.0, 0.18, -1.0)
    _wisp_process.spread = 26.0
    _wisp_process.gravity = Vector3(0.0, 0.75, 0.0)
    _wisp_process.initial_velocity_min = float(particle_rules.get("base_speed", 2.6))
    _wisp_process.initial_velocity_max = float(particle_rules.get("base_speed", 2.6)) + 1.0
    _wisp_process.angular_velocity_min = -125.0
    _wisp_process.angular_velocity_max = 125.0
    _wisp_process.scale_min = 0.55
    _wisp_process.scale_max = 1.35

    _wisp_material = _particle_material(0.10, false)
    var wisp_mesh := QuadMesh.new()
    wisp_mesh.size = Vector2(0.13, 0.13)
    wisp_mesh.material = _wisp_material

    _wisps = GPUParticles3D.new()
    _wisps.name = "AshWisps"
    _wisps.position = Vector3(0.0, spawn_height, 0.0)
    _wisps.amount = int(particle_rules.get("wisps", 34))
    _wisps.lifetime = lifetime
    _wisps.randomness = 0.42
    _wisps.local_coords = false
    _wisps.visibility_aabb = AABB(Vector3(-8.0, -2.0, -10.0), Vector3(16.0, 8.0, 20.0))
    _wisps.process_material = _wisp_process
    _wisps.draw_pass_1 = wisp_mesh
    add_child(_wisps)

    _mote_process = ParticleProcessMaterial.new()
    _mote_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    _mote_process.emission_box_extents = Vector3(0.48, 0.38, 0.38)
    _mote_process.direction = Vector3(0.0, 0.34, -1.0)
    _mote_process.spread = 48.0
    _mote_process.gravity = Vector3(0.0, 1.05, 0.0)
    _mote_process.initial_velocity_min = 1.3
    _mote_process.initial_velocity_max = 2.6
    _mote_process.angular_velocity_min = -220.0
    _mote_process.angular_velocity_max = 220.0
    _mote_process.scale_min = 0.32
    _mote_process.scale_max = 0.78

    _mote_material = _particle_material(0.065, true)
    var mote_mesh := QuadMesh.new()
    mote_mesh.size = Vector2(0.07, 0.07)
    mote_mesh.material = _mote_material

    _motes = GPUParticles3D.new()
    _motes.name = "AshMotes"
    _motes.position = Vector3(0.0, spawn_height + 0.08, 0.0)
    _motes.amount = int(particle_rules.get("motes", 20))
    _motes.lifetime = lifetime * 0.82
    _motes.randomness = 0.58
    _motes.local_coords = false
    _motes.visibility_aabb = AABB(Vector3(-7.0, -2.0, -9.0), Vector3(14.0, 8.0, 18.0))
    _motes.process_material = _mote_process
    _motes.draw_pass_1 = mote_mesh
    add_child(_motes)

func _particle_material(alpha: float, incandescent: bool) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.albedo_color = Color(current_color.r, current_color.g, current_color.b, alpha)
    material.emission_enabled = incandescent
    if incandescent:
        material.emission = current_color
        material.emission_energy_multiplier = 1.8
    return material

func _apply_visual_state() -> void:
    if _policy == null:
        return
    current_color = _policy.color_for(objective_kind, current_proximity)
    var emission_color: Color = _policy.emission_color_for(objective_kind, current_proximity)
    if _wisp_process != null:
        _wisp_process.color = Color(current_color.r, current_color.g, current_color.b, 0.78)
    if _mote_process != null:
        _mote_process.color = Color(emission_color.r, emission_color.g, emission_color.b, 0.92)
    if _wisp_material != null:
        _wisp_material.albedo_color = Color(current_color.r, current_color.g, current_color.b, 0.30)
    if _mote_material != null:
        _mote_material.albedo_color = Color(emission_color.r, emission_color.g, emission_color.b, 0.72)
        _mote_material.emission = emission_color
        _mote_material.emission_energy_multiplier = 1.0 + current_proximity * (2.4 if objective_kind == "boss" else 1.5)

    var particle_rules: Dictionary = _config.get("particles", {})
    var base_speed: float = float(particle_rules.get("base_speed", 2.6))
    var speed_bonus: float = float(particle_rules.get("near_speed_bonus", 2.2)) * current_proximity
    if _wisp_process != null:
        _wisp_process.initial_velocity_min = base_speed + speed_bonus
        _wisp_process.initial_velocity_max = base_speed + 1.0 + speed_bonus
    if _mote_process != null:
        _mote_process.initial_velocity_min = 1.3 + current_proximity * 0.8
        _mote_process.initial_velocity_max = 2.6 + speed_bonus * 0.55
    if _motes != null:
        var base_amount: int = int(particle_rules.get("motes", 20))
        var bonus: int = int(round(current_proximity * (14.0 if objective_kind == "boss" else 7.0)))
        _motes.amount = base_amount + bonus

func _set_emitting(value: bool) -> void:
    if _wisps != null:
        _wisps.emitting = value
    if _motes != null:
        _motes.emitting = value

func snapshot() -> Dictionary:
    return {
        "objective_kind": objective_kind,
        "has_target": target_node != null or has_position_target,
        "proximity": current_proximity,
        "color": current_color,
        "direction": current_direction,
        "wisps_emitting": _wisps != null and _wisps.emitting,
        "motes_emitting": _motes != null and _motes.emitting,
        "mote_count": _motes.amount if _motes != null else 0
    }
