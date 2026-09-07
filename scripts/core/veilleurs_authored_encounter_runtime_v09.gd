extends "res://scripts/core/veilleurs_authored_encounter_runtime_v08.gd"
class_name VeilleursAuthoredEncounterRuntimeV09

const REMANENCE_V09_SCRIPT := preload("res://scripts/core/veilleurs_remanence_combat_bridge_v09.gd")

func _init() -> void:
    super()
    remanence_bridge = REMANENCE_V09_SCRIPT.new() as VeilleursRemanenceCombatBridgeV09

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
