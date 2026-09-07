extends Node

const SERVICE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_service_candidate.gd")

var archive_requests := 0
var remanence_requests := 0

func _ready() -> void:
    _run_service_flow()
    _run_collision_flow()
    _run_migration_flow()
    print("VEILLEURS_REFUGE_MEMORY_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)

func _run_service_flow() -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    var report := service.configure(731903, 8)
    assert(bool(report.get("ok", false)))
    assert(int(report.get("templates", 0)) == 24)
    assert(int(report.get("chains", 0)) == 24)
    assert(int(report.get("regional_sources", 0)) == 16)

    service.archive_hook_requested.connect(_on_archive_hook_requested)
    service.remanence_hook_requested.connect(_on_remanence_hook_requested)

    var participants: Array[String] = ["nayra_orun", "tarek_senn"]
    var rejected := service.record_source_choice(
        "ref.cohabitation.shared_watch",
        "keep_pair",
        {},
        participants,
        {}
    )
    assert(not bool(rejected.get("ok", true)), "A Refuge callback requires written lived history")

    var created := service.record_source_choice(
        "ref.cohabitation.shared_watch",
        "keep_pair",
        {"shared_history": true, "history_ref": "expedition:8:shared_watch"},
        participants,
        {"history_refs": ["expedition:8:shared_watch"], "urgency": 35}
    )
    assert(bool(created.get("ok", false)))
    var created_memory: Dictionary = created.get("memory", {})
    var memory_id := str(created_memory.get("memory_id", ""))
    assert(not memory_id.is_empty())
    assert(str(created_memory.get("state", "")) == "DORMANT")

    var context := {
        "flags": ["same_pair_present"],
        "present_entities": ["nayra_orun", "tarek_senn"],
        "require_declared_participants": true
    }
    service.advance_expedition(context)
    assert(str((service.records[memory_id] as Dictionary).get("state", "")) == "ELIGIBLE")

    var queued := service.queue_for_return(context)
    assert(queued.size() == 1)
    assert(str(queued[0].get("memory_id", "")) == memory_id)
    var serialized_before_surface := service.serialize()
    var original_queue: Array = serialized_before_surface.get("queue", [])
    var original_tiebreak := str((serialized_before_surface.get("records", {}) as Dictionary).get(memory_id, {}).get("deterministic_tiebreak", ""))

    var reloaded := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    reloaded.archive_hook_requested.connect(_on_archive_hook_requested)
    reloaded.remanence_hook_requested.connect(_on_remanence_hook_requested)
    var load_report := reloaded.deserialize(serialized_before_surface)
    assert(bool(load_report.get("ok", false)))
    assert(not bool(load_report.get("migrated", true)))
    assert((reloaded.serialize().get("queue", []) as Array) == original_queue)
    assert(str((reloaded.records[memory_id] as Dictionary).get("deterministic_tiebreak", "")) == original_tiebreak)

    var surfaced := reloaded.surface_next()
    assert(bool(surfaced.get("ok", false)))
    assert(str((surfaced.get("memory", {}) as Dictionary).get("state", "")) == "SURFACED")
    var resolved := reloaded.resolve_memory(memory_id, {
        "entity_id": "aux:test:01",
        "shared_lived_history": true,
        "acknowledged": true
    })
    assert(bool(resolved.get("ok", false)))
    assert(str((resolved.get("memory", {}) as Dictionary).get("state", "")) == "RESOLVED")
    assert(archive_requests == 1)
    assert(remanence_requests == 1)
    assert(reloaded.confirm_projection_committed(memory_id))
    assert(str((reloaded.records[memory_id] as Dictionary).get("state", "")) == "RETIRED")

    var regional_participants: Array[String] = ["tarek_senn", "idris_vael"]
    var regional := reloaded.record_regional_choice(
        "region.a2.signal_without_voice",
        "keep_uncertain",
        {"history_ref": "region:a2:signal:choice", "observed": true},
        regional_participants,
        {"history_refs": ["region:a2:signal:choice"]}
    )
    assert(bool(regional.get("ok", false)))
    var regional_id := str((regional.get("memory", {}) as Dictionary).get("memory_id", ""))
    reloaded.advance_expedition({"flags": ["new_related_observation"]})
    reloaded.advance_expedition({"flags": ["new_related_observation"]})
    var regional_queue := reloaded.queue_for_return({"flags": ["new_related_observation"]})
    assert(regional_queue.any(func(item: Dictionary) -> bool: return str(item.get("memory_id", "")) == regional_id))

func _run_collision_flow() -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    service.configure(731903, 20)
    service.records = {
        "m.work.repair": {
            "memory_id": "m.work.repair",
            "memory_key": "work",
            "source_event_id": "ref.travail.repair_after_expedition",
            "family": "TRAVAIL",
            "state": "ELIGIBLE",
            "source_history_written": true,
            "priority_band": "ROUTINE_OR_WORK",
            "urgency": 40,
            "created_expedition": 17,
            "deterministic_tiebreak": "b",
            "requires": []
        },
        "m.crisis.wounds": {
            "memory_id": "m.crisis.wounds",
            "memory_key": "crisis",
            "source_event_id": "ref.crise.multiple_critical_wounds",
            "family": "CRISE",
            "state": "ELIGIBLE",
            "source_history_written": true,
            "priority_band": "CRISIS",
            "urgency": 60,
            "created_expedition": 19,
            "deterministic_tiebreak": "a",
            "requires": []
        }
    }
    var queued := service.queue_for_return({})
    assert(queued.size() == 2)
    assert(str(queued[0].get("memory_id", "")) == "m.crisis.wounds")
    assert(str(queued[1].get("memory_id", "")) == "m.work.repair")
    var first := service.surface_next()
    assert(str((first.get("memory", {}) as Dictionary).get("memory_id", "")) == "m.crisis.wounds")

func _run_migration_flow() -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    var migrated := service.deserialize({"scheduler_seed": 99, "expedition_index": 3, "records": {}})
    assert(bool(migrated.get("ok", false)))
    assert(bool(migrated.get("migrated", false)))
    assert(int(service.serialize().get("schema_version", 0)) == 1)
    var future := service.deserialize({"schema_version": 99})
    assert(not bool(future.get("ok", true)))
    assert(str(future.get("reason", "")) == "future_schema_unsupported")

func _on_archive_hook_requested(_entity_id: String, _hook: String, _payload: Dictionary) -> void:
    archive_requests += 1

func _on_remanence_hook_requested(_entity_id: String, _event_type: String, _payload: Dictionary) -> void:
    remanence_requests += 1
