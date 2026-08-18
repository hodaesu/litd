extends Area3D
class_name Chapter10Node

var node_id := ""
var used := false

func configure(id_value: String) -> void:
    node_id = id_value
    used = Chapter10Runtime.is_node_active(node_id)
    visible = not used and Chapter10Runtime.node_available(node_id)

func can_interact() -> bool:
    return node_id != "" and not used and Chapter10Runtime.node_available(node_id)

func interact() -> bool:
    if not can_interact(): return false
    used = Chapter10Runtime.activate_node(node_id)
    if used: visible = false
    return used
