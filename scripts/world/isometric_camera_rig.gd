extends Node3D
class_name IsometricCameraRig

const CAMERA_PROFILES_PATH := "res://data/levels/ashlands_camera_profiles.json"

@export var target_path: NodePath
@export var pitch_degrees := 40.0
@export var yaw_degrees := 45.0
@export var distance := 14.0
@export var height_offset := 1.5
@export var framing_offset := Vector3.ZERO
@export var follow_lerp := 8.0
@export var zoom_step := 2.0
@export var min_distance := 10.0
@export var max_distance := 18.0

@onready var camera: Camera3D = $Camera3D
var target: Node3D

func _ready() -> void:
    add_to_group("isometric_camera_rig")
    apply_zone_profile(AshlandsRuntime.current_zone_id)
    if target_path != NodePath(""):
        target = get_node_or_null(target_path) as Node3D
    _apply_camera_transform()

func set_target(node: Node3D) -> void:
    target = node

func _process(delta: float) -> void:
    if target != null:
        var focus_point := target.global_position + Vector3.UP * height_offset + framing_offset
        global_position = global_position.lerp(focus_point, min(1.0, delta * follow_lerp))
    if Input.is_action_just_pressed("camera_zoom_in"):
        zoom_in()
    elif Input.is_action_just_pressed("camera_zoom_out"):
        zoom_out()

func zoom_in() -> void:
    distance = max(min_distance, distance - zoom_step)
    _apply_camera_transform()

func zoom_out() -> void:
    distance = min(max_distance, distance + zoom_step)
    _apply_camera_transform()

func _apply_camera_transform() -> void:
    rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0.0)
    if camera != null:
        camera.position = Vector3(0.0, 0.0, max_distance)
        if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
            camera.size = distance
        camera.current = true

func apply_zone_profile(zone_id: String) -> void:
    if not FileAccess.file_exists(CAMERA_PROFILES_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAMERA_PROFILES_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var defaults: Dictionary = parsed.get("defaults", {})
    var profile: Dictionary = defaults.duplicate(true)
    profile.merge(parsed.get("zones", {}).get(zone_id, {}), true)
    pitch_degrees = float(profile.get("pitch", pitch_degrees))
    yaw_degrees = float(profile.get("yaw", yaw_degrees))
    distance = float(profile.get("view_size", distance))
    min_distance = float(profile.get("min_zoom", min_distance))
    max_distance = float(profile.get("max_zoom", max_distance))
    follow_lerp = float(profile.get("follow_lerp", follow_lerp))
    var focus: Array = profile.get("focus_offset", [0.0, height_offset, 0.0])
    if focus.size() >= 3:
        height_offset = float(focus[1])
        framing_offset = Vector3(float(focus[0]), 0.0, float(focus[2]))
