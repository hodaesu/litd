extends RefCounted
class_name VeilleursSubmissionRuntimeV09

const HP_RATIO_THRESHOLD := 0.35
const RESOLVE_THRESHOLD := 20
const CONTROL_STATUSES: Array[String] = ["FEAR", "PINNED", "IMMOBILIZED", "STAGGER"]

func evaluate(runtime: Variant, target_id: String) -> Dictionary:
    if runtime == null or not runtime.combatants.has(target_id):
        return {"ok":false, "reason":"unknown_target"}
    var row: Dictionary = runtime.combatants[target_id]
    if str(row.get("team", "")) != "enemy":
        return {"ok":false, "reason":"target_not_enemy"}
    if bool(row.get("boss", false)) or target_id.begins_with("ENT_BOSS_"):
        return {"ok":false, "reason":"boss_not_subduable"}
    if int(row.get("hp", 0)) <= 0:
        return {"ok":false, "reason":"target_dead"}
    if bool(row.get("subdued", false)):
        return {"ok":false, "reason":"already_subdued"}
    var max_hp := maxi(1, int(row.get("max_hp", 1)))
    var hp_ratio := float(int(row.get("hp", 0))) / float(max_hp)
    var resolve := int(row.get("resolve_current", (row.get("stats", {}) as Dictionary).get("RES", 60)))
    var statuses: Dictionary = row.get("statuses", {})
    var control_status := ""
    for status: String in CONTROL_STATUSES:
        if statuses.has(status):
            control_status = status
            break
    var vulnerable := hp_ratio <= HP_RATIO_THRESHOLD or resolve <= RESOLVE_THRESHOLD or control_status != ""
    if not vulnerable:
        return {
            "ok":false,
            "reason":"target_not_submittable",
            "hp_ratio":hp_ratio,
            "resolve":resolve,
            "required_hp_ratio":HP_RATIO_THRESHOLD,
            "required_resolve":RESOLVE_THRESHOLD,
            "accepted_statuses":CONTROL_STATUSES.duplicate()
        }
    return {
        "ok":true,
        "target":target_id,
        "hp_ratio":hp_ratio,
        "resolve":resolve,
        "control_status":control_status,
        "reason":"visible_submission_condition"
    }

func subdue(runtime: Variant, target_id: String) -> Dictionary:
    var evaluation := evaluate(runtime, target_id)
    if not bool(evaluation.get("ok", false)):
        return evaluation
    var row: Dictionary = runtime.combatants[target_id]
    row["subdued"] = true
    var statuses: Dictionary = row.get("statuses", {})
    statuses["SUBDUED"] = {"remaining":9999, "strength":1}
    row["statuses"] = statuses
    row["guard_bonus"] = 0
    runtime.combatants[target_id] = row
    var result := evaluation.duplicate(true)
    result["action"] = "subdue"
    result["subdued"] = true
    if runtime.action_log is Array:
        runtime.action_log.append(result.duplicate(true))
    return result

func active_enemy_ids(runtime: Variant) -> Array[String]:
    var result: Array[String] = []
    if runtime == null:
        return result
    for id_value: Variant in runtime.combatants.keys():
        var entity_id := str(id_value)
        var row: Dictionary = runtime.combatants[entity_id]
        if str(row.get("team", "")) != "enemy" or int(row.get("hp", 0)) <= 0 or bool(row.get("subdued", false)):
            continue
        result.append(entity_id)
    return result
