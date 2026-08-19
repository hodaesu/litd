extends CharacterBody3D
class_name ExplorationPartyController

signal interaction_requested
signal movement_state_changed(is_moving: bool, is_running: bool)

@export var walk_speed := 4.5
@export var run_speed := 7.0
@export var acceleration := 18.0
@export var gravity := 24.0
@export var interaction_distance := 2.4
@export var walk_step_interval := 0.48
@export var run_step_interval := 0.34

var _last_moving := false
var _last_running := false
var _virtual_input := Vector2.ZERO
var _virtual_run := false
var _step_elapsed := 0.0

func _ready() -> void:
    add_to_group("player_party")

func _physics_process(delta: float) -> void:
    var keyboard_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var input_vec := _virtual_input if _virtual_input.length_squared() > keyboard_input.length_squared() else keyboard_input
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)
    if direction.length_squared() > 1.0:
        direction = direction.normalized()

    var running := (Input.is_action_pressed("sprint") or _virtual_run) and direction.length_squared() > 0.0
    var speed := run_speed if running else walk_speed
    var target := direction * speed
    velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = min(velocity.y, 0.0)

    if direction.length_squared() > 0.001:
        var target_yaw := atan2(direction.x, direction.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, delta * 10.0))

    move_and_slide()
    var moving := Vector2(velocity.x, velocity.z).length() > 0.1
    _update_footsteps(delta, moving, running)
    if moving != _last_moving or running != _last_running:
        _last_moving = moving
        _last_running = running
        movement_state_changed.emit(moving, running)

func set_virtual_input(value: Vector2) -> void:
    _virtual_input = value.limit_length(1.0)

func set_virtual_run(value: bool) -> void:
    _virtual_run = value

func interact() -> void:
    interaction_requested.emit()
    _try_interact()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        interact()

func _update_footsteps(delta: float, moving: bool, running: bool) -> void:
    if not moving or not is_on_floor():
        _step_elapsed = 0.0
        return
    var interval := maxf(0.12, run_step_interval if running else walk_step_interval)
    _step_elapsed += delta
    if _step_elapsed < interval:
        return
    _step_elapsed = fmod(_step_elapsed, interval)
    AudioDirector.request_sfx(
        _footstep_cue(),
        {
            "reason": "party_step",
            "position_3d": global_position,
            "running": running,
            "max_distance": 22.0,
            "unit_size": 3.0
        }
    )

func _footstep_cue() -> String:
    var zone_id := str(AshlandsRuntime.current_zone_id).to_lower()
    for token: String in ["chapelle", "catacomb", "crypt", "archive", "relay", "complex", "vault", "sanctuary", "temple"]:
        if zone_id.contains(token):
            return "footstep_stone"
    return "footstep_ash"

func _try_interact() -> void:
    var origin := global_position + Vector3.UP * 1.0
    var forward := -global_transform.basis.z.normalized()
    var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * interaction_distance)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var target = hit.get("collider")
    if target != null and target.has_method("interact"):
        target.interact()
    elif target != null and target.has_method("harvest"):
        target.harvest()
    elif target != null and target.has_method("rest"):
        target.rest()
