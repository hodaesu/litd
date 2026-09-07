extends "res://scripts/core/veilleurs_tactical_combat_runtime.gd"
class_name VeilleursTacticalCombatRuntimeV2

const BEHAVIOR_SCRIPT := preload("res://scripts/core/veilleurs_skill_behavior_runtime.gd")
const AI_V3_SCRIPT := preload("res://scripts/core/veilleurs_enemy_ai_v3.gd")

var skill_behavior: VeilleursSkillBehaviorRuntime

func _init() -> void:
    super()
    skill_behavior = BEHAVIOR_SCRIPT.new() as VeilleursSkillBehaviorRuntime
    enemy_ai = AI_V3_SCRIPT.new() as VeilleursEnemyAIV3

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]) -> Dictionary:
    var result: Dictionary = super.setup_first_combat(enemy_ids)
    if not bool(result.get("ok", false)):
        return result
    var balance: Dictionary = content_db.combat_constants.get("v061_balance", {})
    for entity_id_value: Variant in combatants.keys():
        var entity_id := str(entity_id_value)
        var row: Dictionary = combatants[entity_id]
        var stats: Dictionary = row.get("stats", {})
        row["resolve_current"] = int(stats.get("RES", 60))
        row["statuses"] = {}
        row["passive_effects"] = {}
        row["observed_by"] = {}
        row["guard_bonus"] = 0
        row["evasive_bonus"] = 0
        row["adaptations"] = []
        row["weapon_power"] = int(balance.get("watcher_weapon_power", 30)) if str(row.get("team", "")) == "watcher" else int(balance.get("enemy_weapon_power", 42))
        combatants[entity_id] = row
    return result

func resolve_skill(attacker_id: String, target_id: String, skill_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    if not combatants.has(attacker_id) or not combatants.has(target_id):
        return {"ok":false, "reason":"unknown_combatant"}
    var skill: Dictionary = content_db.skill(skill_id)
    if skill.is_empty() or str(skill.get("entity_id", "")) != attacker_id:
        return {"ok":false, "reason":"skill_not_owned"}
    var action := skill_behavior.effective_action(skill)
    if action in ["passive_modifier", "guard", "heal", "support", "observe", "psychological", "control", "move", "transform"]:
        return skill_behavior.resolve_non_damage(self, attacker_id, target_id, skill, zone)

    if action == "attack_move" and grid.distance(attacker_id, target_id) > 1:
        var move_skill := skill.duplicate(true)
        move_skill["action_type"] = "move"
        var move_result := skill_behavior.resolve_non_damage(self, attacker_id, target_id, move_skill, zone)
        if not bool(move_result.get("ok", false)):
            return move_result
        if grid.distance(attacker_id, target_id) > 1:
            move_result["attack_deferred"] = true
            move_result["skill_id"] = skill_id
            return move_result

    var required_range := skill_behavior.range_for(skill)
    var current_distance := grid.distance(attacker_id, target_id)
    if current_distance < 0 or current_distance > required_range:
        return {"ok":false, "reason":"out_of_range", "distance":current_distance, "required_range":required_range, "skill_id":skill_id}
    return _resolve_damage_v2(attacker_id, target_id, skill, zone, forced_roll)

func enemy_step(enemy_id: String) -> Dictionary:
    if not combatants.has(enemy_id) or str((combatants[enemy_id] as Dictionary).get("team", "")) != "enemy":
        return {"ok":false, "reason":"not_enemy"}
    var decision: Dictionary = enemy_ai.decide(self, enemy_id)
    var action := str(decision.get("action", "none"))
    match action:
        "attack":
            var target_id := str(decision.get("target", ""))
            if target_id == "" or not combatants.has(target_id):
                return {"ok":false, "reason":"ai_invalid_target"}
            return _enemy_role_attack(enemy_id, target_id, decision)
        "move", "flee":
            var cell_value: Variant = decision.get("cell", Vector2i(-1, -1))
            if not (cell_value is Vector2i):
                return {"ok":false, "reason":"ai_invalid_cell"}
            var cell: Vector2i = cell_value
            if cell.x >= 0 and grid.move(enemy_id, cell):
                var move_result := {"ok":true, "action":action, "enemy":enemy_id, "target":str(decision.get("target", "")), "to":[cell.x, cell.y], "decision_reason":str(decision.get("reason", ""))}
                action_log.append(move_result.duplicate(true))
                return move_result
            return {"ok":false, "reason":"ai_move_blocked"}
        "support":
            return _enemy_support(enemy_id, str(decision.get("target", "")), str(decision.get("reason", "ally_critical")))
        "hold":
            var hold := {"ok":true, "action":"hold", "enemy":enemy_id, "target":str(decision.get("target", "")), "decision_reason":str(decision.get("reason", "blocked"))}
            action_log.append(hold.duplicate(true))
            return hold
        _:
            return {"ok":false, "reason":str(decision.get("reason", "ai_no_action"))}

func next_round() -> void:
    for entity_id_value: Variant in combatants.keys():
        var entity_id := str(entity_id_value)
        combatants[entity_id] = skill_behavior.decay_round(combatants[entity_id])
    super.next_round()

func apply_remanence_state(enemy_id: String, remanence_id: String) -> void:
    if not combatants.has(enemy_id) or remanence_id == "":
        return
    var state: Dictionary = RemanenceRuntime.entity_state(remanence_id)
    if state.is_empty():
        return
    var row: Dictionary = combatants[enemy_id]
    row["remanence_id"] = remanence_id
    row["remanence_stage"] = str(state.get("stage", "normal"))
    row["adaptations"] = (state.get("adaptations", []) as Array).duplicate()
    combatants[enemy_id] = row

func behavior_coverage() -> Dictionary:
    var actions: Dictionary = {}
    var passives := 0
    var total := 0
    for watcher_id: String in WATCHER_IDS:
        for value: Variant in content_db.skills_for(watcher_id):
            if not (value is Dictionary):
                continue
            var skill: Dictionary = value
            total += 1
            var action := skill_behavior.effective_action(skill)
            actions[action] = int(actions.get(action, 0)) + 1
            if action == "passive_modifier":
                passives += 1
    return {"skills":total, "actions":actions, "passives":passives, "complete":total == 180}

func _resolve_damage_v2(attacker_id: String, target_id: String, skill: Dictionary, zone: String, forced_roll: int) -> Dictionary:
    var attacker: Dictionary = combatants[attacker_id]
    var target: Dictionary = combatants[target_id]
    var chance := _hit_chance(attacker, target, skill, zone)
    chance += int(attacker.get("accuracy_bonus", 0))
    chance -= int(target.get("evasive_bonus", 0))
    if _has_status(target, "EXPOSED"):
        chance += 8
    var clamps: Dictionary = content_db.combat_constants.get("hit_clamp", {})
    chance = clampi(chance, int(clamps.get("min_percent", 10)), int(clamps.get("max_percent", 97)))
    var roll := forced_roll if forced_roll >= 1 else _deterministic_roll(attacker_id, target_id, str(skill.get("skill_id", "")))
    var result := {"ok":true, "hit":roll <= chance, "roll":roll, "hit_chance":chance, "attacker":attacker_id, "target":target_id, "skill_id":str(skill.get("skill_id", "")), "zone":zone, "action":skill_behavior.effective_action(skill)}
    if not bool(result["hit"]):
        action_log.append(result.duplicate(true))
        return result

    var damage := _skill_damage(attacker, target, skill)
    var redirected := _redirect_damage_if_protected(target_id, damage)
    damage = int(redirected.get("remaining", damage))
    target = combatants[target_id]
    target["hp"] = maxi(0, int(target.get("hp", 1)) - damage)
    var effect: Dictionary = skill.get("effect_spec", {})
    var trauma_multiplier := maxf(0.45, float(effect.get("trauma_multiplier", 1.0)))
    var trauma := maxi(1, int(round(float(damage) * trauma_multiplier)))
    var dismemberment: Dictionary = skill.get("dismemberment_rules", {})
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    var body_result := body.apply_trauma(zone, trauma, int(dismemberment.get("power", 0)), 3)
    result["damage"] = damage
    result["target_hp"] = int(target["hp"])
    result["body"] = body_result
    if bool(redirected.get("redirected", false)):
        result["protection_redirect"] = redirected
    var forced_move := int(effect.get("forced_move", 0))
    if forced_move > 0:
        result["forced_move"] = _push_away(attacker_id, target_id, forced_move)
    combatants[target_id] = target
    result = skill_behavior.apply_post_damage(self, attacker_id, target_id, skill, zone, result)
    action_log.append(result.duplicate(true))
    return result

func _skill_damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
    var attacker_stats: Dictionary = attacker.get("stats", {})
    var effect: Dictionary = skill.get("effect_spec", {})
    var multiplier := float(effect.get("damage_multiplier", 0.0))
    if multiplier <= 0.0:
        multiplier = 0.75 + float(maxi(1, int(skill.get("skill_index", 1))) - 1) / 28.0
    var attack_power := float(attacker.get("weapon_power", 25)) * multiplier * (0.70 + float(attacker_stats.get("FOR", 50)) / 200.0)
    var armor := float(target.get("armor", 0)) + float(target.get("guard_bonus", 0))
    if _has_status(target, "EXPOSED"):
        armor *= 0.80
    var reduction := armor / (armor + 100.0)
    return maxi(1, int(round(attack_power * (1.0 - reduction))))

func _enemy_role_attack(attacker_id: String, target_id: String, decision: Dictionary) -> Dictionary:
    var attacker: Dictionary = combatants[attacker_id]
    var target: Dictionary = combatants[target_id]
    var stats: Dictionary = attacker.get("stats", {})
    var target_stats: Dictionary = target.get("stats", {})
    var attack_kind := str(decision.get("attack_kind", "physical"))
    var zone := str(decision.get("zone", "torso"))
    var chance := 70 + int(round((float(stats.get("PRE", 50)) - float(target_stats.get("MOB", 50))) * 0.35))
    chance -= int(target.get("evasive_bonus", 0))
    chance = clampi(chance, 15, 95)
    var roll := _deterministic_roll(attacker_id, target_id, "%s:%s" % [attack_kind, zone])
    var result := {"ok":true, "action":"attack", "attacker":attacker_id, "target":target_id, "attack_kind":attack_kind, "zone":zone, "roll":roll, "hit_chance":chance, "hit":roll <= chance, "decision_reason":str(decision.get("reason", "tactical_attack")), "memory_used":bool(decision.get("memory_used", false))}
    if not bool(result["hit"]):
        action_log.append(result.duplicate(true))
        return result

    if attack_kind == "psych":
        var before_resolve := int(target.get("resolve_current", target_stats.get("RES", 60)))
        var pressure := 8 + int(stats.get("TEC", 50) / 18)
        target["resolve_current"] = maxi(0, before_resolve - pressure)
        target["statuses"] = _add_status(target.get("statuses", {}), "FEAR" if int(target["resolve_current"]) <= 20 else "DISORIENTED", 1, 2)
        combatants[target_id] = target
        result["resolve_delta"] = -pressure
        result["target_resolve"] = int(target["resolve_current"])
        action_log.append(result.duplicate(true))
        return result

    var role := str(attacker.get("combat_role", "assault"))
    var role_multiplier := 1.15 if role in ["brute", "execution"] else (0.92 if role == "ranged" else 1.0)
    var armor := float(target.get("armor", 0)) + float(target.get("guard_bonus", 0))
    var reduction := armor / (armor + 100.0)
    var damage := maxi(1, int(round(float(attacker.get("weapon_power", 20)) * role_multiplier * (1.0 - reduction))))
    var redirected := _redirect_damage_if_protected(target_id, damage)
    damage = int(redirected.get("remaining", damage))
    target = combatants[target_id]
    target["hp"] = maxi(0, int(target.get("hp", 1)) - damage)
    target["guard_bonus"] = 0
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    result["damage"] = damage
    result["target_hp"] = int(target["hp"])
    result["body"] = body.apply_trauma(zone, maxi(1, int(round(float(damage) * (0.95 if attack_kind == "control" else 0.80)))))
    if attack_kind == "control":
        target["statuses"] = _add_status(target.get("statuses", {}), "PINNED", 1, 2)
        result["status_applied"] = "PINNED"
    if bool(redirected.get("redirected", false)):
        result["protection_redirect"] = redirected
    combatants[target_id] = target
    action_log.append(result.duplicate(true))
    return result

func _redirect_damage_if_protected(target_id: String, incoming: int) -> Dictionary:
    var target: Dictionary = combatants.get(target_id, {})
    var protector_id := str(target.get("protected_by", ""))
    if protector_id == "" or not combatants.has(protector_id) or protector_id == target_id:
        return {"redirected":false, "remaining":incoming}
    var protector: Dictionary = combatants[protector_id]
    if int(protector.get("hp", 0)) <= 0 or grid.distance(protector_id, target_id) > 1:
        return {"redirected":false, "remaining":incoming}
    var redirected := maxi(1, int(round(float(incoming) * 0.30)))
    protector["hp"] = maxi(0, int(protector.get("hp", 1)) - redirected)
    combatants[protector_id] = protector
    return {"redirected":true, "protector":protector_id, "amount":redirected, "remaining":maxi(0, incoming - redirected)}

func _has_status(row: Dictionary, status: String) -> bool:
    return (row.get("statuses", {}) as Dictionary).has(status)

func _add_status(statuses_value: Variant, status: String, duration: int, strength: int) -> Dictionary:
    var statuses: Dictionary = statuses_value.duplicate(true) if statuses_value is Dictionary else {}
    statuses[status] = {"remaining":duration, "strength":strength}
    return statuses
