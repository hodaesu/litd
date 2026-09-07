import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
PARALLEL = DATA / "parallel_content"
CURRENT = DATA / "canonical_prepc_2026_09_03" / "current"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_detail_manifest_stays_inactive_and_preserves_canonical_invariants():
    manifest = load(PARALLEL / "post_playtest_detail_manifest_v1.json")
    assert manifest["enabled_by_default"] is False
    assert manifest["runtime_wiring"] == "none_until_explicit_post_playtest_decision"
    assert manifest["source_playtest_pr"] == 173
    assert manifest["source_playtest_commit"] == "0c905800ec21e646e9252f1c14430ed8ad36ada3"
    inv = manifest["canonical_invariants"]
    assert inv["knowledge_source_states"] == ["UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"]
    assert inv["knowledge_is_currency"] is False
    assert inv["capture_is_recruitment"] is False
    assert inv["injuries_reset_on_rally"] is False
    assert inv["bosses_recruitable"] is False
    assert inv["refuge_capacity_by_act"] == {"I": 4, "II": 6, "III": 8, "IV": 10, "V": 12}
    assert inv["max_memorial_enemies_per_encounter"] == 1
    assert inv["artificial_nemesis_spawn_forbidden"] is True
    assert inv["full_scene_snapshot_forbidden"] is True
    assert inv["act_i_numeric_rallying_conditions_must_not_be_invented"] is True


def test_refuge_has_exactly_two_lived_state_templates_for_each_canonical_family():
    data = load(PARALLEL / "refuge_event_templates_v1.json")
    expected = {
        "COHABITATION", "CONFLIT", "RAPPROCHEMENT", "SOUVENIR",
        "BESOIN_BIOLOGIQUE", "BESOIN_PSYCHOLOGIQUE", "TRANSFORMATION", "TRAVAIL",
        "DECOUVERTE", "DEPART", "CRISE", "POLITIQUE",
    }
    assert data["enabled_by_default"] is False
    assert set(data["canonical_families"]) == expected
    assert len(data["templates"]) == 24
    assert Counter(item["family"] for item in data["templates"]) == Counter({family: 2 for family in expected})
    assert len({item["id"] for item in data["templates"]}) == 24
    assert all(item["trigger"].get("all") or item["trigger"].get("any") for item in data["templates"])
    assert all(item["choices"] for item in data["templates"])
    assert set(axis for item in data["templates"] for axis in item["axes"]).issubset(set(data["relationship_axes"]))
    assert data["rules"]["persistent_injury_reset_forbidden"] is True
    assert data["rules"]["boss_recruitment_forbidden"] is True
    assert data["rules"]["numeric_balance_effects_deferred_until_playtest"] is True


def test_all_68_canonical_barks_are_covered_by_exact_trigger_routes():
    source = load(CURRENT / "barks_veilleurs.json")
    binding = load(PARALLEL / "narrative_trigger_binding_v1.json")
    contract = binding["bark_trigger_contract"]
    routed = {item["trigger"] for item in contract["generic_triggers"] + contract["act_entry_triggers"]}
    source_triggers = {item["Déclencheur"] for item in source["records"]}
    assert source["row_count"] == binding["sources"]["barks"]["row_count"] == 68
    assert len(source["records"]) == 68
    assert len({item["Clé"] for item in source["records"]}) == 68
    assert source_triggers == routed
    assert contract["expected_shape"] == {
        "watchers": 4,
        "generic_rows_per_watcher": 12,
        "act_entry_rows_per_watcher": 5,
        "total": 68,
    }
    assert binding["policy"]["canonical_text_rewrite_forbidden"] is True


def test_all_30_boss_dialogue_keys_are_bound_and_phase_scoped():
    source = load(CURRENT / "dialogues_boss.json")
    binding = load(PARALLEL / "narrative_trigger_binding_v1.json")
    records = binding["boss_dialogue_bindings"]
    source_keys = {item["Clé"] for item in source["records"]}
    assert source["row_count"] == binding["sources"]["boss_dialogues"]["row_count"] == 30
    assert len(records) == 30
    assert {item["key"] for item in records} == source_keys
    assert len({item["key"] for item in records}) == 30
    assert {item["boss_id"] for item in records} == {
        "ishar_gardien_du_passage", "orateur_sans_voix", "mere_des_veines",
        "porte_cendres_blanc", "le_copiste",
    }
    assert all(item["phase"] >= 1 for item in records)
    assert binding["boss_rules"]["bosses_recruitable"] is False
    assert binding["boss_rules"]["unseen_phase_delivery_forbidden"] is True


def test_all_16_canonical_remanence_rows_are_bound_without_inventing_truth():
    source = load(CURRENT / "remanence_ii_v.json")
    binding = load(PARALLEL / "narrative_trigger_binding_v1.json")
    records = binding["remanence_fragment_bindings"]
    assert source["row_count"] == binding["sources"]["remanence_ii_v"]["row_count"] == 16
    assert len(records) == 16
    assert {item["source_name"] for item in records} == {item["Ennemi"] for item in source["records"]}
    assert len({item["entity_id"] for item in records}) == 16
    assert {item["mode"] for item in binding["remanence_acquisition_triggers"]} == {
        "observation", "corpse_analysis", "recruitment_or_coexistence"
    }


def test_ux_flow_matches_mobile_desktop_controller_guardrails():
    ui = load(PARALLEL / "ux_screen_flow_v1.json")
    rules = ui["global_rules"]
    assert ui["enabled_by_default"] is False
    assert rules["touch_target_min_points"] >= 48
    assert rules["long_press_required"] is False
    assert rules["hover_required"] is False
    assert rules["phone_max_primary_actions_visible"] <= 5
    assert rules["controller_pointer_dependency"] is False
    assert rules["knowledge_source_states"] == ["UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"]
    assert {screen["id"] for screen in ui["screens"]} == {
        "refuge_home", "active_party", "recruit_roster", "recruit_detail", "archives", "expedition_prepare"
    }
    assert len(ui["combat_context_overlays"]) == 4
    recruit = next(screen for screen in ui["screens"] if screen["id"] == "recruit_detail")
    assert recruit["rules"]["capture_is_recruitment"] is False
    assert recruit["rules"]["boss_recruitment_available"] is False
    assert recruit["rules"]["injury_reset_on_rally"] is False


def test_playtest_telemetry_is_structured_private_and_balance_focused():
    data = load(PARALLEL / "playtest_telemetry_matrix_v1.json")
    assert data["enabled_by_default"] is False
    assert data["privacy"]["personally_identifiable_information"] is False
    assert data["privacy"]["free_text_capture"] is False
    assert data["privacy"]["raw_dialogue_or_player_text_capture"] is False
    assert data["privacy"]["account_identifier_capture"] is False
    assert len(data["events"]) == 33
    assert len({event["id"] for event in data["events"]}) == 33
    forbidden_field_fragments = {"email", "name", "address", "free_text", "message", "dialogue_text"}
    assert all(
        not any(fragment in field.lower() for fragment in forbidden_field_fragments)
        for event in data["events"] for field in event["fields"]
    )
    assert len(data["derived_metrics"]) >= 10
    assert "change one balance family at a time when validating a hypothesis" in data["playtest_decision_rules"]


def test_18_expedition_alterations_are_temporary_reproducible_and_counterable():
    data = load(PARALLEL / "expedition_alteration_candidates_v2.json")
    assert data["enabled_by_default"] is False
    assert data["candidate_count"] == 18
    assert set(data["families"]) == {"light", "noise", "body", "environment", "knowledge", "extraction"}
    assert all(len(items) == 3 for items in data["families"].values())
    all_items = [item for items in data["families"].values() for item in items]
    assert len(all_items) == 18
    assert len({item["id"] for item in all_items}) == 18
    assert all(item["counterplay"] for item in all_items)
    rules = data["rules"]
    assert rules["seed_reproducible"] is True
    assert rules["persistent_runtime_modifier_forbidden"] is True
    assert rules["permanent_stat_inflation_forbidden"] is True
    assert rules["stored_knowledge_erasure_forbidden"] is True
    assert rules["forced_no_win_state_forbidden"] is True
    assert rules["playtest_validation_required_before_activation"] is True


def test_remanence_variants_require_lived_history_and_never_create_fake_nemesis():
    data = load(PARALLEL / "remanence_nemesis_variants_v2.json")
    assert data["enabled_by_default"] is False
    assert data["variant_count"] == len(data["variants"]) == 16
    assert len({item["id"] for item in data["variants"]}) == 16
    rules = data["rules"]
    assert rules["shared_history_required_for_memorial_or_above"] is True
    assert rules["artificial_nemesis_spawn_forbidden"] is True
    assert rules["hp_sponge_nemesis_forbidden"] is True
    assert rules["omniscient_build_reading_forbidden"] is True
    assert rules["full_scene_snapshot_forbidden"] is True
    assert rules["real_wounds_persist"] is True
    assert all(item["requires"] for item in data["variants"])
    assert all(item["telegraph"] and item["counterplay"] and item["narrative_trace"] for item in data["variants"])


def test_active_playtest_contracts_do_not_reference_parallel_detail_files():
    detail_manifest = load(PARALLEL / "post_playtest_detail_manifest_v1.json")
    refs = [entry["path"] for entry in detail_manifest["files"].values()]
    active_paths = [
        DATA / "content_foundation_v2.json",
        DATA / "encounter_generation_contract_v1.json",
        DATA / "archives_refuge_ui_contract_v1.json",
        DATA / "vs001_ui_input_contract.json",
    ]
    for path in active_paths:
        text = path.read_text(encoding="utf-8")
        assert "post_playtest_detail_manifest_v1.json" not in text
        for ref in refs:
            assert ref not in text
