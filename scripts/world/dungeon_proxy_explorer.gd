extends CharacterBody3D

signal interaction_focus_changed(interaction_id: String, label: String)
signal interaction_requested(interaction_id: String, label: String)
signal ash_guidance_requested(source: String)
signal ash_guidance_unavailable

const ASH_GUIDANCE_TRAIL_SCRIPT := preload("res://scripts/world/ash_guidance_trail.gd")

# Contrôleur de blockout : AZERTY/QWERTY/flèches, caméra lisible et interactions
# de proximité. Les animations définitives du groupe remplaceront ce corps sans
# changer le contrat avec les salles.

@export var move_speed: float = 5.0
@export var acceleration: float = 18.0
@export var gravity: float = 18.0
@export var interaction_radius: float = 2.4
@export_range(0.0, 1.0) var ash_touch_zone_min_x_ratio: float = 0.55
@export_range(0.0, 1.0) var ash_touch_zone_max_y_ratio: float = 0.45

@onready var camera: Camera3D = $Camera3D

var focused_interaction_id: String = ""
var focused_interaction_label: String = ""
var interact_was_pressed: bool = false
var base_camera_position := Vector3(0.0, 6.4, 7.4)
var ash_guidance: AshGuidanceTrail = null
var boss_guidance_candidate: Dictionary = {}
var quest_guidance_candidate: Dictionary = {}
var tracked_quest_id: String = ""
var ash_unavailable_feedback_cooldown: float = 0.0

func _ready() -> void:
    add_to_group("player_party")
    ash_guidance = ASH_GUIDANCE_TRAIL_SCRIPT.new() as AshGuidanceTrail
    if ash_guidance != null:
        ash_guidance.name = "AshGuidanceTrail"
        add_child(ash_guidance)
        call_deferred("_sync_ash_environment_from_parent")
    set_process_unhandled_input(true)

func _physics_process(delta: float) -> void:
    ash_unavailable_feedback_cooldown = maxf(0.0, ash_unavailable_feedback_cooldown - delta)
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

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ash_guidance"):
        request_ash_guidance("input_action")
        get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and touch.double_tap and _is_in_ash_touch_zone(touch.position):
            request_ash_guidance("touch_double_tap")
            get_viewport().set_input_as_handled()

func _is_in_ash_touch_zone(screen_position: Vector2) -> bool:
    var screen_size: Vector2 = get_viewport().get_visible_rect().size
    if screen_size.x <= 0.0 or screen_size.y <= 0.0:
        return false
    return screen_position.x >= screen_size.x * ash_touch_zone_min_x_ratio and screen_position.y <= screen_size.y * ash_touch_zone_max_y_ratio

func request_ash_guidance(source: String = "code") -> bool:
    if ash_guidance == null:
        return false
    _apply_preferred_guidance()
    var shown: bool = ash_guidance.request_guidance()
    if shown:
        ash_guidance_requested.emit(source)
    else:
        ash_guidance_unavailable.emit()
        if ash_unavailable_feedback_cooldown <= 0.0:
            GameState.add_log("La cendre ne trouve aucun chemin praticable.")
            ash_unavailable_feedback_cooldown = 1.5
    return shown

func set_boss_guidance_position(world_position: Vector3, route_proximity: float = -1.0) -> void:
    boss_guidance_candidate = {"mode": "position", "position": world_position, "route_proximity": route_proximity}
    _apply_preferred_guidance()

func set_boss_guidance_target(target: Node3D, route_proximity: float = -1.0) -> void:
    boss_guidance_candidate = {"mode": "node", "target": target, "route_proximity": route_proximity}
    _apply_preferred_guidance()

func set_quest_guidance_position(world_position: Vector3, max_distance_m: float = -1.0, quest_id: String = "") -> void:
    tracked_quest_id = quest_id
    quest_guidance_candidate = {"mode": "position", "position": world_position, "max_distance_m": max_distance_m}
    _apply_preferred_guidance()

func set_quest_guidance_target(target: Node3D, max_distance_m: float = -1.0, quest_id: String = "") -> void:
    tracked_quest_id = quest_id
    quest_guidance_candidate = {"mode": "node", "target": target, "max_distance_m": max_distance_m}
    _apply_preferred_guidance()

func complete_or_untrack_quest(quest_id: String = "") -> void:
    if quest_id != "" and tracked_quest_id != "" and quest_id != tracked_quest_id:
        return
    tracked_quest_id = ""
    quest_guidance_candidate.clear()
    _apply_preferred_guidance()

func invalidate_boss_route() -> void:
    boss_guidance_candidate.clear()
    _apply_preferred_guidance()

func _apply_preferred_guidance() -> void:
    if ash_guidance == null:
        return
    if _apply_candidate(quest_guidance_candidate, "quest"):
        return
    if _apply_candidate(boss_guidance_candidate, "boss"):
        return
    ash_guidance.clear_guidance()

func _apply_candidate(candidate: Dictionary, kind: String) -> bool:
    if candidate.is_empty():
        return false
    var mode: String = str(candidate.get("mode", ""))
    if mode == "node":
        var target_value: Variant = candidate.get("target")
        if target_value is Node3D and is_instance_valid(target_value):
            var target := target_value as Node3D
            var distance: float = float(candidate.get("max_distance_m", -1.0))
            var proximity: float = float(candidate.get("route_proximity", -1.0))
            ash_guidance.guide_to_node(target, kind, distance, proximity)
            return true
        candidate.clear()
        return false
    if mode == "position":
        var distance: float = float(candidate.get("max_distance_m", -1.0))
        var proximity: float = float(candidate.get("route_proximity", -1.0))
        ash_guidance.guide_to_world_position(candidate.get("position", Vector3.ZERO), kind, distance, proximity)
        return true
    candidate.clear()
    return false

func set_ash_environment_context(danger_floor: float, safety: float) -> void:
    if ash_guidance != null:
        ash_guidance.set_environment_context(danger_floor, safety)

func set_ash_emotional_context(fear: float = -1.0, danger: float = -1.0, safety: float = -1.0) -> void:
    if ash_guidance != null:
        ash_guidance.set_emotional_context(fear, danger, safety)

func clear_ash_emotional_overrides() -> void:
    if ash_guidance != null:
        ash_guidance.clear_emotional_overrides()

func clear_ash_guidance() -> void:
    tracked_quest_id = ""
    quest_guidance_candidate.clear()
    boss_guidance_candidate.clear()
    if ash_guidance != null:
        ash_guidance.clear_guidance()

func guidance_snapshot() -> Dictionary:
    return ash_guidance.snapshot() if ash_guidance != null else {}

func _sync_ash_environment_from_parent() -> void:
    if ash_guidance == null:
        return
    var room_node: Node = get_parent()
    if room_node == null:
        return
    var room_spec_value: Variant = _property_value(room_node, "room_spec", {})
    if not room_spec_value is Dictionary:
        return
    var room_spec: Dictionary = room_spec_value
    var proxy_value: Variant = room_spec.get("proxy", {})
    var proxy: Dictionary = proxy_value if proxy_value is Dictionary else {}
    var role: String = str(proxy.get("role", room_spec.get("room_role", "generic")))
    var room_type: String = str(room_spec.get("type", ""))
    ash_guidance.configure_environment_for_room(role, room_type)

func _property_value(object: Object, property_name: String, fallback: Variant) -> Variant:
    for property_value: Variant in object.get_property_list():
        if not property_value is Dictionary:
            continue
        var property: Dictionary = property_value
        if str(property.get("name", "")) == property_name:
            return object.get(property_name)
    return fallback

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
