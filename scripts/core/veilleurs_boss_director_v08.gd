extends RefCounted
class_name VeilleursBossDirectorV08

func apply_round(runtime: Variant, boss_id: String, rule_state: Dictionary) -> Dictionary:
    if boss_id == "" or not runtime.combatants.has(boss_id) or not bool(rule_state.get("ok", false)):
        return {}
    match boss_id:
        "ENT_BOSS_GARDIEN_SEUIL":
            return _apply_gardien(runtime, boss_id, rule_state)
        "ENT_BOSS_CHOEUR_FENDU":
            return _apply_choeur(runtime, boss_id, rule_state)
        "ENT_BOSS_MERE_MUES":
            return _apply_mere(runtime, boss_id, rule_state)
        "ENT_BOSS_JUGE_SANS_VISAGE":
            return _apply_juge(runtime, boss_id, rule_state)
        "ENT_BOSS_ARCHIVISTE_AVEUGLE":
            return _apply_archiviste(runtime, boss_id, rule_state)
        _:
            return {}

func cell_locked(runtime: Variant, cell: Vector2i) -> bool:
    if not runtime.has_method("boss_rule_snapshot"):
        return false
    var state: Dictionary = runtime.call("boss_rule_snapshot") as Dictionary
    for value: Variant in state.get("locked_cells", []):
        if value is Array and (value as Array).size() >= 2:
            var coords: Array = value
            if Vector2i(int(coords[0]), int(coords[1])) == cell:
                return true
    return false

func _apply_gardien(runtime: Variant, boss_id: String, state: Dictionary) -> Dictionary:
    var registered := 0
    for value: Variant in state.get("locked_cells", []):
        if not (value is Array) or (value as Array).size() < 2:
            continue
        var coords: Array = value
        var cell := Vector2i(int(coords[0]), int(coords[1]))
        if runtime.has_method("register_terrain_effect"):
            runtime.call("register_terrain_effect", cell, "BOSS_GARDIEN_LOCK", boss_id, 1)
            registered += 1
    return {"boss":boss_id, "mechanic":"locked_cells", "applied":registered, "counter":"change_lane_before_lock"}

func _apply_choeur(runtime: Variant, boss_id: String, state: Dictionary) -> Dictionary:
    var uncertainty := clampi(int(state.get("uncertainty_tokens", 0)), 0, 3)
    var counter_active := _counter_active(runtime, "counter_chorus_tells")
    var penalty := 0 if counter_active else uncertainty * 3
    for watcher_id: String in runtime.alive_ids("watcher"):
        var row: Dictionary = runtime.combatants[watcher_id]
        row["sensory_uncertainty"] = uncertainty
        row["accuracy_penalty"] = penalty
        runtime.combatants[watcher_id] = row
    return {"boss":boss_id, "mechanic":"sensory_uncertainty", "tokens":uncertainty, "accuracy_penalty":penalty, "counter_active":counter_active}

func _apply_mere(runtime: Variant, boss_id: String, state: Dictionary) -> Dictionary:
    var row: Dictionary = runtime.combatants[boss_id]
    var stacks := clampi(int(state.get("mutation_stacks", row.get("mutation_stacks", 0))), 0, 3)
    row["mutation_stacks"] = stacks
    row["weapon_power"] = maxi(int(row.get("weapon_power", 40)), 42 + stacks * 4)
    row["guard_bonus"] = maxi(int(row.get("guard_bonus", 0)), stacks * 5)
    runtime.combatants[boss_id] = row
    return {"boss":boss_id, "mechanic":"mutation", "stacks":stacks, "weapon_power":int(row["weapon_power"]), "counter":"vary_damage_zones_and_delay_mutilation"}

func _apply_juge(runtime: Variant, boss_id: String, state: Dictionary) -> Dictionary:
    var judgments: Array = state.get("judgments", [])
    var severity := mini(4, judgments.size())
    var counter_active := _counter_active(runtime, "counter_accept_judgment")
    var pressure := maxi(0, severity * 3 - (4 if counter_active else 0))
    for watcher_id: String in runtime.alive_ids("watcher"):
        var row: Dictionary = runtime.combatants[watcher_id]
        var max_res := int((row.get("stats", {}) as Dictionary).get("RES", 60))
        row["resolve_current"] = maxi(0, int(row.get("resolve_current", max_res)) - pressure)
        runtime.combatants[watcher_id] = row
    return {"boss":boss_id, "mechanic":"recorded_judgment", "judgments":judgments.duplicate(), "resolve_pressure":pressure, "counter_active":counter_active}

func _apply_archiviste(runtime: Variant, boss_id: String, state: Dictionary) -> Dictionary:
    var adaptation := str(state.get("adaptation", ""))
    var row: Dictionary = runtime.combatants[boss_id]
    row["archivist_adaptation"] = adaptation
    if adaptation != "":
        row["accuracy_bonus"] = maxi(int(row.get("accuracy_bonus", 0)), 6)
        row["guard_bonus"] = maxi(int(row.get("guard_bonus", 0)), 6)
    else:
        row["accuracy_bonus"] = 0
    runtime.combatants[boss_id] = row
    return {"boss":boss_id, "mechanic":"bounded_adaptation", "adaptation":adaptation, "observations":int(state.get("observations", 0)), "counter":"vary_actions"}

func _counter_active(runtime: Variant, expected: String) -> bool:
    if not runtime.has_method("boss_rule_snapshot"):
        return false
    var state: Dictionary = runtime.call("boss_rule_snapshot") as Dictionary
    return str(state.get("active_counter", "")) == expected
