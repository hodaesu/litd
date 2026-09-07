extends "res://scripts/core/veilleurs_remanence_combat_bridge_v08.gd"
class_name VeilleursRemanenceCombatBridgeV09

func prepare_enemy(runtime: Variant, enemy_id: String, region_id: String = "") -> Dictionary:
    var row: Dictionary = super.prepare_enemy(runtime, enemy_id, region_id)
    if row.is_empty() or RemanenceRuntime == null or not runtime.combatants.has(enemy_id):
        return row
    var remanence_id := str(row.get("remanence_id", ""))
    if remanence_id == "":
        return row
    var state: Dictionary = RemanenceRuntime.entity_state(remanence_id)
    var snapshot: Dictionary = state.get("body_snapshot", {})
    var body_state: Dictionary = snapshot.get("body_state", {})
    if body_state.is_empty():
        return row
    var body: Variant = row.get("body")
    if body != null and body.has_method("deserialize"):
        body.call("deserialize", body_state)
        row["body"] = body
        row["returning_body_restored"] = true
        row["persistent_missing_parts"] = (body_state.get("missing_parts", []) as Array).duplicate(true)
        runtime.combatants[enemy_id] = row
    return row.duplicate(true)

func returning_summary(runtime: Variant, enemy_id: String) -> Dictionary:
    if runtime == null or not runtime.combatants.has(enemy_id):
        return {}
    var row: Dictionary = runtime.combatants[enemy_id]
    var remanence_id := str(row.get("remanence_id", ""))
    if remanence_id == "":
        return {}
    var state: Dictionary = RemanenceRuntime.entity_state(remanence_id)
    return {
        "runtime_id":enemy_id,
        "remanence_id":remanence_id,
        "name":str(row.get("name", enemy_id)),
        "stage":str(state.get("stage", row.get("remanence_stage", "normal"))),
        "score":int(state.get("score", 0)),
        "encounters":int(state.get("encounters", 0)),
        "adaptations":(state.get("adaptations", []) as Array).duplicate(true),
        "missing_parts":(row.get("persistent_missing_parts", []) as Array).duplicate(true),
        "body_restored":bool(row.get("returning_body_restored", false))
    }
