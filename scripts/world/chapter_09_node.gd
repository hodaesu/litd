extends Area3D
class_name Chapter09Node

var node_id := ""
var used := false

func configure(id_value: String) -> void:
    node_id = id_value

func can_interact() -> bool:
    return not used and node_id != "" and not Chapter09Runtime.is_node_active(node_id)

func interact() -> bool:
    if not can_interact(): return false
    used = Chapter09Runtime.activate_node(node_id)
    if used: visible = false
    return used
