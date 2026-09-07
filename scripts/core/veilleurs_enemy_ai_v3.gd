extends "res://scripts/core/veilleurs_enemy_ai_v2.gd"
class_name VeilleursEnemyAIV3

const PSYCH_ROLES: Array[String] = ["psych", "psych_support"]
const CONTROL_ROLES: Array[String] = ["controller", "controller_tank"]
const ANATOMY_ROLES: Array[String] = ["anatomy", "execution", "hunter"]

func decide(runtime: Variant, enemy_id: String) -> Dictionary:
    var decision: Dictionary = super.decide(runtime, enemy_id)
    if str(decision.get("action", "")) != "attack":
        return decision
    var enemy: Dictionary = runtime.combatants.get(enemy_id, {})
    var role := str(enemy.get("combat_role", "assault"))
    var target_id := str(decision.get("target", ""))
    if target_id == "" or not runtime.combatants.has(target_id):
        return decision

    var memory := _memory_state(enemy)
    var stage := str(memory.get("stage", enemy.get("remanence_stage", "normal")))
    var adaptations: Array = memory.get("adaptations", enemy.get("adaptations", []))
    var memory_target := _memory_adjusted_target(runtime, enemy_id, target_id, stage, adaptations)
    if memory_target != "":
        target_id = memory_target
        decision["target"] = target_id

    decision["zone"] = _preferred_zone(runtime.combatants[target_id], role, stage)
    decision["attack_kind"] = "psych" if PSYCH_ROLES.has(role) else ("control" if CONTROL_ROLES.has(role) else "physical")
    decision["memory_stage"] = stage
    decision["adaptations"] = adaptations.duplicate()
    decision["memory_used"] = stage in ["veteran", "elite", "nemesis"] or not adaptations.is_empty()
    if bool(decision["memory_used"]):
        decision["reason"] = "%s+remanence" % str(decision.get("reason", "tactical_attack"))
    return decision

func _memory_state(enemy: Dictionary) -> Dictionary:
    var remanence_id := str(enemy.get("remanence_id", ""))
    if remanence_id == "" or RemanenceRuntime == null:
        return {}
    return RemanenceRuntime.entity_state(remanence_id)

func _memory_adjusted_target(runtime: Variant, enemy_id: String, current_target: String, stage: String, adaptations: Array) -> String:
    if stage not in ["veteran", "elite", "nemesis"] and adaptations.is_empty():
        return current_target
    var candidates: Array[String] = runtime.alive_ids("watcher")
    if candidates.is_empty():
        return current_target
    if adaptations.has("avoid_guard"):
        var least_guarded := current_target
        var best_guard := 9999
        for candidate: String in candidates:
            var row: Dictionary = runtime.combatants[candidate]
            var guard := int(row.get("guard_bonus", 0))
            if guard < best_guard:
                best_guard = guard
                least_guarded = candidate
        return least_guarded
    if adaptations.has("pressure_wounded") or stage in ["elite", "nemesis"]:
        var weakest := current_target
        var lowest_ratio := 2.0
        for candidate: String in candidates:
            var row: Dictionary = runtime.combatants[candidate]
            var ratio := float(row.get("hp", 0)) / maxf(1.0, float(row.get("max_hp", 1)))
            if ratio < lowest_ratio:
                lowest_ratio = ratio
                weakest = candidate
        return weakest
    if stage == "veteran" and _recent_target_count(runtime, enemy_id, current_target) >= 2:
        var alternatives: Array[String] = []
        for candidate: String in candidates:
            if candidate != current_target:
                alternatives.append(candidate)
        if not alternatives.is_empty():
            alternatives.sort()
            return alternatives[posmod(enemy_id.hash() + runtime.round_index, alternatives.size())]
    return current_target

func _recent_target_count(runtime: Variant, enemy_id: String, target_id: String) -> int:
    var count := 0
    var checked := 0
    for index in range(runtime.action_log.size() - 1, -1, -1):
        var row: Dictionary = runtime.action_log[index]
        if str(row.get("attacker", row.get("enemy", ""))) != enemy_id:
            continue
        checked += 1
        if str(row.get("target", "")) == target_id:
            count += 1
        if checked >= 4:
            break
    return count

func _preferred_zone(target: Dictionary, role: String, stage: String) -> String:
    if PSYCH_ROLES.has(role):
        return "head"
    if role == "hunter":
        return _weaker_of(target, "left_leg", "right_leg")
    if ANATOMY_ROLES.has(role):
        return _most_injured_zone(target)
    if role == "ranged":
        return "right_arm" if stage in ["veteran", "elite", "nemesis"] else "torso"
    return "torso"

func _most_injured_zone(target: Dictionary) -> String:
    var body: Variant = target.get("body")
    if body == null or not body.has_method("serialize"):
        return "torso"
    var states: Dictionary = (body.call("serialize") as Dictionary).get("states", {})
    var best := "torso"
    var best_level := -1
    for zone_value: Variant in states.keys():
        var zone := str(zone_value)
        var state := str(states.get(zone, "L0"))
        var level := int(state.trim_prefix("L")) if state.begins_with("L") else 0
        if level > best_level:
            best_level = level
            best = zone
    return best

func _weaker_of(target: Dictionary, a: String, b: String) -> String:
    var body: Variant = target.get("body")
    if body == null or not body.has_method("serialize"):
        return a
    var states: Dictionary = (body.call("serialize") as Dictionary).get("states", {})
    var a_level := int(str(states.get(a, "L0")).trim_prefix("L"))
    var b_level := int(str(states.get(b, "L0")).trim_prefix("L"))
    return a if a_level >= b_level else b
