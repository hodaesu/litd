import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARALLEL = ROOT / "data" / "veilleurs" / "parallel_content"


def load(name: str):
    return json.loads((PARALLEL / name).read_text(encoding="utf-8"))


def test_feature_flags_are_all_off_and_developer_gated():
    data = load("post_playtest_feature_flags_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert data["master_flag"]["default"] is False
    assert data["master_flag"]["explicit_developer_activation_required"] is True
    assert data["master_flag"]["may_not_be_enabled_by_save_migration"] is True
    flags = data["flags"]
    assert len(flags) == 7
    assert all(flag["default"] is False for flag in flags)
    ids = {flag["id"] for flag in flags}
    assert ids == {
        "veilleurs.post_playtest.refuge_memory",
        "veilleurs.post_playtest.archive_projection",
        "veilleurs.post_playtest.remanence_projection",
        "veilleurs.post_playtest.auxiliary_reactions",
        "veilleurs.post_playtest.regional_echoes",
        "veilleurs.post_playtest.multi_act_chains",
        "veilleurs.post_playtest.expedition_alterations",
    }
    assert data["evaluation"]["default_resolution"] == "all_false"
    assert data["guardrails"]["all_flags_false_before_pc_playtest"] is True
    assert data["guardrails"]["no_autoload_activation"] is True


def test_feature_flag_candidate_exists_but_is_not_active_runtime():
    script = ROOT / "scripts" / "core" / "veilleurs_post_playtest_feature_flags_candidate.gd"
    smoke = ROOT / "scenes" / "tests" / "veilleurs_post_playtest_feature_flags_candidate_smoke.tscn"
    assert script.exists()
    assert smoke.exists()
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert "VeilleursPostPlaytestFeatureFlagsCandidate" not in project_text
    assert "veilleurs_post_playtest_feature_flags_candidate.gd" not in project_text
    active_paths = [
        ROOT / "data" / "veilleurs" / "content_foundation_v2.json",
        ROOT / "data" / "veilleurs" / "encounter_generation_contract_v1.json",
        ROOT / "data" / "veilleurs" / "archives_refuge_ui_contract_v1.json",
    ]
    forbidden = [
        "post_playtest_feature_flags_v1.json",
        "veilleurs_post_playtest_feature_flags_candidate.gd",
        "veilleurs.post_playtest.enabled",
    ]
    for path in active_paths:
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text


def test_migration_corpus_covers_edge_cases_without_auto_activation():
    data = load("refuge_memory_migration_corpus_v1.json")
    assert data["enabled_by_default"] is False
    assert len(data["cases"]) == 16
    ids = {case["id"] for case in data["cases"]}
    assert {
        "migration.missing_root",
        "migration.unversioned_empty",
        "migration.v1_empty_roundtrip",
        "migration.valid_queued_order",
        "migration.orphan_queue_entry_dropped",
        "migration.queue_nonqueued_record_dropped",
        "migration.valid_surfaced_preserved",
        "migration.invalid_surfaced_reference_cleared",
        "migration.invalid_state_isolated",
        "migration.malformed_record_isolated",
        "migration.resolved_never_reopened",
        "migration.expired_never_reopened",
        "migration.future_schema_rejected",
        "migration.surface_limit_floor",
        "migration.cooldowns_preserved",
        "migration.idempotent_v0_then_v1",
    } == ids
    rules = data["rules"]
    assert rules["migration_must_be_idempotent"] is True
    assert rules["invalid_record_does_not_invalidate_whole_save"] is True
    assert rules["future_schema_is_rejected_without_mutation"] is True
    assert rules["feature_flags_must_not_be_enabled_by_migration"] is True
    assert rules["full_scene_snapshot_forbidden"] is True


def test_arbitration_variants_are_candidates_not_active_balance():
    data = load("refuge_memory_arbitration_variants_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert data["rules"]["no_profile_is_canon"] is True
    assert data["rules"]["active_profile"] == "none"
    assert len(data["profiles"]) == 6
    assert {p["id"] for p in data["profiles"]} == {
        "arb.conservative",
        "arb.baseline_candidate",
        "arb.relationship_forward",
        "arb.archive_forward",
        "arb.low_cooldown",
        "arb.high_pressure_only",
    }
    baseline = next(p for p in data["profiles"] if p["id"] == "arb.baseline_candidate")
    assert baseline["surface_limit"] == 2
    assert baseline["source_cooldown_expeditions"] == 2
    assert baseline["family_soft_cooldown_expeditions"] == 1
    assert data["decision_rules"]["do_not_select_from_single_session"] is True
    assert data["decision_rules"]["record_seed_build_and_save_snapshot"] is True


def test_archive_projection_covers_exactly_all_eight_multi_act_chains():
    source = load("multi_act_consequence_chains_v1.json")
    projection = load("multi_act_archive_projection_v1.json")
    assert projection["enabled_by_default"] is False
    assert projection["runtime_wiring"] == "none"
    source_by_id = {chain["id"]: chain for chain in source["chains"]}
    projection_by_id = {chain["chain_id"]: chain for chain in projection["chains"]}
    assert len(source_by_id) == 8
    assert projection_by_id.keys() == source_by_id.keys()
    rules = projection["rules"]
    assert rules["projection_requires_completed_source_stage"] is True
    assert rules["knowledge_upgrade_requires_new_supporting_observation"] is True
    assert rules["archive_projection_does_not_create_enemy_truth"] is True
    assert rules["remanence_projection_requires_same_entity_reference"] is True

    for chain_id, source_chain in source_by_id.items():
        projected = projection_by_id[chain_id]
        assert len(projected["stages"]) == len(source_chain["stages"])
        for index, source_stage in enumerate(source_chain["stages"], start=1):
            stage = projected["stages"][index - 1]
            assert stage["stage"] == index
            assert stage["source"] == source_stage["source"]
            assert stage["requires_write"] in source_stage["writes"]
            assert stage["project_to"]
            assert set(stage["project_to"]) <= set(projection["archive_sections"])
            assert stage["entry_kind"]
            assert stage["knowledge_effect"]
            assert stage["display_rule"]


def test_projection_payload_forbids_spoilers_hidden_power_and_species_memory():
    data = load("multi_act_archive_projection_v1.json")
    forbidden = set(data["projection_payload"]["forbidden_fields"])
    assert {
        "hidden_absolute_truth",
        "unseen_boss_phase",
        "synthetic_nemesis_spawn",
        "hidden_stat_bonus",
        "species_shared_memory",
    } <= forbidden
    assert data["rules"]["unseen_boss_phase_hidden"] is True
    assert data["rules"]["stored_knowledge_never_erased"] is True
