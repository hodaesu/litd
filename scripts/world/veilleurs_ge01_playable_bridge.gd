extends Node
class_name VeilleursGE01PlayableBridge

signal session_started(snapshot: Dictionary)
signal room_entered(room_id: String, snapshot: Dictionary)
signal enemy_escape_recorded(entity_id: String, remanence_event: Dictionary)
signal refuge_resolved(choice: String, result: Dictionary)
signal extraction_completed(summary: Dictionary)

const SESSION_RUNTIME := preload("res://scripts/core/veilleurs_ge01_session_runtime.gd")
const EXPEDITION_ID := "VS01_GALERIES_ETEINTES"
const REGION_ID := "galeries_eteintes"

var session: RefCounted = SESSION_RUNTIME.new()

func start(seed_value: String = EXPEDITION_ID) -> Dictionary:
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition(seed_value.hash(), EXPEDITION_ID)
    var snapshot: Dictionary = session.call("start", seed_value)
    ExplorationDirector.begin_expedition()
    ExplorationDirector.enter_room(str(snapshot.get("current_room", "ge_01")))
    _sync_exploration_light(snapshot)
    session_started.emit(snapshot.duplicate(true))
    return snapshot

func snapshot() -> Dictionary:
    return session.call("snapshot")

func enter_room(room_id: String) -> Dictionary:
    var result: Dictionary = session.call("enter_room", room_id)
    if not bool(result.get("success", false)):
        return result
    var state_value: Dictionary = result.get("state", snapshot())
    ExplorationDirector.enter_room(room_id)
    _sync_exploration_light(state_value)
    room_entered.emit(room_id, state_value.duplicate(true))
    return result

func spend_light(action_id: String) -> Dictionary:
    var result: Dictionary = session.call("spend_light", action_id)
    if bool(result.get("success", false)):
        _sync_exploration_light(result.get("state", snapshot()))
    return result

func reveal_secret(source: String = "observation") -> Dictionary:
    var result: Dictionary = session.call("reveal_secret", source)
    if bool(result.get("success", false)):
        ExplorationDirector.record_discovery("ge_14_secret", "galeries_eteintes", {"room_id": "ge_14", "source": source})
    return result

func resolve_refuge(choice: String) -> Dictionary:
    var result: Dictionary = session.call("resolve_refuge", choice)
    if not bool(result.get("success", false)):
        return result
    if choice == "field_care":
        result["field_care"] = _stabilize_one_party_injury()
    elif choice == "scout":
        result["scout"] = ExplorationDirector.perceive("presence", "ge_09_ge_10", 25, {"channels": ["sons", "traces", "architecture"]})
    _sync_exploration_light(result.get("state", snapshot()))
    refuge_resolved.emit(choice, result.duplicate(true))
    return result

func record_enemy_escape(enemy: Dictionary, body_state: Dictionary = {}) -> Dictionary:
    if enemy.is_empty():
        return {"success": false, "reason": "missing_enemy"}
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, REGION_ID)
    RemanenceRuntime.note_encounter(enemy, REGION_ID, {
        "room_id": str(session.call("current_room")),
        "summary": "Créature rencontrée dans Les Galeries Éteintes."
    })
    var event: Dictionary = RemanenceRuntime.record_enemy_event(enemy, "escaped", {
        "region_id": REGION_ID,
        "room_id": str(session.call("current_room")),
        "summary": "La créature a fui et peut revenir lors d'une expédition future."
    })
    if not body_state.is_empty():
        enemy["body_state"] = body_state.duplicate(true)
    RemanenceRuntime.sync_body_snapshot(enemy)
    var local_result: Dictionary = session.call("register_enemy_escape", entity_id, str(enemy.get("species_id", enemy.get("id", "unknown"))), body_state)
    enemy_escape_recorded.emit(entity_id, event.duplicate(true))
    return {
        "success": bool(local_result.get("success", false)),
        "entity_id": entity_id,
        "remanence_event": event,
        "session": local_result
    }

func mark_objective_complete(source: String = "corpse_examined") -> Dictionary:
    var result: Dictionary = session.call("mark_objective_complete", source)
    if bool(result.get("success", false)):
        ExplorationDirector.record_discovery("ge01_objective", "galeries_eteintes", {"source": source, "room_id": str(session.call("current_room"))})
    return result

func extract(reason: String = "voluntary") -> Dictionary:
    var summary: Dictionary = session.call("extract", reason)
    if not bool(summary.get("success", false)):
        return summary
    if ExpeditionManager.expedition_active:
        summary["first_descent"] = ExpeditionManager.return_to_hub(reason)
    extraction_completed.emit(summary.duplicate(true))
    return summary

func serialize() -> Dictionary:
    return session.call("serialize")

func deserialize(data: Dictionary) -> bool:
    var ok: bool = bool(session.call("deserialize", data))
    if ok:
        _sync_exploration_light(snapshot())
    return ok

func _sync_exploration_light(state_value: Dictionary) -> void:
    var light_value := clampf(float(state_value.get("light", 0)) / 100.0, 0.0, 1.0)
    ExplorationDirector.set_light_level(light_value, "galeries_eteintes")
    if ExpeditionManager.inventory.has("light"):
        ExpeditionManager.inventory["light"] = int(state_value.get("light", 0))
        ExpeditionManager.inventory_changed.emit(ExpeditionManager.inventory.duplicate(true))

func _stabilize_one_party_injury() -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        for injury_value: Variant in hero.get("persistent_injuries", []):
            var injury: Dictionary = injury_value
            if bool(injury.get("stabilized", false)):
                continue
            var injury_id := str(injury.get("id", ""))
            if injury_id != "" and PersistentInjuryRuntime.stabilize_in_field(hero, injury_id):
                return {"success": true, "hero_id": str(hero.get("id", "")), "injury_id": injury_id}
    return {"success": false, "reason": "no_unstabilized_injury"}
