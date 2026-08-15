extends Node3D
class_name IsometricOccludable

@export var fade_alpha := 0.22
@export var fade_speed := 8.0
@export var auto_collect_meshes := true

var _occluded := false
var _meshes: Array[MeshInstance3D] = []

func _ready() -> void:
    add_to_group("isometric_occludable")
    if auto_collect_meshes:
        _collect_meshes(self)

func _process(delta: float) -> void:
    var target_alpha := fade_alpha if _occluded else 1.0
    for mesh in _meshes:
        if not is_instance_valid(mesh):
            continue
        var material := mesh.material_override
        if material == null:
            material = StandardMaterial3D.new()
            mesh.material_override = material
        if material is StandardMaterial3D:
            var std := material as StandardMaterial3D
            std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            var c := std.albedo_color
            c.a = move_toward(c.a, target_alpha, fade_speed * delta)
            std.albedo_color = c

func set_occluded(value: bool) -> void:
    _occluded = value

func _collect_meshes(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            _meshes.append(child)
        _collect_meshes(child)
