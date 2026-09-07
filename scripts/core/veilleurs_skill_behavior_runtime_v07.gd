extends "res://scripts/core/veilleurs_skill_behavior_runtime.gd"
class_name VeilleursSkillBehaviorRuntimeV07

func range_for(skill: Dictionary) -> int:
    var explicit_range := int(skill.get("range", 0))
    if explicit_range > 0:
        return explicit_range
    return super.range_for(skill)

func resolve_non_damage(runtime: Variant, attacker_id: String, target_id: String, skill: Dictionary, zone: String) -> Dictionary:
    var result: Dictionary = super.resolve_non_damage(runtime, attacker_id, target_id, skill, zone)
    if not bool(result.get("ok", false)):
        return result
    var profile := str(skill.get("mechanical_profile", ""))
    var tier := 1 + int((maxi(1, int(skill.get("skill_index", 1))) - 1) / 3)
    var attacker: Dictionary = runtime.combatants.get(attacker_id, {})
    var target: Dictionary = runtime.combatants.get(target_id, {})
    match profile:
        "pull":
            var pulled := _pull_toward(runtime, attacker_id, target_id)
            result["pulled"] = pulled
            if pulled:
                target = runtime.combatants.get(target_id, target)
                target["statuses"] = _apply_status(target.get("statuses", {}), "PINNED", 1, tier)
                runtime.combatants[target_id] = target
        "terrain":
            if runtime.grid != null and runtime.has_method("register_terrain_effect"):
                var cell: Vector2i = runtime.grid.position_of(target_id)
                result["terrain_effect"] = runtime.call("register_terrain_effect", cell, str(skill.get("skill_id", "")), attacker_id, 2 + int(tier >= 4))
        "summon":
            if runtime.has_method("request_summon"):
                result["summon_request"] = runtime.call("request_summon", attacker_id, 1 + int(tier >= 4), str(skill.get("skill_id", "")))
        "sustain":
            attacker["statuses"] = _apply_status(attacker.get("statuses", {}), "STABILIZED", 2, tier)
            attacker["guard_bonus"] = maxi(int(attacker.get("guard_bonus", 0)), 4 + tier * 2)
            runtime.combatants[attacker_id] = attacker
            result["injury_penalty_suppression"] = tier
        "adaptive":
            var observed_tag := _last_observed_watcher_action(runtime)
            attacker["statuses"] = _apply_status(attacker.get("statuses", {}), "ADAPTED", 2, tier)
            attacker["accuracy_bonus"] = maxi(int(attacker.get("accuracy_bonus", 0)), tier * 2)
            runtime.combatants[attacker_id] = attacker
            result["adapted_to"] = observed_tag
        "tank", "guard":
            attacker["forced_move_resist"] = maxi(int(attacker.get("forced_move_resist", 0)), 10 + tier * 6)
            runtime.combatants[attacker_id] = attacker
            result["forced_move_resist"] = int(attacker["forced_move_resist"])
    return result

func apply_post_damage(runtime: Variant, attacker_id: String, target_id: String, skill: Dictionary, zone: String, result: Dictionary) -> Dictionary:
    result = super.apply_post_damage(runtime, attacker_id, target_id, skill, zone, result)
    if not bool(result.get("ok", false)) or not bool(result.get("hit", false)):
        return result
    var profile := str(skill.get("mechanical_profile", "assault"))
    var tier := 1 + int((maxi(1, int(skill.get("skill_index", 1))) - 1) / 3)
    var attacker: Dictionary = runtime.combatants.get(attacker_id, {})
    var target: Dictionary = runtime.combatants.get(target_id, {})
    match profile:
        "hunter":
            if _body_is_wounded(target):
                target["statuses"] = _apply_status(target.get("statuses", {}), "MARKED", 2, tier)
                result["status_applied"] = "MARKED"
                result["wound_exploited"] = true
        "execution":
            if float(target.get("hp", 0)) / maxf(1.0, float(target.get("max_hp", 1))) <= 0.40:
                target["statuses"] = _apply_status(target.get("statuses", {}), "EXPOSED", 1, tier)
                result["status_applied"] = "EXPOSED"
                result["execution_window"] = true
        "drain":
            var heal_amount := maxi(1, int(round(float(result.get("damage", 0)) * (0.18 + 0.03 * tier))))
            var before := int(attacker.get("hp", 0))
            attacker["hp"] = mini(int(attacker.get("max_hp", 1)), before + heal_amount)
            result["drain_healed"] = int(attacker["hp"]) - before
            if tier >= 3:
                target["statuses"] = _apply_status(target.get("statuses", {}), "BLEED", 2, tier)
                result["status_applied"] = "BLEED"
        "contaminate":
            target["statuses"] = _apply_status(target.get("statuses", {}), "CONTAMINATED", 2 + int(tier >= 4), tier)
            result["status_applied"] = "CONTAMINATED"
        "ranged":
            if tier >= 3:
                target["statuses"] = _apply_status(target.get("statuses", {}), "MARKED", 1, tier)
                result["status_applied"] = "MARKED"
        "area":
            target["statuses"] = _apply_status(target.get("statuses", {}), "STAGGER", 1, tier)
            result["status_applied"] = "STAGGER"
            result["splash"] = _apply_splash(runtime, attacker_id, target_id, maxi(1, int(round(float(result.get("damage", 1)) * 0.35))))
        "terrain":
            target["statuses"] = _apply_status(target.get("statuses", {}), "PINNED", 1, tier)
            result["status_applied"] = "PINNED"
            if runtime.has_method("register_terrain_effect"):
                result["terrain_effect"] = runtime.call("register_terrain_effect", runtime.grid.position_of(target_id), str(skill.get("skill_id", "")), attacker_id, 2 + int(tier >= 4))
        "risk":
            var self_cost := maxi(1, int(round(float(attacker.get("max_hp", 1)) * (0.02 + 0.01 * tier))))
            attacker["hp"] = maxi(1, int(attacker.get("hp", 1)) - self_cost)
            result["self_cost"] = self_cost
        "impact":
            target["forced_move_resist"] = maxi(0, int(target.get("forced_move_resist", 0)) - tier * 3)
            result["guard_break"] = tier * 3
    runtime.combatants[attacker_id] = attacker
    runtime.combatants[target_id] = target
    return result

func _apply_splash(runtime: Variant, attacker_id: String, primary_target_id: String, damage: int) -> Array:
    var affected: Array = []
    if not runtime.combatants.has(primary_target_id):
        return affected
    var target_team := str((runtime.combatants[primary_target_id] as Dictionary).get("team", ""))
    for entity_id_value: Variant in runtime.combatants.keys():
        var entity_id := str(entity_id_value)
        if entity_id == primary_target_id or entity_id == attacker_id:
            continue
        var row: Dictionary = runtime.combatants[entity_id]
        if str(row.get("team", "")) != target_team or int(row.get("hp", 0)) <= 0:
            continue
        if runtime.grid.distance(primary_target_id, entity_id) > 1:
            continue
        row["hp"] = maxi(0, int(row.get("hp", 1)) - damage)
        var body: Variant = row.get("body")
        if body != null and body.has_method("apply_trauma"):
            body.call("apply_trauma", "torso", maxi(1, int(round(float(damage) * 0.65))))
        runtime.combatants[entity_id] = row
        affected.append({"entity_id":entity_id, "damage":damage, "hp":int(row["hp"])})
    return affected

func _pull_toward(runtime: Variant, attacker_id: String, target_id: String) -> bool:
    if not runtime.combatants.has(attacker_id) or not runtime.combatants.has(target_id):
        return false
    var attacker_pos: Vector2i = runtime.grid.position_of(attacker_id)
    var target_pos: Vector2i = runtime.grid.position_of(target_id)
    var best := Vector2i(-1, -1)
    var best_distance := runtime.grid.distance(attacker_id, target_id)
    for cell: Vector2i in runtime.grid.neighbors(target_pos):
        if runtime.grid.occupied(cell):
            continue
        var distance := absi(cell.x - attacker_pos.x) + absi(cell.y - attacker_pos.y)
        if distance < best_distance:
            best_distance = distance
            best = cell
    return best.x >= 0 and runtime.grid.move(target_id, best)

func _last_observed_watcher_action(runtime: Variant) -> String:
    for index: int in range(runtime.action_log.size() - 1, -1, -1):
        var row: Dictionary = runtime.action_log[index]
        var attacker_id := str(row.get("attacker", ""))
        if runtime.combatants.has(attacker_id) and str((runtime.combatants[attacker_id] as Dictionary).get("team", "")) == "watcher":
            return str(row.get("action", row.get("skill_id", "unknown")))
    return "none_observed"

func _body_is_wounded(row: Dictionary) -> bool:
    var body: Variant = row.get("body")
    if body == null or not body.has_method("serialize"):
        return int(row.get("hp", 0)) < int(row.get("max_hp", 1))
    var payload: Dictionary = body.call("serialize") as Dictionary
    for state_value: Variant in (payload.get("states", {}) as Dictionary).values():
        if str(state_value) != "L0":
            return true
    return false
