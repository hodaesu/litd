extends RefCounted
class_name VeilleursRemanenceCombatBridgeV08

const MAX_ACTION_OBSERVATIONS := 8

func prepare_enemy(runtime: Variant, enemy_id: String, region_id: String = "") -> Dictionary:
    if RemanenceRuntime == null or not runtime.combatants.has(enemy_id):
        return {}
    var row: Dictionary = runtime.combatants[enemy_id]
    var source := {
        "id": str(row.get("definition_id", enemy_id)),
        "species_id": str(row.get("definition_id", enemy_id)),
        "name": str(row.get("name", enemy_id)),
        "remanence_id": str(row.get("remanence_id", ""))
    }
    var remanence_id := RemanenceRuntime.prepare_enemy(source, region_id)
    row["remanence_id"] = remanence_id
    RemanenceRuntime.note_encounter(source, region_id, {"summary":"Encountered in Veilleurs tactical runtime"})
    _sync_record_into_row(row, RemanenceRuntime.entity_state(remanence_id))
    runtime.combatants[enemy_id] = row
    return row.duplicate(true)

func refresh_enemy(runtime: Variant, enemy_id: String) -> Dictionary:
    if RemanenceRuntime == null or not runtime.combatants.has(enemy_id):
        return {}
    var row: Dictionary = runtime.combatants[enemy_id]
    var remanence_id := str(row.get("remanence_id", ""))
    if remanence_id == "":
        return prepare_enemy(runtime, enemy_id)
    _sync_record_into_row(row, RemanenceRuntime.entity_state(remanence_id))
    runtime.combatants[enemy_id] = row
    return row.duplicate(true)

func finish_enemy(runtime: Variant, enemy_id: String, outcome: String, context: Dictionary = {}) -> Dictionary:
    if RemanenceRuntime == null or not runtime.combatants.has(enemy_id):
        return {}
    var row: Dictionary = runtime.combatants[enemy_id]
    var remanence_id := str(row.get("remanence_id", ""))
    if remanence_id == "":
        prepare_enemy(runtime, enemy_id, str(context.get("region_id", "")))
        row = runtime.combatants[enemy_id]
        remanence_id = str(row.get("remanence_id", ""))
    var event_type := _event_for_outcome(outcome, row)
    var event_context := context.duplicate(true)
    event_context["summary"] = str(context.get("summary", "%s — %s" % [str(row.get("name", enemy_id)), outcome]))
    var event := RemanenceRuntime.record_event(remanence_id, event_type, event_context)
    if bool(context.get("major_mutilation", false)):
        RemanenceRuntime.record_event(remanence_id, "major_mutilation", event_context)
    if bool(context.get("killed_watcher", false)):
        RemanenceRuntime.record_event(remanence_id, "killed_watcher", event_context)
    _sync_body(runtime, enemy_id)
    _learn_from_player(runtime, enemy_id)
    refresh_enemy(runtime, enemy_id)
    return {"event":event, "state":RemanenceRuntime.entity_state(remanence_id)}

func mark_recruited(runtime: Variant, enemy_id: String) -> bool:
    if RemanenceRuntime == null or not runtime.combatants.has(enemy_id):
        return false
    var row: Dictionary = runtime.combatants[enemy_id]
    var remanence_id := str(row.get("remanence_id", ""))
    if remanence_id == "":
        prepare_enemy(runtime, enemy_id)
        remanence_id = str((runtime.combatants[enemy_id] as Dictionary).get("remanence_id", ""))
    if remanence_id == "":
        return false
    RemanenceRuntime.set_entity_status(remanence_id, "recruited")
    return true

func nemesis_candidates(runtime: Variant) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if RemanenceRuntime == null:
        return result
    for enemy_id: String in runtime.alive_ids("enemy"):
        var row: Dictionary = runtime.combatants[enemy_id]
        var remanence_id := str(row.get("remanence_id", ""))
        if remanence_id == "":
            continue
        var state := RemanenceRuntime.entity_state(remanence_id)
        if str(state.get("stage", "normal")) in ["elite", "nemesis"]:
            result.append({"combatant_id":enemy_id, "remanence_id":remanence_id, "stage":str(state.get("stage", "normal")), "score":int(state.get("score", 0)), "adaptations":state.get("adaptations", []).duplicate(true)})
    return result

func _sync_record_into_row(row: Dictionary, record: Dictionary) -> void:
    if record.is_empty():
        return
    row["remanence_stage"] = str(record.get("stage", "normal"))
    row["adaptations"] = (record.get("adaptations", []) as Array).duplicate(true)
    row["remanence_score"] = int(record.get("score", 0))
    row["remanence_encounters"] = int(record.get("encounters", 0))
    row["remanence_status"] = str(record.get("status", "active"))

func _sync_body(runtime: Variant, enemy_id: String) -> void:
    var row: Dictionary = runtime.combatants[enemy_id]
    var body: Variant = row.get("body")
    var body_state: Dictionary = body.call("serialize") if body != null and body.has_method("serialize") else {}
    RemanenceRuntime.sync_body_snapshot({
        "remanence_id":str(row.get("remanence_id", "")),
        "id":str(row.get("definition_id", enemy_id)),
        "name":str(row.get("name", enemy_id)),
        "hp":int(row.get("hp", 0)),
        "max_hp":int(row.get("max_hp", 0)),
        "persistent_injuries":body_state.get("missing_parts", []).duplicate(true),
        "body_state":body_state
    })

func _learn_from_player(runtime: Variant, enemy_id: String) -> void:
    var row: Dictionary = runtime.combatants[enemy_id]
    var stage := str(row.get("remanence_stage", "normal"))
    if stage not in ["veteran", "elite", "nemesis"]:
        return
    var frequencies: Dictionary = {}
    var inspected := 0
    for index: int in range(runtime.action_log.size() - 1, -1, -1):
        if inspected >= MAX_ACTION_OBSERVATIONS:
            break
        var action: Dictionary = runtime.action_log[index]
        var attacker_id := str(action.get("attacker", ""))
        if not runtime.combatants.has(attacker_id) or str((runtime.combatants[attacker_id] as Dictionary).get("team", "")) != "watcher":
            continue
        inspected += 1
        var tag := str(action.get("action", action.get("skill_id", "attack")))
        frequencies[tag] = int(frequencies.get(tag, 0)) + 1
    var dominant := ""
    var count := 0
    for key_value: Variant in frequencies.keys():
        var key := str(key_value)
        if int(frequencies[key]) > count:
            dominant = key
            count = int(frequencies[key])
    if count < 3:
        return
    var adaptation := ""
    if dominant in ["guard", "support"]:
        adaptation = "counter_guard"
    elif dominant in ["move", "attack_move"]:
        adaptation = "keep_distance"
    elif dominant in ["attack", "psychological", "control"]:
        adaptation = "pressure_wounded"
    if adaptation != "":
        RemanenceRuntime.add_adaptation(str(row.get("remanence_id", "")), adaptation)

func _event_for_outcome(outcome: String, row: Dictionary) -> String:
    if outcome in ["killed", "dead", "defeat_enemy"] or int(row.get("hp", 0)) <= 0:
        return "killed"
    if outcome in ["retreat", "player_retreat", "forced_retreat"]:
        return "forced_retreat"
    if outcome in ["escaped", "enemy_escape"]:
        return "escaped"
    return "survived_combat"
