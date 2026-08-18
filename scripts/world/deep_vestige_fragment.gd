extends Area3D
class_name DeepVestigeFragment

var fragment_id := ""
var collected := false

func configure(id_value: String) -> void:
    fragment_id = id_value
    collected = DeepVestigeRuntime.fragments.has(fragment_id)
    monitoring = not collected
    visible = not collected

func can_interact() -> bool:
    return not collected and fragment_id != ""

func interact() -> void:
    if not can_interact():
        return
    if DeepVestigeRuntime.collect_fragment(fragment_id):
        collected = true
        monitoring = false
        visible = false
