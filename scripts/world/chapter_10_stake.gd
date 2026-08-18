extends Area3D
class_name Chapter10Stake

var stake_id := ""
var collected := false

func configure(id_value: String) -> void:
    stake_id = id_value
    collected = Chapter10Runtime.is_stake_collected(stake_id)
    visible = not collected

func can_interact() -> bool:
    return stake_id != "" and not collected and not Chapter10Runtime.is_stake_collected(stake_id)

func interact() -> bool:
    if not can_interact(): return false
    collected = Chapter10Runtime.collect_stake(stake_id)
    if collected: visible = false
    return collected
