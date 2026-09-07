extends RefCounted
class_name VeilleursEnemySkillSelector

func ensure_tree(runtime: Variant, enemy_id: String) -> String:
    if not runtime.combatants.has(enemy_id):
        return ""
    var row: Dictionary = runtime.combatants[enemy_id]
    var chosen := str(row.get("chosen_tree", ""))
    if chosen != "":
        return chosen
    var tree_ids: Array[String] = []
    for value: Variant in runtime.content_db.skills_for(enemy_id):
        if not (value is Dictionary):
            continue
        var tree_id := str((value as Dictionary).get("tree_id", ""))
        if tree_id != "" and not tree_ids.has(tree_id):
            tree_ids.append(tree_id)
    tree_ids.sort()
    if tree_ids.is_empty():
        return ""
    var identity_seed := str(row.get("remanence_id", enemy_id))
    chosen = tree_ids[posmod(identity_seed.hash(), tree_ids.size())]
    row["chosen_tree"] = chosen
    runtime.combatants[enemy_id] = row
    return chosen

func select_skill(runtime: Variant, enemy_id: String, decision: Dictionary) -> Dictionary:
    if not runtime.combatants.has(enemy_id):
        return {}
    var tree_id := ensure_tree(runtime, enemy_id)
    if tree_id == "":
        return {}
    var row: Dictionary = runtime.combatants[enemy_id]
    var level := clampi(int(row.get("level", 1)), 1, 50)
    var target_id := str(decision.get("target", ""))
    var desired := _desired_actions(decision)
    var candidates: Array[Dictionary] = []
    var fallback: Array[Dictionary] = []
    for value: Variant in runtime.content_db.skills_for(enemy_id):
        if not (value is Dictionary):
            continue
        var skill: Dictionary = value
        if str(skill.get("tree_id", "")) != tree_id:
            continue
        if int(skill.get("unlock_level", 99)) > level:
            continue
        var action: String = str(runtime.skill_behavior.effective_action(skill))
        if action == "passive_modifier":
            continue
        fallback.append(skill)
        if desired.has(action) and _range_valid(runtime, enemy_id, target_id, skill, action):
            candidates.append(skill)
    if candidates.is_empty():
        for skill: Dictionary in fallback:
            var action: String = str(runtime.skill_behavior.effective_action(skill))
            if _range_valid(runtime, enemy_id, target_id, skill, action):
                candidates.append(skill)
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("skill_id", "")) < str(b.get("skill_id", "")))
    var index := posmod(enemy_id.hash() + runtime.round_index * 31 + target_id.hash(), candidates.size())
    return candidates[index].duplicate(true)

func _desired_actions(decision: Dictionary) -> Array[String]:
    var action := str(decision.get("action", "attack"))
    var attack_kind := str(decision.get("attack_kind", "physical"))
    if action == "support":
        return ["support", "heal", "guard"]
    if action in ["move", "flee"]:
        return ["attack_move", "move"]
    if attack_kind == "psych":
        return ["psychological", "control", "attack"]
    if attack_kind == "control":
        return ["control", "attack", "attack_move"]
    return ["attack", "attack_move", "control", "psychological", "transform"]

func _range_valid(runtime: Variant, source_id: String, target_id: String, skill: Dictionary, action: String) -> bool:
    if action in ["support", "heal", "guard", "transform"]:
        return true
    if target_id == "" or not runtime.combatants.has(target_id):
        return false
    var distance: int = int(runtime.grid.distance(source_id, target_id))
    return distance >= 0 and distance <= runtime.skill_behavior.range_for(skill)
