extends RefCounted
class_name VeilleursRefugeMemoryServiceCandidate

signal memory_recorded(memory: Dictionary)
signal memory_became_eligible(memory: Dictionary)
signal memory_queued(memory: Dictionary)
signal memory_surfaced(memory: Dictionary)
signal memory_resolved(memory: Dictionary)
signal memory_expired(memory: Dictionary, reason: String)
signal scheduler_changed(snapshot: Dictionary)
signal archive_hook_requested(entity_id: String, hook: String, payload: Dictionary)
signal remanence_hook_requested(entity_id: String, event_type: String, payload: Dictionary)

const TEMPLATES_PATH := "res://data/veilleurs/parallel_content/refuge_event_templates_v1.json"
const CHAINS_PATH := "res://data/veilleurs/parallel_content/refuge_event_chains_v1.json"
const REGIONAL_ECHOES_PATH := "res://data/veilleurs/parallel_content/regional_event_choice_echoes_v1.json"
const SERVICE_CONTRACT_PATH := "res://data/veilleurs/parallel_content/refuge_memory_service_contract_v1.json"
const SAVE_SCHEMA_PATH := "res://data/veilleurs/parallel_content/refuge_memory_save_schema_v1.json"

const SCHEMA_VERSION := 1
const VALID_STATES := ["DORMANT", "ELIGIBLE", "QUEUED", "SURFACED", "RESOLVED", "EXPIRED", "RETIRED"]
const PRIORITY_BANDS := {
    "CRISIS": 50,
    "BODY_OR_AVAILABILITY": 40,
    "RELATIONSHIP_OR_DEPARTURE": 30,
    "DISCOVERY_OR_ARCHIVE": 20,
    "ROUTINE_OR_WORK": 10
}
const SOURCE_COOLDOWN_EXPEDITIONS := 2
const FAMILY_SOFT_COOLDOWN_EXPEDITIONS := 1
const DEFAULT_SURFACE_LIMIT := 2

var templates: Dictionary = {}
var chains: Dictionary = {}
var regional_echoes: Dictionary = {}
var service_contract: Dictionary = {}
var save_schema: Dictionary = {}

var scheduler_seed := 0
var expedition_index := 0
var return_index := 0
var sequence := 0
var records: Dictionary = {}
var queue: Array[String] = []
var surfaced_memory_id := ""
var source_cooldowns: Dictionary = {}
var family_cooldowns: Dictionary = {}
var migration_log: Array[Dictionary] = []
var current_surface_limit := DEFAULT_SURFACE_LIMIT
var surfaced_count_this_return := 0

func _init() -> void:
    templates = _load_dictionary(TEMPLATES_PATH)
    chains = _load_dictionary(CHAINS_PATH)
    regional_echoes = _load_dictionary(REGIONAL_ECHOES_PATH)
    service_contract = _load_dictionary(SERVICE_CONTRACT_PATH)
    save_schema = _load_dictionary(SAVE_SCHEMA_PATH)

func configure(seed_value: int, expedition_index_value: int = 0) -> Dictionary:
    scheduler_seed = seed_value
    expedition_index = maxi(0, expedition_index_value)
    return validation_report()

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    var template_records: Array = templates.get("templates", [])
    var chain_records: Array = chains.get("chains", [])
    var regional_records: Array = regional_echoes.get("events", [])
    if template_records.size() != 24:
        errors.append("refuge_templates:%d" % template_records.size())
    if chain_records.size() != 24:
        errors.append("refuge_chains:%d" % chain_records.size())
    if regional_records.size() != 16:
        errors.append("regional_echo_sources:%d" % regional_records.size())
    if bool(service_contract.get("enabled_by_default", true)):
        errors.append("service_contract_must_remain_inactive")
    if bool(save_schema.get("enabled_by_default", true)):
        errors.append("save_schema_must_remain_inactive")
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "templates": template_records.size(),
        "chains": chain_records.size(),
        "regional_sources": regional_records.size(),
        "scheduler_seed": scheduler_seed,
        "expedition_index": expedition_index
    }

func record_source_choice(source_event_id: String, choice_id: String, evidence: Dictionary, participants: Array[String], context: Dictionary = {}) -> Dictionary:
    var template := _template_by_id(source_event_id)
    var chain := _chain_by_source_id(source_event_id)
    if template.is_empty() or chain.is_empty():
        return {"ok": false, "reason": "unknown_refuge_source", "source_event_id": source_event_id}
    if not _template_has_choice(template, choice_id):
        return {"ok": false, "reason": "unknown_source_choice", "choice_id": choice_id}
    var echoes: Dictionary = chain.get("echoes", {})
    if not echoes.has(choice_id):
        return {"ok": false, "reason": "missing_choice_echo", "choice_id": choice_id}
    if not _history_is_written(evidence, context):
        return {"ok": false, "reason": "written_lived_history_required"}
    var echo: Dictionary = echoes.get(choice_id, {})
    var memory := _build_memory_record(
        "refuge_event",
        source_event_id,
        choice_id,
        str(template.get("family", "")),
        str(echo.get("window", "")),
        echo,
        evidence,
        participants,
        context
    )
    records[str(memory.get("memory_id", ""))] = memory.duplicate(true)
    memory_recorded.emit(memory.duplicate(true))
    scheduler_changed.emit(snapshot())
    return {"ok": true, "memory": memory.duplicate(true)}

func record_regional_choice(regional_event_id: String, choice_id: String, evidence: Dictionary, participants: Array[String], context: Dictionary = {}) -> Dictionary:
    var source := _regional_echo_by_id(regional_event_id)
    if source.is_empty():
        return {"ok": false, "reason": "unknown_regional_source", "source_event_id": regional_event_id}
    var echoes: Dictionary = source.get("choice_echoes", {})
    if not echoes.has(choice_id):
        return {"ok": false, "reason": "unknown_regional_choice", "choice_id": choice_id}
    if not _history_is_written(evidence, context):
        return {"ok": false, "reason": "written_lived_history_required"}
    var echo: Dictionary = echoes.get(choice_id, {})
    var memory := _build_memory_record(
        "regional_event",
        regional_event_id,
        choice_id,
        "REGIONAL",
        str(echo.get("window", "")),
        echo,
        evidence,
        participants,
        context
    )
    records[str(memory.get("memory_id", ""))] = memory.duplicate(true)
    memory_recorded.emit(memory.duplicate(true))
    scheduler_changed.emit(snapshot())
    return {"ok": true, "memory": memory.duplicate(true)}

func advance_expedition(context: Dictionary = {}) -> Dictionary:
    expedition_index += 1
    surfaced_count_this_return = 0
    surfaced_memory_id = ""
    collect_eligible(context)
    scheduler_changed.emit(snapshot())
    return snapshot()

func collect_eligible(context: Dictionary = {}) -> Array[Dictionary]:
    var eligible: Array[Dictionary] = []
    var ids: Array = records.keys()
    ids.sort()
    for id_value: Variant in ids:
        var memory_id := str(id_value)
        var memory: Dictionary = records.get(memory_id, {})
        var state := str(memory.get("state", "DORMANT"))
        if state in ["RESOLVED", "EXPIRED", "RETIRED", "SURFACED"]:
            continue
        var max_exp := int(memory.get("max_surface_expedition", -1))
        if max_exp >= 0 and expedition_index > max_exp:
            _expire_internal(memory_id, "window_expired")
            continue
        if expedition_index < int(memory.get("min_surface_expedition", 0)):
            continue
        if not bool(memory.get("source_history_written", false)):
            continue
        if not _requirements_satisfied(memory, context):
            continue
        if state == "DORMANT":
            memory["state"] = "ELIGIBLE"
            memory["first_eligible_expedition"] = expedition_index
            memory["last_transition_expedition"] = expedition_index
            records[memory_id] = memory
            memory_became_eligible.emit(memory.duplicate(true))
        eligible.append((records.get(memory_id, {}) as Dictionary).duplicate(true))
    return eligible

func queue_for_return(context: Dictionary = {}, surface_limit: int = -1) -> Array[Dictionary]:
    if not queue.is_empty():
        return _records_for_ids(queue)
    return_index += 1
    surfaced_count_this_return = 0
    current_surface_limit = DEFAULT_SURFACE_LIMIT if surface_limit <= 0 else surface_limit
    var candidates := collect_eligible(context)
    var filtered: Array[Dictionary] = []
    for candidate: Dictionary in candidates:
        if _source_on_cooldown(candidate):
            continue
        candidate["soft_family_cooldown"] = _family_on_soft_cooldown(candidate)
        filtered.append(candidate)
    filtered.sort_custom(Callable(self, "_candidate_before"))

    var seen_sources: Dictionary = {}
    var seen_memory_keys: Dictionary = {}
    for candidate: Dictionary in filtered:
        var source_event_id := str(candidate.get("source_event_id", ""))
        var memory_key := str(candidate.get("memory_key", ""))
        if seen_sources.has(source_event_id):
            continue
        if not memory_key.is_empty() and seen_memory_keys.has(memory_key):
            continue
        var memory_id := str(candidate.get("memory_id", ""))
        var stored: Dictionary = records.get(memory_id, {})
        if stored.is_empty():
            continue
        stored["state"] = "QUEUED"
        stored["last_transition_expedition"] = expedition_index
        records[memory_id] = stored
        queue.append(memory_id)
        seen_sources[source_event_id] = true
        if not memory_key.is_empty():
            seen_memory_keys[memory_key] = true
        memory_queued.emit(stored.duplicate(true))
    scheduler_changed.emit(snapshot())
    return _records_for_ids(queue)

func surface_next() -> Dictionary:
    if not surfaced_memory_id.is_empty():
        return {"ok": false, "reason": "memory_already_surfaced", "memory_id": surfaced_memory_id}
    if surfaced_count_this_return >= current_surface_limit:
        return {"ok": false, "reason": "surface_limit_reached", "limit": current_surface_limit}
    while not queue.is_empty():
        var memory_id := queue.pop_front()
        var memory: Dictionary = records.get(memory_id, {})
        if memory.is_empty() or str(memory.get("state", "")) != "QUEUED":
            continue
        memory["state"] = "SURFACED"
        memory["last_transition_expedition"] = expedition_index
        memory["surfaced_count"] = int(memory.get("surfaced_count", 0)) + 1
        records[memory_id] = memory
        surfaced_memory_id = memory_id
        surfaced_count_this_return += 1
        memory_surfaced.emit(memory.duplicate(true))
        scheduler_changed.emit(snapshot())
        return {"ok": true, "memory": memory.duplicate(true)}
    return {"ok": false, "reason": "queue_empty"}

func resolve_memory(memory_id: String, resolution: Dictionary = {}) -> Dictionary:
    if memory_id.is_empty() or memory_id != surfaced_memory_id:
        return {"ok": false, "reason": "memory_not_currently_surfaced"}
    var memory: Dictionary = records.get(memory_id, {})
    if str(memory.get("state", "")) != "SURFACED":
        return {"ok": false, "reason": "invalid_state_for_resolution"}
    memory["state"] = "RESOLVED"
    memory["resolution"] = resolution.duplicate(true)
    memory["resolved_expedition_index"] = expedition_index
    memory["last_transition_expedition"] = expedition_index
    records[memory_id] = memory
    surfaced_memory_id = ""
    source_cooldowns[str(memory.get("source_event_id", ""))] = expedition_index
    var family := str(memory.get("family", ""))
    if not family.is_empty():
        family_cooldowns[family] = expedition_index
    _request_projection_hooks(memory, resolution)
    memory_resolved.emit(memory.duplicate(true))
    scheduler_changed.emit(snapshot())
    return {"ok": true, "memory": memory.duplicate(true)}

func confirm_projection_committed(memory_id: String) -> bool:
    var memory: Dictionary = records.get(memory_id, {})
    if str(memory.get("state", "")) not in ["RESOLVED", "EXPIRED"]:
        return false
    memory["state"] = "RETIRED"
    memory["last_transition_expedition"] = expedition_index
    records[memory_id] = memory
    scheduler_changed.emit(snapshot())
    return true

func expire_memory(memory_id: String, reason: String) -> bool:
    return _expire_internal(memory_id, reason)

func serialize() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "scheduler_seed": scheduler_seed,
        "expedition_index": expedition_index,
        "return_index": return_index,
        "sequence": sequence,
        "records": records.duplicate(true),
        "queue": queue.duplicate(),
        "surfaced_memory_id": surfaced_memory_id,
        "source_cooldowns": source_cooldowns.duplicate(true),
        "family_cooldowns": family_cooldowns.duplicate(true),
        "migration_log": migration_log.duplicate(true),
        "current_surface_limit": current_surface_limit,
        "surfaced_count_this_return": surfaced_count_this_return
    }

func deserialize(payload: Dictionary) -> Dictionary:
    if payload.is_empty():
        reset()
        migration_log.append({"from":"missing","to":SCHEMA_VERSION,"action":"initialize_empty_v1"})
        return {"ok": true, "migrated": true, "from": "missing", "to": SCHEMA_VERSION}
    var incoming_version := int(payload.get("schema_version", 0))
    if incoming_version > SCHEMA_VERSION:
        return {"ok": false, "reason": "future_schema_unsupported", "incoming": incoming_version, "supported": SCHEMA_VERSION}
    var normalized := payload.duplicate(true)
    var migrated := false
    if incoming_version <= 0:
        normalized = _migrate_unversioned_to_v1(normalized)
        migrated = true
    scheduler_seed = int(normalized.get("scheduler_seed", 0))
    expedition_index = maxi(0, int(normalized.get("expedition_index", 0)))
    return_index = maxi(0, int(normalized.get("return_index", 0)))
    sequence = maxi(0, int(normalized.get("sequence", 0)))
    records = _validated_records(normalized.get("records", {}))
    queue.clear()
    for value: Variant in normalized.get("queue", []):
        var memory_id := str(value)
        if records.has(memory_id) and str((records[memory_id] as Dictionary).get("state", "")) == "QUEUED":
            queue.append(memory_id)
    surfaced_memory_id = str(normalized.get("surfaced_memory_id", ""))
    if not surfaced_memory_id.is_empty():
        if not records.has(surfaced_memory_id) or str((records[surfaced_memory_id] as Dictionary).get("state", "")) != "SURFACED":
            surfaced_memory_id = ""
    source_cooldowns = (normalized.get("source_cooldowns", {}) as Dictionary).duplicate(true)
    family_cooldowns = (normalized.get("family_cooldowns", {}) as Dictionary).duplicate(true)
    migration_log.clear()
    for value: Variant in normalized.get("migration_log", []):
        if value is Dictionary:
            migration_log.append((value as Dictionary).duplicate(true))
    current_surface_limit = maxi(1, int(normalized.get("current_surface_limit", DEFAULT_SURFACE_LIMIT)))
    surfaced_count_this_return = maxi(0, int(normalized.get("surfaced_count_this_return", 0)))
    scheduler_changed.emit(snapshot())
    return {"ok": true, "migrated": migrated, "from": incoming_version, "to": SCHEMA_VERSION, "record_count": records.size()}

func reset() -> void:
    scheduler_seed = 0
    expedition_index = 0
    return_index = 0
    sequence = 0
    records.clear()
    queue.clear()
    surfaced_memory_id = ""
    source_cooldowns.clear()
    family_cooldowns.clear()
    migration_log.clear()
    current_surface_limit = DEFAULT_SURFACE_LIMIT
    surfaced_count_this_return = 0
    scheduler_changed.emit(snapshot())

func snapshot() -> Dictionary:
    return {
        "scheduler_seed": scheduler_seed,
        "expedition_index": expedition_index,
        "return_index": return_index,
        "record_count": records.size(),
        "states": _state_counts(),
        "queue": queue.duplicate(),
        "surfaced_memory_id": surfaced_memory_id,
        "surface_limit": current_surface_limit,
        "surfaced_count_this_return": surfaced_count_this_return
    }

func _build_memory_record(source_type: String, source_event_id: String, choice_id: String, family: String, window_id: String, echo: Dictionary, evidence: Dictionary, participants: Array[String], context: Dictionary) -> Dictionary:
    sequence += 1
    var windows: Dictionary = chains.get("temporal_windows", {}) if source_type == "refuge_event" else regional_echoes.get("temporal_windows", {})
    var window: Dictionary = windows.get(window_id, {})
    var min_offset := int(window.get("min_expeditions", 0))
    var max_offset := int(window.get("max_expeditions", -1))
    var memory_key := str(context.get("memory_key", "%s:%s" % [source_event_id, choice_id]))
    var material := "%d|%d|%s|%s|%d" % [scheduler_seed, expedition_index, source_event_id, choice_id, sequence]
    var digest := material.sha256_text()
    var memory_id := "rmem:%s" % digest.substr(0, 20)
    var first_eligible := expedition_index + min_offset
    var max_surface := -1 if max_offset < 0 else expedition_index + max_offset
    var priority_band := _priority_band_for_family(family)
    return {
        "memory_id": memory_id,
        "memory_key": memory_key,
        "source_type": source_type,
        "source_event_id": source_event_id,
        "choice_id": choice_id,
        "chosen_option_id": choice_id,
        "family": family,
        "state": "DORMANT",
        "created_expedition": expedition_index,
        "created_expedition_index": expedition_index,
        "first_eligible_expedition": -1,
        "last_transition_expedition": expedition_index,
        "min_surface_expedition": first_eligible,
        "max_surface_expedition": max_surface,
        "window_id": window_id,
        "priority_band": priority_band,
        "urgency": clampi(int(context.get("urgency", 50)), 0, 100),
        "deterministic_tiebreak": ("%d|%s|%d" % [scheduler_seed, memory_id, first_eligible]).sha256_text(),
        "participants": participants.duplicate(),
        "world_anchors": (context.get("world_anchors", []) as Array).duplicate(),
        "evidence": evidence.duplicate(true),
        "requirements_snapshot": (echo.get("requires", []) as Array).duplicate(),
        "requires": (echo.get("requires", []) as Array).duplicate(),
        "writes": (echo.get("writes", []) as Array).duplicate(),
        "archive_link": str(echo.get("archive_link", "")),
        "remanence_link": str(echo.get("remanence_link", "")),
        "possible_outcomes": (echo.get("possible_outcomes", []) as Array).duplicate(),
        "reaction_priority": (echo.get("reaction_priority", []) as Array).duplicate(),
        "history_refs": (context.get("history_refs", []) as Array).duplicate(),
        "source_history_written": true,
        "surfaced_count": 0,
        "resolution": {}
    }

func _requirements_satisfied(memory: Dictionary, context: Dictionary) -> bool:
    var flags: Array = context.get("flags", [])
    for requirement_value: Variant in memory.get("requires", []):
        var requirement := str(requirement_value)
        if bool(context.get(requirement, false)):
            continue
        if requirement in flags:
            continue
        return false
    var require_participants := bool(context.get("require_declared_participants", false))
    if require_participants:
        var present: Array = context.get("present_entities", [])
        for participant_value: Variant in memory.get("participants", []):
            if not str(participant_value) in present:
                return false
    return true

func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
    var a_score := _candidate_score(a)
    var b_score := _candidate_score(b)
    if a_score != b_score:
        return a_score > b_score
    return str(a.get("deterministic_tiebreak", "")) < str(b.get("deterministic_tiebreak", ""))

func _candidate_score(memory: Dictionary) -> int:
    var band := int(PRIORITY_BANDS.get(str(memory.get("priority_band", "DISCOVERY_OR_ARCHIVE")), 0))
    var urgency := clampi(int(memory.get("urgency", 50)), 0, 100)
    var age := maxi(0, expedition_index - int(memory.get("created_expedition", expedition_index)))
    var score := band * 1000 + urgency * 10 + mini(age, 99)
    if bool(memory.get("soft_family_cooldown", false)):
        score -= 500
    return score

func _source_on_cooldown(memory: Dictionary) -> bool:
    var source_event_id := str(memory.get("source_event_id", ""))
    if not source_cooldowns.has(source_event_id):
        return false
    return expedition_index - int(source_cooldowns[source_event_id]) < SOURCE_COOLDOWN_EXPEDITIONS

func _family_on_soft_cooldown(memory: Dictionary) -> bool:
    var family := str(memory.get("family", ""))
    if family.is_empty() or not family_cooldowns.has(family):
        return false
    return expedition_index - int(family_cooldowns[family]) <= FAMILY_SOFT_COOLDOWN_EXPEDITIONS

func _expire_internal(memory_id: String, reason: String) -> bool:
    var memory: Dictionary = records.get(memory_id, {})
    if memory.is_empty() or str(memory.get("state", "")) in ["RESOLVED", "EXPIRED", "RETIRED"]:
        return false
    queue.erase(memory_id)
    if surfaced_memory_id == memory_id:
        surfaced_memory_id = ""
    memory["state"] = "EXPIRED"
    memory["expiry_reason"] = reason
    memory["last_transition_expedition"] = expedition_index
    records[memory_id] = memory
    memory_expired.emit(memory.duplicate(true), reason)
    scheduler_changed.emit(snapshot())
    return true

func _request_projection_hooks(memory: Dictionary, resolution: Dictionary) -> void:
    var entity_id := str(resolution.get("entity_id", ""))
    var archive_link := str(memory.get("archive_link", ""))
    if not archive_link.is_empty():
        archive_hook_requested.emit(entity_id, "refuge_memory_resolved", {
            "memory_id": memory.get("memory_id", ""),
            "source_event_id": memory.get("source_event_id", ""),
            "choice_id": memory.get("choice_id", ""),
            "archive_link": archive_link,
            "writes": (memory.get("writes", []) as Array).duplicate(),
            "resolution": resolution.duplicate(true),
            "evidence": (memory.get("evidence", {}) as Dictionary).duplicate(true)
        })
    var remanence_link := str(memory.get("remanence_link", ""))
    if not remanence_link.is_empty() and bool(resolution.get("shared_lived_history", false)):
        remanence_hook_requested.emit(entity_id, "refuge_memory_shared_history", {
            "memory_id": memory.get("memory_id", ""),
            "source_event_id": memory.get("source_event_id", ""),
            "remanence_link": remanence_link,
            "evidence": (memory.get("evidence", {}) as Dictionary).duplicate(true)
        })

func _template_by_id(source_event_id: String) -> Dictionary:
    for value: Variant in templates.get("templates", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == source_event_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _chain_by_source_id(source_event_id: String) -> Dictionary:
    for value: Variant in chains.get("chains", []):
        if value is Dictionary and str((value as Dictionary).get("source_event_id", "")) == source_event_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _regional_echo_by_id(source_event_id: String) -> Dictionary:
    for value: Variant in regional_echoes.get("events", []):
        if value is Dictionary and str((value as Dictionary).get("source_event_id", "")) == source_event_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _template_has_choice(template: Dictionary, choice_id: String) -> bool:
    for value: Variant in template.get("choices", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
            return true
    return false

func _history_is_written(evidence: Dictionary, context: Dictionary) -> bool:
    return bool(evidence.get("shared_history", false)) or not str(evidence.get("history_ref", "")).is_empty() or bool(context.get("source_history_written", false))

func _priority_band_for_family(family: String) -> String:
    if family == "CRISE":
        return "CRISIS"
    if family in ["BESOIN_BIOLOGIQUE", "TRANSFORMATION"]:
        return "BODY_OR_AVAILABILITY"
    if family in ["CONFLIT", "RAPPROCHEMENT", "DEPART", "POLITIQUE", "BESOIN_PSYCHOLOGIQUE"]:
        return "RELATIONSHIP_OR_DEPARTURE"
    if family in ["DECOUVERTE", "SOUVENIR", "REGIONAL"]:
        return "DISCOVERY_OR_ARCHIVE"
    return "ROUTINE_OR_WORK"

func _records_for_ids(ids: Array[String]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for memory_id: String in ids:
        if records.has(memory_id):
            result.append((records[memory_id] as Dictionary).duplicate(true))
    return result

func _state_counts() -> Dictionary:
    var result: Dictionary = {}
    for state: String in VALID_STATES:
        result[state] = 0
    for value: Variant in records.values():
        if value is Dictionary:
            var state := str((value as Dictionary).get("state", "DORMANT"))
            result[state] = int(result.get(state, 0)) + 1
    return result

func _validated_records(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if not (value is Dictionary):
        return result
    for key_value: Variant in (value as Dictionary).keys():
        var memory_id := str(key_value)
        var record_value: Variant = (value as Dictionary).get(key_value, {})
        if not (record_value is Dictionary):
            continue
        var record: Dictionary = (record_value as Dictionary).duplicate(true)
        var state := str(record.get("state", "DORMANT"))
        if not state in VALID_STATES:
            migration_log.append({"memory_id":memory_id,"warning":"invalid_state_reset_to_DORMANT","old_state":state})
            record["state"] = "DORMANT"
        record["memory_id"] = memory_id
        result[memory_id] = record
    return result

func _migrate_unversioned_to_v1(payload: Dictionary) -> Dictionary:
    var migrated := payload.duplicate(true)
    migrated["schema_version"] = SCHEMA_VERSION
    for pair: Array in [
        ["return_index", 0],
        ["sequence", 0],
        ["records", {}],
        ["queue", []],
        ["surfaced_memory_id", ""],
        ["source_cooldowns", {}],
        ["family_cooldowns", {}],
        ["migration_log", []],
        ["current_surface_limit", DEFAULT_SURFACE_LIMIT],
        ["surfaced_count_this_return", 0]
    ]:
        if not migrated.has(pair[0]):
            migrated[pair[0]] = pair[1]
    var logs: Array = migrated.get("migration_log", [])
    logs.append({"from":0,"to":SCHEMA_VERSION,"action":"normalize_to_v1"})
    migrated["migration_log"] = logs
    return migrated

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
