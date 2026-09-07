extends "res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd"
class_name VeilleursTacticalCombatRuntimeV07

const CONTENT_DB_V07_SCRIPT := preload("res://scripts/core/veilleurs_content_db_v07_runtime.gd")
const BEHAVIOR_V07_SCRIPT := preload("res://scripts/core/veilleurs_skill_behavior_runtime_v07.gd")
const SELECTOR_SCRIPT := preload("res://scripts/core/veilleurs_enemy_skill_selector.gd")
const BOSS_RULE_SCRIPT := preload("res://scripts/core/veilleurs_boss_rule_runtime.gd")
const ULTIMATE_SCRIPT := preload("res://scripts/core/veilleurs_ultimate_runtime.gd")

var skill_selector: VeilleursEnemySkillSelector
var boss_rules: VeilleursBossRuleRuntime
var ultimate_runtime: VeilleursUltimateRuntime
var active_boss_id := ""
var last_boss_rule: Dictionary = {}
var terrain_effects: Dictionary = {}
var summon_requests: Array[Dictionary] = []

func _init() -> void:
    super()
    content_db = CONTENT_DB_V07_SCRIPT.new() as VeilleursContentDBV07Runtime
    content_db.reload()
    skill_behavior = BEHAVIOR_V07_SCRIPT.new() as VeilleursSkillBehaviorRuntimeV07
    skill_selector = SELECTOR_SCRIPT.new() as VeilleursEnemySkillSelector
    boss_rules = BOSS_RULE_SCRIPT.new() as VeilleursBossRuleRuntime
    ultimate_runtime = ULTIMATE_SCRIPT.new() as VeilleursUltimateRuntime

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]) -> Dictionary:
    active_boss_id = ""
    last_boss_rule.clear()
    terrain_effects.clear()
    summon_requests.clear()
    var result: Dictionary = super.setup_first_combat(enemy_ids)
    if not bool(result.get("ok", false)):
        return result
    var chosen_trees: Dictionary = {}
    for enemy_id: String in enemy_ids:
        if not combatants.has(enemy_id):
            continue
        var row: Dictionary = combatants[enemy_id]
        row["level"] = _initial_enemy_level(row)
        row["ultimate_charges"] = _ultimate_charges_for_level(int(row["level"]))
        combatants[enemy_id] = row
        chosen_trees[enemy_id] = skill_selector.ensure_tree(self, enemy_id)
    result["chosen_trees"] = chosen_trees
    result["version"] = "0.7.0"
    return result

func setup_boss_combat(boss_id: String, context: Dictionary = {}) -> Dictionary:
    active_boss_id = ""
    last_boss_rule.clear()
    terrain_effects.clear()
    summon_requests.clear()
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
    row["ultimate_charges"] = 3
    combatants[boss_id] = row
    var chosen_tree: String = skill_selector.ensure_tree(self, boss_id)
    active_boss_id = boss_id
    last_boss_rule = boss_rules.begin(boss_id, context)
    return {"ok":true, "watchers":WATCHER_IDS.duplicate(), "boss":boss_id, "chosen_tree":chosen_tree, "boss_rule":last_boss_rule.duplicate(true), "grid":grid.snapshot(), "version":"0.7.0"}

func resolve_skill(attacker_id: String, target_id: String, skill_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    var result: Dictionary = super.resolve_skill(attacker_id, target_id, skill_id, zone, forced_roll)
    if not bool(result.get("ok", false)):
        return result
    if active_boss_id != "" and combatants.has(attacker_id) and str((combatants[attacker_id] as Dictionary).get("team", "")) == "watcher":
        var skill: Dictionary = content_db.skill(skill_id)
        boss_rules.register_player_action(str(skill.get("action_type", "attack")))
    if active_boss_id != "" and target_id == active_boss_id and bool(result.get("hit", false)):
        var mutation: Dictionary = boss_rules.after_body_change(self)
        if not mutation.is_empty():
            result["boss_body_response"] = mutation
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    if not combatants.has(enemy_id) or str((combatants[enemy_id] as Dictionary).get("team", "")) != "enemy":
        return {"ok":false, "reason":"not_enemy"}
    var decision: Dictionary = enemy_ai.decide(self, enemy_id)
    var row: Dictionary = combatants[enemy_id]
    var level := int(row.get("level", 1))
    var progress_state := _progress_state_for(enemy_id)
    if level >= 16:
        if ultimate_runtime.pending.has(enemy_id):
            var executed: Dictionary = ultimate_runtime.execute_pending(self, enemy_id, progress_state)
            if bool(executed.get("ok", false)):
                _apply_progress_state(enemy_id, executed.get("progress_state", {}))
                executed["generated_ultimate"] = true
                return executed
        elif round_index % 4 == 1 and str(decision.get("target", "")) != "":
            var prepared: Dictionary = ultimate_runtime.prepare(self, enemy_id, str(decision.get("target", "")), progress_state)
            if bool(prepared.get("ok", false)) and bool(prepared.get("prepared", false)):
                prepared["generated_ultimate"] = true
                action_log.append(prepared.duplicate(true))
                return prepared

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

func use_ultimate(attacker_id: String, target_id: String, progress_state: Dictionary) -> Dictionary:
    var result: Dictionary = ultimate_runtime.prepare(self, attacker_id, target_id, progress_state)
    if bool(result.get("ok", false)) and result.has("progress_state"):
        _apply_progress_state(attacker_id, result.get("progress_state", {}))
    if bool(result.get("ok", false)) and combatants.has(attacker_id) and str((combatants[attacker_id] as Dictionary).get("team", "")) == "watcher":
        boss_rules.register_player_action("ultimate")
    action_log.append(result.duplicate(true))
    return result

func register_terrain_effect(cell: Vector2i, skill_id: String, owner_id: String, duration: int) -> Dictionary:
    var key := "%d:%d" % [cell.x, cell.y]
    terrain_effects[key] = {"cell":[cell.x, cell.y], "skill_id":skill_id, "owner_id":owner_id, "remaining":maxi(1, duration)}
    return (terrain_effects[key] as Dictionary).duplicate(true)

func request_summon(owner_id: String, count: int, skill_id: String) -> Dictionary:
    var request := {"owner_id":owner_id, "count":clampi(count, 1, 2), "skill_id":skill_id, "round":round_index}
    summon_requests.append(request)
    while summon_requests.size() > 4:
        summon_requests.pop_front()
    return request.duplicate(true)

func next_round() -> void:
    super.next_round()
    _decay_terrain_effects()
    if active_boss_id != "" and combatants.has(active_boss_id) and int((combatants[active_boss_id] as Dictionary).get("hp", 0)) > 0:
        last_boss_rule = boss_rules.before_round(self)
        action_log.append({"ok":true, "action":"boss_rule", "boss":active_boss_id, "state":last_boss_rule.duplicate(true)})

func set_enemy_level(enemy_id: String, level: int) -> bool:
    if not combatants.has(enemy_id):
        return false
    var row: Dictionary = combatants[enemy_id]
    row["level"] = clampi(level, 1, 50)
    row["ultimate_charges"] = _ultimate_charges_for_level(int(row["level"]))
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

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["v07_active_boss_id"] = active_boss_id
    payload["v07_boss_rules"] = boss_rules.snapshot()
    payload["v07_ultimates"] = ultimate_runtime.serialize()
    payload["v07_last_boss_rule"] = last_boss_rule.duplicate(true)
    payload["v07_terrain_effects"] = terrain_effects.duplicate(true)
    payload["v07_summon_requests"] = summon_requests.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    active_boss_id = str(payload.get("v07_active_boss_id", ""))
    boss_rules.restore(payload.get("v07_boss_rules", {}))
    ultimate_runtime.deserialize(payload.get("v07_ultimates", {}))
    last_boss_rule = (payload.get("v07_last_boss_rule", {}) as Dictionary).duplicate(true)
    terrain_effects = (payload.get("v07_terrain_effects", {}) as Dictionary).duplicate(true)
    summon_requests.clear()
    for value: Variant in payload.get("v07_summon_requests", []):
        if value is Dictionary:
            summon_requests.append((value as Dictionary).duplicate(true))
    return true

func _push_away(attacker_id: String, target_id: String, distance: int) -> int:
    if not combatants.has(target_id):
        return 0
    var row: Dictionary = combatants[target_id]
    var resist := maxi(0, int(row.get("forced_move_resist", 0)))
    var blocked_steps := mini(distance, int(resist / 10))
    var effective_distance := maxi(0, distance - blocked_steps)
    row["forced_move_resist"] = maxi(0, resist - distance * 10)
    combatants[target_id] = row
    if effective_distance <= 0:
        return 0
    return super._push_away(attacker_id, target_id, effective_distance)

func _decay_terrain_effects() -> void:
    var remove_keys: Array[String] = []
    for key_value: Variant in terrain_effects.keys():
        var key := str(key_value)
        var state: Dictionary = terrain_effects[key]
        state["remaining"] = int(state.get("remaining", 1)) - 1
        if int(state["remaining"]) <= 0:
            remove_keys.append(key)
        else:
            terrain_effects[key] = state
    for key: String in remove_keys:
        terrain_effects.erase(key)

func _progress_state_for(entity_id: String) -> Dictionary:
    var row: Dictionary = combatants.get(entity_id, {})
    return {
        "entity_id":entity_id,
        "level":int(row.get("level", 1)),
        "chosen_tree":str(row.get("chosen_tree", "")),
        "ultimate_charges":int(row.get("ultimate_charges", _ultimate_charges_for_level(int(row.get("level", 1)))))
    }

func _apply_progress_state(entity_id: String, state: Dictionary) -> void:
    if not combatants.has(entity_id) or state.is_empty():
        return
    var row: Dictionary = combatants[entity_id]
    row["level"] = int(state.get("level", row.get("level", 1)))
    row["chosen_tree"] = str(state.get("chosen_tree", row.get("chosen_tree", "")))
    row["ultimate_charges"] = int(state.get("ultimate_charges", row.get("ultimate_charges", 0)))
    combatants[entity_id] = row

func _ultimate_charges_for_level(level: int) -> int:
    if level >= 48:
        return 3
    if level >= 32:
        return 2
    if level >= 16:
        return 1
    return 0

func _initial_enemy_level(row: Dictionary) -> int:
    var threat := float(row.get("threat_value", 1.0))
    return clampi(1 + int(floor(threat * 3.0)), 1, 8)
