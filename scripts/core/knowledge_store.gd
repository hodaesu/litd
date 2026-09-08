extends Node

signal knowledge_changed(entity_id: String)

const SAVE_SCHEMA_VERSION := 1
const MAX_ACTIVE_OBSERVATIONS := 8
const FORBIDDEN_FIELDS := ["ai_reason","target_score","raw_rng_roll","true_intent","future_intent","hidden_stat_values"]

var observations_by_id: Dictionary = {}
var active_observation_ids_by_entity: Dictionary = {}
var evidence_by_id: Dictionary = {}
var hypotheses_by_id: Dictionary = {}
var archive_levels_by_entity: Dictionary = {}
var unlock_ids_by_entity: Dictionary = {}
var processed_event_ids: Dictionary = {}
var last_sequence := -1

func reset_new_game() -> void:
    observations_by_id = {}
    active_observation_ids_by_entity = {}
    evidence_by_id = {}
    hypotheses_by_id = {}
    archive_levels_by_entity = {}
    unlock_ids_by_entity = {}
    processed_event_ids = {}
    last_sequence = -1

func is_event_processed(event_id: String, sequence: int) -> bool:
    return processed_event_ids.has(event_id) or (last_sequence >= 0 and sequence <= last_sequence)

func commit_event_batch(event_id: String, sequence: int, entity_id: String, rows: Array) -> Dictionary:
    if event_id == "" or entity_id == "" or sequence < 0:
        return {"ok":false,"error":"invalid_batch"}
    if is_event_processed(event_id, sequence):
        return {"ok":true,"deduplicated":true}
    if last_sequence >= 0 and sequence <= last_sequence:
        return {"ok":false,"error":"out_of_order"}

    var next_obs := observations_by_id.duplicate(true)
    var next_active := active_observation_ids_by_entity.duplicate(true)
    var next_evidence := evidence_by_id.duplicate(true)
    var next_hyp := hypotheses_by_id.duplicate(true)
    var next_levels := archive_levels_by_entity.duplicate(true)
    var next_unlocks := unlock_ids_by_entity.duplicate(true)
    var final_projection: Dictionary = {}

    for value: Variant in rows:
        if not (value is Dictionary):
            return {"ok":false,"error":"invalid_row"}
        var row: Dictionary = value
        var observation: Dictionary = row.get("observation", {}) as Dictionary
        var result: Dictionary = row.get("resolution_result", {}) as Dictionary
        if str(observation.get("event_id", "")) != event_id or str(observation.get("subject_entity_id", "")) != entity_id:
            return {"ok":false,"error":"observation_mismatch"}
        if int((observation.get("logical_time", {}) as Dictionary).get("sequence", -1)) != sequence:
            return {"ok":false,"error":"sequence_mismatch"}
        if _contains_forbidden(observation) or _contains_forbidden(result):
            return {"ok":false,"error":"forbidden_field"}

        var observation_id := str(observation.get("observation_id", ""))
        if observation_id == "" or next_obs.has(observation_id):
            return {"ok":false,"error":"duplicate_or_missing_observation"}
        next_obs[observation_id] = observation.duplicate(true)
        var active: Array = next_active.get(entity_id, []) if next_active.get(entity_id, []) is Array else []
        active.append(observation_id)
        while active.size() > MAX_ACTIVE_OBSERVATIONS:
            var old_id := str(active.pop_front())
            next_obs.erase(old_id)
        next_active[entity_id] = active

        for evidence_value: Variant in result.get("new_evidence_records", []):
            if evidence_value is Dictionary:
                var evidence: Dictionary = evidence_value
                var evidence_id := str(evidence.get("evidence_id", ""))
                if evidence_id != "" and not next_evidence.has(evidence_id):
                    next_evidence[evidence_id] = evidence.duplicate(true)

        var hypothesis: Dictionary = result.get("hypothesis_after", {}) as Dictionary
        if not hypothesis.is_empty():
            next_hyp[str(hypothesis.get("hypothesis_id", ""))] = hypothesis.duplicate(true)

        var projection: Dictionary = result.get("knowledge_projection", {}) as Dictionary
        if not projection.is_empty():
            final_projection = projection.duplicate(true)

    if not final_projection.is_empty():
        next_levels[entity_id] = maxi(int(next_levels.get(entity_id, 0)), int(final_projection.get("archive_level", 0)))
        var unlocks: Array = next_unlocks.get(entity_id, []) if next_unlocks.get(entity_id, []) is Array else []
        for unlock_value: Variant in final_projection.get("unlock_ids", []):
            var unlock_id := str(unlock_value)
            if unlock_id != "" and not unlocks.has(unlock_id):
                unlocks.append(unlock_id)
        next_unlocks[entity_id] = unlocks

    observations_by_id = next_obs
    active_observation_ids_by_entity = next_active
    evidence_by_id = next_evidence
    hypotheses_by_id = next_hyp
    archive_levels_by_entity = next_levels
    unlock_ids_by_entity = next_unlocks
    processed_event_ids[event_id] = true
    last_sequence = sequence
    knowledge_changed.emit(entity_id)
    return {"ok":true,"deduplicated":false}

func resolver_snapshot(hypothesis_id: String) -> Dictionary:
    var h: Dictionary = hypotheses_by_id.get(hypothesis_id, {}) as Dictionary
    return {"current_hypothesis":h.duplicate(true),"existing_evidence_by_id":evidence_by_id.duplicate(true)}

func active_observations(entity_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var ids: Array = active_observation_ids_by_entity.get(entity_id, []) if active_observation_ids_by_entity.get(entity_id, []) is Array else []
    for value: Variant in ids:
        var id := str(value)
        if observations_by_id.has(id):
            result.append((observations_by_id[id] as Dictionary).duplicate(true))
    return result

func archive_level(entity_id: String) -> int:
    return int(archive_levels_by_entity.get(entity_id, 0))

func has_unlock(entity_id: String, unlock_id: String) -> bool:
    return (unlock_ids_by_entity.get(entity_id, []) as Array).has(unlock_id)

func hypothesis_record(hypothesis_id: String) -> Dictionary:
    return (hypotheses_by_id.get(hypothesis_id, {}) as Dictionary).duplicate(true)

func serialize() -> Dictionary:
    return {
        "schema_version":SAVE_SCHEMA_VERSION,
        "observations_by_id":observations_by_id.duplicate(true),
        "active_observation_ids_by_entity":active_observation_ids_by_entity.duplicate(true),
        "evidence_by_id":evidence_by_id.duplicate(true),
        "hypotheses_by_id":hypotheses_by_id.duplicate(true),
        "archive_levels_by_entity":archive_levels_by_entity.duplicate(true),
        "unlock_ids_by_entity":unlock_ids_by_entity.duplicate(true),
        "processed_event_ids":processed_event_ids.duplicate(true),
        "last_sequence":last_sequence
    }

func deserialize(payload: Dictionary) -> void:
    if payload.is_empty():
        reset_new_game()
        return
    observations_by_id = (payload.get("observations_by_id", {}) as Dictionary).duplicate(true)
    active_observation_ids_by_entity = (payload.get("active_observation_ids_by_entity", {}) as Dictionary).duplicate(true)
    evidence_by_id = (payload.get("evidence_by_id", {}) as Dictionary).duplicate(true)
    hypotheses_by_id = (payload.get("hypotheses_by_id", {}) as Dictionary).duplicate(true)
    archive_levels_by_entity = (payload.get("archive_levels_by_entity", {}) as Dictionary).duplicate(true)
    unlock_ids_by_entity = (payload.get("unlock_ids_by_entity", {}) as Dictionary).duplicate(true)
    processed_event_ids = (payload.get("processed_event_ids", {}) as Dictionary).duplicate(true)
    last_sequence = int(payload.get("last_sequence", -1))
    _enforce_observation_cap()

func _enforce_observation_cap() -> void:
    var keep: Dictionary = {}
    for entity_value: Variant in active_observation_ids_by_entity.keys():
        var entity_id := str(entity_value)
        var ids: Array = active_observation_ids_by_entity[entity_id]
        while ids.size() > MAX_ACTIVE_OBSERVATIONS:
            ids.pop_front()
        active_observation_ids_by_entity[entity_id] = ids
        for id_value: Variant in ids:
            keep[str(id_value)] = true
    for id_value: Variant in observations_by_id.keys():
        var id := str(id_value)
        if not keep.has(id):
            observations_by_id.erase(id)

func _contains_forbidden(value: Variant) -> bool:
    var text := JSON.stringify(value)
    for field: String in FORBIDDEN_FIELDS:
        if text.contains("\"%s\"" % field):
            return true
    return false
