extends "res://scripts/ui/main_v10.gd"

# Combat v11 : blessures fonctionnelles sans démembrement obligatoire.

func _report_anatomy_result(target: Dictionary, result: Dictionary) -> void:
    super._report_anatomy_result(target, result)
    if bool(result.get("severed", false)):
        return
    var state := str(result.get("state", ""))
    if state not in ["injured", "critical"]:
        return
    var injury := InjuryRuntime.apply_if_needed(target, str(result.get("part_id", "")), state)
    if injury.is_empty():
        return
    GameState.add_log("BLESSURE — %s : %s (%s)." % [
        str(injury.get("part_name", "Partie")), str(injury.get("injury_name", "blessure")), state
    ])
    if bool(injury.get("critical_disables_part", false)):
        GameState.add_log("La fonction de cette partie est neutralisée sans démembrement.")

func _part_is_available(enemy: Dictionary, part_id: String) -> bool:
    if not super._part_is_available(enemy, part_id):
        return false
    return InjuryRuntime.part_functional(enemy, part_id)

func _move_enemy_relative(enemy: Dictionary, delta: int) -> bool:
    var mobility_state := str(enemy.get("mobility_injury", ""))
    if mobility_state == "critical" and randi_range(1, 100) <= 50:
        GameState.add_log("%s tente de se déplacer mais sa blessure de mobilité cède." % str(enemy.get("name", "L'ennemi")))
        return false
    return super._move_enemy_relative(enemy, delta)

func _lost_attack_multiplier(enemy: Dictionary) -> float:
    var multiplier := super._lost_attack_multiplier(enemy)
    var states: Dictionary = enemy.get("applied_injury_states", {})
    for part_id_value in states.keys():
        var state := str(states.get(part_id_value, ""))
        var part := AnatomyRuntime.part_definition(enemy, str(part_id_value))
        var tags: Array = part.get("tags", [])
        if tags.has("attack") or tags.has("weapon") or tags.has("sensor"):
            multiplier *= 0.75 if state == "critical" else 0.90
    return multiplier

func _lost_fear_multiplier(enemy: Dictionary) -> float:
    var multiplier := super._lost_fear_multiplier(enemy)
    var states: Dictionary = enemy.get("applied_injury_states", {})
    for part_id_value in states.keys():
        var state := str(states.get(part_id_value, ""))
        var part := AnatomyRuntime.part_definition(enemy, str(part_id_value))
        var tags: Array = part.get("tags", [])
        if tags.has("fear") or tags.has("sensor") or tags.has("venom") or tags.has("veil") or tags.has("anchor"):
            multiplier *= 0.75 if state == "critical" else 0.90
    return multiplier
