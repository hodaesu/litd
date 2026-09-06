extends Node
class_name VeilleursCombatMemoryAdapter

signal canonical_event_forwarded(entity_id: String, event_type: String, payload: Dictionary)
signal canonical_event_rejected(entity_id: String, event_type: String, reason: String)

var coordinator: VeilleursRuntimeCoordinator = null
var meaningful_exchange: Dictionary = {}
var encounter_open: Dictionary = {}

func bind(runtime_coordinator: VeilleursRuntimeCoordinator) -> void:
    coordinator = runtime_coordinator
    if RemanenceRuntime != null and not RemanenceRuntime.event_recorded.is_connected(_on_remanence_event_recorded):
        RemanenceRuntime.event_recorded.connect(_on_remanence_event_recorded)
    if GameState != null and not GameState.new_game_reset.is_connected(reset):
        GameState.new_game_reset.connect(reset)

func reset() -> void:
    meaningful_exchange.clear()
    encounter_open.clear()

func note_actual_escape(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    if not _watcher_context_active():
        return {"ok": false, "reason": "veilleurs_party_inactive"}
    var evidence := payload.duplicate(true)
    evidence["entity_alive"] = bool(evidence.get("entity_alive", _entity_alive(entity_id)))
    evidence["direct_exchange"] = bool(evidence.get("direct_exchange", true))
    evidence["shared_history"] = bool(evidence.get("shared_history", true))
    evidence["recognized_watchers"] = _recognized_watchers()
    evidence["evidence_source"] = str(evidence.get("evidence_source", "combat_state_machine"))
    return _forward(entity_id, "escape", evidence)

func note_actual_important_item_event(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    if not _watcher_context_active():
        return {"ok": false, "reason": "veilleurs_party_inactive"}
    var evidence := payload.duplicate(true)
    evidence["recognized_watchers"] = _recognized_watchers()
    evidence["evidence_source"] = str(evidence.get("evidence_source", "combat_or_world_interaction"))
    return _forward(entity_id, "important_item_taken_or_recovered", evidence)

func _on_remanence_event_recorded(event: Dictionary) -> void:
    if coordinator == null or not _watcher_context_active():
        return
    var entity_id := str(event.get("entity_id", ""))
    if entity_id.is_empty():
        return
    var event_type := str(event.get("type", ""))
    match event_type:
        "encountered":
            encounter_open[entity_id] = int(event.get("seq", 0))
            meaningful_exchange.erase(entity_id)
        "reencountered":
            encounter_open[entity_id] = int(event.get("seq", 0))
            meaningful_exchange.erase(entity_id)
            _forward(entity_id, "repeated_encounter", {
                "entity_alive": _entity_alive(entity_id),
                "direct_confrontation": true,
                "recognized_watchers": _recognized_watchers(),
                "shared_history": true,
                "evidence_source": "remanence_combat_bridge:reencountered",
                "source_event_seq": int(event.get("seq", 0)),
                "species_id": _entity_species_id(entity_id)
            })
        "major_mutilation":
            meaningful_exchange[entity_id] = true
            _forward(entity_id, "mutilation", {
                "entity_alive": _entity_alive(entity_id),
                "direct_exchange": true,
                "shared_history": true,
                "body_zone": str(event.get("object_id", "")),
                "lost_or_impaired_function": str(event.get("injury_state", "")),
                "source_actor": str(event.get("hero_id", "")),
                "source_intent_family": str(event.get("source_intent_family", event.get("intent_family", ""))),
                "recognized_watchers": _recognized_watchers(),
                "evidence_source": "remanence_combat_bridge:major_mutilation",
                "source_event_seq": int(event.get("seq", 0)),
                "species_id": _entity_species_id(entity_id),
                "salience": 3
            })
        "killed_watcher":
            meaningful_exchange[entity_id] = true
            _forward(entity_id, "watcher_kill", {
                "entity_alive": _entity_alive(entity_id),
                "direct_exchange": true,
                "shared_history": true,
                "watcher_id": str(event.get("hero_id", "")),
                "method_or_skill_family": str(event.get("intent_family", "")),
                "position": str(event.get("position", "")),
                "witnessed_by_group": true,
                "recognized_watchers": _recognized_watchers(),
                "evidence_source": "remanence_combat_bridge:killed_watcher",
                "source_event_seq": int(event.get("seq", 0)),
                "species_id": _entity_species_id(entity_id),
                "salience": 5
            })
        "capture_escaped":
            meaningful_exchange[entity_id] = true
            _forward(entity_id, "failed_capture", {
                "entity_alive": _entity_alive(entity_id),
                "direct_exchange": true,
                "shared_history": true,
                "capture_method": str(event.get("capture_method", "capture_seal")),
                "initiator": str(event.get("hero_id", event.get("initiator", ""))),
                "body_state": _entity_body_snapshot(entity_id),
                "escape_or_resistance_result": "capture_failed_enemy_remained_free",
                "recognized_watchers": _recognized_watchers(),
                "evidence_source": "remanence_combat_bridge:capture_escaped",
                "source_event_seq": int(event.get("seq", 0)),
                "species_id": _entity_species_id(entity_id),
                "salience": 4
            })
        "forced_retreat":
            meaningful_exchange[entity_id] = true
            _forward(entity_id, "forced_retreat", {
                "entity_alive": _entity_alive(entity_id),
                "direct_exchange": true,
                "shared_history": true,
                "retreating_side": "watchers",
                "trigger_intent_family": str(event.get("intent_family", "")),
                "terrain_factor": str(event.get("terrain_factor", "")),
                "recognized_watchers": _recognized_watchers(),
                "evidence_source": "remanence_combat_bridge:forced_retreat",
                "source_event_seq": int(event.get("seq", 0)),
                "species_id": _entity_species_id(entity_id),
                "salience": 4
            })
        "survived_combat":
            if bool(meaningful_exchange.get(entity_id, false)):
                _forward(entity_id, "survival", {
                    "entity_alive": _entity_alive(entity_id),
                    "direct_exchange": true,
                    "shared_history": true,
                    "last_dangerous_player_intent_family": str(event.get("intent_family", "")),
                    "exit_axis": str(event.get("exit_axis", "")),
                    "recognized_watchers": _recognized_watchers(),
                    "evidence_source": "remanence_combat_bridge:survived_combat_after_meaningful_exchange",
                    "source_event_seq": int(event.get("seq", 0)),
                    "species_id": _entity_species_id(entity_id),
                    "salience": 2
                })
            encounter_open.erase(entity_id)
            meaningful_exchange.erase(entity_id)
        "relic_taken":
            _forward(entity_id, "important_item_taken_or_recovered", {
                "entity_alive": _entity_alive(entity_id),
                "shared_history": _entity_alive(entity_id),
                "direct_exchange": _entity_alive(entity_id),
                "item_id": str(event.get("object_id", "")),
                "action": "taken",
                "location_anchor": str(event.get("dungeon_id", event.get("zone_id", ""))),
                "recognized_watchers": _recognized_watchers(),
                "evidence_source": "remanence_combat_bridge:relic_taken",
                "source_event_seq": int(event.get("seq", 0)),
                "species_id": _entity_species_id(entity_id),
                "salience": 3
            })

func _forward(entity_id: String, event_type: String, payload: Dictionary) -> Dictionary:
    if coordinator == null:
        return {"ok": false, "reason": "coordinator_unbound"}
    var result := coordinator.note_enemy_memory_event(entity_id, event_type, payload)
    if bool(result.get("ok", false)):
        canonical_event_forwarded.emit(entity_id, event_type, payload.duplicate(true))
    else:
        canonical_event_rejected.emit(entity_id, event_type, str(result.get("reason", "unknown")))
    return result

func _watcher_context_active() -> bool:
    if GameState == null:
        return false
    var watcher_ids: Array[String] = VeilleursSkillCatalog.watcher_ids()
    for hero_value: Variant in GameState.party:
        if hero_value is Dictionary and str((hero_value as Dictionary).get("id", "")) in watcher_ids:
            return true
    return false

func _recognized_watchers() -> Array[String]:
    var result: Array[String] = []
    var watcher_ids: Array[String] = VeilleursSkillCatalog.watcher_ids()
    for hero_value: Variant in GameState.party:
        if not (hero_value is Dictionary):
            continue
        var hero_id := str((hero_value as Dictionary).get("id", ""))
        if hero_id in watcher_ids and not result.has(hero_id):
            result.append(hero_id)
    return result

func _entity_alive(entity_id: String) -> bool:
    var state: Dictionary = RemanenceRuntime.entity_state(entity_id)
    return str(state.get("status", "active")) != "dead"

func _entity_species_id(entity_id: String) -> String:
    return str(RemanenceRuntime.entity_state(entity_id).get("species_id", ""))

func _entity_body_snapshot(entity_id: String) -> Dictionary:
    return (RemanenceRuntime.entity_state(entity_id).get("body_snapshot", {}) as Dictionary).duplicate(true)
