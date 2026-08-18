extends Area3D
class_name Chapter08AncientTrace

var trace_id := ""
var collected := false

func configure(id_value: String) -> void:
    trace_id = id_value

func can_interact() -> bool:
    return not collected and trace_id != "" and not Chapter08Runtime.is_ancient_trace_collected(trace_id)

func interact() -> bool:
    if not can_interact(): return false
    collected = Chapter08Runtime.collect_ancient_trace(trace_id)
    if collected: visible = false
    return collected
