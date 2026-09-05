extends RefCounted

const MANIFEST_PATH := "res://data/veilleurs/boss_production_manifest.json"
const BossContractRuntime := preload("res://scripts/core/veilleurs_boss_contract_runtime.gd")

var payload: Dictionary = {}
var bosses_by_act: Dictionary = {}
var bosses_by_id: Dictionary = {}
var contract_runtime: RefCounted

func _init() -> void:
    contract_runtime = BossContractRuntime.new()
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if not (parsed is Dictionary):
        return
    payload = parsed
    for value: Variant in payload.get("bosses", []):
        if not (value is Dictionary):
            continue
        var boss: Dictionary = (value as Dictionary).duplicate(true)
        var act_id := str(boss.get("act_id", ""))
        var boss_id := str(boss.get("boss_id", ""))
        if act_id != "":
            bosses_by_act[act_id] = boss
        if boss_id != "":
            bosses_by_id[boss_id] = boss

func boss_count() -> int:
    return bosses_by_id.size()

func boss_for_act(act_id: String) -> Dictionary:
    return (bosses_by_act.get(act_id, {}) as Dictionary).duplicate(true)

func boss_by_id(boss_id: String) -> Dictionary:
    return (bosses_by_id.get(boss_id, {}) as Dictionary).duplicate(true)

func route_after_preboss(act_id: String, depth: int, preboss_completed: bool) -> Dictionary:
    var boss := boss_for_act(act_id)
    if boss.is_empty():
        return {"spawn_boss": false, "reason": "boss_missing", "act_id": act_id}
    var required_depth := int(boss.get("preboss_depth", 5))
    if depth != required_depth:
        return {
            "spawn_boss": false,
            "reason": "not_preboss_depth",
            "act_id": act_id,
            "required_depth": required_depth,
            "current_depth": depth
        }
    if not preboss_completed:
        return {
            "spawn_boss": false,
            "reason": "preboss_not_completed",
            "act_id": act_id,
            "required_depth": required_depth
        }
    var routed := boss.duplicate(true)
    routed["spawn_boss"] = true
    routed["reason"] = "preboss_completed"
    routed["source"] = "boss_production_router"
    return routed

func validate_contract() -> Dictionary:
    var errors: Array[String] = []
    if boss_count() != int(payload.get("boss_count", 5)):
        errors.append("boss_count")
    var expected_acts: Array[String] = ["I", "II", "III", "IV", "V"]
    var expected_phases := {"I":3,"II":3,"III":3,"IV":3,"V":4}
    for act_id: String in expected_acts:
        if not bosses_by_act.has(act_id):
            errors.append("missing_act:%s" % act_id)
            continue
        var boss: Dictionary = bosses_by_act[act_id]
        if int(boss.get("phase_count", 0)) != int(expected_phases[act_id]):
            errors.append("phase_count:%s" % act_id)
        if bool(boss.get("recruitable", true)):
            errors.append("recruitable:%s" % act_id)
        if bool(boss.get("standard_generator_injection", true)):
            errors.append("standard_injection:%s" % act_id)
        if int(boss.get("preboss_depth", 0)) != 5:
            errors.append("preboss_depth:%s" % act_id)
        for method_value: Variant in boss.get("contract_methods", []):
            var method := str(method_value)
            if method == "" or not contract_runtime.has_method(method):
                errors.append("contract_method:%s:%s" % [act_id, method])
    return {
        "valid": errors.is_empty(),
        "errors": errors,
        "boss_count": boss_count(),
        "acts": expected_acts
    }
