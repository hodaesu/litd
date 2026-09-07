import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARALLEL = ROOT / "data" / "veilleurs" / "parallel_content"


def load(name: str):
    return json.loads((PARALLEL / name).read_text(encoding="utf-8"))


def test_refuge_chains_cover_all_24_templates_exactly():
    templates = load("refuge_event_templates_v1.json")
    chains = load("refuge_event_chains_v1.json")
    source_ids = {item["id"] for item in templates["templates"]}
    chain_ids = [item["source_event_id"] for item in chains["chains"]]
    assert len(source_ids) == 24
    assert len(chain_ids) == 24
    assert len(set(chain_ids)) == 24
    assert set(chain_ids) == source_ids
    assert chains["enabled_by_default"] is False
    assert chains["runtime_wiring"] == "none"


def test_each_refuge_chain_has_two_choice_echoes_and_history_gate():
    templates = load("refuge_event_templates_v1.json")
    chains = load("refuge_event_chains_v1.json")
    choice_ids = {item["id"]: {choice["id"] for choice in item["choices"]} for item in templates["templates"]}
    for chain in chains["chains"]:
        assert set(chain["echoes"]) == choice_ids[chain["source_event_id"]]
        for echo in chain["echoes"].values():
            assert echo["window"] in chains["temporal_windows"]
            assert echo["requires"]
            assert echo["writes"]
            assert echo["reaction_priority"]
            assert echo["archive_link"]


def test_watcher_profiles_are_exact_quartet():
    chains = load("refuge_event_chains_v1.json")
    assert set(chains["watcher_reaction_profiles"]) == {
        "nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"
    }


def test_cross_reaction_matrix_covers_all_12_families_and_quartet():
    templates = load("refuge_event_templates_v1.json")
    matrix = load("refuge_cross_reaction_matrix_v1.json")
    expected_families = {item["family"] for item in templates["templates"]}
    assert len(matrix["families"]) == 12
    assert {item["family"] for item in matrix["families"]} == expected_families
    for item in matrix["families"]:
        assert set(item["watchers"]) == {"nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"}
        assert item["auxiliary_contexts"]
        assert item["writes"]
    assert matrix["rules"]["generic_species_personality_forbidden"] is True
    assert matrix["rules"]["no_new_canonical_dialogue"] is True


def test_regional_events_cover_acts_ii_to_v_four_each():
    data = load("regional_event_candidates_acts_ii_v_v1.json")
    assert data["enabled_by_default"] is False
    assert data["rules"]["events_are_not_canon_until_validated"] is True
    assert len(data["events"]) == 16
    counts = {act: 0 for act in ["II", "III", "IV", "V"]}
    for event in data["events"]:
        counts[event["act"]] += 1
        assert event["trigger"]
        assert event["choice_a"]["writes"]
        assert event["choice_b"]["writes"]
        assert event["future_echo"]
    assert counts == {"II": 4, "III": 4, "IV": 4, "V": 4}


def test_ux_copy_preserves_canonical_epistemic_states_and_forbidden_surfaces():
    data = load("ux_copy_fr_post_playtest_v1.json")
    s = data["strings"]
    assert [s[f"knowledge.state.{state}"] for state in ["UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"]] == [
        "Inconnu", "Soupçonné", "Observé", "Confirmé", "Compris"
    ]
    assert data["enabled_by_default"] is False
    assert data["rules"]["capture_percentage_forbidden"] is True
    assert data["rules"]["future_boss_phase_spoilers_forbidden"] is True
    joined = " ".join(s.values()).lower()
    assert "% de capture" not in joined
    assert "pourcentage de capture" not in joined


def test_diagnosis_matrix_is_evidence_gated_and_non_mutating():
    data = load("playtest_diagnosis_matrix_v1.json")
    assert data["enabled_by_default"] is False
    assert data["rules"]["single_session_never_sufficient_for_core_rule_change"] is True
    assert data["rules"]["active_values_are_not_modified_by_this_file"] is True
    assert len(data["cases"]) >= 24
    ids = [case["id"] for case in data["cases"]]
    assert len(ids) == len(set(ids))
    for case in data["cases"]:
        assert case["observe"]
        assert case["pattern"]
        assert case["diagnoses"]
        assert case["candidate_changes"]
        assert case["do_not_conclude"]


def test_active_playtest_contracts_do_not_reference_new_parallel_files():
    forbidden = [
        "refuge_event_chains_v1.json",
        "refuge_cross_reaction_matrix_v1.json",
        "regional_event_candidates_acts_ii_v_v1.json",
        "ux_copy_fr_post_playtest_v1.json",
        "playtest_diagnosis_matrix_v1.json",
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
