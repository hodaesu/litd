extends "res://scripts/core/veilleurs_enemy_skill_selector.gd"
class_name VeilleursEnemySkillSelectorV2

const DOCTRINE_SCRIPT := preload("res://scripts/core/veilleurs_enemy_doctrine_runtime.gd")

var doctrine: VeilleursEnemyDoctrineRuntime

func _init() -> void:
    doctrine = DOCTRINE_SCRIPT.new() as VeilleursEnemyDoctrineRuntime

func ensure_tree(runtime: Variant, enemy_id: String) -> String:
    if not runtime.combatants.has(enemy_id):
        return ""
    var row: Dictionary = runtime.combatants[enemy_id]
    var chosen := str(row.get("chosen_tree", ""))
    if chosen != "":
        return chosen
    var definition_id := str(row.get("definition_id", enemy_id))
    var tree_ids: Array[String] = []
    for value: Variant in runtime.content_db.skills_for(definition_id):
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

func refine_decision(runtime: Variant, enemy_id: String, decision: Dictionary) -> Dictionary:
    var refined := decision.duplicate(true)
    var action := str(refined.get("action", ""))
    if action == "support":
        return refined
    if doctrine.should_retreat(runtime, enemy_id):
        var flee_cell := _best_escape_cell(runtime, enemy_id)
        if flee_cell.x >= 0:
            refined["action"] = "flee"
            refined["cell"] = flee_cell
            refined["reason"] = "doctrine_retreat_threshold"
            refined["doctrine_used"] = true
            return refined
    var current_target := str(refined.get("target", ""))
    var best_target := current_target
    var best_score := doctrine.target_priority_bonus(runtime, enemy_id, current_target)
    for target_id: String in runtime.alive_ids("watcher"):
        var score := doctrine.target_priority_bonus(runtime, enemy_id, target_id)
        if score > best_score or (score == best_score and best_target != "" and target_id < best_target):
            best_score = score
            best_target = target_id
    if best_target != "" and best_target != current_target:
        refined["target"] = best_target
        refined["reason"] = "doctrine_target_priority"
        refined["doctrine_used"] = true
    return refined

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
    for value: Variant in runtime.content_db.skills_for(str(row.get("definition_id", enemy_id))):
        if not (value is Dictionary):
            continue
        var skill: Dictionary = value
        if str(skill.get("tree_id", "")) != tree_id:
            continue
        if int(skill.get("unlock_level", 99)) > level:
            continue
        var skill_action := str(runtime.skill_behavior.effective_action(skill))
        if skill_action == "passive_modifier":
            continue
        if not _range_valid(runtime, enemy_id, target_id, skill, skill_action):
            continue
        var score := doctrine.score_skill(runtime, enemy_id, skill, decision)
        if desired.has(skill_action):
            score += 12
        var scored := skill.duplicate(true)
        scored["_doctrine_score"] = score
        candidates.append(scored)
    if candidates.is_empty():
        return super.select_skill(runtime, enemy_id, decision)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_score := int(a.get("_doctrine_score", 0))
        var b_score := int(b.get("_doctrine_score", 0))
        if a_score == b_score:
            return str(a.get("skill_id", "")) < str(b.get("skill_id", ""))
        return a_score > b_score)
    var best: Dictionary = candidates[0].duplicate(true)
    best.erase("_doctrine_score")
    return best

func _best_escape_cell(runtime: Variant, enemy_id: String) -> Vector2i:
    var origin: Vector2i = runtime.grid.position_of(enemy_id)
    if origin.x < 0:
        return Vector2i(-1, -1)
    var best := Vector2i(-1, -1)
    var best_distance := -1
    for cell: Vector2i in runtime.grid.neighbors(origin):
        if runtime.grid.occupied(cell):
            continue
        var nearest := 999
        for watcher_id: String in runtime.alive_ids("watcher"):
            var watcher_pos: Vector2i = runtime.grid.position_of(watcher_id)
            var distance := absi(cell.x - watcher_pos.x) + absi(cell.y - watcher_pos.y)
            nearest = mini(nearest, distance)
        if nearest > best_distance:
            best_distance = nearest
            best = cell
    return best
