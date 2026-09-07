extends Node

const SERVICE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_service_candidate.gd")
const CORPUS_PATH := "res://data/veilleurs/parallel_content/refuge_memory_migration_corpus_v1.json"

func _ready() -> void:
    var corpus := _load_dictionary(CORPUS_PATH)
    var cases: Array = corpus.get("cases", [])
    assert(cases.size() == 16)
    var executed := 0
    for value: Variant in cases:
        assert(value is Dictionary)
        var case_data: Dictionary = value
        _run_case(case_data)
        executed += 1
    assert(executed == 16)
    print("VEILLEURS_REFUGE_MEMORY_MIGRATION_CORPUS_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)

func _run_case(case_data: Dictionary) -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    var input: Dictionary = (case_data.get("input", {}) as Dictionary).duplicate(true)
    var expected: Dictionary = (case_data.get("expected", {}) as Dictionary).duplicate(true)
    var case_id := str(case_data.get("id", ""))

    if case_id == "migration.idempotent_v0_then_v1":
        var first := service.deserialize(input)
        assert(bool(first.get("ok", false)))
        assert(bool(first.get("migrated", false)))
        var saved := service.serialize()
        var ids_before: Array = (saved.get("records", {}) as Dictionary).keys()
        ids_before.sort()
        var queue_before: Array = (saved.get("queue", []) as Array).duplicate()
        var seed_before := int(saved.get("scheduler_seed", 0))
        var second := service.deserialize(saved)
        assert(bool(second.get("ok", false)))
        assert(not bool(second.get("migrated", true)))
        var saved_again := service.serialize()
        var ids_after: Array = (saved_again.get("records", {}) as Dictionary).keys()
        ids_after.sort()
        assert(ids_after == ids_before)
        assert((saved_again.get("queue", []) as Array) == queue_before)
        assert(int(saved_again.get("scheduler_seed", 0)) == seed_before)
        return

    var before := service.serialize()
    var result := service.deserialize(input)
    assert(bool(result.get("ok", false)) == bool(expected.get("ok", false)), "%s ok mismatch" % case_id)
    if expected.has("reason"):
        assert(str(result.get("reason", "")) == str(expected.get("reason", "")), "%s reason mismatch" % case_id)
    for key: String in ["migrated", "from", "to", "incoming", "supported", "record_count"]:
        if expected.has(key):
            assert(result.get(key) == expected.get(key), "%s result mismatch: %s" % [case_id, key])

    if not bool(result.get("ok", false)):
        if expected.get("mutate_save", true) == false:
            assert(service.serialize() == before, "%s must not mutate state on rejection" % case_id)
        return

    var saved := service.serialize()
    var snapshot := service.snapshot()
    if expected.has("queue"):
        assert((saved.get("queue", []) as Array) == (expected.get("queue", []) as Array), "%s queue mismatch" % case_id)
    if expected.has("surfaced_memory_id"):
        assert(str(saved.get("surfaced_memory_id", "")) == str(expected.get("surfaced_memory_id", "")), "%s surfaced mismatch" % case_id)
    if expected.has("surfaced_count_this_return"):
        assert(int(saved.get("surfaced_count_this_return", -1)) == int(expected.get("surfaced_count_this_return", -2)), "%s surfaced count mismatch" % case_id)
    if expected.has("current_surface_limit"):
        assert(int(saved.get("current_surface_limit", 0)) == int(expected.get("current_surface_limit", -1)), "%s surface limit mismatch" % case_id)
    if expected.has("scheduler_seed"):
        assert(int(saved.get("scheduler_seed", 0)) == int(expected.get("scheduler_seed", -1)), "%s seed mismatch" % case_id)
    if expected.has("expedition_index"):
        assert(int(saved.get("expedition_index", 0)) == int(expected.get("expedition_index", -1)), "%s expedition mismatch" % case_id)
    if expected.has("source_cooldowns"):
        assert((saved.get("source_cooldowns", {}) as Dictionary) == (expected.get("source_cooldowns", {}) as Dictionary), "%s source cooldown mismatch" % case_id)
    if expected.has("family_cooldowns"):
        assert((saved.get("family_cooldowns", {}) as Dictionary) == (expected.get("family_cooldowns", {}) as Dictionary), "%s family cooldown mismatch" % case_id)
    if expected.has("contains"):
        var records: Dictionary = saved.get("records", {})
        for value: Variant in expected.get("contains", []):
            assert(records.has(str(value)), "%s missing record %s" % [case_id, str(value)])
    if expected.has("excludes"):
        var records: Dictionary = saved.get("records", {})
        for value: Variant in expected.get("excludes", []):
            assert(not records.has(str(value)), "%s unexpected record %s" % [case_id, str(value)])
    if expected.has("states"):
        var records: Dictionary = saved.get("records", {})
        var states: Dictionary = expected.get("states", {})
        for key_value: Variant in states.keys():
            var memory_id := str(key_value)
            assert(records.has(memory_id))
            assert(str((records[memory_id] as Dictionary).get("state", "")) == str(states.get(key_value, "")), "%s state mismatch %s" % [case_id, memory_id])
    if expected.has("state"):
        var records: Dictionary = saved.get("records", {})
        assert(records.has("rmem:a"))
        assert(str((records["rmem:a"] as Dictionary).get("state", "")) == str(expected.get("state", "")), "%s state mismatch" % case_id)
    if expected.has("reroll_forbidden") and bool(expected.get("reroll_forbidden", false)):
        var queue_before: Array = (saved.get("queue", []) as Array).duplicate()
        var reload_result := service.deserialize(saved)
        assert(bool(reload_result.get("ok", false)))
        assert((service.serialize().get("queue", []) as Array) == queue_before, "%s reload changed queue" % case_id)
    if expected.get("record_count", null) != null:
        assert(int(snapshot.get("record_count", -1)) == int(expected.get("record_count", -2)), "%s snapshot count mismatch" % case_id)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
