extends Node3D
class_name IsometricCameraRig

@export var target_path: NodePath
@export var pitch_degrees := 40.0
@export var yaw_degrees := 45.0
@export var distance := 14.0
@export var height_offset := 1.5
@export var follow_lerp := 8.0
@export var zoom_step := 2.0
@export var min_distance := 10.0
@export var max_distance := 18.0

@onready var camera: Camera3D = $Camera3D
var target: Node3D

func _ready() -> void:
    if target_path != NodePath(""):
        target = get_node_or_null(target_path) as Node3D
    _apply_camera_transform()

func set_target(node: Node3D) -> void:
    target = node

func _process(delta: float) -> void:
    if target != null:
        global_position = global_position.lerp(target.global_position + Vector3.UP * height_offset, min(1.0, delta * follow_lerp))
    if Input.is_action_just_pressed("camera_zoom_in"):
        distance = max(min_distance, distance - zoom_step)
        _apply_camera_transform()
    elif Input.is_action_just_pressed("camera_zoom_out"):
        distance = min(max_distance, distance + zoom_step)
        _apply_camera_transform()

func _apply_camera_transform() -> void:
    rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0.0)
    if camera != null:
        camera.position = Vector3(0.0, 0.0, distance)
        camera.current = true
