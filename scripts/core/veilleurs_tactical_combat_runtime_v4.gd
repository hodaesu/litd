extends "res://scripts/core/veilleurs_tactical_combat_runtime_v3.gd"
class_name VeilleursTacticalCombatRuntimeV4

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]) -> Dictionary:
    var result := super.setup_first_combat(enemy_ids)
    if bool(result.get("ok", false)):
        _sync_all_combat_ranks_from_grid()
    return result

func available_basic_actions(entity_id: String) -> Array[Dictionary]:
    _sync_combat_rank_from_grid(entity_id)
    return super.available_basic_actions(entity_id)

func resolve_basic_action(attacker_id: String, target_id: String, action_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    _sync_combat_rank_from_grid(attacker_id)
    _sync_combat_rank_from_grid(target_id)
    if not combatants.has(attacker_id):
        return {"ok":false, "reason":"unknown_combatant"}
    var attacker: Dictionary = combatants[attacker_id]
    var action: Dictionary = basic_actions.action(attacker_id, attacker, action_id)
    if action.is_empty():
        return {"ok":false, "reason":"basic_action_not_owned", "action_id":action_id}
    var target_type := str(action.get("target", "enemy"))
    if target_type == "self":
        target_id = attacker_id
    if target_id != "" and combatants.has(target_id) and target_type != "self":
        var maximum_range := _basic_action_range(action)
        var distance := grid.distance(attacker_id, target_id)
        if distance > maximum_range:
            return {"ok":false, "reason":"basic_action_out_of_range", "action_id":action_id, "distance":distance, "required_range":maximum_range}
    var kind := str(action.get("kind", ""))
    if kind in ["summon", "copy_buff", "area_denial", "counter"]:
        var special := _resolve_special_basic_action(attacker_id, target_id, action)
        _sync_all_combat_ranks_from_grid()
        return special
    var result := super.resolve_basic_action(attacker_id, target_id, action_id, zone, forced_roll)
    _sync_all_combat_ranks_from_grid()
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    _sync_all_combat_ranks_from_grid()
    var result := super.enemy_step(enemy_id)
    _sync_all_combat_ranks_from_grid()
    return result

func next_round() -> void:
    _sync_all_combat_ranks_from_grid()
    super.next_round()
    _sync_all_combat_ranks_from_grid()

func _resolve_basic_reposition(attacker_id: String, action: Dictionary) -> Dictionary:
    if not combatants.has(attacker_id):
        return {"ok":false, "reason":"unknown_combatant"}
    _sync_combat_rank_from_grid(attacker_id)
    var row: Dictionary = combatants[attacker_id]
    var before := int(row.get("combat_rank", 1))
    var origin := grid.position_of(attacker_id)
    if origin.x < 0:
        return {"ok":false, "reason":"combatant_not_on_grid"}
    var team := str(row.get("team", ""))
    var kind := str(action.get("kind", "reposition"))
    var name := str(action.get("name", "")).to_lower()
    var advance := kind.find("advance") >= 0 or name.find("reprise") >= 0 or name.find("bond") >= 0 or name.find("ruée") >= 0
    var retreat := kind.find("retreat") >= 0 or name.find("recul") >= 0 or name.find("repli") >= 0 or name.find("décrochage") >= 0 or name.find("reflux") >= 0
    var dx := 0
    if advance:
        dx = 1 if team == "watcher" else -1
    elif retreat:
        dx = -1 if team == "watcher" else 1
    else:
        var natural := basic_actions.natural_ranks_for(attacker_id, row)
        if not natural.is_empty():
            var preferred := natural[0]
            if preferred < before:
                dx = 1 if team == "watcher" else -1
            elif preferred > before:
                dx = -1 if team == "watcher" else 1
    if dx == 0:
        return {"ok":false, "reason":"reposition_no_valid_direction", "action_id":str(action.get("id", ""))}
    var destination := Vector2i(origin.x + dx, origin.y)
    if not grid.inside(destination) or grid.occupied(destination):
        return {"ok":false, "reason":"reposition_blocked", "action_id":str(action.get("id", "")), "from":[origin.x, origin.y], "to":[destination.x, destination.y]}
    if not grid.move(attacker_id, destination):
        return {"ok":false, "reason":"reposition_failed", "action_id":str(action.get("id", ""))}
    _sync_combat_rank_from_grid(attacker_id)
    var after := int((combatants[attacker_id] as Dictionary).get("combat_rank", before))
    var result := {"ok":true, "hit":true, "non_damage":true, "basic_action":true, "action_id":str(action.get("id", "")), "basic_action_name":str(action.get("name", "")), "attacker":attacker_id, "target":attacker_id, "rank_before":before, "rank_after":after, "from":[origin.x, origin.y], "to":[destination.x, destination.y]}
    action_log.append(result.duplicate(true))
    return result

func _resolve_special_basic_action(attacker_id: String, target_id: String, action: Dictionary) -> Dictionary:
    var kind := str(action.get("kind", ""))
    var attacker: Dictionary = combatants[attacker_id]
    var result := {"ok":true, "hit":true, "non_damage":true, "basic_action":true, "action_id":str(action.get("id", "")), "basic_action_name":str(action.get("name", "")), "attacker":attacker_id, "target":target_id}
    match kind:
        "summon":
            attacker["statuses"] = _add_status(attacker.get("statuses", {}), "SUMMON_READY", 1, 1)
            combatants[attacker_id] = attacker
            result["status_applied"] = "SUMMON_READY"
            result["summon_request"] = true
        "copy_buff":
            if target_id == "" or not combatants.has(target_id):
                return {"ok":false, "reason":"copy_target_missing"}
            var target: Dictionary = combatants[target_id]
            attacker["guard_bonus"] = int(target.get("guard_bonus", 0))
            attacker["statuses"] = (target.get("statuses", {}) as Dictionary).duplicate(true)
            combatants[attacker_id] = attacker
            result["copied_guard"] = int(attacker.get("guard_bonus", 0))
            result["copied_statuses"] = (attacker.get("statuses", {}) as Dictionary).keys()
        "area_denial":
            var affected: Array[String] = []
            for enemy_id: String in alive_ids("watcher" if str(attacker.get("team", "")) == "enemy" else "enemy"):
                if grid.distance(attacker_id, enemy_id) <= _basic_action_range(action):
                    var row: Dictionary = combatants[enemy_id]
                    row["statuses"] = _add_status(row.get("statuses", {}), "SUPPRESSED", 1, 1)
                    combatants[enemy_id] = row
                    affected.append(enemy_id)
            result["affected"] = affected
            result["status_applied"] = "SUPPRESSED"
        "counter":
            attacker["statuses"] = _add_status(attacker.get("statuses", {}), "RIPOSTE", 1, 1)
            combatants[attacker_id] = attacker
            result["status_applied"] = "RIPOSTE"
        _:
            return {"ok":false, "reason":"unsupported_special_basic_action", "kind":kind}
    action_log.append(result.duplicate(true))
    return result

func _basic_action_range(action: Dictionary) -> int:
    var kind := str(action.get("kind", ""))
    if str(action.get("target", "enemy")) == "self":
        return 0
    if str(action.get("target", "enemy")) == "ally":
        return 1
    if kind in ["ranged_damage", "ranged_burn", "mark", "fear", "madness_pressure", "debuff", "group_debuff", "timeline_control", "accuracy_control", "precision_setup", "area_denial", "summon"]:
        return 5
    if kind in ["observation_offense", "diagnostic_debuff", "coordination", "adaptive_attack", "copy_buff", "psychological"]:
        return 4
    if kind.find("ranged") >= 0:
        return 5
    if kind.find("advance_attack") >= 0 or kind.find("retreat_attack") >= 0:
        return 3
    if kind in ["pull", "grab", "limb_control", "stability_control", "interrupt", "control", "damage_interrupt"]:
        return 2
    return 1

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
    row["combat_rank"] = _rank_from_grid_x(team, position.x)
    combatants[entity_id] = row

func _rank_from_grid_x(team: String, x: int) -> int:
    if team == "watcher":
        return clampi(4 - x, 1, 4)
    return clampi(6 - x, 1, 4)
