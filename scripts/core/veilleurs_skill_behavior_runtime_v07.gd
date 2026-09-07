extends "res://scripts/core/veilleurs_skill_behavior_runtime.gd"
class_name VeilleursSkillBehaviorRuntimeV07

func range_for(skill: Dictionary) -> int:
    var explicit_range := int(skill.get("range", 0))
    if explicit_range > 0:
        return explicit_range
    return super.range_for(skill)

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
        "terrain":
            target["statuses"] = _apply_status(target.get("statuses", {}), "PINNED", 1, tier)
            result["status_applied"] = "PINNED"
        "risk":
            var self_cost := maxi(1, int(round(float(attacker.get("max_hp", 1)) * (0.02 + 0.01 * tier))))
            attacker["hp"] = maxi(1, int(attacker.get("hp", 1)) - self_cost)
            result["self_cost"] = self_cost
    runtime.combatants[attacker_id] = attacker
    runtime.combatants[target_id] = target
    return result

func _body_is_wounded(row: Dictionary) -> bool:
    var body: Variant = row.get("body")
    if body == null or not body.has_method("serialize"):
        return int(row.get("hp", 0)) < int(row.get("max_hp", 1))
    var payload: Dictionary = body.call("serialize") as Dictionary
    for state_value: Variant in (payload.get("states", {}) as Dictionary).values():
        if str(state_value) != "L0":
            return true
    return false
