extends Node
class_name VeilleursRuntimeCoordinator

signal runtime_event(event_type: String, payload: Dictionary)

var content_runtime: VeilleursContentRuntime = null
var encounter_director: VeilleursEncounterDirector = null
var boss_director: VeilleursBossDirector = null

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

func create_rally_candidate(enemy: Dictionary, act_token: String = "", context: Dictionary = {}) -> Dictionary:
    if content_runtime == null:
        return {"ok": false, "reason": "content_runtime_unbound"}
    return content_runtime.create_rally_candidate(enemy, act_token, context)

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
