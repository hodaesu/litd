extends "res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd"
class_name VeilleursTacticalCombatRuntimeV07

const CONTENT_DB_V07_SCRIPT := preload("res://scripts/core/veilleurs_content_db_v07_runtime.gd")
const BEHAVIOR_V07_SCRIPT := preload("res://scripts/core/veilleurs_skill_behavior_runtime_v07.gd")
const SELECTOR_SCRIPT := preload("res://scripts/core/veilleurs_enemy_skill_selector.gd")

var skill_selector: VeilleursEnemySkillSelector

func _init() -> void:
    super()
    content_db = CONTENT_DB_V07_SCRIPT.new() as VeilleursContentDBV07Runtime
    content_db.reload()
    skill_behavior = BEHAVIOR_V07_SCRIPT.new() as VeilleursSkillBehaviorRuntimeV07
    skill_selector = SELECTOR_SCRIPT.new() as VeilleursEnemySkillSelector

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]) -> Dictionary:
    var result: Dictionary = super.setup_first_combat(enemy_ids)
    if not bool(result.get("ok", false)):
        return result
    var chosen_trees: Dictionary = {}
    for enemy_id: String in enemy_ids:
        if not combatants.has(enemy_id):
            continue
        var row: Dictionary = combatants[enemy_id]
        row["level"] = _initial_enemy_level(row)
        combatants[enemy_id] = row
        chosen_trees[enemy_id] = skill_selector.ensure_tree(self, enemy_id)
    result["chosen_trees"] = chosen_trees
    result["version"] = "0.7.0"
    return result

func setup_boss_combat(boss_id: String) -> Dictionary:
    var no_enemies: Array[String] = []
    var result: Dictionary = super.setup_first_combat(no_enemies)
    if not bool(result.get("ok", false)):
        return result
    var definition: Dictionary = (content_db as VeilleursContentDBV07Runtime).boss(boss_id)
    if definition.is_empty():
        return {"ok":false, "reason":"missing_boss", "boss_id":boss_id}
    _register(definition, "enemy")
    if not grid.place(boss_id, Vector2i(5, 2)):
        return {"ok":false, "reason":"boss_placement", "boss_id":boss_id}
    var row: Dictionary = combatants[boss_id]
    var stats: Dictionary = row.get("stats", {})
    var balance: Dictionary = content_db.combat_constants.get("v061_balance", {})
    row["resolve_current"] = int(stats.get("RES", 80))
    row["statuses"] = {}
    row["passive_effects"] = {}
    row["observed_by"] = {}
    row["guard_bonus"] = 0
    row["evasive_bonus"] = 0
    row["adaptations"] = []
    row["weapon_power"] = int(balance.get("enemy_weapon_power", 42)) + 8
    row["level"] = 50
    row["boss"] = true
    combatants[boss_id] = row
    var chosen_tree := skill_selector.ensure_tree(self, boss_id)
    return {"ok":true, "watchers":WATCHER_IDS.duplicate(), "boss":boss_id, "chosen_tree":chosen_tree, "grid":grid.snapshot(), "version":"0.7.0"}

func enemy_step(enemy_id: String) -> Dictionary:
    if not combatants.has(enemy_id) or str((combatants[enemy_id] as Dictionary).get("team", "")) != "enemy":
        return {"ok":false, "reason":"not_enemy"}
    var decision: Dictionary = enemy_ai.decide(self, enemy_id)
    var action := str(decision.get("action", "none"))
    if action not in ["attack", "support"]:
        return super.enemy_step(enemy_id)
    var skill: Dictionary = skill_selector.select_skill(self, enemy_id, decision)
    if skill.is_empty():
        var fallback: Dictionary = super.enemy_step(enemy_id)
        fallback["generated_skill_fallback"] = true
        return fallback
    var skill_action := skill_behavior.effective_action(skill)
    var target_id := str(decision.get("target", ""))
    if skill_action in ["guard", "heal", "transform"]:
        target_id = enemy_id
    elif skill_action == "support" and (target_id == "" or not combatants.has(target_id) or str((combatants[target_id] as Dictionary).get("team", "")) != "enemy"):
        target_id = enemy_id
    if target_id == "":
        var fallback_no_target: Dictionary = super.enemy_step(enemy_id)
        fallback_no_target["generated_skill_fallback"] = true
        return fallback_no_target
    var zone := str(decision.get("zone", "torso"))
    var result: Dictionary = resolve_skill(enemy_id, target_id, str(skill.get("skill_id", "")), zone, -1)
    if not bool(result.get("ok", false)):
        var fallback_failed: Dictionary = super.enemy_step(enemy_id)
        fallback_failed["generated_skill_fallback"] = true
        fallback_failed["generated_skill_reason"] = str(result.get("reason", "failed"))
        return fallback_failed
    result["generated_skill"] = true
    result["selected_tree"] = str((combatants[enemy_id] as Dictionary).get("chosen_tree", ""))
    result["decision_reason"] = str(decision.get("reason", "tactical_skill"))
    result["memory_used"] = bool(decision.get("memory_used", false))
    return result

func set_enemy_level(enemy_id: String, level: int) -> bool:
    if not combatants.has(enemy_id):
        return false
    var row: Dictionary = combatants[enemy_id]
    row["level"] = clampi(level, 1, 50)
    combatants[enemy_id] = row
    return true

func set_enemy_tree(enemy_id: String, tree_id: String) -> bool:
    if not combatants.has(enemy_id):
        return false
    var valid := false
    for value: Variant in content_db.skills_for(enemy_id):
        if value is Dictionary and str((value as Dictionary).get("tree_id", "")) == tree_id:
            valid = true
            break
    if not valid:
        return false
    var row: Dictionary = combatants[enemy_id]
    row["chosen_tree"] = tree_id
    combatants[enemy_id] = row
    return true

func _initial_enemy_level(row: Dictionary) -> int:
    var threat := float(row.get("threat_value", 1.0))
    return clampi(1 + int(floor(threat * 3.0)), 1, 8)
