import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARALLEL = ROOT / "data" / "veilleurs" / "parallel_content"


def load(name: str):
    return json.loads((PARALLEL / name).read_text(encoding="utf-8"))


def test_refuge_memory_service_contract_is_complete_and_inactive():
    data = load("refuge_memory_service_contract_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert data["states"] == [
        "DORMANT", "ELIGIBLE", "QUEUED", "SURFACED", "RESOLVED", "EXPIRED", "RETIRED"
    ]
    methods = {entry["method"] for entry in data["public_api"]}
    assert {
        "configure", "record_source_choice", "record_regional_choice", "advance_expedition",
        "collect_eligible", "queue_for_return", "surface_next", "resolve_memory",
        "confirm_projection_committed", "expire_memory", "serialize", "deserialize",
        "snapshot", "reset"
    } <= methods
    signals = {entry["name"] for entry in data["signals"]}
    assert {
        "memory_recorded", "memory_became_eligible", "memory_queued", "memory_surfaced",
        "memory_resolved", "memory_expired", "scheduler_changed",
        "archive_hook_requested", "remanence_hook_requested"
    } == signals
    assert data["arbitration"]["reload_reroll_forbidden"] is True
    assert data["arbitration"]["queued_order_persisted"] is True
    assert data["side_effect_boundary"]["archive_truth_must_be_applied_by_existing_runtime"] is True
    assert data["side_effect_boundary"]["remanence_adaptation_must_be_applied_by_existing_policy"] is True
    assert data["active_playtest_isolation"]["autoload_registration_forbidden_before_pc_validation"] is True


def test_refuge_memory_save_schema_preserves_queue_and_rejects_future_schema():
    data = load("refuge_memory_save_schema_v1.json")
    assert data["root_key"] == "veilleurs_refuge_memory"
    assert data["schema_version"] == 1
    rules = data["serialization_rules"]
    assert rules["full_scene_snapshot_forbidden"] is True
    assert rules["node_path_storage_forbidden"] is True
    assert rules["queued_order_must_persist"] is True
    assert rules["tiebreak_key_must_persist"] is True
    assert rules["refuge_and_regional_memories_share_one_records_dictionary"] is True
    assert data["migration"]["missing_root_key"]["action"] == "initialize_empty_v1"
    assert data["migration"]["future_schema"]["action"] == "reject_read_only_with_report"
    defaults = data["migration"]["schema_0_or_unversioned_candidate"]["defaults"]
    assert defaults["queue"] == []
    assert defaults["surfaced_memory_id"] == ""
    assert defaults["current_surface_limit"] == 2


def test_refuge_memory_fixtures_and_collisions_are_deterministic_and_cover_edge_cases():
    fixtures = load("refuge_memory_fixtures_v1.json")
    collisions = load("refuge_memory_collision_scenarios_v1.json")
    assert fixtures["enabled_by_default"] is False
    assert len(fixtures["fixtures"]) == 8
    fixture_ids = {item["id"] for item in fixtures["fixtures"]}
    assert {
        "fixture.no_history_no_memory",
        "fixture.short_echo_becomes_eligible",
        "fixture.absent_participant_blocks_without_expiring",
        "fixture.window_expiry",
        "fixture.queue_persists_reload",
        "fixture.crisis_outweighs_routine",
        "fixture.same_source_cooldown",
        "fixture.regional_echo_preserves_uncertainty",
    } == fixture_ids
    assert len(collisions["scenarios"]) == 8
    assert collisions["rules"]["selection_must_be_deterministic"] is True
    assert collisions["rules"]["reload_reroll_forbidden"] is True
    assert collisions["rules"]["surface_limit_is_canon"] is False


def test_auxiliary_reaction_contract_is_individual_not_species_personality():
    data = load("auxiliary_individual_reaction_contract_v1.json")
    assert data["enabled_by_default"] is False
    identity = data["identity_requirements"]
    assert identity["stable_entity_id_required"] is True
    assert identity["species_id_is_context_not_personality"] is True
    assert identity["persistent_injuries_are_facts_not_character_traits"] is True
    gate = data["reaction_gate"]
    assert gate["species_membership_alone_never_sufficient"] is True
    assert gate["same_species_does_not_share_memory"] is True
    assert gate["diagnosis_or_fixed_personality_label_forbidden"] is True
    assert gate["reaction_text_generation_from_species_archetype_forbidden"] is True
    assert len(data["reaction_dimensions"]) == 9
    assert data["selection"]["random_selection_forbidden_when_evidence_differs"] is True


def test_multi_act_consequence_chains_are_optional_history_not_hidden_power():
    data = load("multi_act_consequence_chains_v1.json")
    assert data["enabled_by_default"] is False
    assert len(data["chains"]) == 8
    rules = data["rules"]
    assert rules["skipping_a_stage_must_not_block_campaign_progress"] is True
    assert rules["choices_may_change_context_not_enemy_truth"] is True
    assert rules["no_hidden_stat_bonus"] is True
    assert rules["no_boss_phase_spoiler"] is True
    assert rules["knowledge_upgrade_requires_new_evidence"] is True
    for chain in data["chains"]:
        assert len(chain["stages"]) >= 3
        assert chain["payoff"]
        for stage in chain["stages"]:
            assert stage["source"]
            assert stage["writes"]
    assert data["save_projection"]["do_not_store_scene_snapshot"] is True
    assert data["save_projection"]["chain_can_remain_incomplete_forever"] is True


def test_candidate_scripts_exist_but_are_not_active_autoloads_or_contract_dependencies():
    service_path = ROOT / "scripts" / "core" / "veilleurs_refuge_memory_service_candidate.gd"
    resolver_path = ROOT / "scripts" / "core" / "veilleurs_auxiliary_reaction_resolver_candidate.gd"
    assert service_path.exists()
    assert resolver_path.exists()
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert "VeilleursRefugeMemoryServiceCandidate" not in project_text
    assert "veilleurs_refuge_memory_service_candidate.gd" not in project_text
    assert "VeilleursAuxiliaryReactionResolverCandidate" not in project_text
    assert "veilleurs_auxiliary_reaction_resolver_candidate.gd" not in project_text

    forbidden = [
        "refuge_memory_service_contract_v1.json",
        "refuge_memory_save_schema_v1.json",
        "refuge_memory_fixtures_v1.json",
        "refuge_memory_collision_scenarios_v1.json",
        "auxiliary_individual_reaction_contract_v1.json",
        "multi_act_consequence_chains_v1.json",
        "veilleurs_refuge_memory_service_candidate.gd",
        "veilleurs_auxiliary_reaction_resolver_candidate.gd",
    ]
    active_paths = [
        ROOT / "data" / "veilleurs" / "content_foundation_v2.json",
        ROOT / "data" / "veilleurs" / "encounter_generation_contract_v1.json",
        ROOT / "data" / "veilleurs" / "archives_refuge_ui_contract_v1.json",
    ]
    for path in active_paths:
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text


def test_parallel_candidate_smokes_are_present_without_being_game_runtime_scenes():
    workflow = (ROOT / ".github" / "workflows" / "remanence-smoke.yml").read_text(encoding="utf-8")
    assert "veilleurs_refuge_memory_service_candidate_smoke.tscn" in workflow
    assert "veilleurs_auxiliary_reaction_resolver_candidate_smoke.tscn" in workflow
    assert (ROOT / "scenes" / "tests" / "veilleurs_refuge_memory_service_candidate_smoke.tscn").exists()
    assert (ROOT / "scenes" / "tests" / "veilleurs_auxiliary_reaction_resolver_candidate_smoke.tscn").exists()
