extends Area3D
class_name VeilleursVS001RoomSensor

signal party_entered(room_id: String)

@export var room_id: String = ""

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    monitorable = false
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

func configure(room_id_value: String, center: Vector3, size: Vector3) -> void:
    room_id = room_id_value
    name = "RoomSensor_%s" % room_id
    position = center + Vector3(0.0, maxf(1.2, size.y * 0.35), 0.0)
    var collision := CollisionShape3D.new()
    collision.name = "RoomVolume"
    var shape := BoxShape3D.new()
    shape.size = Vector3(maxf(1.0, size.x - 1.2), maxf(2.4, size.y * 0.7), maxf(1.0, size.z - 1.2))
    collision.shape = shape
    add_child(collision)
    set_meta("room_id", room_id)
    add_to_group("veilleurs_vs001_room_sensor")

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player_party"):
        party_entered.emit(room_id)
