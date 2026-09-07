extends Node

const SERVICE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_service_candidate.gd")
const ADAPTER_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_projection_adapter_candidate.gd")
const CONTENT_SCRIPT := preload("res://scripts/core/veilleurs_content_runtime.gd")
const COORDINATOR_SCRIPT := preload("res://scripts/core/veilleurs_runtime_coordinator.gd")

var reference_events := 0
var forwarded_events := 0

func _ready() -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    var content := CONTENT_SCRIPT.new() as VeilleursContentRuntime
    var coordinator := COORDINATOR_SCRIPT.new() as VeilleursRuntimeCoordinator
    add_child(content)
    add_child(coordinator)
    var adapter := ADAPTER_SCRIPT.new() as VeilleursRefugeMemoryProjectionAdapterCandidate

    assert(bool(adapter.validation_report().get("ok", false)))
    var bound := adapter.bind(service, content, coordinator)
    assert(bool(bound.get("ok", false)))
    assert(bool(bound.get("remanence_bound", false)))

    coordinator.runtime_event.connect(_on_runtime_event)
    adapter.remanence_lived_event_forwarded.connect(_on_forwarded)

    service.archive_hook_requested.emit("aux:test:archive", "refuge_memory_resolved", {
        "memory_id": "rmem:test-archive",
        "source_event_id": "ref.souvenir.old_wound",
        "choice_id": "document_memory",
        "archive_link": "corps.persistent_wound_history",
        "writes": ["archive_history", "body_history"],
        "evidence": {"history_ref": "injury:test:1"}
    })
    var archive_entry := content.archive_entry("aux:test:archive")
    assert(not archive_entry.is_empty())
    assert((archive_entry.get("events", []) as Array).size() == 1)

    var entity_id := "enemy:delie_affame:adapter-smoke"
    service.remanence_hook_requested.emit(entity_id, "refuge_memory_shared_history", {
        "memory_id": "rmem:reference-only",
        "source_event_id": "ref.souvenir.old_wound",
        "remanence_link": "memory_of_wound",
        "evidence": {"history_ref": "injury:test:2"}
    })
    assert(reference_events == 1)
    assert(coordinator.enemy_memory_state(entity_id).is_empty(), "Reference-only social history must not mutate Remanence rank")

    service.remanence_hook_requested.emit(entity_id, "refuge_memory_shared_history", {
        "memory_id": "rmem:verified-failed-capture",
        "source_event_id": "ref.conflit.recruit_friction",
        "remanence_link": "memory_of_failed_capture",
        "canonical_event_type": "failed_capture",
        "evidence_verified": true,
        "evidence": {
            "shared_history": true,
            "direct_exchange": true,
            "capture_method": "binding_chain",
            "initiator": "tarek_senn",
            "salience": 2
        }
    })
    assert(forwarded_events == 1)
    var state := coordinator.enemy_memory_state(entity_id)
    assert(str(state.get("memory_rank", "")) == "memorial")

    var before_events := forwarded_events
    service.remanence_hook_requested.emit(entity_id, "refuge_memory_shared_history", {
        "memory_id": "rmem:unverified",
        "canonical_event_type": "watcher_kill",
        "evidence_verified": false,
        "evidence": {"shared_history": true}
    })
    assert(forwarded_events == before_events, "Unverified lived event must never reach Remanence policy")
    assert(reference_events == 2, "Unverified request becomes reference-only rather than a promotion event")

    adapter.unbind()
    print("VEILLEURS_REFUGE_MEMORY_PROJECTION_ADAPTER_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)

func _on_runtime_event(event_type: String, _payload: Dictionary) -> void:
    if event_type == "refuge_remanence_reference":
        reference_events += 1

func _on_forwarded(_entity_id: String, _event_type: String, _result: Dictionary) -> void:
    forwarded_events += 1
