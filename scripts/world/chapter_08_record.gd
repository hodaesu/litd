extends Area3D
class_name Chapter08Record

var record_id := ""
var collected := false

func configure(id_value: String) -> void:
    record_id = id_value

func can_interact() -> bool:
    return not collected and record_id != "" and not Chapter08Runtime.is_record_collected(record_id)

func interact() -> bool:
    if not can_interact(): return false
    collected = Chapter08Runtime.collect_record(record_id)
    if collected: visible = false
    return collected
