extends Node3D
class_name VeilleursGE01Blockout

const ROOM_POSITIONS := {
    "ge_01": Vector3(0, 0, 0),
    "ge_02": Vector3(0, 0, -8),
    "ge_03": Vector3(0, 0, -16),
    "ge_03b": Vector3(-8, 0, -16),
    "ge_04": Vector3(0, 0, -24),
    "ge_05": Vector3(0, 0, -32),
    "ge_06": Vector3(0, 0, -40),
    "ge_07": Vector3(0, 0, -48),
    "ge_08": Vector3(-8, 0, -48),
    "ge_09": Vector3(-8, 0, -56),
    "ge_10": Vector3(0, 0, -56),
    "ge_11": Vector3(8, 0, -56),
    "ge_12": Vector3(8, 0, -64),
    "ge_13": Vector3(0, 0, -64),
    "ge_14": Vector3(8, 0, -32)
}

func _ready() -> void:
    if get_child_count() == 0:
        build()

func build() -> void:
    for room_id: String in ROOM_POSITIONS.keys():
        _build_room(room_id, ROOM_POSITIONS[room_id])

func room_anchor(room_id: String) -> Node3D:
    return get_node_or_null(NodePath(room_id)) as Node3D

func _build_room(room_id: String, position_value: Vector3) -> void:
    var room := Node3D.new()
    room.name = room_id
    room.position = position_value
    add_child(room)

    var floor_mesh := MeshInstance3D.new()
    floor_mesh.name = "Floor"
    var floor := BoxMesh.new()
    floor.size = Vector3(6.0, 0.4, 6.0)
    floor_mesh.mesh = floor
    floor_mesh.position.y = -0.2
    room.add_child(floor_mesh)

    var body := StaticBody3D.new()
    body.name = "Collision"
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(6.0, 0.4, 6.0)
    shape_node.shape = shape
    shape_node.position.y = -0.2
    body.add_child(shape_node)
    room.add_child(body)

    var marker := Label3D.new()
    marker.name = "RoomLabel"
    marker.text = room_id.to_upper()
    marker.position = Vector3(0, 1.6, 0)
    marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    room.add_child(marker)
