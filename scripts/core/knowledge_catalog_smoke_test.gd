extends Node
const Runtime = preload("res://scripts/core/knowledge_catalog_runtime.gd")
var failures: Array[String] = []

func run() -> void:
    var runtime = Runtime.new()
    add_child(runtime)
    _check(runtime.reload_catalog(), "catalog must load")
    var summary := runtime.catalog_summary()
    _check(int(summary.get("profiles",0)) == 29, "29 profiles")
    _check(int(summary.get("facts",0)) == 29, "29 facts")
    _check(int(summary.get("unlocks",0)) == 29, "29 unlocks")
    var p := runtime.profile("ENT_ENEMY_GOULE_AFFAMEE")
    _check(str(p.get("hypothesis_id","")) == "HYP_GOULE_AFFAMEE_01", "canonical hypothesis")
    _check(runtime.entities_for_event("combat.target_selected").has("ENT_ENEMY_GOULE_AFFAMEE"), "target route")
    _check(runtime.extractors_for_entity("ENT_ENEMY_GOULE_AFFAMEE").size() == 2, "two extractors")
    _finish()

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("KNOWLEDGE_CATALOG_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    get_tree().quit(1)
