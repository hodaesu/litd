extends Area3D
class_name Chapter06Signal

var signal_id := ""
var collected := false

func configure(id_value: String) -> void:
    signal_id = id_value
    collected = Chapter06Runtime.discovered_signals.has(signal_id)
    monitoring = not collected
    visible = not collected

func can_interact() -> bool:
    return signal_id != "" and not collected

func interact() -> void:
    if not can_interact(): return
    if Chapter06Runtime.collect_signal(signal_id):
        collected = true
        monitoring = false
        visible = false
