extends Node
class_name IsometricOcclusionManager

@export var camera_path: NodePath
@export var target_path: NodePath
@export var ray_collision_mask := 1

var camera: Camera3D
var target: Node3D
var _last_occluder: Node = null

func _ready() -> void:
    camera = get_node_or_null(camera_path) as Camera3D
    target = get_node_or_null(target_path) as Node3D

func _physics_process(_delta: float) -> void:
    if camera == null or target == null:
        return
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position + Vector3.UP)
    query.collision_mask = ray_collision_mask
    query.exclude = [target.get_rid()] if target is CollisionObject3D else []
    var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
    var occluder: Node = null
    if not hit.is_empty():
        occluder = _find_occludable(hit.get("collider"))
    if occluder == _last_occluder:
        return
    if _last_occluder != null and is_instance_valid(_last_occluder):
        _last_occluder.set_occluded(false)
    _last_occluder = occluder
    if _last_occluder != null:
        _last_occluder.set_occluded(true)

func _find_occludable(node: Node) -> Node:
    var current := node
    while current != null:
        if current.has_method("set_occluded"):
            return current
        current = current.get_parent()
    return null
