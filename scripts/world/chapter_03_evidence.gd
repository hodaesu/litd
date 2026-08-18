extends Area3D
class_name Chapter03Evidence

var evidence_id := ""
var collected := false

func configure(id_value: String) -> void:
    evidence_id = id_value
    collected = Chapter03Runtime.is_evidence_collected(evidence_id)
    visible = not collected
    monitoring = not collected
    set_meta("interaction_prompt", "Examiner")

func can_interact() -> bool:
    return not collected and evidence_id != ""

func interact() -> void:
    if not can_interact():
        return
    if Chapter03Runtime.collect_evidence(evidence_id):
        collected = true
        visible = false
        monitoring = false
