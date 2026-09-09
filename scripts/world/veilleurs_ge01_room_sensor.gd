extends Area3D
class_name VeilleursGE01RoomSensor

signal party_entered(room_id: String)

@export var room_id: String = ""

func configure(room_id_value: String, center: Vector3, size: Vector3 = Vector3(5.0, 2.5, 5.0)) -> void:
    room_id = room_id_value
    name = "GE01RoomSensor_%s" % room_id
    position = center + Vector3(0.0, 1.2, 0.0)
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    monitorable = false
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    add_child(collision)
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player_party"):
        party_entered.emit(room_id)
