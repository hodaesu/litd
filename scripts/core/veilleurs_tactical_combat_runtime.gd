extends RefCounted
class_name VeilleursTacticalCombatRuntime

const GRID_SCRIPT := preload("res://scripts/core/veilleurs_tactical_grid.gd")
const BODY_SCRIPT := preload("res://scripts/core/veilleurs_body_component.gd")
const CONTENT_DB_SCRIPT := preload("res://scripts/core/content_db.gd")
const AI_SCRIPT := preload("res://scripts/core/veilleurs_enemy_ai_v2.gd")
const WATCHER_IDS: Array[String] = ["ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA"]

var content_db: VeilleursContentDB
var enemy_ai: VeilleursEnemyAIV2
var grid: VeilleursTacticalGrid
var combatants: Dictionary = {}
var round_index := 1
var action_log: Array[Dictionary] = []

func _init() -> void:
    content_db = CONTENT_DB_SCRIPT.new() as VeilleursContentDB
    content_db.reload()
    enemy_ai = AI_SCRIPT.new() as VeilleursEnemyAIV2
    grid = GRID_SCRIPT.new() as VeilleursTacticalGrid

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]) -> Dictionary:
    combatants.clear()
    action_log.clear()
    round_index = 1
    grid = GRID_SCRIPT.new() as VeilleursTacticalGrid
    for index in range(WATCHER_IDS.size()):
        var entity_id := WATCHER_IDS[index]
        var definition := content_db.watcher(entity_id)
        if definition.is_empty():
            return {"ok": false, "reason": "missing_watcher", "entity_id": entity_id}
        _register(definition, "watcher")
        var pos: Array = definition.get("starter_position", [0, index])
        if not grid.place(entity_id, Vector2i(int(pos[0]), int(pos[1]))):
            return {"ok": false, "reason": "watcher_placement", "entity_id": entity_id}
    var enemy_cells: Array[Vector2i] = [Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)]
    for index in range(enemy_ids.size()):
        var enemy_id := enemy_ids[index]
        var definition := content_db.enemy(enemy_id)
        if definition.is_empty():
            return {"ok": false, "reason": "missing_enemy", "entity_id": enemy_id}
        _register(definition, "enemy")
        if not grid.place(enemy_id, enemy_cells[mini(index, enemy_cells.size() - 1)]):
            return {"ok": false, "reason": "enemy_placement", "entity_id": enemy_id}
    return {"ok": true, "watchers": WATCHER_IDS.duplicate(), "enemies": enemy_ids.duplicate(), "grid": grid.snapshot()}

func resolve_skill(attacker_id: String, target_id: String, skill_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    if not combatants.has(attacker_id) or not combatants.has(target_id):
        return {"ok": false, "reason": "unknown_combatant"}
    var skill := content_db.skill(skill_id)
    if skill.is_empty() or str(skill.get("entity_id", "")) != attacker_id:
        return {"ok": false, "reason": "skill_not_owned"}
    var attacker: Dictionary = combatants[attacker_id]
    var target: Dictionary = combatants[target_id]
    var action_type := str(skill.get("action_type", "attack"))
    if action_type in ["observe", "support", "guard", "heal", "passive_modifier", "psychological", "control", "transform"]:
        return _resolve_non_damage(attacker_id, target_id, skill)
    var chance := _hit_chance(attacker, target, skill, zone)
    var roll := forced_roll if forced_roll >= 1 else _deterministic_roll(attacker_id, target_id, skill_id)
    var hit := roll <= chance
    var result := {"ok": true, "hit": hit, "roll": roll, "hit_chance": chance, "attacker": attacker_id, "target": target_id, "skill_id": skill_id, "zone": zone}
    if not hit:
        action_log.append(result.duplicate(true))
        return result
    var damage := _damage(attacker, target, skill)
    target["hp"] = maxi(0, int(target.get("hp", 1)) - damage)
    var effect: Dictionary = skill.get("effect_spec", {})
    var trauma := maxi(1, int(round(float(damage) * float(effect.get("trauma_multiplier", 1.0)))))
    var dismemberment: Dictionary = skill.get("dismemberment_rules", {})
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    var body_result := body.apply_trauma(zone, trauma, int(dismemberment.get("power", 0)), 3)
    result["damage"] = damage
    result["target_hp"] = int(target["hp"])
    result["body"] = body_result
    var forced_move := int(effect.get("forced_move", 0))
    if forced_move > 0:
        result["forced_move"] = _push_away(attacker_id, target_id, forced_move)
    combatants[target_id] = target
    action_log.append(result.duplicate(true))
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    if not combatants.has(enemy_id) or str((combatants[enemy_id] as Dictionary).get("team", "")) != "enemy":
        return {"ok": false, "reason": "not_enemy"}
    var decision := enemy_ai.decide(self, enemy_id)
    var action := str(decision.get("action", "none"))
    match action:
        "attack":
            var target_id := str(decision.get("target", ""))
            if target_id == "" or not combatants.has(target_id):
                return {"ok": false, "reason": "ai_invalid_target"}
            var result := _enemy_basic_attack(enemy_id, target_id)
            result["decision_reason"] = str(decision.get("reason", "tactical_attack"))
            return result
        "move", "flee":
            var cell_value: Variant = decision.get("cell", Vector2i(-1, -1))
            if not (cell_value is Vector2i):
                return {"ok": false, "reason": "ai_invalid_cell"}
            var cell: Vector2i = cell_value
            if cell.x >= 0 and grid.move(enemy_id, cell):
                var result := {"ok": true, "action": action, "enemy": enemy_id, "target": str(decision.get("target", "")), "to": [cell.x, cell.y], "decision_reason": str(decision.get("reason", ""))}
                action_log.append(result.duplicate(true))
                return result
            return {"ok": false, "reason": "ai_move_blocked"}
        "support":
            return _enemy_support(enemy_id, str(decision.get("target", "")), str(decision.get("reason", "ally_critical")))
        "hold":
            var hold := {"ok": true, "action": "hold", "enemy": enemy_id, "target": str(decision.get("target", "")), "decision_reason": str(decision.get("reason", "blocked"))}
            action_log.append(hold.duplicate(true))
            return hold
        _:
            return {"ok": false, "reason": str(decision.get("reason", "ai_no_action"))}

func next_round() -> void:
    round_index += 1

func alive_ids(team: String = "") -> Array[String]:
    var result: Array[String] = []
    for entity_id_value: Variant in combatants.keys():
        var entity_id := str(entity_id_value)
        var row: Dictionary = combatants[entity_id]
        if int(row.get("hp", 0)) <= 0:
            continue
        if team != "" and str(row.get("team", "")) != team:
            continue
        result.append(entity_id)
    return result

func serialize() -> Dictionary:
    var rows: Dictionary = {}
    for entity_id_value: Variant in combatants.keys():
        var entity_id := str(entity_id_value)
        var row: Dictionary = (combatants[entity_id] as Dictionary).duplicate(true)
        var body: VeilleursBodyComponent = row.get("body") as VeilleursBodyComponent
        row["body"] = body.serialize()
        rows[entity_id] = row
    return {"round": round_index, "grid": grid.snapshot(), "combatants": rows, "action_log": action_log.duplicate(true)}

func deserialize(payload: Dictionary) -> bool:
    combatants.clear()
    action_log.clear()
    grid = GRID_SCRIPT.new() as VeilleursTacticalGrid
    if not grid.restore(payload.get("grid", {})):
        return false
    round_index = maxi(1, int(payload.get("round", 1)))
    var source_rows: Dictionary = payload.get("combatants", {})
    for entity_id_value: Variant in source_rows.keys():
        var entity_id := str(entity_id_value)
        var source: Dictionary = source_rows.get(entity_id, {})
        var row := source.duplicate(true)
        var body_payload: Dictionary = source.get("body", {})
        var integrity: Dictionary = body_payload.get("maximum", content_db.combat_constants.get("body_integrity_reference", {}))
        var body: VeilleursBodyComponent = BODY_SCRIPT.new(integrity) as VeilleursBodyComponent
        body.deserialize(body_payload)
        row["body"] = body
        combatants[entity_id] = row
    for value: Variant in payload.get("action_log", []):
        if value is Dictionary:
            action_log.append((value as Dictionary).duplicate(true))
    return not combatants.is_empty()

func _register(definition: Dictionary, team: String) -> void:
    var entity_id := str(definition.get("entity_id", ""))
    var stats: Dictionary = (definition.get("stats", {}) as Dictionary).duplicate(true)
    var body_integrity: Dictionary = (definition.get("body_integrity", content_db.combat_constants.get("body_integrity_reference", {})) as Dictionary).duplicate(true)
    var vigor := int(stats.get("VIG", 60))
    combatants[entity_id] = {
        "entity_id": entity_id,
        "name": str(definition.get("name_fr", entity_id)),
        "team": team,
        "family": str(definition.get("family", "WATCHERS" if team == "watcher" else "")),
        "combat_role": str(definition.get("combat_role", "watcher" if team == "watcher" else "assault")),
        "threat_value": float(definition.get("threat_value", 1.0)),
        "remanence_stage": str(definition.get("remanence_stage", "normal")),
        "stats": stats,
        "hp": 80 + vigor,
        "max_hp": 80 + vigor,
        "armor": 30 if team == "watcher" else 20,
        "weapon_power": 30 if team == "watcher" else 24,
        "body": BODY_SCRIPT.new(body_integrity)
    }

func _hit_chance(attacker: Dictionary, target: Dictionary, skill: Dictionary, zone: String) -> int:
    var attacker_stats: Dictionary = attacker.get("stats", {})
    var target_stats: Dictionary = target.get("stats", {})
    var zone_mods: Dictionary = content_db.combat_constants.get("zone_accuracy_mod", {})
    var chance := 75.0
    chance += (float(attacker_stats.get("PRE", 50)) - float(target_stats.get("MOB", 50))) * 0.45
    chance += float(skill.get("precision_mod", 0))
    chance += float(zone_mods.get(zone, 0))
    var clamps: Dictionary = content_db.combat_constants.get("hit_clamp", {})
    return clampi(int(round(chance)), int(clamps.get("min_percent", 10)), int(clamps.get("max_percent", 97)))

func _damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
    var attacker_stats: Dictionary = attacker.get("stats", {})
    var effect: Dictionary = skill.get("effect_spec", {})
    var multiplier := float(effect.get("damage_multiplier", 1.0))
    var attack_power := float(attacker.get("weapon_power", 25)) * multiplier * (0.70 + float(attacker_stats.get("FOR", 50)) / 200.0)
    var armor := float(target.get("armor", 0))
    var reduction := armor / (armor + 100.0)
    return maxi(1, int(round(attack_power * (1.0 - reduction))))

func _resolve_non_damage(attacker_id: String, target_id: String, skill: Dictionary) -> Dictionary:
    var effect: Dictionary = skill.get("effect_spec", {})
    var result := {"ok": true, "hit": true, "attacker": attacker_id, "target": target_id, "skill_id": str(skill.get("skill_id", "")), "non_damage": true, "knowledge_reveal": int(effect.get("knowledge_reveal", 0)), "guard_delta": int(effect.get("guard_delta", 0)), "resolve_delta": int(effect.get("resolve_delta", 0))}
    action_log.append(result.duplicate(true))
    return result

func _push_away(attacker_id: String, target_id: String, distance: int) -> int:
    var attacker_pos := grid.position_of(attacker_id)
    var target_pos := grid.position_of(target_id)
    var delta := target_pos - attacker_pos
    if delta == Vector2i.ZERO:
        return 0
    var x_step := 1 if delta.x > 0 else -1
    var y_step := 1 if delta.y > 0 else -1
    var step := Vector2i(x_step, 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, y_step)
    var moved := 0
    for _index in range(distance):
        var destination := grid.position_of(target_id) + step
        if not grid.inside(destination) or grid.occupied(destination):
            break
        if grid.move(target_id, destination):
            moved += 1
    return moved

func _enemy_support(attacker_id: String, target_id: String, reason: String) -> Dictionary:
    if target_id == "" or not combatants.has(target_id):
        return {"ok": false, "reason": "support_target_missing"}
    var target: Dictionary = combatants[target_id]
    if str(target.get("team", "")) != "enemy" or int(target.get("hp", 0)) <= 0:
        return {"ok": false, "reason": "support_target_invalid"}
    var before := int(target.get("hp", 0))
    var amount := maxi(4, int(round(float(target.get("max_hp", 1)) * 0.10)))
    target["hp"] = mini(int(target.get("max_hp", 1)), before + amount)
    target["guard_bonus"] = maxi(int(target.get("guard_bonus", 0)), 8)
    combatants[target_id] = target
    var result := {"ok": true, "action": "support", "enemy": attacker_id, "target": target_id, "healed": int(target["hp"]) - before, "guard_bonus": 8, "decision_reason": reason, "persistent_injury_healed": false}
    action_log.append(result.duplicate(true))
    return result

func _enemy_basic_attack(attacker_id: String, target_id: String) -> Dictionary:
    var attacker: Dictionary = combatants[attacker_id]
    var target: Dictionary = combatants[target_id]
    var stats: Dictionary = attacker.get("stats", {})
    var target_stats: Dictionary = target.get("stats", {})
    var chance := clampi(70 + int(round((float(stats.get("PRE", 50)) - float(target_stats.get("MOB", 50))) * 0.35)), 15, 95)
    var roll := _deterministic_roll(attacker_id, target_id, "basic")
    var result := {"ok": true, "action": "attack", "attacker": attacker_id, "target": target_id, "roll": roll, "hit_chance": chance, "hit": roll <= chance}
    if bool(result["hit"]):
        var armor := float(target.get("armor", 0))
        var guard_bonus := float(target.get("guard_bonus", 0))
        var effective_armor := armor + guard_bonus
        var damage := maxi(1, int(round(float(attacker.get("weapon_power", 20)) * (1.0 - effective_armor / (effective_armor + 100.0)))))
        target["hp"] = maxi(0, int(target.get("hp", 1)) - damage)
        target["guard_bonus"] = 0
        result["damage"] = damage
        result["target_hp"] = int(target["hp"])
        var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
        result["body"] = body.apply_trauma("torso", maxi(1, int(round(float(damage) * 0.75))))
        combatants[target_id] = target
    action_log.append(result.duplicate(true))
    return result

func _deterministic_roll(a: String, b: String, c: String) -> int:
    return posmod((a + "|" + b + "|" + c + "|" + str(round_index)).hash(), 100) + 1
