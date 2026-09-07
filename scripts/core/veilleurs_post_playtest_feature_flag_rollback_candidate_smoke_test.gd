extends Node

const FLAGS_SCRIPT := preload("res://scripts/core/veilleurs_post_playtest_feature_flags_candidate.gd")
const MEMORY_SCRIPT := preload("res://scripts/core/veilleurs_refuge_memory_service_candidate.gd")
const SCENARIOS_PATH := "res://data/veilleurs/parallel_content/post_playtest_feature_flag_rollback_scenarios_v1.json"

func _ready() -> void:
    var flags := FLAGS_SCRIPT.new() as VeilleursPostPlaytestFeatureFlagsCandidate
    var memory := MEMORY_SCRIPT.new() as VeilleursRefugeMemoryServiceCandidate
    var scenarios := _load_dictionary(SCENARIOS_PATH)
    assert(bool(scenarios.get("enabled_by_default", true)) == false)
    assert((scenarios.get("scenarios", []) as Array).size() == 8)
    var rules: Dictionary = scenarios.get("rules", {})
    assert(bool(rules.get("rollback_must_not_delete_memory_records", false)))
    assert(bool(rules.get("rollback_must_not_reroll_memory_ids", false)))
    assert(bool(rules.get("reenable_may_resume_only_from_persisted_history", false)))

    var enable_result := flags.configure_overrides({
        "veilleurs.post_playtest.enabled": true,
        "veilleurs.post_playtest.refuge_memory": true,
        "veilleurs.post_playtest.archive_projection": true
    }, true)
    assert(bool(enable_result.get("ok", false)))
    assert(flags.enabled("veilleurs.post_playtest.refuge_memory"))
    assert(flags.enabled("veilleurs.post_playtest.archive_projection"))

    var validation := memory.configure(731903, 8)
    assert(bool(validation.get("ok", false)))
    var recorded := memory.record_source_choice(
        "ref.cohabitation.shared_watch",
        "keep_pair",
        {"shared_history": true, "history_ref": "rollback-smoke-history"},
        ["nayra_orun", "tarek_senn"],
        {"memory_key": "rollback-smoke-shared-watch"}
    )
    assert(bool(recorded.get("ok", false)))
    var recorded_memory: Dictionary = recorded.get("memory", {})
    var memory_id := str(recorded_memory.get("memory_id", ""))
    var tiebreak := str(recorded_memory.get("deterministic_tiebreak", ""))
    assert(not memory_id.is_empty())
    assert(not tiebreak.is_empty())

    var context := {
        "present_entities": ["nayra_orun", "tarek_senn"],
        "flags": ["same_pair_present"]
    }
    memory.advance_expedition(context)
    var queued := memory.queue_for_return(context)
    assert(queued.size() >= 1)
    var surfaced := memory.surface_next()
    assert(bool(surfaced.get("ok", false)))
    var resolved := memory.resolve_memory(memory_id, {
        "entity_id": "nayra_orun",
        "shared_lived_history": false,
        "resolution_kind": "rollback_smoke"
    })
    assert(bool(resolved.get("ok", false)))

    var history_before_rollback: Dictionary = memory.serialize()
    var record_before: Dictionary = (history_before_rollback.get("records", {}) as Dictionary).get(memory_id, {})
    assert(str(record_before.get("state", "")) == "RESOLVED")

    var rollback := flags.configure_overrides({}, true)
    assert(bool(rollback.get("ok", false)))
    assert(bool((rollback.get("snapshot", {}) as Dictionary).get("all_disabled", false)))
    assert(not flags.enabled("veilleurs.post_playtest.refuge_memory"))
    assert(not flags.enabled("veilleurs.post_playtest.archive_projection"))

    var history_while_disabled: Dictionary = memory.serialize()
    assert(history_while_disabled == history_before_rollback, "feature rollback must not mutate persisted history")
    var disabled_record: Dictionary = (history_while_disabled.get("records", {}) as Dictionary).get(memory_id, {})
    assert(str(disabled_record.get("deterministic_tiebreak", "")) == tiebreak)

    var reenable := flags.configure_overrides({
        "veilleurs.post_playtest.enabled": true,
        "veilleurs.post_playtest.refuge_memory": true
    }, true)
    assert(bool(reenable.get("ok", false)))
    assert(flags.enabled("veilleurs.post_playtest.refuge_memory"))
    var history_after_reenable: Dictionary = memory.serialize()
    assert(history_after_reenable == history_before_rollback, "reenable must resume from the same persisted history")
    assert((history_after_reenable.get("records", {}) as Dictionary).size() == 1)
    var reenabled_record: Dictionary = (history_after_reenable.get("records", {}) as Dictionary).get(memory_id, {})
    assert(str(reenabled_record.get("memory_id", "")) == memory_id)
    assert(str(reenabled_record.get("deterministic_tiebreak", "")) == tiebreak)

    print("VEILLEURS_POST_PLAYTEST_FEATURE_FLAG_ROLLBACK_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
