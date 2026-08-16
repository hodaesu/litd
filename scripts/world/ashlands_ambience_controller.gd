extends Node3D
class_name AshlandsAmbienceController

@export var zone_id := ""
@export var base_ash_density := 0.35

var environment: Environment
var key_light: DirectionalLight3D
var ash_particles: CPUParticles3D
var _target_fog_density := 0.018
var _target_light_energy := 0.72

func _ready() -> void:
    add_to_group("ashlands_ambience")
    _build_environment()
    _build_ash_particles()
    _build_audio_placeholders()

func _process(delta: float) -> void:
    if environment != null:
        environment.fog_density = move_toward(environment.fog_density, _target_fog_density, delta * 0.06)
    if key_light != null:
        key_light.light_energy = move_toward(key_light.light_energy, _target_light_energy, delta * 1.5)

func set_dense_ash(active: bool, density: float = 0.7) -> void:
    _target_fog_density = clamp(0.025 + density * 0.045, 0.025, 0.075) if active else 0.018
    _target_light_energy = 0.42 if active else 0.72
    if ash_particles != null:
        ash_particles.amount = 160 if active else 72

func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    world_environment.name = "AshlandsWorldEnvironment"
    environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.055, 0.045, 0.04, 1.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.34, 0.29, 0.25, 1.0)
    environment.ambient_light_energy = 0.62
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.31, 0.26, 0.22, 1.0)
    environment.fog_density = _target_fog_density
    world_environment.environment = environment
    add_child(world_environment)

    key_light = DirectionalLight3D.new()
    key_light.name = "AshlandsKeyLight"
    key_light.rotation_degrees = Vector3(-54.0, -34.0, 0.0)
    key_light.light_color = Color(0.92, 0.72, 0.55, 1.0)
    key_light.light_energy = _target_light_energy
    key_light.shadow_enabled = true
    add_child(key_light)

func _build_ash_particles() -> void:
    ash_particles = CPUParticles3D.new()
    ash_particles.name = "AshVFXPlaceholder"
    ash_particles.amount = 72
    ash_particles.lifetime = 7.0
    ash_particles.preprocess = 7.0
    ash_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    ash_particles.emission_box_extents = Vector3(34.0, 7.0, 34.0)
    ash_particles.direction = Vector3(0.25, -0.65, 0.1)
    ash_particles.spread = 28.0
    ash_particles.gravity = Vector3(0.0, -0.08, 0.0)
    ash_particles.initial_velocity_min = 0.25
    ash_particles.initial_velocity_max = 0.75
    ash_particles.scale_amount_min = 0.025
    ash_particles.scale_amount_max = 0.085
    ash_particles.color = Color(0.58, 0.5, 0.43, 0.44)
    add_child(ash_particles)

func _build_audio_placeholders() -> void:
    var wind := AudioStreamPlayer.new()
    wind.name = "WindLoopPlaceholder"
    wind.volume_db = -18.0
    wind.set_meta("audio_contract", "ashlands_wind_loop")
    add_child(wind)
    var zone_stinger := AudioStreamPlayer.new()
    zone_stinger.name = "ZoneStingerPlaceholder"
    zone_stinger.volume_db = -12.0
    zone_stinger.set_meta("audio_contract", "zone_%s_stinger" % zone_id)
    add_child(zone_stinger)
