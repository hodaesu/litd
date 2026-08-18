extends Area3D
class_name Chapter09Observation

var observation_id := ""
var collected := false

func configure(id_value: String) -> void:
    observation_id = id_value

func can_interact() -> bool:
    return not collected and observation_id != "" and not Chapter09Runtime.is_observation_collected(observation_id)

func interact() -> bool:
    if not can_interact(): return false
    collected = Chapter09Runtime.collect_observation(observation_id)
    if collected: visible = false
    return collected
