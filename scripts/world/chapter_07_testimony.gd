extends Area3D
class_name Chapter07Testimony

var testimony_id := ""
var consumed := false

func configure(id_value: String) -> void:
    testimony_id = id_value
    consumed = Chapter07Runtime.collected_testimonies.has(testimony_id)
    monitoring = not consumed
    visible = not consumed

func can_interact() -> bool:
    return testimony_id != "" and not consumed

func interact() -> void:
    if not can_interact(): return
    if Chapter07Runtime.collect_testimony(testimony_id):
        consumed = true
        monitoring = false
        visible = false
