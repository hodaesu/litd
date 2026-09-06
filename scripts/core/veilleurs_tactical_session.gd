extends Node

signal session_started(snapshot: Dictionary)
signal session_changed(snapshot: Dictionary)
signal session_finished(summary: Dictionary)

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime.gd")

var runtime: VeilleursTacticalCombatRuntime = null
var active := false
var encounter_id := ""
var region_id := ""

func start_first_combat() -> Dictionary:
    runtime = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntime
    var result := runtime.setup_first_combat()
    active = bool(result.get("ok", false))
    encounter_id = "veilleurs_v06_first_combat"
    region_id = "khar_sen"
    if active:
        _note_enemy_encounters()
        session_started.emit(snapshot())
        session_changed.emit(snapshot())
    return result

func is_active() -> bool:
    return active and runtime != null

func resolve_skill(attacker_id: String, target_id: String, skill_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    if not is_active():
        return {"ok": false, "reason": "inactive"}
    var result := runtime.resolve_skill(attacker_id, target_id, skill_id, zone, forced_roll)
    if bool(result.get("ok", false)):
        session_changed.emit(snapshot())
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    if not is_active():
        return {"ok": false, "reason": "inactive"}
    var result := runtime.enemy_step(enemy_id)
    if bool(result.get("ok", false)):
        session_changed.emit(snapshot())
    return result

func finish(reason: String = "resolved") -> Dictionary:
    if not is_active():
        return {"ok": false, "reason": "inactive"}
    _commit_enemy_remanence(reason)
    var summary := {
        "ok": true,
        "reason": reason,
        "encounter_id": encounter_id,
        "round": runtime.round_index,
        "watchers_alive": runtime.alive_ids("watcher"),
        "enemies_alive": runtime.alive_ids("enemy")
    }
    active = false
    session_finished.emit(summary.duplicate(true))
    return summary

func reset() -> void:
    runtime = null
    active = false
    encounter_id = ""
    region_id = ""

func snapshot() -> Dictionary:
    return {
        "active": active,
        "encounter_id": encounter_id,
        "region_id": region_id,
        "runtime": runtime.serialize() if runtime != null else {}
    }

func serialize() -> Dictionary:
    return snapshot()

func deserialize(payload: Dictionary) -> void:
    reset()
    if payload.is_empty() or not bool(payload.get("active", false)):
        return
    var restored: VeilleursTacticalCombatRuntime = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntime
    if not restored.deserialize(payload.get("runtime", {})):
        return
    runtime = restored
    active = true
    encounter_id = str(payload.get("encounter_id", "veilleurs_v06_first_combat"))
    region_id = str(payload.get("region_id", "khar_sen"))
    session_changed.emit(snapshot())

func _note_enemy_encounters() -> void:
    if runtime == null:
        return
    for enemy_id: String in runtime.alive_ids("enemy"):
        var row: Dictionary = runtime.combatants.get(enemy_id, {})
        var bridge_enemy := _remanence_enemy(row)
        RemanenceRuntime.note_encounter(bridge_enemy, region_id, {"summary":"Premier combat tactique v0.6", "encounter_id":encounter_id})
        row["remanence_id"] = str(bridge_enemy.get("remanence_id", ""))
        runtime.combatants[enemy_id] = row

func _commit_enemy_remanence(reason: String) -> void:
    if runtime == null:
        return
    for entity_id_value: Variant in runtime.combatants.keys():
        var entity_id := str(entity_id_value)
        var row: Dictionary = runtime.combatants[entity_id]
        if str(row.get("team", "")) != "enemy":
            continue
        var bridge_enemy := _remanence_enemy(row)
        var remanence_id := str(row.get("remanence_id", ""))
        if remanence_id != "":
            bridge_enemy["remanence_id"] = remanence_id
        RemanenceRuntime.prepare_enemy(bridge_enemy, region_id)
        var body: VeilleursBodyComponent = row.get("body") as VeilleursBodyComponent
        var body_payload := body.serialize()
        bridge_enemy["body_state"] = body_payload.get("states", {})
        bridge_enemy["persistent_injuries"] = _persistent_injuries(body_payload)
        RemanenceRuntime.sync_body_snapshot(bridge_enemy)
        var event_type := "killed_by_watchers" if int(row.get("hp", 0)) <= 0 else ("escaped" if reason == "retreat" else "survived_player")
        RemanenceRuntime.record_enemy_event(bridge_enemy, event_type, {"region_id":region_id, "summary":"Combat v0.6: %s" % reason, "encounter_id":encounter_id})
        if not (body_payload.get("missing_parts", []) as Array).is_empty():
            RemanenceRuntime.record_enemy_event(bridge_enemy, "lost_limb", {"region_id":region_id, "summary":"Mutilation persistante pendant le combat v0.6"})

func _remanence_enemy(row: Dictionary) -> Dictionary:
    return {
        "id": str(row.get("entity_id", "unknown")),
        "species_id": str(row.get("entity_id", "unknown")),
        "name": str(row.get("name", "Adversaire")),
        "hp": int(row.get("hp", 0)),
        "max_hp": int(row.get("max_hp", 1)),
        "remanence_id": str(row.get("remanence_id", ""))
    }

func _persistent_injuries(body_payload: Dictionary) -> Array:
    var result: Array = []
    var states: Dictionary = body_payload.get("states", {})
    for zone_value: Variant in states.keys():
        var zone := str(zone_value)
        var state := str(states.get(zone, "L0"))
        if state != "L0":
            result.append({"zone":zone, "state":state})
    for value: Variant in body_payload.get("missing_parts", []):
        result.append({"zone":str(value), "state":"L5", "missing":true})
    return result
