extends Node

const SERVICE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_service_candidate.gd")
const AUDIT_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_migration_audit_candidate.gd")

func _ready() -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    var audit := AUDIT_SCRIPT.new() as VeilleursRefugeMemoryMigrationAuditCandidate
    var payload := {
        "schema_version": 1,
        "scheduler_seed": 731903,
        "expedition_index": 4,
        "records": {
            "rmem:invalid-state": {
                "memory_id": "rmem:invalid-state",
                "state": "IMPOSSIBLE_STATE",
                "source_event_id": "ref.cohabitation.shared_watch",
                "source_history_written": true
            }
        },
        "queue": [],
        "migration_log": []
    }
    var result := audit.deserialize_with_audit(service, payload)
    assert(bool(result.get("ok", false)))
    var serialized := service.serialize()
    var record: Dictionary = (serialized.get("records", {}) as Dictionary).get("rmem:invalid-state", {})
    assert(str(record.get("state", "")) == "DORMANT")
    var found_warning := false
    for value: Variant in serialized.get("migration_log", []):
        if not (value is Dictionary):
            continue
        var warning: Dictionary = value
        if str(warning.get("memory_id", "")) == "rmem:invalid-state" and str(warning.get("warning", "")) == "invalid_state_reset_to_DORMANT":
            assert(str(warning.get("old_state", "")) == "IMPOSSIBLE_STATE")
            assert(str(warning.get("new_state", "")) == "DORMANT")
            found_warning = true
    assert(found_warning, "invalid-state normalization must remain explicit in migration_log")

    var second := audit.deserialize_with_audit(service, service.serialize())
    assert(bool(second.get("ok", false)))
    var duplicate_count := 0
    for value: Variant in service.serialize().get("migration_log", []):
        if value is Dictionary and str((value as Dictionary).get("warning", "")) == "invalid_state_reset_to_DORMANT":
            duplicate_count += 1
    assert(duplicate_count == 1, "migration audit warnings must be idempotent")

    print("VEILLEURS_REFUGE_MEMORY_MIGRATION_AUDIT_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)
