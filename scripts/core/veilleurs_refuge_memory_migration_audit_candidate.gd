extends RefCounted
class_name VeilleursRefugeMemoryMigrationAuditCandidate

const VALID_STATES := ["DORMANT", "ELIGIBLE", "QUEUED", "SURFACED", "RESOLVED", "EXPIRED", "RETIRED"]

func deserialize_with_audit(service: VeilleursRefugeMemoryServiceCandidate, payload: Dictionary) -> Dictionary:
    if service == null:
        return {"ok": false, "reason": "service_required", "audit_warnings": []}
    var warnings: Array[Dictionary] = _scan_payload(payload)
    var result: Dictionary = service.deserialize(payload)
    if not bool(result.get("ok", false)):
        result["audit_warnings"] = warnings.duplicate(true)
        return result
    for warning: Dictionary in warnings:
        if not _log_contains(service.migration_log, warning):
            service.migration_log.append(warning.duplicate(true))
    result["audit_warnings"] = warnings.duplicate(true)
    result["migration_log_count"] = service.migration_log.size()
    return result

func _scan_payload(payload: Dictionary) -> Array[Dictionary]:
    var warnings: Array[Dictionary] = []
    var records_value: Variant = payload.get("records", {})
    if not (records_value is Dictionary):
        warnings.append({
            "warning": "records_not_dictionary_reset_empty",
            "source": "migration_audit_candidate"
        })
        return warnings
    var records: Dictionary = records_value
    for key_value: Variant in records.keys():
        var memory_id := str(key_value)
        var record_value: Variant = records.get(key_value, {})
        if not (record_value is Dictionary):
            warnings.append({
                "memory_id": memory_id,
                "warning": "malformed_record_dropped",
                "source": "migration_audit_candidate"
            })
            continue
        var record: Dictionary = record_value
        var state := str(record.get("state", "DORMANT"))
        if not state in VALID_STATES:
            warnings.append({
                "memory_id": memory_id,
                "warning": "invalid_state_reset_to_DORMANT",
                "old_state": state,
                "new_state": "DORMANT",
                "source": "migration_audit_candidate"
            })
    return warnings

func _log_contains(log_entries: Array[Dictionary], warning: Dictionary) -> bool:
    for existing: Dictionary in log_entries:
        if str(existing.get("warning", "")) != str(warning.get("warning", "")):
            continue
        if str(existing.get("memory_id", "")) != str(warning.get("memory_id", "")):
            continue
        if str(existing.get("old_state", "")) != str(warning.get("old_state", "")):
            continue
        return true
    return false
