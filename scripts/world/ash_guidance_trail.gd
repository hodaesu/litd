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

var current_fear: float = 0.0
var current_danger: float = 0.0
var current_safety: float = 0.0
var emotional_mode: String = "steady"
var environment_danger_floor: float = 0.0
var environment_safety: float = 0.0
var fear_override: float = -1.0
var danger_override: float = -1.0
var safety_override: float = -1.0
var danger_burst: float = 0.0

var _policy: AshGuidancePolicy
var _config: Dictionary = {}
var _wisps: GPUParticles3D = null
var _motes: GPUParticles3D = null
var _wisp_process: ParticleProcessMaterial = null
var _mote_process: ParticleProcessMaterial = null
var _wisp_material: StandardMaterial3D = null
var _mote_material: StandardMaterial3D = null
var _emotion_time: float = 0.0
var reveal_time_remaining: float = 0.0
var reveal_duration_s: float = 3.5

func _ready() -> void:
    _policy = POLICY_SCRIPT.new() as AshGuidancePolicy
    _config = _policy.config if _policy != null else {}
    _build_particle_layers()
    var activation: Dictionary = _config.get("activation", {})
    reveal_duration_s = maxf(0.1, float(activation.get("visible_duration_s", 3.5)))
    set_process(true)
    _set_emitting(false)

func guide_to_node(node: Node3D, kind: String, distance_override: float = -1.0, route_proximity: float = -1.0) -> void:
    target_node = node
    has_position_target = false
    objective_kind = _sanitize_kind(kind)
    max_distance_m = distance_override
    proximity_override = route_proximity
    _set_emitting(false)
    guidance_changed.emit(snapshot())

func guide_to_world_position(world_position: Vector3, kind: String, distance_override: float = -1.0, route_proximity: float = -1.0) -> void:
    target_node = null
    target_world_position = world_position
    has_position_target = true
    objective_kind = _sanitize_kind(kind)
    max_distance_m = distance_override
    proximity_override = route_proximity
    _set_emitting(false)
    guidance_changed.emit(snapshot())

func request_guidance(duration_override: float = -1.0) -> bool:
    if objective_kind == "" or (target_node == null and not has_position_target):
        hide_guidance()
        return false
    reveal_time_remaining = duration_override if duration_override > 0.0 else reveal_duration_s
    _set_emitting(true)
    guidance_changed.emit(snapshot())
    return true

func hide_guidance() -> void:
    reveal_time_remaining = 0.0
    _set_emitting(false)
    guidance_changed.emit(snapshot())

func is_guidance_revealed() -> bool:
    return reveal_time_remaining > 0.0

func set_environment_context(danger_floor: float, safety: float) -> void:
    environment_danger_floor = clampf(danger_floor, 0.0, 1.0)
    environment_safety = clampf(safety, 0.0, 1.0)

func configure_environment_for_room(role: String, room_type: String) -> void:
    var environment_rules: Dictionary = _config.get("environment_context", {})
    var danger_by_role: Dictionary = environment_rules.get("danger_floor_by_role", {})
    var safety_by_type: Dictionary = environment_rules.get("safety_by_room_type", {})
    var danger_floor: float = float(danger_by_role.get(role, danger_by_role.get("generic", 0.18)))
    var safety: float = float(safety_by_type.get(room_type, 0.0))
    set_environment_context(danger_floor, safety)

func set_emotional_context(fear: float = -1.0, danger: float = -1.0, safety: float = -1.0) -> void:
    fear_override = clampf(fear, 0.0, 1.0) if fear >= 0.0 else -1.0
    danger_override = clampf(danger, 0.0, 1.0) if danger >= 0.0 else -1.0
    safety_override = clampf(safety, 0.0, 1.0) if safety >= 0.0 else -1.0

func clear_emotional_overrides() -> void:
    fear_override = -1.0
    danger_override = -1.0
    safety_override = -1.0

func clear_guidance() -> void:
    target_node = null
    has_position_target = false
    objective_kind = ""
    proximity_override = -1.0
    current_proximity = 0.0
    reveal_time_remaining = 0.0
    _set_emitting(false)
    guidance_changed.emit(snapshot())

func _sanitize_kind(kind: String) -> String:
    return kind if kind in ["boss", "quest"] else ""

func _process(delta: float) -> void:
    _emotion_time += delta
    _update_emotional_state(delta)
    if objective_kind == "" or (target_node == null and not has_position_target):
        _set_emitting(false)
        return
    if target_node != null and not is_instance_valid(target_node):
        clear_guidance()
        return
    if reveal_time_remaining <= 0.0:
        _set_emitting(false)
        return
    reveal_time_remaining = maxf(0.0, reveal_time_remaining - delta)
    if reveal_time_remaining <= 0.0:
        _set_emitting(false)
        guidance_changed.emit(snapshot())
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
    _update_emotional_state(delta)
    _apply_visual_state()
    _set_emitting(is_guidance_revealed())

func _update_emotional_state(delta: float) -> void:
    var emotion_rules: Dictionary = _config.get("emotion", {})
    var smoothing: float = maxf(0.1, float(emotion_rules.get("context_smoothing", 4.0)))
    var blend: float = clampf(delta * smoothing, 0.0, 1.0)

    var target_fear: float = fear_override if fear_override >= 0.0 else _party_fear()
    var target_danger: float = danger_override if danger_override >= 0.0 else maxf(environment_danger_floor, _runtime_danger())
    if objective_kind == "boss":
        target_danger = maxf(target_danger, current_proximity * float(emotion_rules.get("danger_from_boss_proximity", 0.88)))
    var target_safety: float = safety_override if safety_override >= 0.0 else environment_safety
    target_safety *= 1.0 - clampf(target_danger * 0.82, 0.0, 0.82)

    current_fear = lerpf(current_fear, clampf(target_fear, 0.0, 1.0), blend)
    current_danger = lerpf(current_danger, clampf(target_danger, 0.0, 1.0), blend)
    current_safety = lerpf(current_safety, clampf(target_safety, 0.0, 1.0), blend)
    _update_emotional_mode()
    danger_burst = _danger_burst_value()

func _party_fear() -> float:
    var total: float = 0.0
    var count: int = 0
    for hero_value: Variant in GameState.party:
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        total += clampf(float(hero.get("fear", 0)) / 100.0, 0.0, 1.0)
        count += 1
    return total / float(count) if count > 0 else 0.0

func _runtime_danger() -> float:
    var risk: Dictionary = ExpeditionManager.current_risk_profile()
    var multiplier: float = maxf(1.0, float(risk.get("danger_multiplier", 1.0)))
    var emotion_rules: Dictionary = _config.get("emotion", {})
    var span: float = maxf(0.1, float(emotion_rules.get("risk_multiplier_span", 1.25)))
    return clampf((multiplier - 1.0) / span, 0.0, 1.0)

func _update_emotional_mode() -> void:
    var emotion_rules: Dictionary = _config.get("emotion", {})
    var fear_rules: Dictionary = emotion_rules.get("fear", {})
    var danger_rules: Dictionary = emotion_rules.get("major_danger", {})
    var safe_rules: Dictionary = emotion_rules.get("safe", {})

    var danger_enter: float = float(danger_rules.get("enter", 0.72))
    var danger_exit: float = float(danger_rules.get("exit", 0.60))
    var fear_enter: float = float(fear_rules.get("enter", 0.48))
    var fear_exit: float = float(fear_rules.get("exit", 0.38))
    var safe_enter: float = float(safe_rules.get("enter", 0.68))
    var safe_exit: float = float(safe_rules.get("exit", 0.55))

    if emotional_mode == "danger" and current_danger >= danger_exit:
        return
    if current_danger >= danger_enter:
        emotional_mode = "danger"
        return
    if emotional_mode == "fearful" and current_fear >= fear_exit:
        return
    if current_fear >= fear_enter:
        emotional_mode = "fearful"
        return
    if emotional_mode == "safe" and current_safety >= safe_exit and current_danger < danger_enter:
        return
    if current_safety >= safe_enter and current_danger < danger_exit:
        emotional_mode = "safe"
        return
    emotional_mode = "steady"

func _danger_burst_value() -> float:
    if emotional_mode != "danger":
        return 0.0
    var danger_rules: Dictionary = (_config.get("emotion", {}) as Dictionary).get("major_danger", {})
    var hz: float = maxf(0.1, float(danger_rules.get("burst_hz", 0.82)))
    var wave: float = 0.5 + 0.5 * sin(TAU * hz * _emotion_time)
    return pow(wave, 7.0) * current_danger

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

    _apply_emotional_motion()

func _apply_emotional_motion() -> void:
    var particle_rules: Dictionary = _config.get("particles", {})
    var emotion_rules: Dictionary = _config.get("emotion", {})
    var fear_rules: Dictionary = emotion_rules.get("fear", {})
    var danger_rules: Dictionary = emotion_rules.get("major_danger", {})
    var safe_rules: Dictionary = emotion_rules.get("safe", {})

    var base_speed: float = float(particle_rules.get("base_speed", 2.6))
    var proximity_speed: float = float(particle_rules.get("near_speed_bonus", 2.2)) * current_proximity
    var wisp_speed: float = base_speed + proximity_speed
    var mote_speed: float = 1.3 + current_proximity * 0.8
    var wisp_spread: float = 26.0
    var mote_spread: float = 48.0
    var wisp_angular: float = 125.0
    var mote_angular: float = 220.0
    var lifetime_multiplier: float = 1.0
    var mote_multiplier: float = 1.0
    var extra_motes: int = int(round(current_proximity * (14.0 if objective_kind == "boss" else 7.0)))
    var side_bias: float = 0.0

    if emotional_mode == "fearful":
        var fear_strength: float = current_fear
        wisp_spread += float(fear_rules.get("max_spread_bonus_deg", 34.0)) * fear_strength
        mote_spread += float(fear_rules.get("max_spread_bonus_deg", 34.0)) * fear_strength * 0.72
        var angular_multiplier: float = lerpf(1.0, float(fear_rules.get("angular_velocity_multiplier", 1.55)), fear_strength)
        wisp_angular *= angular_multiplier
        mote_angular *= angular_multiplier
        extra_motes += int(round(float(fear_rules.get("mote_bonus", 10)) * fear_strength))
        var hesitation_hz: float = float(fear_rules.get("hesitation_hz", 1.65))
        side_bias = sin(TAU * hesitation_hz * _emotion_time) * float(fear_rules.get("max_side_bias", 0.28)) * fear_strength
    elif emotional_mode == "danger":
        var danger_strength: float = current_danger
        wisp_speed += float(danger_rules.get("speed_bonus", 3.0)) * danger_strength
        mote_speed += float(danger_rules.get("speed_bonus", 3.0)) * danger_strength * 0.65
        var burst_speed: float = float(danger_rules.get("burst_speed_bonus", 2.4)) * danger_burst
        wisp_speed += burst_speed
        mote_speed += burst_speed * 0.75
        var spread_reduction: float = float(danger_rules.get("forward_spread_reduction_deg", 10.0)) * danger_strength
        wisp_spread = maxf(8.0, wisp_spread - spread_reduction)
        mote_spread = maxf(16.0, mote_spread - spread_reduction * 1.4)
        lifetime_multiplier = lerpf(1.0, float(danger_rules.get("lifetime_multiplier", 0.78)), danger_strength)
        extra_motes += int(round(float(danger_rules.get("burst_mote_bonus", 18)) * danger_burst))
    elif emotional_mode == "safe":
        var safe_strength: float = current_safety
        var speed_multiplier: float = lerpf(1.0, float(safe_rules.get("speed_multiplier", 0.68)), safe_strength)
        var spread_multiplier: float = lerpf(1.0, float(safe_rules.get("spread_multiplier", 0.58)), safe_strength)
        var angular_multiplier: float = lerpf(1.0, float(safe_rules.get("angular_velocity_multiplier", 0.42)), safe_strength)
        wisp_speed *= speed_multiplier
        mote_speed *= speed_multiplier
        wisp_spread *= spread_multiplier
        mote_spread *= spread_multiplier
        wisp_angular *= angular_multiplier
        mote_angular *= angular_multiplier
        lifetime_multiplier = lerpf(1.0, float(safe_rules.get("lifetime_multiplier", 1.22)), safe_strength)
        mote_multiplier = lerpf(1.0, float(safe_rules.get("mote_multiplier", 0.72)), safe_strength)

    var fidelity: float = clampf(float(emotion_rules.get("direction_fidelity_min", 0.78)), 0.1, 1.0)
    var max_side_from_fidelity: float = sqrt(maxf(0.0, 1.0 / (fidelity * fidelity) - 1.0))
    side_bias = clampf(side_bias, -max_side_from_fidelity, max_side_from_fidelity)

    if _wisp_process != null:
        _wisp_process.direction = Vector3(side_bias, 0.18 + current_fear * 0.08, -1.0).normalized()
        _wisp_process.spread = wisp_spread
        _wisp_process.initial_velocity_min = wisp_speed
        _wisp_process.initial_velocity_max = wisp_speed + 1.0 + danger_burst * 0.8
        _wisp_process.angular_velocity_min = -wisp_angular
        _wisp_process.angular_velocity_max = wisp_angular
    if _mote_process != null:
        _mote_process.direction = Vector3(side_bias * 1.25, 0.34 + current_fear * 0.10, -1.0).normalized()
        _mote_process.spread = mote_spread
        _mote_process.initial_velocity_min = mote_speed
        _mote_process.initial_velocity_max = maxf(mote_speed + 0.8, 2.6 + proximity_speed * 0.55 + danger_burst)
        _mote_process.angular_velocity_min = -mote_angular
        _mote_process.angular_velocity_max = mote_angular

    var base_lifetime: float = float(particle_rules.get("lifetime_s", 1.8))
    if _wisps != null:
        _wisps.lifetime = maxf(0.45, base_lifetime * lifetime_multiplier)
    if _motes != null:
        _motes.lifetime = maxf(0.35, base_lifetime * 0.82 * lifetime_multiplier)
        var base_amount: int = int(particle_rules.get("motes", 20))
        _motes.amount = maxi(4, int(round(float(base_amount + extra_motes) * mote_multiplier)))

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
        "emotion": emotional_mode,
        "fear": current_fear,
        "danger": current_danger,
        "safety": current_safety,
        "danger_burst": danger_burst,
        "environment_danger_floor": environment_danger_floor,
        "environment_safety": environment_safety,
        "wisps_emitting": _wisps != null and _wisps.emitting,
        "motes_emitting": _motes != null and _motes.emitting,
        "mote_count": _motes.amount if _motes != null else 0,
        "revealed": is_guidance_revealed(),
        "reveal_time_remaining": reveal_time_remaining,
        "reveal_duration_s": reveal_duration_s
    }
