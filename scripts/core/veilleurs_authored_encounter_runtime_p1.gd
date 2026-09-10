extends "res://scripts/core/veilleurs_authored_encounter_runtime_p0.gd"
class_name VeilleursAuthoredEncounterRuntimeP1

func setup_authored_encounter(encounter: Dictionary) -> Dictionary:
    var result := super.setup_authored_encounter(encounter)
    if bool(result.get("ok", false)):
        _sync_all_combat_ranks_from_grid()
    return result

func available_basic_actions(entity_id: String) -> Array[Dictionary]:
    _sync_combat_rank_from_grid(entity_id)
    return super.available_basic_actions(entity_id)

func resolve_basic_action(attacker_id: String, target_id: String, action_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    _sync_combat_rank_from_grid(attacker_id)
    _sync_combat_rank_from_grid(target_id)
    var result := super.resolve_basic_action(attacker_id, target_id, action_id, zone, forced_roll)
    _sync_all_combat_ranks_from_grid()
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    _sync_all_combat_ranks_from_grid()
    var result := super.enemy_step(enemy_id)
    _sync_all_combat_ranks_from_grid()
    return result

func _resolve_basic_reposition(attacker_id: String, action: Dictionary) -> Dictionary:
    return VeilleursTacticalCombatRuntimeV4._resolve_basic_reposition.call(self, attacker_id, action)

func _basic_action_range(action: Dictionary) -> int:
    return VeilleursTacticalCombatRuntimeV4._basic_action_range.call(self, action)

func _resolve_special_basic_action(attacker_id: String, target_id: String, action: Dictionary) -> Dictionary:
    return VeilleursTacticalCombatRuntimeV4._resolve_special_basic_action.call(self, attacker_id, target_id, action)

func _sync_all_combat_ranks_from_grid() -> void:
    for entity_value: Variant in combatants.keys():
        _sync_combat_rank_from_grid(str(entity_value))

func _sync_combat_rank_from_grid(entity_id: String) -> void:
    if entity_id == "" or not combatants.has(entity_id):
        return
    var position := grid.position_of(entity_id)
    if position.x < 0:
        return
    var row: Dictionary = combatants[entity_id]
    var team := str(row.get("team", ""))
    row["combat_rank"] = clampi(4 - position.x, 1, 4) if team == "watcher" else clampi(6 - position.x, 1, 4)
    combatants[entity_id] = row
