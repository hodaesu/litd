extends CharacterBody3D

signal interaction_focus_changed(interaction_id: String, label: String)
signal interaction_requested(interaction_id: String, label: String)

const ASH_GUIDANCE_TRAIL_SCRIPT := preload("res://scripts/world/ash_guidance_trail.gd")

# Contrôleur de blockout : AZERTY/QWERTY/flèches, caméra lisible et interactions
# de proximité. Les animations définitives du groupe remplaceront ce corps sans
# changer le contrat avec les salles.

@export var move_speed: float = 5.0
@export var acceleration: float = 18.0
@export var gravity: float = 18.0
@export var interaction_radius: float = 2.4

@onready var camera: Camera3D = $Camera3D

var focused_interaction_id: String = ""
var focused_interaction_label: String = ""
var interact_was_pressed: bool = false
var base_camera_position := Vector3(0.0, 6.4, 7.4)
var ash_guidance: AshGuidanceTrail = null

func _ready() -> void:
    add_to_group("player_party")
    ash_guidance = ASH_GUIDANCE_TRAIL_SCRIPT.new() as AshGuidanceTrail
    if ash_guidance != null:
        ash_guidance.name = "AshGuidanceTrail"
        add_child(ash_guidance)

func _physics_process(delta: float) -> void:
    var input_vector: Vector2 = _movement_input()
    var desired: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y).normalized() * move_speed
    velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
    move_and_slide()
    _update_camera(delta)
    _update_interaction_focus()

func set_boss_guidance_position(world_position: Vector3, route_proximity: float = -1.0) -> void:
    if ash_guidance != null:
        ash_guidance.guide_to_world_position(world_position, "boss", -1.0, route_proximity)

func set_boss_guidance_target(target: Node3D, route_proximity: float = -1.0) -> void:
    if ash_guidance != null:
        ash_guidance.guide_to_node(target, "boss", -1.0, route_proximity)

func set_quest_guidance_position(world_position: Vector3, max_distance_m: float = -1.0) -> void:
    if ash_guidance != null:
        ash_guidance.guide_to_world_position(world_position, "quest", max_distance_m)

func set_quest_guidance_target(target: Node3D, max_distance_m: float = -1.0) -> void:
    if ash_guidance != null:
        ash_guidance.guide_to_node(target, "quest", max_distance_m)

func clear_ash_guidance() -> void:
    if ash_guidance != null:
        ash_guidance.clear_guidance()

func guidance_snapshot() -> Dictionary:
    return ash_guidance.snapshot() if ash_guidance != null else {}

func _movement_input() -> Vector2:
    var x_axis: float = 0.0
    var y_axis: float = 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
        x_axis -= 1.0
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        x_axis += 1.0
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
        y_axis -= 1.0
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        y_axis += 1.0
    return Vector2(x_axis, y_axis)

func _update_camera(delta: float) -> void:
    if camera == null:
        return
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    var look_ahead := Vector3(velocity.x * 0.10, 0.0, velocity.z * 0.06)
    var target_position := base_camera_position + look_ahead
    camera.position = camera.position.lerp(target_position, clampf(delta * 5.5, 0.0, 1.0))
    var target_fov := 62.0 + clampf(horizontal_speed / maxf(0.1, move_speed), 0.0, 1.0) * 3.0
    camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 3.5, 0.0, 1.0))

func _update_interaction_focus() -> void:
    var parent_room: Node = get_parent()
    var nearest: Dictionary = {}
    if parent_room != null and parent_room.has_method("nearest_interaction_for"):
        nearest = parent_room.call("nearest_interaction_for", global_position, interaction_radius)
    var next_id := str(nearest.get("id", ""))
    var next_label := str(nearest.get("label", ""))
    if next_id != focused_interaction_id or next_label != focused_interaction_label:
        focused_interaction_id = next_id
        focused_interaction_label = next_label
        interaction_focus_changed.emit(focused_interaction_id, focused_interaction_label)

    var interact_pressed := Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)
    if interact_pressed and not interact_was_pressed and focused_interaction_id != "":
        interaction_requested.emit(focused_interaction_id, focused_interaction_label)
    interact_was_pressed = interact_pressed
