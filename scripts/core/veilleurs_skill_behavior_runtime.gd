extends RefCounted
class_name VeilleursSkillBehaviorRuntime

const DAMAGE_ACTIONS: Array[String] = ["attack", "attack_move"]
const ACTION_OVERRIDES := {
    "SK_MIRA_OEIL_VEILLEUR_05":"attack",
    "SK_MIRA_OEIL_VEILLEUR_14":"attack",
    "SK_MIRA_ANATOMIE_MOUVEMENT_01":"observe",
    "SK_NAREM_BASTION_VIVANT_09":"heal"
}

func effective_action(skill: Dictionary) -> String:
    var skill_id := str(skill.get("skill_id", ""))
    return str(ACTION_OVERRIDES.get(skill_id, skill.get("action_type", "attack")))

func range_for(skill: Dictionary) -> int:
    var action := effective_action(skill)
    var profile := str(skill.get("mechanical_profile", "assault"))
    if action in ["guard", "heal", "support", "passive_modifier", "move"]:
        return 0
    if action == "observe":
        return 4
    if action in ["psychological", "control"]:
        return 3
    if profile == "observe":
        return 4
    return 1

func passive_payload(skill: Dictionary) -> Dictionary:
    var tier := _tier(skill)
    var profile := str(skill.get("mechanical_profile", "assault"))
    var payload := {"profile":profile, "tier":tier, "skill_id":str(skill.get("skill_id", ""))}
    match profile:
        "guard":
            payload["guard_bonus"] = 3 + tier * 2
            payload["forced_move_resist"] = 5 + tier * 4
        "anatomy":
            payload["body_zone_precision"] = 2 + tier * 2
            payload["functional_consequence_bonus"] = tier
        "observe":
            payload["knowledge_retention"] = tier
            payload["precision_against_observed"] = 2 + tier * 2
        "mobility":
            payload["evasion_after_move"] = 2 + tier * 2
        "sustain":
            payload["injury_penalty_suppression"] = tier
        "support":
            payload["ally_guard_bonus"] = 2 + tier
        "psych":
            payload["resolve_pressure_bonus"] = 2 + tier * 2
        _:
            payload["power_bonus"] = tier
    return payload

func resolve_non_damage(runtime: Variant, attacker_id: String, target_id: String, skill: Dictionary, zone: String) -> Dictionary:
    var action := effective_action(skill)
    var tier := _tier(skill)
    var skill_id := str(skill.get("skill_id", ""))
    var attacker: Dictionary = runtime.combatants.get(attacker_id, {})
    var target: Dictionary = runtime.combatants.get(target_id, {})
    var result := {"ok":true, "hit":true, "non_damage":true, "action":action, "attacker":attacker_id, "target":target_id, "skill_id":skill_id, "zone":zone}

    match action:
        "passive_modifier":
            var passives: Dictionary = attacker.get("passive_effects", {})
            passives[skill_id] = passive_payload(skill)
            attacker["passive_effects"] = passives
            runtime.combatants[attacker_id] = attacker
            result["passive_effect"] = passives[skill_id]
        "guard":
            var effect: Dictionary = skill.get("effect_spec", {})
            var guard_amount := maxi(8 + tier * 4, int(effect.get("guard_delta", 0)))
            attacker["guard_bonus"] = maxi(int(attacker.get("guard_bonus", 0)), guard_amount)
            attacker["statuses"] = _apply_status(attacker.get("statuses", {}), "GUARDED", 1 + int(tier >= 4), tier)
            runtime.combatants[attacker_id] = attacker
            result["guard_delta"] = guard_amount
        "heal":
            var before := int(attacker.get("hp", 0))
            var amount := 6 + tier * 4
            attacker["hp"] = mini(int(attacker.get("max_hp", 1)), before + amount)
            attacker["statuses"] = _apply_status(attacker.get("statuses", {}), "STABILIZED", 1, tier)
            runtime.combatants[attacker_id] = attacker
            result["healed"] = int(attacker["hp"]) - before
            result["persistent_injury_healed"] = false
        "support":
            if target.is_empty() or str(target.get("team", "")) != str(attacker.get("team", "")):
                target = attacker
                target_id = attacker_id
                result["target"] = target_id
            target["guard_bonus"] = maxi(int(target.get("guard_bonus", 0)), 5 + tier * 3)
            target["resolve_current"] = mini(int((target.get("stats", {}) as Dictionary).get("RES", 60)), int(target.get("resolve_current", 60)) + 3 + tier * 2)
            if skill_id == "SK_NAREM_GARDIEN_AUTRES_01":
                target["protected_by"] = attacker_id
            runtime.combatants[target_id] = target
            result["guard_delta"] = 5 + tier * 3
            result["resolve_restored"] = 3 + tier * 2
        "observe":
            if target.is_empty():
                return {"ok":false, "reason":"observe_target_missing"}
            var observed_by: Dictionary = target.get("observed_by", {})
            observed_by[attacker_id] = mini(3, maxi(int(observed_by.get(attacker_id, 0)), 1 + int(tier >= 3) + int(tier >= 5)))
            target["observed_by"] = observed_by
            target["statuses"] = _apply_status(target.get("statuses", {}), "OBSERVED", 2 + int(tier >= 4), tier)
            if tier >= 3:
                target["statuses"] = _apply_status(target.get("statuses", {}), "EXPOSED", 1 + int(tier >= 5), tier)
            runtime.combatants[target_id] = target
            result["knowledge_reveal"] = observed_by[attacker_id]
            result["exposed"] = tier >= 3
        "psychological":
            if target.is_empty():
                return {"ok":false, "reason":"psych_target_missing"}
            var resolve_before := int(target.get("resolve_current", (target.get("stats", {}) as Dictionary).get("RES", 60)))
            var pressure := 5 + tier * 3
            target["resolve_current"] = maxi(0, resolve_before - pressure)
            var status := "DOUBT" if tier <= 2 else ("DISORIENTED" if tier <= 4 else "FEAR")
            target["statuses"] = _apply_status(target.get("statuses", {}), status, 1 + int(tier >= 4), tier)
            runtime.combatants[target_id] = target
            result["resolve_delta"] = -pressure
            result["status_applied"] = status
        "control":
            if target.is_empty():
                return {"ok":false, "reason":"control_target_missing"}
            var status := "STAGGER" if tier <= 2 else "PINNED"
            target["statuses"] = _apply_status(target.get("statuses", {}), status, 1, tier)
            runtime.combatants[target_id] = target
            result["status_applied"] = status
        "move":
            var moved := _move_toward(runtime, attacker_id, target_id)
            attacker = runtime.combatants.get(attacker_id, attacker)
            attacker["evasive_bonus"] = maxi(int(attacker.get("evasive_bonus", 0)), 4 + tier * 2)
            runtime.combatants[attacker_id] = attacker
            result["moved"] = moved
            result["evasive_bonus"] = 4 + tier * 2
        "transform":
            attacker["statuses"] = _apply_status(attacker.get("statuses", {}), "ADAPTED", 2, tier)
            attacker["guard_bonus"] = maxi(int(attacker.get("guard_bonus", 0)), 3 + tier * 2)
            runtime.combatants[attacker_id] = attacker
            result["status_applied"] = "ADAPTED"
        _:
            return {"ok":false, "reason":"unsupported_non_damage_action", "action":action}
    runtime.action_log.append(result.duplicate(true))
    return result

func apply_post_damage(runtime: Variant, attacker_id: String, target_id: String, skill: Dictionary, zone: String, result: Dictionary) -> Dictionary:
    if not bool(result.get("ok", false)) or not bool(result.get("hit", false)):
        return result
    var profile := str(skill.get("mechanical_profile", "assault"))
    var tier := _tier(skill)
    var attacker: Dictionary = runtime.combatants.get(attacker_id, {})
    var target: Dictionary = runtime.combatants.get(target_id, {})
    match profile:
        "impact":
            target["statuses"] = _apply_status(target.get("statuses", {}), "STAGGER", 1, tier)
            result["status_applied"] = "STAGGER"
        "anatomy":
            var penalty_key := _functional_penalty_for_zone(zone)
            target[penalty_key] = maxi(int(target.get(penalty_key, 0)), tier * 3)
            if tier >= 3:
                target["statuses"] = _apply_status(target.get("statuses", {}), "EXPOSED", 1, tier)
            result["functional_penalty"] = penalty_key
            result["functional_penalty_value"] = tier * 3
        "mobility":
            attacker["evasive_bonus"] = maxi(int(attacker.get("evasive_bonus", 0)), 3 + tier * 2)
            result["evasive_bonus"] = 3 + tier * 2
        "observe":
            target["statuses"] = _apply_status(target.get("statuses", {}), "EXPOSED", 1 + int(tier >= 4), tier)
            result["status_applied"] = "EXPOSED"
    runtime.combatants[attacker_id] = attacker
    runtime.combatants[target_id] = target
    return result

func decay_round(row: Dictionary) -> Dictionary:
    var result := row.duplicate(true)
    var statuses: Dictionary = result.get("statuses", {})
    var next_statuses: Dictionary = {}
    for key_value: Variant in statuses.keys():
        var key := str(key_value)
        var state: Dictionary = statuses.get(key, {})
        var remaining := int(state.get("remaining", 0)) - 1
        if remaining > 0:
            state["remaining"] = remaining
            next_statuses[key] = state
    result["statuses"] = next_statuses
    result["evasive_bonus"] = 0
    if not next_statuses.has("GUARDED"):
        result["guard_bonus"] = 0
    return result

func _tier(skill: Dictionary) -> int:
    return 1 + int((maxi(1, int(skill.get("skill_index", 1))) - 1) / 3)

func _apply_status(statuses_value: Variant, status: String, duration: int, strength: int) -> Dictionary:
    var statuses: Dictionary = statuses_value.duplicate(true) if statuses_value is Dictionary else {}
    var current: Dictionary = statuses.get(status, {})
    statuses[status] = {"remaining":maxi(duration, int(current.get("remaining", 0))), "strength":maxi(strength, int(current.get("strength", 0)))}
    return statuses

func _functional_penalty_for_zone(zone: String) -> String:
    if zone in ["left_arm", "right_arm"]:
        return "weapon_use_penalty"
    if zone in ["left_leg", "right_leg"]:
        return "mobility_penalty"
    if zone == "head":
        return "perception_penalty"
    return "vigor_penalty"

func _move_toward(runtime: Variant, source_id: String, target_id: String) -> bool:
    if not runtime.combatants.has(target_id):
        return false
    var origin: Vector2i = runtime.grid.position_of(source_id)
    var target: Vector2i = runtime.grid.position_of(target_id)
    var best := Vector2i(-1, -1)
    var best_distance := 999
    for cell: Vector2i in runtime.grid.neighbors(origin):
        if runtime.grid.occupied(cell):
            continue
        var distance := absi(cell.x - target.x) + absi(cell.y - target.y)
        if distance < best_distance:
            best_distance = distance
            best = cell
    return best.x >= 0 and runtime.grid.move(source_id, best)
