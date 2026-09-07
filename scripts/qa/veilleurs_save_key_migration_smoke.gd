extends Node

func _ready() -> void:
    var legacy_payload: Dictionary = {
        "version": "0.31",
        "veilleurs_vs001": {"marker": "legacy", "watchers_active": true}
    }
    var migrated_legacy: Dictionary = SaveManager.call("_migrate", legacy_payload)
    if migrated_legacy.is_empty():
        _fail("legacy 0.31 payload was rejected")
        return
    if migrated_legacy.has("veilleurs_vs001"):
        _fail("legacy key survived migration")
        return
    var migrated_value: Dictionary = migrated_legacy.get("veilleurs", {})
    if str(migrated_value.get("marker", "")) != "legacy":
        _fail("legacy payload was not copied to canonical veilleurs key")
        return

    var dual_payload: Dictionary = {
        "version": "0.31",
        "veilleurs": {"marker": "canonical"},
        "veilleurs_vs001": {"marker": "legacy"}
    }
    var migrated_dual: Dictionary = SaveManager.call("_migrate", dual_payload)
    var canonical_value: Dictionary = migrated_dual.get("veilleurs", {})
    if str(canonical_value.get("marker", "")) != "canonical":
        _fail("canonical veilleurs payload did not win over legacy fallback")
        return
    if migrated_dual.has("veilleurs_vs001"):
        _fail("legacy key survived dual-key migration")
        return

    print("VEILLEURS_SAVE_KEY_MIGRATION_OK")
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("VEILLEURS_SAVE_KEY_MIGRATION_FAILED: %s" % message)
    get_tree().quit(1)
