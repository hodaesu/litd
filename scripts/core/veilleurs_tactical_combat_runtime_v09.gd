extends "res://scripts/core/veilleurs_tactical_combat_runtime_v08.gd"
class_name VeilleursTacticalCombatRuntimeV09

const PHASE_SCRIPT := preload("res://scripts/core/veilleurs_boss_phase_runtime_v09.gd")
const REMANENCE_V09_SCRIPT := preload("res://scripts/core/veilleurs_remanence_combat_bridge_v09.gd")
const SUBMISSION_SCRIPT := preload("res://scripts/core/veilleurs_submission_runtime_v09.gd")

var boss_phase: VeilleursBossPhaseRuntimeV09
var submission: VeilleursSubmissionRuntimeV09
var last_phase_event: Dictionary = {}

func _init() -> void:
    super()
    boss_phase = PHASE_SCRIPT.new() as VeilleursBossPhaseRuntimeV09
    submission = SUBMISSION_SCRIPT.new() as VeilleursSubmissionRuntimeV09
    remanence_bridge = REMANENCE_V09_SCRIPT.new() as VeilleursRemanenceCombatBridgeV09

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"], region_id: String = "khar_sen") -> Dictionary:
    last_phase_event.clear()
    return super.setup_first_combat(enemy_ids, region_id)

func setup_boss_combat(boss_id: String, context: Dictionary = {}) -> Dictionary:
    last_phase_event.clear()
    var result: Dictionary = super.setup_boss_combat(boss_id, context)
    if not bool(result.get("ok", false)):
        return result
    result["boss_phase"] = boss_phase.begin(boss_id)
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

func next_round() -> void:
    super.next_round()
    if active_boss_id == "" or not combatants.has(active_boss_id) or int((combatants[active_boss_id] as Dictionary).get("hp", 0)) <= 0:
        return
    last_phase_event = boss_phase.update(self)
    if not last_phase_event.is_empty():
        action_log.append({"ok":true, "action":"boss_phase", "boss":active_boss_id, "state":last_phase_event.duplicate(true)})

func boss_phase_snapshot() -> Dictionary:
    return boss_phase.snapshot()

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["v09_boss_phase"] = boss_phase.snapshot()
    payload["v09_last_phase_event"] = last_phase_event.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    boss_phase.restore(payload.get("v09_boss_phase", {}))
    last_phase_event = (payload.get("v09_last_phase_event", {}) as Dictionary).duplicate(true)
    return true
