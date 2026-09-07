extends "res://scripts/core/veilleurs_authored_encounter_runtime_v08.gd"
class_name VeilleursAuthoredEncounterRuntimeV09

const REMANENCE_V09_SCRIPT := preload("res://scripts/core/veilleurs_remanence_combat_bridge_v09.gd")
const SUBMISSION_SCRIPT := preload("res://scripts/core/veilleurs_submission_runtime_v09.gd")

var submission: VeilleursSubmissionRuntimeV09

func _init() -> void:
    super()
    remanence_bridge = REMANENCE_V09_SCRIPT.new() as VeilleursRemanenceCombatBridgeV09
    submission = SUBMISSION_SCRIPT.new() as VeilleursSubmissionRuntimeV09

func setup_authored_encounter(encounter: Dictionary, region_id: String = "") -> Dictionary:
    var result: Dictionary = super.setup_authored_encounter(encounter, region_id)
    if not bool(result.get("ok", false)):
        return result
    var returning: Array[Dictionary] = []
    for enemy_id: String in alive_ids("enemy"):
        var row: Dictionary = combatants[enemy_id]
        var remanence_id := str(row.get("remanence_id", ""))
        if remanence_id == "":
            continue
        var state: Dictionary = RemanenceRuntime.entity_state(remanence_id) if RemanenceRuntime != null else {}
        if str(state.get("stage", "normal")) not in ["elite", "nemesis"]:
            continue
        returning.append((remanence_bridge as VeilleursRemanenceCombatBridgeV09).returning_summary(self, enemy_id))
    result["returning_enemies"] = returning
    result["version"] = "0.9.0"
    return result

func attempt_subdue(target_id: String) -> Dictionary:
    return submission.subdue(self, target_id)

func subdue_status(target_id: String) -> Dictionary:
    return submission.evaluate(self, target_id)

func alive_ids(team: String = "") -> Array[String]:
    if team == "enemy":
        return submission.active_enemy_ids(self)
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

func enemy_step(enemy_id: String) -> Dictionary:
    if combatants.has(enemy_id) and bool((combatants[enemy_id] as Dictionary).get("subdued", false)):
        return {"ok":false, "reason":"enemy_subdued", "enemy":enemy_id}
    return super.enemy_step(enemy_id)
