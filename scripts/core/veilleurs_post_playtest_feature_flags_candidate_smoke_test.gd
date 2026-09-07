extends Node

const FLAGS_SCRIPT := preload("res://scripts/core/veilleurs_post_playtest_feature_flags_candidate.gd")

func _ready() -> void:
    var flags := FLAGS_SCRIPT.new() as VeilleursPostPlaytestFeatureFlagsCandidate
    var report := flags.validation_report()
    assert(bool(report.get("ok", false)))
    assert(bool(report.get("all_disabled", false)))
    assert(not flags.enabled("veilleurs.post_playtest.enabled"))
    assert(not flags.enabled("veilleurs.post_playtest.refuge_memory"))
    assert(not flags.enabled("unknown.flag"))

    var unauthorized := flags.configure_overrides({
        "veilleurs.post_playtest.enabled": true,
        "veilleurs.post_playtest.refuge_memory": true
    }, false)
    assert(not bool(unauthorized.get("ok", true)))
    assert(bool((unauthorized.get("snapshot", {}) as Dictionary).get("all_disabled", false)))

    var authorized := flags.configure_overrides({
        "veilleurs.post_playtest.enabled": true,
        "veilleurs.post_playtest.refuge_memory": true,
        "veilleurs.post_playtest.archive_projection": true
    }, true)
    assert(bool(authorized.get("ok", false)))
    assert(flags.enabled("veilleurs.post_playtest.enabled"))
    assert(flags.enabled("veilleurs.post_playtest.refuge_memory"))
    assert(flags.enabled("veilleurs.post_playtest.archive_projection"))
    assert(not flags.enabled("veilleurs.post_playtest.remanence_projection"))
    assert(not flags.enabled("veilleurs.post_playtest.multi_act_chains"))

    flags.reset()
    assert(bool(flags.snapshot().get("all_disabled", false)))
    print("VEILLEURS_POST_PLAYTEST_FEATURE_FLAGS_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)
