extends Area3D
class_name Chapter02Clue

var clue_id := ""
var collected := false

func configure(id_value: String) -> void:
    clue_id = id_value
    collected = Chapter02Runtime.is_clue_discovered(clue_id)
    visible = not collected
    monitoring = not collected
    set_meta("interaction_prompt", "Examiner")

func can_interact() -> bool:
    return clue_id != "" and not collected

func interact() -> void:
    if not can_interact():
        return
    if Chapter02Runtime.collect_clue(clue_id):
        collected = true
        visible = false
        monitoring = false
