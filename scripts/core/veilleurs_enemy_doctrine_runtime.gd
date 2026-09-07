extends RefCounted
class_name VeilleursEnemyDoctrineRuntime

const DATA_PATH := "res://data/veilleurs/v08/enemy_doctrines_24.json"

var data: Dictionary = {}
var load_errors: Array[String] = []

func _init() -> void:
    reload()

func reload() -> void:
    load_errors.clear()
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not (parsed is Dictionary):
        data = {}
        load_errors.append("enemy_doctrines_parse")
        return
    data = (parsed as Dictionary).duplicate(true)
    var rows: Dictionary = data.get("enemies", {})
    if rows.size() != 24:
        load_errors.append("enemy_doctrines_count:%d" % rows.size())

func doctrine(enemy_id: String) -> Dictionary:
    return ((data.get("enemies", {}) as Dictionary).get(enemy_id, {}) as Dictionary).duplicate(true)

func score_skill(runtime: Variant, enemy_id: String, skill: Dictionary, decision: Dictionary) -> int:
    var row: Dictionary = runtime.combatants.get(enemy_id, {})
    var rule := doctrine(str(row.get("definition_id", enemy_id)))
    if rule.is_empty():
        rule = doctrine(enemy_id)
    var profile := str(skill.get("mechanical_profile", "assault"))
    var action := str(runtime.skill_behavior.effective_action(skill))
    var score := 10
    var preferred: Array = rule.get("preferred_profiles", [])
    var profile_index := preferred.find(profile)
    if profile_index >= 0:
        score += 18 - profile_index * 5
    var desired_action := str(decision.get("action", "attack"))
    if desired_action == "support" and action in ["support", "heal", "guard"]:
        score += 14
    elif desired_action == "attack" and action in ["attack", "attack_move", "control", "psychological"]:
        score += 8
    elif desired_action in ["move", "flee"] and action in ["move", "attack_move"]:
        score += 8
    score += _target_context_score(runtime, enemy_id, skill, decision, rule)
    score += _memory_score(row, profile, decision)
    score += int(skill.get("skill_index", 1)) / 3
    return score

func should_retreat(runtime: Variant, enemy_id: String) -> bool:
    if not runtime.combatants.has(enemy_id):
        return false
    var row: Dictionary = runtime.combatants[enemy_id]
    var definition_id := str(row.get("definition_id", enemy_id))
    var rule := doctrine(definition_id)
    if rule.is_empty():
        rule = doctrine(enemy_id)
    var threshold := float(rule.get("retreat_hp_ratio", 0.18))
    var stage := str(row.get("remanence_stage", "normal"))
    if stage in ["elite", "nemesis"]:
        threshold *= 0.65
    var hp_ratio := float(row.get("hp", 0)) / maxf(1.0, float(row.get("max_hp", 1)))
    return hp_ratio > 0.0 and hp_ratio <= threshold

func target_priority_bonus(runtime: Variant, enemy_id: String, target_id: String) -> int:
    if not runtime.combatants.has(enemy_id) or not runtime.combatants.has(target_id):
        return 0
    var enemy: Dictionary = runtime.combatants[enemy_id]
    var target: Dictionary = runtime.combatants[target_id]
    var rule := doctrine(str(enemy.get("definition_id", enemy_id)))
    if rule.is_empty():
        rule = doctrine(enemy_id)
    var bonus := 0
    for priority_value: Variant in rule.get("target_priority", []):
        bonus += _priority_bonus(str(priority_value), target, runtime, target_id)
    return bonus

func _target_context_score(runtime: Variant, enemy_id: String, skill: Dictionary, decision: Dictionary, rule: Dictionary) -> int:
    var target_id := str(decision.get("target", ""))
    if target_id == "" or not runtime.combatants.has(target_id):
        return 0
    var score := target_priority_bonus(runtime, enemy_id, target_id)
    var target: Dictionary = runtime.combatants[target_id]
    var profile := str(skill.get("mechanical_profile", ""))
    var statuses: Dictionary = target.get("statuses", {})
    if profile == "execution" and float(target.get("hp", 0)) / maxf(1.0, float(target.get("max_hp", 1))) <= 0.40:
        score += 15
    if profile in ["hunter", "anatomy"] and _body_wounded(target):
        score += 12
    if profile == "drain" and int(target.get("hp", 0)) > 0:
        score += 6
    if profile == "ranged" and runtime.grid.distance(enemy_id, target_id) >= 2:
        score += 10
    if profile in ["area", "terrain"] and _adjacent_allies(runtime, target_id) >= 1:
        score += 8
    if profile == "contaminate" and not statuses.has("CONTAMINATED"):
        score += 8
    if profile == "observe" and not statuses.has("OBSERVED"):
        score += 7
    return score

func _memory_score(row: Dictionary, profile: String, decision: Dictionary) -> int:
    var stage := str(row.get("remanence_stage", "normal"))
    var modifiers: Dictionary = (data.get("stage_modifiers", {}) as Dictionary).get(stage, {})
    var score := int(modifiers.get("memory_weight", 0)) if bool(decision.get("memory_used", false)) else 0
    var adaptations: Array = row.get("adaptations", [])
    if adaptations.has("pressure_wounded") and profile in ["hunter", "execution", "anatomy"]:
        score += int(modifiers.get("adaptation_weight", 0))
    if adaptations.has("counter_guard") and profile in ["impact", "control"]:
        score += int(modifiers.get("adaptation_weight", 0))
    if adaptations.has("keep_distance") and profile == "ranged":
        score += int(modifiers.get("adaptation_weight", 0))
    return score

func _priority_bonus(priority: String, target: Dictionary, runtime: Variant, target_id: String) -> int:
    var hp_ratio := float(target.get("hp", 0)) / maxf(1.0, float(target.get("max_hp", 1)))
    var statuses: Dictionary = target.get("statuses", {})
    match priority:
        "wounded", "wounded_zone", "severe_wound", "disabled_limb":
            return 6 if _body_wounded(target) else 0
        "low_hp":
            return 7 if hp_ratio <= 0.45 else 0
        "bleeding":
            return 8 if statuses.has("BLEED") else 0
        "marked":
            return 7 if statuses.has("MARKED") else 0
        "observed", "unobserved":
            var observed := statuses.has("OBSERVED")
            return 5 if (priority == "observed" and observed) or (priority == "unobserved" and not observed) else 0
        "low_resolve":
            var res_max := int((target.get("stats", {}) as Dictionary).get("RES", 60))
            return 7 if int(target.get("resolve_current", res_max)) <= int(res_max * 0.55) else 0
        "low_mobility":
            return 5 if int((target.get("stats", {}) as Dictionary).get("MOB", 50)) <= 55 else 0
        "guarded":
            return 5 if int(target.get("guard_bonus", 0)) > 0 else 0
        "low_guard":
            return 4 if int(target.get("guard_bonus", 0)) <= 0 else 0
        "cluster":
            return mini(8, _adjacent_allies(runtime, target_id) * 4)
        _:
            return 0

func _adjacent_allies(runtime: Variant, target_id: String) -> int:
    if not runtime.combatants.has(target_id):
        return 0
    var target_team := str((runtime.combatants[target_id] as Dictionary).get("team", ""))
    var count := 0
    for key_value: Variant in runtime.combatants.keys():
        var other_id := str(key_value)
        if other_id == target_id:
            continue
        var row: Dictionary = runtime.combatants[other_id]
        if str(row.get("team", "")) == target_team and int(row.get("hp", 0)) > 0 and runtime.grid.distance(target_id, other_id) == 1:
            count += 1
    return count

func _body_wounded(row: Dictionary) -> bool:
    var body: Variant = row.get("body")
    if body == null or not body.has_method("serialize"):
        return int(row.get("hp", 0)) < int(row.get("max_hp", 1))
    var payload: Dictionary = body.call("serialize") as Dictionary
    for value: Variant in (payload.get("states", {}) as Dictionary).values():
        if str(value) != "L0":
            return true
    return false
