extends Area3D
class_name AshVolume

signal entered_dense_ash(result: Dictionary)
signal exited_ash

@export var density: float = 0.5
@export var obscures_visibility := true
@export var muffles_audio := true
@export var hideable_marker_types: Array[String] = ["normal_enemy", "loot", "resource"]

var _inside_bodies: Dictionary = {}

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func can_hide(marker_type: String) -> bool:
    if marker_type in ["miniboss", "boss"]:
        return false
    return marker_type in hideable_marker_types

func _on_body_entered(body: Node) -> void:
    _inside_bodies[body.get_instance_id()] = true
    if density >= 0.65 and body.is_in_group("player_party"):
        var result := ExpeditionManager.cross_dense_ash()
        entered_dense_ash.emit(result)

func _on_body_exited(body: Node) -> void:
    _inside_bodies.erase(body.get_instance_id())
    if body.is_in_group("player_party"):
        exited_ash.emit()
