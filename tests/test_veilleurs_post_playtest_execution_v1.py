import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARALLEL = ROOT / "data" / "veilleurs" / "parallel_content"


def load(name: str):
    return json.loads((PARALLEL / name).read_text(encoding="utf-8"))


def test_refuge_execution_contract_is_inactive_and_history_gated():
    data = load("refuge_chain_execution_contract_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert data["guardrails"]["requires_written_lived_history"] is True
    assert data["guardrails"]["random_callback_without_source_history_forbidden"] is True
    assert data["guardrails"]["active_playtest_wiring_forbidden"] is True
    assert data["guardrails"]["persistent_injury_reset_forbidden"] is True
    assert data["guardrails"]["boss_recruitment_forbidden"] is True


def test_refuge_memory_state_machine_has_no_illegal_shortcuts():
    data = load("refuge_chain_execution_contract_v1.json")
    machine = data["state_machine"]
    assert machine["initial"] == "DORMANT"
    assert machine["states"] == [
        "DORMANT", "ELIGIBLE", "QUEUED", "SURFACED", "RESOLVED", "EXPIRED", "RETIRED"
    ]
    transitions = {(item["from"], item["to"]) for item in machine["transitions"]}
    assert ("DORMANT", "ELIGIBLE") in transitions
    assert ("ELIGIBLE", "QUEUED") in transitions
    assert ("QUEUED", "SURFACED") in transitions
    assert ("SURFACED", "RESOLVED") in transitions
    assert ("DORMANT", "SURFACED") not in transitions
    assert ("ELIGIBLE", "RESOLVED") not in transitions
    assert "DORMANT->SURFACED" in machine["forbidden_transitions"]
    assert "RETIRED->SURFACED" in machine["forbidden_transitions"]


def test_refuge_execution_is_deterministic_and_not_scene_snapshot_based():
    data = load("refuge_chain_execution_contract_v1.json")
    arbitration = data["candidate_arbitration_policy"]
    save = data["save_contract"]
    assert arbitration["reroll_on_reload"] is False
    assert arbitration["tie_breaker"].startswith("stable_hash(")
    assert arbitration["maximum_callbacks_surfaced_per_refuge_return"] >= 1
    assert save["serialize_memory_records_not_scene_nodes"] is True
    assert save["seed_inputs_required_for_reproducibility"] is True
    assert "full_scene_snapshot" in data["memory_record_schema"]["forbidden_fields"]


def test_regional_echoes_cover_exact_source_events_and_both_choices():
    source = load("regional_event_candidates_acts_ii_v_v1.json")
    echoes = load("regional_event_choice_echoes_v1.json")
    source_by_id = {item["id"]: item for item in source["events"]}
    echo_by_id = {item["source_event_id"]: item for item in echoes["events"]}
    assert len(source_by_id) == 16
    assert len(echo_by_id) == 16
    assert set(echo_by_id) == set(source_by_id)
    for event_id, src in source_by_id.items():
        expected_choices = {src["choice_a"]["id"], src["choice_b"]["id"]}
        actual_choices = set(echo_by_id[event_id]["choice_echoes"])
        assert actual_choices == expected_choices


def test_regional_echoes_are_history_gated_and_epistemically_bounded():
    data = load("regional_event_choice_echoes_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert data["rules"]["follow_up_requires_written_history"] is True
    assert data["rules"]["absolute_truth_from_choice_forbidden"] is True
    assert data["rules"]["future_boss_phase_spoiler_forbidden"] is True
    assert data["rules"]["stored_knowledge_erasure_forbidden"] is True
    for event in data["events"]:
        for echo in event["choice_echoes"].values():
            assert echo["window"] in data["temporal_windows"]
            assert echo["requires"]
            assert echo["writes"]
            assert echo["possible_outcomes"]
            assert echo["reaction_priority"]


def test_active_playtest_contracts_do_not_reference_execution_layer():
    forbidden = [
        "refuge_chain_execution_contract_v1.json",
        "regional_event_choice_echoes_v1.json",
    ]
    active_paths = [
        ROOT / "data" / "veilleurs" / "content_foundation_v2.json",
        ROOT / "data" / "veilleurs" / "encounter_generation_contract_v1.json",
        ROOT / "data" / "veilleurs" / "archives_refuge_ui_contract_v1.json",
    ]
    for path in active_paths:
        text = path.read_text(encoding="utf-8")
        for name in forbidden:
            assert name not in text
