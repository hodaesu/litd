extends CharacterBody3D
class_name ExplorationPartyController

signal interaction_requested
signal interaction_resolved(result: Dictionary)
signal interaction_feedback(result: Dictionary)
signal interaction_target_changed(descriptor: Dictionary)
signal movement_state_changed(is_moving: bool, is_running: bool)

@export var walk_speed := 4.5
@export var run_speed := 7.0
@export var acceleration := 18.0
@export var gravity := 24.0
@export var interaction_distance := 2.4
@export var interaction_forward_bias := 2.2
@export var interaction_distance_bias := 1.0
@export var interaction_switch_margin := 0.18
@export var interaction_min_alignment := 0.20
@export var walk_step_interval := 0.48
@export var run_step_interval := 0.34

var _last_moving := false
var _last_running := false
var _virtual_input := Vector2.ZERO
var _virtual_run := false
var _step_elapsed := 0.0
var _interaction_target: Object = null
var _interaction_descriptor: Dictionary = {}

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
    _refresh_interaction_target()
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

func interaction_descriptor_for(target: Object) -> Dictionary:
    return EnvironmentInteractionContract.describe(target, self)

func get_interaction_descriptor() -> Dictionary:
    return _interaction_descriptor.duplicate(true)

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

func _probe_interaction_target() -> Object:
    var candidates := _collect_interaction_candidates()
    return _choose_interaction_candidate(candidates)

func _collect_interaction_candidates() -> Array[Dictionary]:
    var shape := SphereShape3D.new()
    shape.radius = interaction_distance
    var origin := global_position + Vector3.UP * 1.0
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = Transform3D(Basis.IDENTITY, origin)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.exclude = [get_rid()]

    var forward := -global_transform.basis.z.normalized()
    var raw_hits := get_world_3d().direct_space_state.intersect_shape(query, 24)
    var candidates: Array[Dictionary] = []
    for hit: Dictionary in raw_hits:
        var target := hit.get("collider") as Object
        if target == null or not EnvironmentInteractionContract.supports(target):
            continue
        if not target is Node3D:
            continue
        var target_node := target as Node3D
        var offset := target_node.global_position - global_position
        offset.y = 0.0
        var distance := offset.length()
        if distance > interaction_distance or distance <= 0.001:
            continue
        var direction := offset / distance
        var alignment := forward.dot(direction)
        if alignment < interaction_min_alignment:
            continue
        candidates.append({
            "target": target,
            "distance": distance,
            "alignment": alignment,
            "score": _interaction_candidate_score(distance, alignment),
        })
    return candidates

func _interaction_candidate_score(distance: float, alignment: float) -> float:
    var normalized_distance := clampf(distance / maxf(interaction_distance, 0.001), 0.0, 1.0)
    return alignment * interaction_forward_bias + (1.0 - normalized_distance) * interaction_distance_bias

func _choose_interaction_candidate(candidates: Array[Dictionary]) -> Object:
    if candidates.is_empty():
        return null

    var best: Dictionary = candidates[0]
    var current: Dictionary = {}
    for candidate: Dictionary in candidates:
        if float(candidate.get("score", -INF)) > float(best.get("score", -INF)):
            best = candidate
        if candidate.get("target") == _interaction_target:
            current = candidate

    if not current.is_empty():
        var current_score := float(current.get("score", -INF))
        var best_score := float(best.get("score", -INF))
        if best.get("target") != _interaction_target and best_score < current_score + interaction_switch_margin:
            return _interaction_target
    return best.get("target") as Object

func _refresh_interaction_target() -> void:
    var target := _probe_interaction_target()
    if target == null:
        _set_interaction_target(null, {})
        return
    var descriptor := EnvironmentInteractionContract.describe(target, self)
    _set_interaction_target(target, descriptor)

func _set_interaction_target(target: Object, descriptor: Dictionary) -> void:
    if target == _interaction_target and descriptor == _interaction_descriptor:
        return
    _interaction_target = target
    _interaction_descriptor = descriptor.duplicate(true)
    interaction_target_changed.emit(_interaction_descriptor.duplicate(true))

func _try_interact() -> Dictionary:
    var target := _probe_interaction_target()
    if target == null:
        _set_interaction_target(null, {})
        return {}
    var descriptor := EnvironmentInteractionContract.describe(target, self)
    _set_interaction_target(target, descriptor)
    var result := EnvironmentInteractionContract.perform(target, self)
    interaction_resolved.emit(result)
    interaction_feedback.emit(result)
    _refresh_interaction_target()
    return result
