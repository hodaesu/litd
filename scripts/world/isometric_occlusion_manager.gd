extends Node
class_name IsometricOcclusionManager

@export var camera_path: NodePath
@export var target_path: NodePath
@export var ray_collision_mask := 1

var camera: Camera3D
var target: Node3D
var _active_occluders: Array[Node] = []

func _ready() -> void:
    camera = get_node_or_null(camera_path) as Camera3D
    target = get_node_or_null(target_path) as Node3D

func _physics_process(_delta: float) -> void:
    if camera == null or target == null:
        return
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position + Vector3.UP)
    query.collision_mask = ray_collision_mask
    query.exclude = [target.get_rid()] if target is CollisionObject3D else []
    var next_occluders: Array[Node] = []
    for _index in 4:
        var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
        if hit.is_empty():
            break
        var collider := hit.get("collider") as CollisionObject3D
        var occluder := _find_occludable(collider)
        if occluder != null and not next_occluders.has(occluder):
            next_occluders.append(occluder)
        if collider == null:
            break
        query.exclude.append(collider.get_rid())
    for old_occluder in _active_occluders:
        if is_instance_valid(old_occluder) and not next_occluders.has(old_occluder):
            old_occluder.set_occluded(false)
    for new_occluder in next_occluders:
        if not _active_occluders.has(new_occluder):
            new_occluder.set_occluded(true)
    _active_occluders = next_occluders

func _find_occludable(node: Node) -> Node:
    var current := node
    while current != null:
        if current.has_method("set_occluded"):
            return current
        current = current.get_parent()
    return null
