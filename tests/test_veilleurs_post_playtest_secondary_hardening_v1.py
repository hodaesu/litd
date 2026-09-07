import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PARALLEL = ROOT / "data" / "veilleurs" / "parallel_content"


def load(name: str):
    return json.loads((PARALLEL / name).read_text(encoding="utf-8"))


def test_feature_flag_rollback_scenarios_preserve_history_instead_of_reversing_world_state():
    data = load("post_playtest_feature_flag_rollback_scenarios_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert len(data["scenarios"]) == 8
    assert len({item["id"] for item in data["scenarios"]}) == 8
    rules = data["rules"]
    assert rules["rollback_disables_execution_not_history"] is True
    assert rules["rollback_must_not_delete_memory_records"] is True
    assert rules["rollback_must_not_reroll_memory_ids"] is True
    assert rules["rollback_must_not_change_deterministic_tiebreak"] is True
    assert rules["rollback_must_not_downgrade_archive_knowledge"] is True
    assert rules["rollback_must_not_reverse_real_injuries"] is True
    assert rules["rollback_must_not_remove_world_scars"] is True
    assert rules["rollback_must_not_demote_existing_remanence_rank"] is True
    assert rules["reenable_may_resume_only_from_persisted_history"] is True
    assert any(item["id"] == "rollback.reenable_same_build_same_history" for item in data["scenarios"])


def test_archive_visual_fixtures_cover_exactly_the_eight_multi_act_projections():
    projection = load("multi_act_archive_projection_v1.json")
    fixtures = load("multi_act_archive_visual_fixtures_v1.json")
    assert fixtures["enabled_by_default"] is False
    assert fixtures["runtime_wiring"] == "none"
    assert fixtures["rules"]["fixture_count"] == 8
    assert fixtures["rules"]["visual_fixture_may_not_upgrade_knowledge"] is True
    assert fixtures["rules"]["canonical_text_generation_forbidden"] is True
    assert fixtures["rules"]["touch_target_min_points"] >= 48
    assert fixtures["rules"]["long_press_required"] is False
    assert fixtures["rules"]["hover_required"] is False
    assert set(fixtures["profiles"]) == {"phone", "tablet", "desktop", "controller"}
    assert fixtures["profiles"]["controller"]["pointer_dependency"] is False

    projection_by_id = {item["chain_id"]: item for item in projection["chains"]}
    fixture_by_id = {item["chain_id"]: item for item in fixtures["fixtures"]}
    assert len(fixture_by_id) == 8
    assert set(fixture_by_id) == set(projection_by_id)

    valid_sections = set(projection["archive_sections"])
    for chain_id, fixture in fixture_by_id.items():
        source = projection_by_id[chain_id]
        assert fixture["summary_mode"] == source["summary_mode"]
        assert fixture["primary_sections"] == source["primary_sections"]
        assert fixture["knowledge_state_source"] == "PRESERVE_CURRENT_ARCHIVE_STATE"
        assert set(fixture["expected_visible_sections"]).issubset(valid_sections)
        assert len(fixture["cards"]) == len(source["stages"])
        source_stages = {item["stage"]: item for item in source["stages"]}
        for card in fixture["cards"]:
            stage = source_stages[card["stage"]]
            assert card["source"] == stage["source"]
            assert card["entry_kind"] == stage["entry_kind"]
            assert card["sections"] == stage["project_to"]
        assert fixture["visual_assertions"]


def test_secondary_hardening_remains_absent_from_active_playtest_contracts():
    refs = [
        "post_playtest_feature_flag_rollback_scenarios_v1.json",
        "multi_act_archive_visual_fixtures_v1.json",
        "veilleurs_refuge_memory_migration_audit_candidate.gd",
    ]
    active_paths = [
        ROOT / "data" / "veilleurs" / "content_foundation_v2.json",
        ROOT / "data" / "veilleurs" / "encounter_generation_contract_v1.json",
        ROOT / "data" / "veilleurs" / "archives_refuge_ui_contract_v1.json",
        ROOT / "data" / "veilleurs" / "vs001_ui_input_contract.json",
    ]
    for path in active_paths:
        text = path.read_text(encoding="utf-8")
        for ref in refs:
            assert ref not in text
