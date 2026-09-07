extends Node

const PRESENTER_SCRIPT := preload("res://scripts/ui/veilleurs_multi_act_archive_visual_fixture_candidate.gd")

func _ready() -> void:
    var presenter := PRESENTER_SCRIPT.new() as VeilleursMultiActArchiveVisualFixtureCandidate
    var report := presenter.validation_report()
    assert(bool(report.get("ok", false)))
    var chain_ids: Array[String] = presenter.fixture_ids()
    assert(chain_ids.size() == 8)
    var profiles: Array[String] = ["phone", "tablet", "desktop", "controller"]
    for chain_id: String in chain_ids:
        for profile_name: String in profiles:
            var view := presenter.fixture_view(chain_id, profile_name, "OBSERVED")
            assert(bool(view.get("ok", false)))
            assert(str(view.get("knowledge_state", "")) == "OBSERVED")
            assert(not bool(view.get("knowledge_state_changed", true)))
            assert(not bool(view.get("canonical_text_generated", true)))
            assert(not (view.get("cards", []) as Array).is_empty())
            assert(not (view.get("visible_sections", []) as Array).is_empty())
            var layout: Dictionary = view.get("layout", {})
            if profile_name == "phone":
                assert(bool(layout.get("safe_area_required", false)))
                assert(int(layout.get("max_simultaneous_columns", 0)) == 1)
            elif profile_name == "controller":
                assert(not bool(layout.get("pointer_dependency", true)))
    var unknown_profile := presenter.fixture_view(chain_ids[0], "telepathic", "OBSERVED")
    assert(not bool(unknown_profile.get("ok", true)))
    print("VEILLEURS_MULTI_ACT_ARCHIVE_VISUAL_FIXTURE_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)
