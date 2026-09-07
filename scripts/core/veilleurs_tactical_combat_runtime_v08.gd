extends "res://scripts/core/veilleurs_tactical_combat_runtime_v07.gd"
class_name VeilleursTacticalCombatRuntimeV08

const SELECTOR_V2_SCRIPT := preload("res://scripts/core/veilleurs_enemy_skill_selector_v2.gd")
const REMANENCE_BRIDGE_SCRIPT := preload("res://scripts/core/veilleurs_remanence_combat_bridge_v08.gd")
const BOSS_DIRECTOR_SCRIPT := preload("res://scripts/core/veilleurs_boss_director_v08.gd")

var remanence_bridge: VeilleursRemanenceCombatBridgeV08
var boss_director: VeilleursBossDirectorV08
var last_boss_mechanics: Dictionary = {}
var active_region_id := ""

func _init() -> void:
    super()
    skill_selector = SELECTOR_V2_SCRIPT.new() as VeilleursEnemySkillSelectorV2
    remanence_bridge = REMANENCE_BRIDGE_SCRIPT.new() as VeilleursRemanenceCombatBridgeV08
    boss_director = BOSS_DIRECTOR_SCRIPT.new() as VeilleursBossDirectorV08

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"], region_id: String = "khar_sen") -> Dictionary:
    active_region_id = region_id
    last_boss_mechanics.clear()
    var result: Dictionary = super.setup_first_combat(enemy_ids)
    if not bool(result.get("ok", false)):
        return result
    var remanence_rows: Dictionary = {}
    var chosen_trees: Dictionary = {}
    for enemy_id: String in enemy_ids:
        if not combatants.has(enemy_id):
            continue
        var row: Dictionary = combatants[enemy_id]
        row["definition_id"] = enemy_id
        row.erase("chosen_tree")
        combatants[enemy_id] = row
        remanence_rows[enemy_id] = remanence_bridge.prepare_enemy(self, enemy_id, active_region_id)
        chosen_trees[enemy_id] = skill_selector.ensure_tree(self, enemy_id)
    result["chosen_trees"] = chosen_trees
    result["remanence"] = remanence_rows
    result["version"] = "0.8.0"
    return result

func setup_boss_combat(boss_id: String, context: Dictionary = {}) -> Dictionary:
    active_region_id = str(context.get("region_id", "boss_region"))
    last_boss_mechanics.clear()
    var result: Dictionary = super.setup_boss_combat(boss_id, context)
    if not bool(result.get("ok", false)):
        return result
    if combatants.has(boss_id):
        var row: Dictionary = combatants[boss_id]
        row["definition_id"] = boss_id
        combatants[boss_id] = row
    last_boss_mechanics = boss_director.apply_round(self, boss_id, last_boss_rule)
    result["boss_mechanics"] = last_boss_mechanics.duplicate(true)
    result["version"] = "0.8.0"
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    if not combatants.has(enemy_id) or str((combatants[enemy_id] as Dictionary).get("team", "")) != "enemy":
        return {"ok":false, "reason":"not_enemy"}
    remanence_bridge.refresh_enemy(self, enemy_id)
    var base_decision: Dictionary = enemy_ai.decide(self, enemy_id)
    var decision: Dictionary = (skill_selector as VeilleursEnemySkillSelectorV2).refine_decision(self, enemy_id, base_decision)
    if str(decision.get("action", "")) in ["move", "flee"]:
        var cell_value: Variant = decision.get("cell", Vector2i(-1, -1))
        if cell_value is Vector2i and not can_move_to(cell_value as Vector2i):
            decision["action"] = "hold"
            decision["reason"] = "boss_or_terrain_cell_locked"
    var row: Dictionary = combatants[enemy_id]
    var level := int(row.get("level", 1))
    var progress_state := _progress_state_for(enemy_id)
    if level >= 16:
        if ultimate_runtime.pending.has(enemy_id):
            var executed: Dictionary = ultimate_runtime.execute_pending(self, enemy_id, progress_state)
            if bool(executed.get("ok", false)):
                _apply_progress_state(enemy_id, executed.get("progress_state", {}))
                executed["generated_ultimate"] = true
                executed["doctrine_used"] = bool(decision.get("doctrine_used", false))
                return executed
        elif round_index % 4 == 1 and str(decision.get("target", "")) != "":
            var prepared: Dictionary = ultimate_runtime.prepare(self, enemy_id, str(decision.get("target", "")), progress_state)
            if bool(prepared.get("ok", false)) and bool(prepared.get("prepared", false)):
                prepared["generated_ultimate"] = true
                prepared["doctrine_used"] = bool(decision.get("doctrine_used", false))
                action_log.append(prepared.duplicate(true))
                return prepared
    var action := str(decision.get("action", "none"))
    if action not in ["attack", "support"]:
        return _resolve_non_skill_decision(enemy_id, decision)
    var skill: Dictionary = skill_selector.select_skill(self, enemy_id, decision)
    if skill.is_empty():
        return _fallback_enemy_action(enemy_id, decision, "no_doctrine_skill")
    var skill_action := str(skill_behavior.effective_action(skill))
    var target_id := str(decision.get("target", ""))
    if skill_action in ["guard", "heal", "transform"]:
        target_id = enemy_id
    elif skill_action == "support" and (target_id == "" or not combatants.has(target_id) or str((combatants[target_id] as Dictionary).get("team", "")) != "enemy"):
        target_id = enemy_id
    if target_id == "":
        return _fallback_enemy_action(enemy_id, decision, "missing_target")
    var zone := str(decision.get("zone", "torso"))
    var result: Dictionary = resolve_skill(enemy_id, target_id, str(skill.get("skill_id", "")), zone, -1)
    if not bool(result.get("ok", false)):
        return _fallback_enemy_action(enemy_id, decision, str(result.get("reason", "skill_failed")))
    result["generated_skill"] = true
    result["selected_tree"] = str((combatants[enemy_id] as Dictionary).get("chosen_tree", ""))
    result["decision_reason"] = str(decision.get("reason", "doctrine_skill"))
    result["memory_used"] = bool(decision.get("memory_used", false))
    result["doctrine_used"] = true
    return result

func finish_remanence(outcome: String, context: Dictionary = {}) -> Dictionary:
    var results: Dictionary = {}
    for enemy_id_value: Variant in combatants.keys():
        var enemy_id := str(enemy_id_value)
        var row: Dictionary = combatants[enemy_id]
        if str(row.get("team", "")) != "enemy" or bool(row.get("boss", false)):
            continue
        var enemy_outcome := "killed" if int(row.get("hp", 0)) <= 0 else outcome
        var merged := context.duplicate(true)
        merged["region_id"] = str(context.get("region_id", active_region_id))
        results[enemy_id] = remanence_bridge.finish_enemy(self, enemy_id, enemy_outcome, merged)
    return results

func can_move_to(cell: Vector2i) -> bool:
    if not grid.inside(cell) or grid.occupied(cell):
        return false
    if active_boss_id != "" and boss_director.cell_locked(self, cell):
        return false
    var key := "%d:%d" % [cell.x, cell.y]
    if terrain_effects.has(key):
        var effect: Dictionary = terrain_effects[key]
        if str(effect.get("skill_id", "")) == "BOSS_GARDIEN_LOCK":
            return false
    return true

func boss_rule_snapshot() -> Dictionary:
    return boss_rules.snapshot()

func next_round() -> void:
    super.next_round()
    if active_boss_id != "" and combatants.has(active_boss_id) and int((combatants[active_boss_id] as Dictionary).get("hp", 0)) > 0:
        last_boss_mechanics = boss_director.apply_round(self, active_boss_id, last_boss_rule)
        action_log.append({"ok":true, "action":"boss_mechanic", "boss":active_boss_id, "state":last_boss_mechanics.duplicate(true)})

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["v08_region_id"] = active_region_id
    payload["v08_last_boss_mechanics"] = last_boss_mechanics.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    active_region_id = str(payload.get("v08_region_id", ""))
    last_boss_mechanics = (payload.get("v08_last_boss_mechanics", {}) as Dictionary).duplicate(true)
    return true

func _resolve_non_skill_decision(enemy_id: String, decision: Dictionary) -> Dictionary:
    var action := str(decision.get("action", "none"))
    if action in ["move", "flee"]:
        var cell_value: Variant = decision.get("cell", Vector2i(-1, -1))
        if cell_value is Vector2i:
            var cell: Vector2i = cell_value
            if can_move_to(cell) and grid.move(enemy_id, cell):
                var moved := {"ok":true, "action":action, "enemy":enemy_id, "to":[cell.x, cell.y], "decision_reason":str(decision.get("reason", "doctrine_move")), "doctrine_used":bool(decision.get("doctrine_used", false))}
                action_log.append(moved.duplicate(true))
                return moved
        return {"ok":false, "reason":"doctrine_move_blocked"}
    if action == "hold":
        var hold := {"ok":true, "action":"hold", "enemy":enemy_id, "decision_reason":str(decision.get("reason", "hold")), "doctrine_used":bool(decision.get("doctrine_used", false))}
        action_log.append(hold.duplicate(true))
        return hold
    return _fallback_enemy_action(enemy_id, decision, "unsupported_decision")

func _fallback_enemy_action(enemy_id: String, decision: Dictionary, reason: String) -> Dictionary:
    var fallback: Dictionary = super.enemy_step(enemy_id)
    fallback["generated_skill_fallback"] = true
    fallback["generated_skill_reason"] = reason
    fallback["original_decision_reason"] = str(decision.get("reason", ""))
    return fallback
