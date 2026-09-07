extends "res://scripts/core/veilleurs_tactical_session_v2.gd"
class_name VeilleursTacticalSessionV062

const RUNTIME_V062_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v062.gd")
const AUTHORED_V062_SCRIPT := preload("res://scripts/core/veilleurs_authored_encounter_runtime_v062.gd")

func start_first_combat(watcher_state: Dictionary = {}) -> Dictionary:
    runtime = RUNTIME_V062_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    var result: Dictionary = runtime.call("setup_first_combat")
    active = bool(result.get("ok", false))
    encounter_id = "veilleurs_v062_first_combat"
    region_id = "khar_sen"
    major_mutilation_keys.clear()
    watcher_kill_keys.clear()
    if active:
        _apply_watcher_state(watcher_state)
        _note_enemy_encounters()
        session_started.emit(snapshot())
        session_changed.emit(snapshot())
    return result

func start_authored_encounter(encounter: Dictionary, encounter_id_value: String, region_id_value: String = "khar_sen", watcher_state: Dictionary = {}) -> Dictionary:
    var authored: VeilleursAuthoredEncounterRuntimeV062 = AUTHORED_V062_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV062
    runtime = authored
    var result := authored.setup_authored_encounter(encounter)
    active = bool(result.get("ok", false))
    encounter_id = encounter_id_value if encounter_id_value != "" else str(encounter.get("template_id", "veilleurs_v062_authored"))
    region_id = region_id_value
    major_mutilation_keys.clear()
    watcher_kill_keys.clear()
    if active:
        _apply_watcher_state(watcher_state)
        _note_enemy_encounters()
        session_started.emit(snapshot())
        session_changed.emit(snapshot())
    return result

func configure_watcher_progression(watcher_id: String, level: int, specialization: String, reset_charges: bool = true) -> Dictionary:
    if not is_active() or runtime == null or not runtime.has_method("configure_watcher_progression"):
        return {"ok": false, "reason": "ultimate_runtime_unavailable"}
    var value: Variant = runtime.call("configure_watcher_progression", watcher_id, level, specialization, reset_charges)
    var result: Dictionary = value if value is Dictionary else {"ok": false, "reason": "invalid_runtime_result"}
    if bool(result.get("ok", false)):
        session_changed.emit(snapshot())
    return result

func note_vascular_knowledge(target_id: String, zone: String, certainty: int = 2) -> Dictionary:
    if not is_active() or runtime == null or not runtime.has_method("note_vascular_knowledge"):
        return {"ok": false, "reason": "ultimate_runtime_unavailable"}
    var value: Variant = runtime.call("note_vascular_knowledge", target_id, zone, certainty)
    var result: Dictionary = value if value is Dictionary else {"ok": false, "reason": "invalid_runtime_result"}
    if bool(result.get("ok", false)):
        session_changed.emit(snapshot())
    return result

func apply_bleeding(target_id: String, amount: int, wound_delta: int = 1) -> Dictionary:
    if not is_active() or runtime == null or not runtime.has_method("apply_bleeding"):
        return {"ok": false, "reason": "ultimate_runtime_unavailable"}
    var value: Variant = runtime.call("apply_bleeding", target_id, amount, wound_delta)
    var result: Dictionary = value if value is Dictionary else {"ok": false, "reason": "invalid_runtime_result"}
    if bool(result.get("ok", false)):
        session_changed.emit(snapshot())
    return result

func ultimate_status(attacker_id: String, target_id: String, branch: String) -> Dictionary:
    if not is_active() or runtime == null or not runtime.has_method("ultimate_status"):
        return {"available": false, "reason": "ultimate_runtime_unavailable"}
    var value: Variant = runtime.call("ultimate_status", attacker_id, target_id, branch, encounter_id)
    return value if value is Dictionary else {"available": false, "reason": "invalid_runtime_result"}

func resolve_ultimate(attacker_id: String, target_id: String, branch: String) -> Dictionary:
    if not is_active() or runtime == null or not runtime.has_method("resolve_ultimate"):
        return {"ok": false, "reason": "ultimate_runtime_unavailable"}
    var value: Variant = runtime.call("resolve_ultimate", attacker_id, target_id, branch, encounter_id)
    var result: Dictionary = value if value is Dictionary else {"ok": false, "reason": "invalid_runtime_result"}
    if bool(result.get("ok", false)):
        _record_major_body_event_if_needed(result)
        session_changed.emit(snapshot())
    return result

func watcher_aftermath() -> Dictionary:
    var result: Dictionary = super.watcher_aftermath()
    if runtime == null:
        return result
    for watcher_id_value: Variant in result.keys():
        var watcher_id := str(watcher_id_value)
        if not runtime.combatants.has(watcher_id):
            continue
        var row: Dictionary = runtime.combatants[watcher_id]
        var aftermath_row: Dictionary = result.get(watcher_id, {})
        aftermath_row["level"] = int(row.get("level", 1))
        aftermath_row["specialization"] = str(row.get("specialization", ""))
        aftermath_row["ultimate_state"] = (row.get("ultimate_state", {}) as Dictionary).duplicate(true)
        result[watcher_id] = aftermath_row
    return result

func deserialize(payload: Dictionary) -> void:
    reset()
    if payload.is_empty() or not bool(payload.get("active", false)):
        return
    var runtime_payload: Dictionary = payload.get("runtime", {})
    var restored: VeilleursTacticalCombatRuntimeV2
    if runtime_payload.has("encounter_template"):
        restored = AUTHORED_V062_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV062
    else:
        restored = RUNTIME_V062_SCRIPT.new() as VeilleursTacticalCombatRuntimeV062
    if restored == null or not restored.deserialize(runtime_payload):
        return
    runtime = restored
    active = true
    encounter_id = str(payload.get("encounter_id", "veilleurs_v062_first_combat"))
    region_id = str(payload.get("region_id", "khar_sen"))
    major_mutilation_keys = (payload.get("major_mutilation_keys", {}) as Dictionary).duplicate(true)
    watcher_kill_keys = (payload.get("watcher_kill_keys", {}) as Dictionary).duplicate(true)
    _restore_remanence_into_runtime()
    session_changed.emit(snapshot())

func _apply_watcher_state(watcher_state: Dictionary) -> void:
    if runtime == null or watcher_state.is_empty():
        return
    for watcher_id_value: Variant in watcher_state.keys():
        var watcher_id := str(watcher_id_value)
        if not runtime.combatants.has(watcher_id):
            continue
        var saved: Dictionary = watcher_state.get(watcher_id, {})
        var row: Dictionary = runtime.combatants[watcher_id]
        row["hp"] = clampi(int(saved.get("hp", row.get("hp", 0))), 0, int(row.get("max_hp", 1)))
        row["resolve_current"] = maxi(0, int(saved.get("resolve", row.get("resolve_current", 0))))
        row["level"] = clampi(int(saved.get("level", row.get("level", 1))), 1, 50)
        row["specialization"] = str(saved.get("specialization", row.get("specialization", "")))
        if saved.has("ultimate_state"):
            row["ultimate_state"] = (saved.get("ultimate_state", {}) as Dictionary).duplicate(true)
        var body_payload: Dictionary = saved.get("body", {})
        var body: VeilleursBodyComponent = row.get("body") as VeilleursBodyComponent
        if body != null and not body_payload.is_empty():
            body.deserialize(body_payload)
        runtime.combatants[watcher_id] = row
