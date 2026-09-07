extends Node
class_name VeilleursTacticalSessionV2

signal session_started(snapshot: Dictionary)
signal session_changed(snapshot: Dictionary)
signal session_finished(summary: Dictionary)

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd")
const SNAPSHOT_PATH := "user://veilleurs_v061_tactical_snapshot.json"

var runtime: VeilleursTacticalCombatRuntimeV2 = null
var active := false
var encounter_id := ""
var region_id := ""
var major_mutilation_keys: Dictionary = {}
var watcher_kill_keys: Dictionary = {}

func start_first_combat() -> Dictionary:
    runtime = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    var result := runtime.setup_first_combat()
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

func is_active() -> bool:
    return active and runtime != null

func resolve_skill(attacker_id: String, target_id: String, skill_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    if not is_active():
        return {"ok":false, "reason":"inactive"}
    var result := runtime.resolve_skill(attacker_id, target_id, skill_id, zone, forced_roll)
    if bool(result.get("ok", false)):
        _record_major_body_event_if_needed(result)
        session_changed.emit(snapshot())
    return result

func enemy_step(enemy_id: String) -> Dictionary:
    if not is_active():
        return {"ok":false, "reason":"inactive"}
    var result := runtime.enemy_step(enemy_id)
    if bool(result.get("ok", false)):
        _record_watcher_kill_if_needed(enemy_id, result)
        session_changed.emit(snapshot())
    return result

func finish(reason: String = "resolved") -> Dictionary:
    if not is_active():
        return {"ok":false, "reason":"inactive"}
    _commit_enemy_remanence(reason)
    var summary := {
        "ok":true,
        "reason":reason,
        "encounter_id":encounter_id,
        "round":runtime.round_index,
        "watchers_alive":runtime.alive_ids("watcher"),
        "enemies_alive":runtime.alive_ids("enemy")
    }
    active = false
    session_finished.emit(summary.duplicate(true))
    return summary

func reset() -> void:
    runtime = null
    active = false
    encounter_id = ""
    region_id = ""
    major_mutilation_keys.clear()
    watcher_kill_keys.clear()

func snapshot() -> Dictionary:
    return {
        "active":active,
        "encounter_id":encounter_id,
        "region_id":region_id,
        "runtime":runtime.serialize() if runtime != null else {},
        "major_mutilation_keys":major_mutilation_keys.duplicate(true),
        "watcher_kill_keys":watcher_kill_keys.duplicate(true)
    }

func serialize() -> Dictionary:
    return snapshot()

func deserialize(payload: Dictionary) -> void:
    reset()
    if payload.is_empty() or not bool(payload.get("active", false)):
        return
    var restored: VeilleursTacticalCombatRuntimeV2 = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    if not restored.deserialize(payload.get("runtime", {})):
        return
    runtime = restored
    active = true
    encounter_id = str(payload.get("encounter_id", "veilleurs_v061_first_combat"))
    region_id = str(payload.get("region_id", "khar_sen"))
    major_mutilation_keys = (payload.get("major_mutilation_keys", {}) as Dictionary).duplicate(true)
    watcher_kill_keys = (payload.get("watcher_kill_keys", {}) as Dictionary).duplicate(true)
    _restore_remanence_into_runtime()
    session_changed.emit(snapshot())

func save_snapshot(path: String = SNAPSHOT_PATH) -> bool:
    var payload := {"version":"0.6.1", "session":serialize(), "remanence":RemanenceRuntime.serialize()}
    var body := JSON.stringify(payload)
    var envelope := JSON.stringify({"checksum":body.sha256_text(), "body":body})
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(envelope)
    file.flush()
    file.close()
    return true

func load_snapshot(path: String = SNAPSHOT_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var envelope_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (envelope_value is Dictionary):
        return false
    var envelope: Dictionary = envelope_value
    var body := str(envelope.get("body", ""))
    if body == "" or str(envelope.get("checksum", "")) != body.sha256_text():
        return false
    var payload_value: Variant = JSON.parse_string(body)
    if not (payload_value is Dictionary):
        return false
    var payload: Dictionary = payload_value
    if str(payload.get("version", "")) != "0.6.1":
        return false
    RemanenceRuntime.deserialize(payload.get("remanence", {}))
    deserialize(payload.get("session", {}))
    return is_active()

func delete_snapshot(path: String = SNAPSHOT_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return true
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

func _note_enemy_encounters() -> void:
    if runtime == null:
        return
    for enemy_id: String in runtime.alive_ids("enemy"):
        var row: Dictionary = runtime.combatants.get(enemy_id, {})
        var bridge_enemy := _remanence_enemy(row)
        RemanenceRuntime.note_encounter(bridge_enemy, region_id, {"summary":"Premier combat tactique v0.6.1", "encounter_id":encounter_id})
        var remanence_id := str(bridge_enemy.get("remanence_id", ""))
        row["remanence_id"] = remanence_id
        runtime.combatants[enemy_id] = row
        runtime.apply_remanence_state(enemy_id, remanence_id)

func _restore_remanence_into_runtime() -> void:
    if runtime == null:
        return
    for enemy_id: String in runtime.alive_ids("enemy"):
        var row: Dictionary = runtime.combatants.get(enemy_id, {})
        runtime.apply_remanence_state(enemy_id, str(row.get("remanence_id", "")))

func _record_major_body_event_if_needed(result: Dictionary) -> void:
    var target_id := str(result.get("target", ""))
    if target_id == "" or not runtime.combatants.has(target_id):
        return
    var row: Dictionary = runtime.combatants[target_id]
    if str(row.get("team", "")) != "enemy":
        return
    var body_result: Dictionary = result.get("body", {})
    if not bool(body_result.get("severed", false)):
        return
    var zone := str(result.get("zone", ""))
    var event_key := "%s:%s" % [target_id, zone]
    if major_mutilation_keys.has(event_key):
        return
    var bridge_enemy := _remanence_enemy(row)
    bridge_enemy["remanence_id"] = str(row.get("remanence_id", ""))
    RemanenceRuntime.record_enemy_event(bridge_enemy, "major_mutilation", {
        "region_id":region_id,
        "hero_id":str(result.get("attacker", "")),
        "summary":"Mutilation majeure pendant %s" % encounter_id,
        "zone":zone,
        "encounter_id":encounter_id
    })
    major_mutilation_keys[event_key] = true
    _sync_runtime_remanence(target_id)

func _record_watcher_kill_if_needed(enemy_id: String, result: Dictionary) -> void:
    var target_id := str(result.get("target", ""))
    if target_id == "" or not runtime.combatants.has(target_id) or not runtime.combatants.has(enemy_id):
        return
    var target: Dictionary = runtime.combatants[target_id]
    if str(target.get("team", "")) != "watcher" or int(target.get("hp", 0)) > 0:
        return
    var event_key := "%s:%s" % [enemy_id, target_id]
    if watcher_kill_keys.has(event_key):
        return
    var enemy: Dictionary = runtime.combatants[enemy_id]
    var bridge_enemy := _remanence_enemy(enemy)
    bridge_enemy["remanence_id"] = str(enemy.get("remanence_id", ""))
    RemanenceRuntime.record_enemy_event(bridge_enemy, "killed_watcher", {
        "region_id":region_id,
        "hero_id":target_id,
        "summary":"%s a tué %s pendant %s" % [str(enemy.get("name", enemy_id)), str(target.get("name", target_id)), encounter_id],
        "encounter_id":encounter_id
    })
    watcher_kill_keys[event_key] = true
    _sync_runtime_remanence(enemy_id)

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

        if int(row.get("hp", 0)) <= 0:
            RemanenceRuntime.set_entity_status(str(bridge_enemy.get("remanence_id", "")), "dead")
            continue
        var event_type := "forced_retreat" if reason == "retreat" else "survived_combat"
        RemanenceRuntime.record_enemy_event(bridge_enemy, event_type, {
            "region_id":region_id,
            "summary":"Combat v0.6.1 : %s" % reason,
            "encounter_id":encounter_id
        })
        for missing_value: Variant in body_payload.get("missing_parts", []):
            var missing_zone := str(missing_value)
            var event_key := "%s:%s" % [entity_id, missing_zone]
            if major_mutilation_keys.has(event_key):
                continue
            RemanenceRuntime.record_enemy_event(bridge_enemy, "major_mutilation", {
                "region_id":region_id,
                "summary":"Mutilation persistante pendant le combat v0.6.1",
                "zone":missing_zone,
                "encounter_id":encounter_id
            })
            major_mutilation_keys[event_key] = true
        _grant_stage_adaptation(entity_id, str(bridge_enemy.get("remanence_id", "")))
        _sync_runtime_remanence(entity_id)

func _grant_stage_adaptation(enemy_id: String, remanence_id: String) -> void:
    if remanence_id == "" or not runtime.combatants.has(enemy_id):
        return
    var state := RemanenceRuntime.entity_state(remanence_id)
    var stage := str(state.get("stage", "normal"))
    if stage not in ["veteran", "elite", "nemesis"]:
        return
    var role := str((runtime.combatants[enemy_id] as Dictionary).get("combat_role", "assault"))
    var adaptation := "avoid_guard" if role in ["ranged", "controller", "psych", "psych_support"] else "pressure_wounded"
    RemanenceRuntime.add_adaptation(remanence_id, adaptation)

func _sync_runtime_remanence(enemy_id: String) -> void:
    if not runtime.combatants.has(enemy_id):
        return
    var row: Dictionary = runtime.combatants[enemy_id]
    runtime.apply_remanence_state(enemy_id, str(row.get("remanence_id", "")))

func _remanence_enemy(row: Dictionary) -> Dictionary:
    return {
        "id":str(row.get("entity_id", "unknown")),
        "species_id":str(row.get("entity_id", "unknown")),
        "name":str(row.get("name", "Adversaire")),
        "hp":int(row.get("hp", 0)),
        "max_hp":int(row.get("max_hp", 1)),
        "remanence_id":str(row.get("remanence_id", ""))
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
