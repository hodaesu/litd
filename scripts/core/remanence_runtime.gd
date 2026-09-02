extends Node

signal remanence_changed
signal entity_stage_changed(entity_id: String, previous_stage: String, new_stage: String)
signal event_recorded(event: Dictionary)
signal world_scar_changed(scar_id: String)
signal archive_link_added(source_id: String, target_id: String, relation: String)

const DATA_PATH := "res://data/remanence_rules.json"
const SAVE_SCHEMA_VERSION := 1

var rules: Dictionary = {}
var entities: Dictionary = {}
var archived_entities: Array = []
var event_timeline: Array = []
var world_scars: Dictionary = {}
var archived_scars: Array = []
var archive_links: Array = []

var entity_sequence := 0
var event_sequence := 0
var scar_sequence := 0
var run_index := 0

func _ready() -> void:
    _load_rules()
    call_deferred("_connect_game_state")

func _connect_game_state() -> void:
    if GameState != null and not GameState.new_game_reset.is_connected(reset_new_game):
        GameState.new_game_reset.connect(reset_new_game)

func _load_rules() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    rules = parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    entities = {}
    archived_entities = []
    event_timeline = []
    world_scars = {}
    archived_scars = []
    archive_links = []
    entity_sequence = 0
    event_sequence = 0
    scar_sequence = 0
    run_index = 0
    remanence_changed.emit()

func prepare_enemy(enemy: Dictionary, region_id: String = "") -> String:
    var entity_id := str(enemy.get("remanence_id", ""))
    if entity_id == "":
        entity_id = _next_entity_id(_species_key(enemy))
        enemy["remanence_id"] = entity_id
    if not entities.has(entity_id):
        entities[entity_id] = {
            "id": entity_id,
            "species_id": str(enemy.get("species_id", enemy.get("id", "unknown"))),
            "name": str(enemy.get("name", "Adversaire")),
            "region_id": region_id,
            "stage": "normal",
            "score": 0,
            "encounters": 0,
            "major_events": 0,
            "status": "active",
            "adaptations": [],
            "body_snapshot": {},
            "first_event_seq": event_sequence,
            "last_event_seq": event_sequence,
            "protected": bool(enemy.get("remanence_protected", false))
        }
    else:
        var record: Dictionary = entities[entity_id]
        if region_id != "":
            record["region_id"] = region_id
        record["name"] = str(enemy.get("name", record.get("name", "Adversaire")))
        entities[entity_id] = record
    return entity_id

func note_encounter(enemy: Dictionary, region_id: String = "", context: Dictionary = {}) -> Dictionary:
    var entity_id := prepare_enemy(enemy, region_id)
    var record: Dictionary = entities.get(entity_id, {})
    var event_type := "encountered" if int(record.get("encounters", 0)) == 0 else "reencountered"
    var merged := context.duplicate(true)
    if region_id != "":
        merged["region_id"] = region_id
    return record_event(entity_id, event_type, merged)

func record_enemy_event(enemy: Dictionary, event_type: String, context: Dictionary = {}) -> Dictionary:
    var entity_id := prepare_enemy(enemy, str(context.get("region_id", "")))
    return record_event(entity_id, event_type, context)

func record_event(entity_id: String, event_type: String, context: Dictionary = {}) -> Dictionary:
    if not entities.has(entity_id):
        return {}
    var record: Dictionary = entities[entity_id]
    event_sequence += 1
    var event := {
        "seq": event_sequence,
        "entity_id": entity_id,
        "type": event_type,
        "weight": _event_weight(event_type),
        "run_index": run_index,
        "chapter_id": str(context.get("chapter_id", CampaignState.current_chapter_id)),
        "zone_id": str(context.get("zone_id", AshlandsRuntime.current_zone_id)),
        "region_id": str(context.get("region_id", record.get("region_id", ""))),
        "hero_id": str(context.get("hero_id", "")),
        "object_id": str(context.get("object_id", "")),
        "scar_id": str(context.get("scar_id", "")),
        "summary": str(context.get("summary", "")),
        "timestamp": Time.get_datetime_string_from_system()
    }
    for key_value: Variant in context.keys():
        var key := str(key_value)
        if not event.has(key):
            event[key] = context.get(key_value)
    event_timeline.append(event)
    record["score"] = int(record.get("score", 0)) + int(event.get("weight", 0))
    record["last_event_seq"] = event_sequence
    if event_type in ["encountered", "reencountered"]:
        record["encounters"] = int(record.get("encounters", 0)) + 1
    if _major_event_types().has(event_type):
        record["major_events"] = int(record.get("major_events", 0)) + 1
    if str(event.get("region_id", "")) != "":
        record["region_id"] = str(event.get("region_id", ""))
    entities[entity_id] = record
    _recompute_stage(entity_id)
    _enforce_caps()
    event_recorded.emit(event.duplicate(true))
    remanence_changed.emit()
    return event.duplicate(true)

func sync_body_snapshot(enemy: Dictionary) -> void:
    var entity_id := prepare_enemy(enemy)
    var record: Dictionary = entities.get(entity_id, {})
    record["body_snapshot"] = {
        "persistent_injuries": (enemy.get("persistent_injuries", []) as Array).duplicate(true),
        "body_state": (enemy.get("body_state", {}) as Dictionary).duplicate(true),
        "hp": int(enemy.get("hp", 0)),
        "max_hp": int(enemy.get("max_hp", enemy.get("hp", 0)))
    }
    entities[entity_id] = record
    remanence_changed.emit()

func set_entity_status(entity_id: String, status: String) -> void:
    if not entities.has(entity_id):
        return
    var record: Dictionary = entities[entity_id]
    record["status"] = status
    if status in ["recruited", "nemesis"]:
        record["protected"] = true
    entities[entity_id] = record
    _enforce_caps()
    remanence_changed.emit()

func add_adaptation(entity_id: String, adaptation_id: String) -> bool:
    if not entities.has(entity_id) or adaptation_id == "":
        return false
    var record: Dictionary = entities[entity_id]
    var adaptations: Array = record.get("adaptations", [])
    if adaptations.has(adaptation_id):
        return false
    var limit := _adaptation_limit(str(record.get("stage", "normal")))
    if limit <= 0:
        return false
    adaptations.append(adaptation_id)
    while adaptations.size() > limit:
        adaptations.remove_at(0)
    record["adaptations"] = adaptations
    entities[entity_id] = record
    remanence_changed.emit()
    return true

func create_world_scar(anchor_id: String, scar_type: String, severity: String = "trace", context: Dictionary = {}) -> String:
    scar_sequence += 1
    var scar_id := "scar:%s:%06d" % [_sanitize(anchor_id if anchor_id != "" else scar_type), scar_sequence]
    var scar := {
        "id": scar_id,
        "anchor_id": anchor_id,
        "type": scar_type,
        "severity": severity,
        "region_id": str(context.get("region_id", "")),
        "zone_id": str(context.get("zone_id", AshlandsRuntime.current_zone_id)),
        "origin_entity_id": str(context.get("origin_entity_id", "")),
        "origin_hero_id": str(context.get("origin_hero_id", "")),
        "summary": str(context.get("summary", "")),
        "created_run": run_index,
        "age_runs": 0,
        "age_stage": "fresh",
        "protected": bool(context.get("protected", severity == "historical")),
        "payload": context.duplicate(true)
    }
    world_scars[scar_id] = scar
    _enforce_caps()
    world_scar_changed.emit(scar_id)
    remanence_changed.emit()
    return scar_id

func update_world_scar(scar_id: String, patch: Dictionary) -> bool:
    if not world_scars.has(scar_id):
        return false
    var scar: Dictionary = world_scars[scar_id]
    for key_value: Variant in patch.keys():
        scar[str(key_value)] = patch.get(key_value)
    world_scars[scar_id] = scar
    world_scar_changed.emit(scar_id)
    remanence_changed.emit()
    return true

func advance_expedition_cycle() -> void:
    run_index += 1
    var to_archive: Array[String] = []
    for scar_id_value: Variant in world_scars.keys():
        var scar_id := str(scar_id_value)
        var scar: Dictionary = world_scars[scar_id]
        scar["age_runs"] = int(scar.get("age_runs", 0)) + 1
        scar["age_stage"] = _scar_age_stage(int(scar.get("age_runs", 0)))
        world_scars[scar_id] = scar
        if str(scar.get("age_stage", "")) == "archive" and not bool(scar.get("protected", false)):
            to_archive.append(scar_id)
    for scar_id: String in to_archive:
        _archive_scar(scar_id)
    _enforce_caps()
    remanence_changed.emit()

func link_archive_nodes(source_id: String, target_id: String, relation: String, context: Dictionary = {}) -> bool:
    if source_id == "" or target_id == "" or relation == "":
        return false
    for value: Variant in archive_links:
        var existing: Dictionary = value
        if str(existing.get("source_id", "")) == source_id and str(existing.get("target_id", "")) == target_id and str(existing.get("relation", "")) == relation:
            return false
    var link := {
        "source_id": source_id,
        "target_id": target_id,
        "relation": relation,
        "event_seq": event_sequence,
        "context": context.duplicate(true)
    }
    archive_links.append(link)
    _enforce_caps()
    archive_link_added.emit(source_id, target_id, relation)
    remanence_changed.emit()
    return true

func linked_entries(node_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in archive_links:
        var link: Dictionary = value
        if str(link.get("source_id", "")) == node_id or str(link.get("target_id", "")) == node_id:
            result.append(link.duplicate(true))
    return result

func entity_state(entity_id: String) -> Dictionary:
    return (entities.get(entity_id, {}) as Dictionary).duplicate(true)

func recent_events(entity_id: String = "", limit: int = 12) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(event_timeline.size() - 1, -1, -1):
        var event: Dictionary = event_timeline[index]
        if entity_id != "" and str(event.get("entity_id", "")) != entity_id:
            continue
        result.append(event.duplicate(true))
        if result.size() >= limit:
            break
    return result

func serialize() -> Dictionary:
    _enforce_caps()
    return {
        "schema_version": SAVE_SCHEMA_VERSION,
        "entities": entities.duplicate(true),
        "archived_entities": archived_entities.duplicate(true),
        "event_timeline": event_timeline.duplicate(true),
        "world_scars": world_scars.duplicate(true),
        "archived_scars": archived_scars.duplicate(true),
        "archive_links": archive_links.duplicate(true),
        "entity_sequence": entity_sequence,
        "event_sequence": event_sequence,
        "scar_sequence": scar_sequence,
        "run_index": run_index
    }

func deserialize(payload: Dictionary) -> void:
    if payload.is_empty():
        reset_new_game()
        return
    entities = payload.get("entities", {}).duplicate(true)
    archived_entities = payload.get("archived_entities", []).duplicate(true)
    event_timeline = payload.get("event_timeline", []).duplicate(true)
    world_scars = payload.get("world_scars", {}).duplicate(true)
    archived_scars = payload.get("archived_scars", []).duplicate(true)
    archive_links = payload.get("archive_links", []).duplicate(true)
    entity_sequence = int(payload.get("entity_sequence", 0))
    event_sequence = int(payload.get("event_sequence", 0))
    scar_sequence = int(payload.get("scar_sequence", 0))
    run_index = int(payload.get("run_index", 0))
    _enforce_caps()
    remanence_changed.emit()

func _recompute_stage(entity_id: String) -> void:
    if not entities.has(entity_id):
        return
    var record: Dictionary = entities[entity_id]
    var previous_stage := str(record.get("stage", "normal"))
    var score := int(record.get("score", 0))
    var encounters := int(record.get("encounters", 0))
    var major_events := int(record.get("major_events", 0))
    var thresholds: Dictionary = rules.get("stage_thresholds", {})
    var minimums: Dictionary = rules.get("minimum_encounters", {})
    var new_stage := "normal"
    if score >= int(thresholds.get("memorial", 3)):
        new_stage = "memorial"
    if score >= int(thresholds.get("veteran", 7)) and encounters >= int(minimums.get("veteran", 2)):
        new_stage = "veteran"
    if score >= int(thresholds.get("elite", 12)) and encounters >= int(minimums.get("elite", 3)):
        new_stage = "elite"
    if score >= int(thresholds.get("nemesis", 18)) and encounters >= int(minimums.get("nemesis", 4)) and major_events >= 1 and _nemesis_capacity_available(entity_id, str(record.get("region_id", ""))):
        new_stage = "nemesis"
    record["stage"] = new_stage
    if new_stage == "nemesis":
        record["protected"] = true
    var adaptations: Array = record.get("adaptations", [])
    var adaptation_limit := _adaptation_limit(new_stage)
    while adaptations.size() > adaptation_limit:
        adaptations.remove_at(0)
    record["adaptations"] = adaptations
    entities[entity_id] = record
    if previous_stage != new_stage:
        entity_stage_changed.emit(entity_id, previous_stage, new_stage)
        if new_stage != "normal":
            CampaignMemoryDirector.record_notable_enemy({
                "id": entity_id,
                "name": str(record.get("name", "Adversaire")),
                "fear_gauge": 0
            }, "promotion:%s" % new_stage)

func _nemesis_capacity_available(entity_id: String, region_id: String) -> bool:
    var limits: Dictionary = rules.get("nemesis_limits", {})
    var global_count := 0
    var region_count := 0
    for key_value: Variant in entities.keys():
        var current_id := str(key_value)
        if current_id == entity_id:
            continue
        var record: Dictionary = entities[current_id]
        if str(record.get("stage", "")) != "nemesis" or str(record.get("status", "active")) == "dead":
            continue
        global_count += 1
        if str(record.get("region_id", "")) == region_id:
            region_count += 1
    return global_count < int(limits.get("global", 3)) and region_count < int(limits.get("per_region", 1))

func _archive_entity(entity_id: String) -> void:
    if not entities.has(entity_id):
        return
    var record: Dictionary = entities[entity_id]
    archived_entities.append({
        "id": entity_id,
        "species_id": str(record.get("species_id", "")),
        "name": str(record.get("name", "Adversaire")),
        "stage": str(record.get("stage", "normal")),
        "score": int(record.get("score", 0)),
        "status": str(record.get("status", "archived")),
        "region_id": str(record.get("region_id", "")),
        "last_event_seq": int(record.get("last_event_seq", 0))
    })
    entities.erase(entity_id)

func _archive_scar(scar_id: String) -> void:
    if not world_scars.has(scar_id):
        return
    var scar: Dictionary = world_scars[scar_id]
    archived_scars.append({
        "id": scar_id,
        "anchor_id": str(scar.get("anchor_id", "")),
        "type": str(scar.get("type", "trace")),
        "severity": str(scar.get("severity", "trace")),
        "region_id": str(scar.get("region_id", "")),
        "zone_id": str(scar.get("zone_id", "")),
        "summary": str(scar.get("summary", "")),
        "age_runs": int(scar.get("age_runs", 0)),
        "age_stage": str(scar.get("age_stage", "archive"))
    })
    world_scars.erase(scar_id)

func _enforce_caps() -> void:
    var caps: Dictionary = rules.get("mobile_caps", {})
    _trim_front(event_timeline, int(caps.get("event_timeline", 220)))
    _trim_front(archive_links, int(caps.get("archive_links", 256)))
    _trim_front(archived_entities, int(caps.get("archived_entities", 64)))
    _trim_front(archived_scars, int(caps.get("archived_scars", 128)))

    var entity_cap := int(caps.get("active_entities", 64))
    if entities.size() > entity_cap:
        var candidates: Array = []
        for key_value: Variant in entities.keys():
            var candidate_id := str(key_value)
            var record: Dictionary = entities[candidate_id]
            if bool(record.get("protected", false)) or str(record.get("stage", "")) == "nemesis" or str(record.get("status", "")) == "recruited":
                continue
            candidates.append(record)
        candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var a_priority := _entity_retention_priority(a)
            var b_priority := _entity_retention_priority(b)
            if a_priority == b_priority:
                return int(a.get("last_event_seq", 0)) < int(b.get("last_event_seq", 0))
            return a_priority < b_priority
        )
        for value: Variant in candidates:
            if entities.size() <= entity_cap:
                break
            _archive_entity(str((value as Dictionary).get("id", "")))

    var scar_cap := int(caps.get("active_scars", 96))
    if world_scars.size() > scar_cap:
        var scar_candidates: Array = []
        for scar_id_value: Variant in world_scars.keys():
            var scar: Dictionary = world_scars[str(scar_id_value)]
            if bool(scar.get("protected", false)):
                continue
            scar_candidates.append(scar)
        scar_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var ranks: Dictionary = rules.get("scar_severity_rank", {})
            var a_rank := int(ranks.get(str(a.get("severity", "trace")), 0))
            var b_rank := int(ranks.get(str(b.get("severity", "trace")), 0))
            if a_rank == b_rank:
                return int(a.get("created_run", 0)) < int(b.get("created_run", 0))
            return a_rank < b_rank
        )
        for value: Variant in scar_candidates:
            if world_scars.size() <= scar_cap:
                break
            _archive_scar(str((value as Dictionary).get("id", "")))

    _trim_front(archived_entities, int(caps.get("archived_entities", 64)))
    _trim_front(archived_scars, int(caps.get("archived_scars", 128)))

func _entity_retention_priority(record: Dictionary) -> int:
    var stage_rank := {"normal": 0, "memorial": 20, "veteran": 40, "elite": 60, "nemesis": 100}
    return int(stage_rank.get(str(record.get("stage", "normal")), 0)) + int(record.get("score", 0)) + int(record.get("major_events", 0)) * 10

func _scar_age_stage(age_runs: int) -> String:
    var resolved := "fresh"
    for value: Variant in rules.get("scar_aging", []):
        var entry: Dictionary = value
        if age_runs >= int(entry.get("after_runs", 0)):
            resolved = str(entry.get("stage", resolved))
    return resolved

func _event_weight(event_type: String) -> int:
    return int((rules.get("event_weights", {}) as Dictionary).get(event_type, 0))

func _major_event_types() -> Array:
    return rules.get("major_event_types", []) as Array

func _adaptation_limit(stage: String) -> int:
    return int((rules.get("adaptation_limits", {}) as Dictionary).get(stage, 0))

func _species_key(enemy: Dictionary) -> String:
    return str(enemy.get("species_id", enemy.get("id", "unknown")))

func _next_entity_id(species_key: String) -> String:
    entity_sequence += 1
    return "mem:%s:%06d" % [_sanitize(species_key), entity_sequence]

func _sanitize(value: String) -> String:
    return value.to_lower().replace(" ", "_").replace(":", "_").replace("/", "_")

func _trim_front(array: Array, maximum: int) -> void:
    if maximum <= 0:
        array.clear()
        return
    while array.size() > maximum:
        array.remove_at(0)
