extends Node
class_name VeilleursRuntimeCoordinator

signal runtime_event(event_type: String, payload: Dictionary)

var content_runtime: VeilleursContentRuntime = null
var encounter_director: VeilleursEncounterDirector = null
var boss_director: VeilleursBossDirector = null
var intent_resolver := VeilleursIntentResolver.new()
var remanence_policy := VeilleursRemanencePolicy.new()

func bind(content: VeilleursContentRuntime, encounters: VeilleursEncounterDirector, bosses: VeilleursBossDirector) -> void:
    _disconnect_sources()
    content_runtime = content
    encounter_director = encounters
    boss_director = bosses
    if boss_director != null:
        if not boss_director.phase_changed.is_connected(_on_boss_phase_changed):
            boss_director.phase_changed.connect(_on_boss_phase_changed)
        if not boss_director.boss_finished.is_connected(_on_boss_finished):
            boss_director.boss_finished.connect(_on_boss_finished)
    if encounter_director != null and not encounter_director.encounter_selected.is_connected(_on_encounter_selected):
        encounter_director.encounter_selected.connect(_on_encounter_selected)

func select_encounter(seed_value: int, act_token: String, context: Dictionary = {}) -> Dictionary:
    if encounter_director == null:
        return {"success": false, "reason": "encounter_director_unbound"}
    return encounter_director.select_encounter(seed_value, act_token, context)

func start_boss(boss_id: String, entity_id: String = "", body_snapshot: Dictionary = {}) -> Dictionary:
    if boss_director == null:
        return {"success": false, "reason": "boss_director_unbound"}
    return boss_director.start_boss(boss_id, entity_id, body_snapshot)

func advance_boss_phase(transition_satisfied: bool, body_snapshot: Dictionary = {}) -> Dictionary:
    if boss_director == null:
        return {"success": false, "reason": "boss_director_unbound"}
    return boss_director.advance_phase(transition_satisfied, body_snapshot)

func finish_boss(victory: bool, body_snapshot: Dictionary = {}) -> Dictionary:
    if boss_director == null:
        return {"success": false, "reason": "boss_director_unbound"}
    return boss_director.finish_boss(victory, body_snapshot)

func resolve_enemy_intent(entity_id: String, skill: Dictionary, stored_detail: int, perception: String = "clear") -> Dictionary:
    var resolved := intent_resolver.resolve_skill_intent(entity_id, skill)
    if not bool(resolved.get("ok", false)):
        return {"ok": false, "resolved": resolved, "telegraph": {"visible": false, "detail_level": 0}}
    var telegraph := intent_resolver.telegraph(resolved, stored_detail, perception)
    runtime_event.emit("enemy_intent_resolved", {
        "entity_id": entity_id,
        "intent_family": resolved.get("intent_family", ""),
        "action_channel": resolved.get("action_channel", ""),
        "detail_level": telegraph.get("detail_level", 0),
        "perception": perception
    })
    return {"ok": true, "resolved": resolved, "telegraph": telegraph}

func resolve_enemy_state_intent(state_intent: String, payload: Dictionary = {}) -> Dictionary:
    var resolved := intent_resolver.resolve_state_intent(state_intent, payload)
    if bool(resolved.get("ok", false)):
        runtime_event.emit("enemy_state_intent", resolved.duplicate(true))
    return resolved

func note_enemy_memory_event(entity_id: String, event_type: String, payload: Dictionary = {}) -> Dictionary:
    var previous_rank := remanence_policy.rank(entity_id)
    var result := remanence_policy.note_event(entity_id, event_type, payload)
    if not bool(result.get("ok", false)):
        return result
    var state: Dictionary = result.get("state", {})
    var current_rank := str(state.get("memory_rank", "normal"))
    _archive_hook(entity_id, "remanence_lived_event", {
        "event_type": event_type,
        "memory_rank": current_rank,
        "evidence": payload.duplicate(true)
    })
    _emit_promotion_if_needed(entity_id, previous_rank, current_rank, state)
    return result

func apply_enemy_lesson(entity_id: String, channel: String, context: Dictionary = {}) -> Dictionary:
    var previous_rank := remanence_policy.rank(entity_id)
    var result := remanence_policy.apply_lesson(entity_id, channel, context)
    if not bool(result.get("ok", false)):
        return result
    var state: Dictionary = result.get("state", {})
    var current_rank := str(state.get("memory_rank", previous_rank))
    _archive_hook(entity_id, "remanence_lesson_applied", {
        "channel": channel,
        "memory_rank": current_rank,
        "context": context.duplicate(true)
    })
    _emit_promotion_if_needed(entity_id, previous_rank, current_rank, state)
    return result

func note_enemy_group_influence(entity_id: String, channel: String, context: Dictionary = {}) -> Dictionary:
    var previous_rank := remanence_policy.rank(entity_id)
    var result := remanence_policy.note_group_influence(entity_id, channel, context)
    if not bool(result.get("ok", false)):
        return result
    var state: Dictionary = result.get("state", {})
    var current_rank := str(state.get("memory_rank", previous_rank))
    _archive_hook(entity_id, "remanence_group_influence", {
        "channel": channel,
        "memory_rank": current_rank,
        "context": context.duplicate(true)
    })
    _emit_promotion_if_needed(entity_id, previous_rank, current_rank, state)
    return result

func enemy_memory_state(entity_id: String) -> Dictionary:
    return remanence_policy.state(entity_id)

func create_rally_candidate(enemy: Dictionary, act_token: String = "", context: Dictionary = {}) -> Dictionary:
    if content_runtime == null:
        return {"ok": false, "reason": "content_runtime_unbound"}
    var runtime_enemy := enemy.duplicate(true)
    var entity_id := str(runtime_enemy.get("remanence_id", runtime_enemy.get("instance_id", "")))
    var policy_state := remanence_policy.state(entity_id)
    if not policy_state.is_empty():
        runtime_enemy["memory_rank"] = str(policy_state.get("memory_rank", runtime_enemy.get("memory_rank", "normal")))
    return content_runtime.create_rally_candidate(runtime_enemy, act_token, context)

func resolve_rally(rally_id: String, player_accepts: bool, resolution: Dictionary = {}) -> Dictionary:
    if content_runtime == null:
        return {"ok": false, "reason": "content_runtime_unbound"}
    return content_runtime.resolve_rally_candidate(rally_id, player_accepts, resolution)

func note_enemy_suspected(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    return _archive_hook(entity_id, "knowledge_suspected", payload)

func note_enemy_observed(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    return _archive_hook(entity_id, "knowledge_observed", payload)

func note_enemy_analyzed(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    return _archive_hook(entity_id, "knowledge_confirmed", payload)

func note_enemy_understood(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    return _archive_hook(entity_id, "knowledge_understood", payload)

func note_knowledge_contradicted(entity_id: String, payload: Dictionary = {}) -> Dictionary:
    return _archive_hook(entity_id, "knowledge_contradicted", payload)

func note_persistent_injury(entity_id: String, injury: Dictionary) -> Dictionary:
    return _archive_hook(entity_id, "persistent_injury_added", injury)

func note_world_scar(entity_id: String, scar: Dictionary) -> Dictionary:
    return _archive_hook(entity_id, "world_scar_created", scar)

func note_relationship_threshold(entity_id: String, payload: Dictionary) -> Dictionary:
    return _archive_hook(entity_id, "relationship_threshold_crossed", payload)

func archive_entry(entity_id: String) -> Dictionary:
    if content_runtime == null:
        return {}
    return content_runtime.archive_entry(entity_id)

func _archive_hook(entity_id: String, hook: String, payload: Dictionary) -> Dictionary:
    if content_runtime == null:
        return {}
    var entry := content_runtime.record_archive_hook(entity_id, hook, payload)
    runtime_event.emit(hook, {"entity_id": entity_id, "payload": payload.duplicate(true)})
    return entry

func _emit_promotion_if_needed(entity_id: String, previous_rank: String, current_rank: String, state: Dictionary) -> void:
    if previous_rank == current_rank:
        return
    _archive_hook(entity_id, "entity_promoted", {
        "from": previous_rank,
        "to": current_rank,
        "promotion_policy": "lived_events",
        "state": state.duplicate(true)
    })
    runtime_event.emit("enemy_memory_rank_changed", {
        "entity_id": entity_id,
        "from": previous_rank,
        "to": current_rank
    })

func _on_encounter_selected(runtime_encounter: Dictionary) -> void:
    # Selection is not observation: no knowledge is granted before the encounter is actually perceived.
    runtime_event.emit("encounter_selected", {
        "name": runtime_encounter.get("name", ""),
        "act": runtime_encounter.get("act", ""),
        "runtime_actor_count": runtime_encounter.get("runtime_actor_count", 0)
    })

func _on_boss_phase_changed(state: Dictionary, definition: Dictionary) -> void:
    if content_runtime == null:
        return
    var boss_id := str(state.get("boss_id", ""))
    var phase := int(state.get("current_phase", 0))
    content_runtime.record_boss_phase_observed(boss_id, phase)
    var archive_id := str(state.get("entity_id", ""))
    if archive_id.is_empty():
        archive_id = "boss:%s" % boss_id
    content_runtime.record_archive_hook(archive_id, "knowledge_observed", {
        "boss_id": boss_id,
        "boss_name": state.get("boss_name", ""),
        "phase": phase,
        "phase_title": definition.get("title", ""),
        "doctrine": definition.get("doctrine", "")
    })
    runtime_event.emit("boss_phase_observed", {"boss_id": boss_id, "phase": phase, "archive_id": archive_id})

func _on_boss_finished(state: Dictionary) -> void:
    if content_runtime == null:
        return
    var boss_id := str(state.get("boss_id", ""))
    var archive_id := str(state.get("entity_id", ""))
    if archive_id.is_empty():
        archive_id = "boss:%s" % boss_id
    content_runtime.record_archive_hook(archive_id, "boss_finished", {
        "boss_id": boss_id,
        "victory": bool(state.get("victory", false)),
        "observed_phases": (state.get("observed_phases", []) as Array).duplicate(),
        "body_snapshot": (state.get("body_snapshot", {}) as Dictionary).duplicate(true)
    })
    runtime_event.emit("boss_finished", {"boss_id": boss_id, "victory": bool(state.get("victory", false))})

func _disconnect_sources() -> void:
    if boss_director != null:
        if boss_director.phase_changed.is_connected(_on_boss_phase_changed):
            boss_director.phase_changed.disconnect(_on_boss_phase_changed)
        if boss_director.boss_finished.is_connected(_on_boss_finished):
            boss_director.boss_finished.disconnect(_on_boss_finished)
    if encounter_director != null and encounter_director.encounter_selected.is_connected(_on_encounter_selected):
        encounter_director.encounter_selected.disconnect(_on_encounter_selected)
