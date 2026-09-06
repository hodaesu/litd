extends RefCounted
class_name VeilleursEnemyAIV2

const PREDATOR_ROLES: Array[String] = ["assault", "anatomy", "drain", "hunter", "execution"]
const RANGED_ROLES: Array[String] = ["ranged", "psych", "psych_support", "controller"]
const SUPPORT_ROLES: Array[String] = ["support", "psych_support", "tank_support"]
const STOIC_ROLES: Array[String] = ["brute", "tank", "controller_tank", "tank_support"]

func decide(runtime, enemy_id: String) -> Dictionary:
    if runtime == null or not runtime.combatants.has(enemy_id):
        return {"action":"none", "reason":"unknown_enemy"}
    var enemy: Dictionary = runtime.combatants[enemy_id]
    if int(enemy.get("hp", 0)) <= 0:
        return {"action":"none", "reason":"dead"}
    var role := str(enemy.get("combat_role", "assault"))
    var hp_ratio := _hp_ratio(enemy)
    if hp_ratio <= 0.18 and not STOIC_ROLES.has(role) and str(enemy.get("remanence_stage", "normal")) != "nemesis":
        var flee_cell := _best_escape_cell(runtime, enemy_id)
        if flee_cell.x >= 0:
            return {"action":"flee", "cell":flee_cell, "reason":"critical_survival"}
    if SUPPORT_ROLES.has(role):
        var ally := _most_wounded_ally(runtime, enemy_id)
        if ally != "" and _hp_ratio(runtime.combatants[ally]) < 0.55:
            var ally_distance := runtime.grid.distance(enemy_id, ally)
            if ally_distance <= 1:
                return {"action":"support", "target":ally, "reason":"ally_critical"}
            var support_cell := _best_step_toward(runtime, enemy_id, ally)
            if support_cell.x >= 0:
                return {"action":"move", "cell":support_cell, "target":ally, "reason":"support_ally"}
    var target := _choose_target(runtime, enemy_id, role)
    if target == "":
        return {"action":"none", "reason":"no_target"}
    var distance := runtime.grid.distance(enemy_id, target)
    var preferred_range := _preferred_range(role)
    if RANGED_ROLES.has(role) and distance < 2:
        var retreat_cell := _best_step_away(runtime, enemy_id, target)
        if retreat_cell.x >= 0:
            return {"action":"move", "cell":retreat_cell, "target":target, "reason":"restore_range"}
    if distance <= preferred_range:
        return {"action":"attack", "target":target, "reason":_attack_reason(role, runtime.combatants[target])}
    var move_cell := _best_step_toward(runtime, enemy_id, target)
    if move_cell.x >= 0:
        return {"action":"move", "cell":move_cell, "target":target, "reason":"close_distance"}
    return {"action":"hold", "target":target, "reason":"blocked"}

func _choose_target(runtime, enemy_id: String, role: String) -> String:
    var candidates: Array[String] = runtime.alive_ids("watcher")
    if candidates.is_empty():
        return ""
    var best := candidates[0]
    var best_score := -999999.0
    for target_id: String in candidates:
        var target: Dictionary = runtime.combatants[target_id]
        var distance := runtime.grid.distance(enemy_id, target_id)
        var hp_ratio := _hp_ratio(target)
        var score := 100.0 - float(distance) * 8.0
        if PREDATOR_ROLES.has(role):
            score += (1.0 - hp_ratio) * 65.0
            score += float(_body_severity(target)) * 8.0
        if role == "ranged":
            score += 12.0 if distance >= 2 and distance <= 4 else 0.0
        if role in ["controller", "psych", "psych_support"]:
            var stats: Dictionary = target.get("stats", {})
            score += (100.0 - float(stats.get("RES", 60))) * 0.25
        if score > best_score:
            best_score = score
            best = target_id
    return best

func _most_wounded_ally(runtime, enemy_id: String) -> String:
    var best := ""
    var best_ratio := 2.0
    for ally_id: String in runtime.alive_ids("enemy"):
        if ally_id == enemy_id:
            continue
        var ratio := _hp_ratio(runtime.combatants[ally_id])
        if ratio < best_ratio:
            best_ratio = ratio
            best = ally_id
    return best

func _preferred_range(role: String) -> int:
    if role == "ranged":
        return 4
    if role in ["psych", "psych_support", "controller"]:
        return 3
    return 1

func _attack_reason(role: String, target: Dictionary) -> String:
    if PREDATOR_ROLES.has(role) and (_hp_ratio(target) < 0.65 or _body_severity(target) >= 2):
        return "exploit_wounded_target"
    if role == "ranged":
        return "maintain_ranged_pressure"
    if role in ["psych", "psych_support"]:
        return "resolve_pressure"
    return "tactical_attack"

func _best_step_toward(runtime, source_id: String, target_id: String) -> Vector2i:
    var origin := runtime.grid.position_of(source_id)
    var target := runtime.grid.position_of(target_id)
    var best := Vector2i(-1, -1)
    var best_distance := 999
    for cell: Vector2i in runtime.grid.neighbors(origin):
        if runtime.grid.occupied(cell):
            continue
        var distance := _cell_distance(cell, target)
        if distance < best_distance:
            best_distance = distance
            best = cell
    return best

func _best_step_away(runtime, source_id: String, target_id: String) -> Vector2i:
    var origin := runtime.grid.position_of(source_id)
    var target := runtime.grid.position_of(target_id)
    var best := Vector2i(-1, -1)
    var best_distance := _cell_distance(origin, target)
    for cell: Vector2i in runtime.grid.neighbors(origin):
        if runtime.grid.occupied(cell):
            continue
        var distance := _cell_distance(cell, target)
        if distance > best_distance:
            best_distance = distance
            best = cell
    return best

func _best_escape_cell(runtime, source_id: String) -> Vector2i:
    var origin := runtime.grid.position_of(source_id)
    var watchers: Array[String] = runtime.alive_ids("watcher")
    var best := Vector2i(-1, -1)
    var best_score := -1
    for cell: Vector2i in runtime.grid.neighbors(origin):
        if runtime.grid.occupied(cell):
            continue
        var score := 0
        for watcher_id: String in watchers:
            score += _cell_distance(cell, runtime.grid.position_of(watcher_id))
        if score > best_score:
            best_score = score
            best = cell
    return best

func _hp_ratio(row: Dictionary) -> float:
    return float(row.get("hp", 0)) / maxf(1.0, float(row.get("max_hp", 1)))

func _body_severity(row: Dictionary) -> int:
    var body: Variant = row.get("body")
    if body == null or not body.has_method("serialize"):
        return 0
    var payload: Dictionary = body.call("serialize")
    var highest := 0
    for state_value: Variant in (payload.get("states", {}) as Dictionary).values():
        var state := str(state_value)
        if state.begins_with("L"):
            highest = maxi(highest, int(state.trim_prefix("L")))
    return highest

func _cell_distance(a: Vector2i, b: Vector2i) -> int:
    return absi(a.x - b.x) + absi(a.y - b.y)
