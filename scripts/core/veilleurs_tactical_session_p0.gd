extends "res://scripts/core/veilleurs_tactical_session_v2.gd"
class_name VeilleursTacticalSessionP0

const RUNTIME_P0_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v4.gd")
const AUTHORED_P0_SCRIPT := preload("res://scripts/core/veilleurs_authored_encounter_runtime_p0.gd")

func start_first_combat() -> Dictionary:
    runtime = RUNTIME_P0_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    var result := (runtime as VeilleursTacticalCombatRuntimeV4).setup_first_combat()
    active = bool(result.get("ok", false))
    encounter_id = "veilleurs_v061_first_combat"
    region_id = "khar_sen"
    major_mutilation_keys.clear()
    watcher_kill_keys.clear()
    if active:
        _note_enemy_encounters()
        session_started.emit(snapshot())
        session_changed.emit(snapshot())
    return result

func start_authored_encounter(encounter: Dictionary, encounter_id_value: String, region_id_value: String = "khar_sen") -> Dictionary:
    var authored := AUTHORED_P0_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeP0
    runtime = authored
    var result := authored.setup_authored_encounter(encounter)
    active = bool(result.get("ok", false))
    encounter_id = encounter_id_value if encounter_id_value != "" else str(encounter.get("template_id", "veilleurs_v061_authored"))
    region_id = region_id_value
    major_mutilation_keys.clear()
    watcher_kill_keys.clear()
    if active:
        _note_enemy_encounters()
        session_started.emit(snapshot())
        session_changed.emit(snapshot())
    return result

func resolve_basic_action(attacker_id: String, target_id: String, action_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    if not is_active() or runtime == null or not runtime.has_method("resolve_basic_action"):
        return {"ok":false, "reason":"basic_action_runtime_unavailable"}
    var result: Dictionary = runtime.call("resolve_basic_action", attacker_id, target_id, action_id, zone, forced_roll)
    if bool(result.get("ok", false)):
        _record_major_body_event_if_needed(result)
        session_changed.emit(snapshot())
    return result

func basic_actions_for(entity_id: String) -> Array[Dictionary]:
    if not is_active() or runtime == null or not runtime.has_method("basic_actions_for"):
        return []
    var result: Variant = runtime.call("basic_actions_for", entity_id)
    return result if result is Array else []

func available_basic_actions(entity_id: String) -> Array[Dictionary]:
    if not is_active() or runtime == null or not runtime.has_method("available_basic_actions"):
        return []
    var result: Variant = runtime.call("available_basic_actions", entity_id)
    return result if result is Array else []

func deserialize(payload: Dictionary) -> void:
    reset()
    if payload.is_empty() or not bool(payload.get("active", false)):
        return
    var runtime_payload: Dictionary = payload.get("runtime", {})
    var restored: VeilleursTacticalCombatRuntimeV2
    if runtime_payload.has("encounter_template"):
        restored = AUTHORED_P0_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    else:
        restored = RUNTIME_P0_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    if restored == null or not restored.deserialize(runtime_payload):
        return
    runtime = restored
    active = true
    encounter_id = str(payload.get("encounter_id", "veilleurs_v061_first_combat"))
    region_id = str(payload.get("region_id", "khar_sen"))
    major_mutilation_keys = (payload.get("major_mutilation_keys", {}) as Dictionary).duplicate(true)
    watcher_kill_keys = (payload.get("watcher_kill_keys", {}) as Dictionary).duplicate(true)
    _restore_remanence_into_runtime()
    session_changed.emit(snapshot())
