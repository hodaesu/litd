extends RefCounted
class_name VeilleursRefugeMemoryProjectionAdapterCandidate

signal archive_projected(entity_id: String, hook: String, entry: Dictionary)
signal remanence_reference_projected(entity_id: String, payload: Dictionary)
signal remanence_lived_event_forwarded(entity_id: String, event_type: String, result: Dictionary)
signal projection_rejected(domain: String, reason: String, payload: Dictionary)

const CONTRACT_PATH := "res://data/veilleurs/parallel_content/refuge_memory_projection_adapter_contract_v1.json"
const CANONICAL_PROMOTION_EVENTS := [
    "survival",
    "watcher_kill",
    "mutilation",
    "escape",
    "failed_capture",
    "important_item_taken_or_recovered",
    "forced_retreat",
    "repeated_encounter"
]

var contract: Dictionary = {}
var service = null
var content_runtime = null
var coordinator = null

func _init() -> void:
    contract = _load_dictionary(CONTRACT_PATH)

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    if bool(contract.get("enabled_by_default", true)):
        errors.append("contract_must_remain_inactive")
    var configured: Array = (contract.get("remanence_policy", {}) as Dictionary).get("canonical_promotion_events", [])
    if configured.size() != CANONICAL_PROMOTION_EVENTS.size():
        errors.append("canonical_promotion_event_count:%d" % configured.size())
    for event_type: String in CANONICAL_PROMOTION_EVENTS:
        if not event_type in configured:
            errors.append("missing_promotion_event:%s" % event_type)
    return {"ok": errors.is_empty(), "errors": errors}

func bind(service_candidate, content_runtime_candidate, coordinator_candidate = null) -> Dictionary:
    unbind()
    if service_candidate == null:
        return {"ok": false, "reason": "memory_service_required"}
    if content_runtime_candidate == null:
        return {"ok": false, "reason": "content_runtime_required"}
    service = service_candidate
    content_runtime = content_runtime_candidate
    coordinator = coordinator_candidate
    if not service.archive_hook_requested.is_connected(_on_archive_hook_requested):
        service.archive_hook_requested.connect(_on_archive_hook_requested)
    if not service.remanence_hook_requested.is_connected(_on_remanence_hook_requested):
        service.remanence_hook_requested.connect(_on_remanence_hook_requested)
    return {"ok": true, "remanence_bound": coordinator != null}

func unbind() -> void:
    if service != null:
        if service.archive_hook_requested.is_connected(_on_archive_hook_requested):
            service.archive_hook_requested.disconnect(_on_archive_hook_requested)
        if service.remanence_hook_requested.is_connected(_on_remanence_hook_requested):
            service.remanence_hook_requested.disconnect(_on_remanence_hook_requested)
    service = null
    content_runtime = null
    coordinator = null

func _on_archive_hook_requested(entity_id: String, hook: String, payload: Dictionary) -> void:
    if content_runtime == null:
        projection_rejected.emit("archive", "content_runtime_unbound", payload.duplicate(true))
        return
    if hook != "refuge_memory_resolved":
        projection_rejected.emit("archive", "unsupported_archive_hook", payload.duplicate(true))
        return
    var safe_payload := payload.duplicate(true)
    safe_payload.erase("future_boss_phase_truth")
    safe_payload.erase("capture_probability")
    safe_payload["projection_source"] = "refuge_memory_candidate"
    var entry: Dictionary = content_runtime.record_archive_hook(entity_id, "refuge_memory_resolved", safe_payload)
    archive_projected.emit(entity_id, "refuge_memory_resolved", entry.duplicate(true))

func _on_remanence_hook_requested(entity_id: String, event_type: String, payload: Dictionary) -> void:
    if coordinator == null:
        projection_rejected.emit("remanence", "coordinator_unbound", payload.duplicate(true))
        return
    if entity_id.is_empty():
        projection_rejected.emit("remanence", "stable_entity_id_required", payload.duplicate(true))
        return

    var canonical_event_type := str(payload.get("canonical_event_type", ""))
    var evidence_verified := bool(payload.get("evidence_verified", false))
    var evidence: Dictionary = (payload.get("evidence", {}) as Dictionary).duplicate(true)
    var may_forward := (
        event_type == "refuge_memory_shared_history"
        and canonical_event_type in CANONICAL_PROMOTION_EVENTS
        and evidence_verified
        and not evidence.is_empty()
    )
    if may_forward:
        evidence["refuge_memory_reference"] = str(payload.get("memory_id", ""))
        evidence["refuge_memory_source_event_id"] = str(payload.get("source_event_id", ""))
        evidence["evidence_verified"] = true
        var result: Dictionary = coordinator.note_enemy_memory_event(entity_id, canonical_event_type, evidence)
        if bool(result.get("ok", false)):
            remanence_lived_event_forwarded.emit(entity_id, canonical_event_type, result.duplicate(true))
        else:
            projection_rejected.emit("remanence", "canonical_policy_rejected_event", {
                "event_type": canonical_event_type,
                "result": result.duplicate(true),
                "request": payload.duplicate(true)
            })
        return

    var reference_payload := payload.duplicate(true)
    reference_payload["entity_id"] = entity_id
    reference_payload["request_event_type"] = event_type
    reference_payload["mutates_memory_rank"] = false
    reference_payload["projection_source"] = "refuge_memory_candidate"
    coordinator.runtime_event.emit("refuge_remanence_reference", reference_payload.duplicate(true))
    remanence_reference_projected.emit(entity_id, reference_payload.duplicate(true))

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
