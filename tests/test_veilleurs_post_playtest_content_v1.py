import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
PARALLEL = DATA / "parallel_content" / "post_playtest_content_v1.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def res_path(value: str) -> Path:
    assert value.startswith("res://")
    return ROOT / value.removeprefix("res://")


def test_post_playtest_content_is_disabled_and_not_wired_into_playtest_contracts():
    parallel = load(PARALLEL)
    assert parallel["status"] == "post_playtest_parallel_content"
    assert parallel["activation"]["enabled_by_default"] is False
    assert parallel["activation"]["runtime_wiring"] == "none_until_post_playtest_merge"
    assert parallel["activation"]["playtest_branch_must_remain_unchanged"] is True
    assert parallel["activation"]["source_playtest_pr"] == 173

    forbidden_ref = "parallel_content/post_playtest_content_v1.json"
    for active_path in [
        DATA / "content_foundation_v2.json",
        DATA / "encounter_generation_contract_v1.json",
        DATA / "archives_refuge_ui_contract_v1.json",
    ]:
        assert forbidden_ref not in active_path.read_text(encoding="utf-8")


def test_parallel_contract_preserves_canonical_system_guardrails():
    parallel = load(PARALLEL)
    rules = load(DATA / "canonical_prepc_2026_09_03" / "system_rules_v1.json")
    guard = parallel["canonical_guardrails"]

    assert guard["knowledge_source_states"] == rules["knowledge"]["states"] == [
        "UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"
    ]
    assert guard["knowledge_is_currency"] is rules["knowledge"]["is_currency"] is False
    assert guard["presentation_detail_levels_are_projection_only"] == [0, 1, 2, 3, 4, 5]
    assert guard["capture_is_recruitment"] is rules["ralliement"]["capture_is_recruitment"] is False
    assert guard["injuries_reset_on_rally"] is rules["ralliement"]["injuries_reset_on_rally"] is False
    assert guard["bosses_recruitable"] is rules["ralliement"]["bosses_recruitable"] is False
    assert guard["party_max"] == rules["party"]["max_size"] == 4
    assert guard["party_min_watchers"] == rules["party"]["min_veilleurs"] == 1
    assert guard["refuge_capacity_by_act"] == rules["refuge"]["capacity_by_level"] == {
        "I": 4, "II": 6, "III": 8, "IV": 10, "V": 12
    }
    assert guard["max_memorial_enemies_per_encounter"] == 1
    assert guard["artificial_nemesis_spawn_forbidden"] is True
    assert guard["full_scene_snapshot_forbidden"] is True


def test_all_bound_canonical_sources_exist():
    parallel = load(PARALLEL)
    for ref in parallel["canonical_source_bindings"].values():
        assert res_path(ref).exists(), ref


def test_acts_ii_v_projection_only_reuses_existing_runtime_ids():
    parallel = load(PARALLEL)
    species = load(DATA / "species_catalog_recovered_v1.json")
    synergies = load(DATA / "enemy_synergy_binding_v1.json")
    bosses = load(DATA / "canonical_bestiary_normalization_v2.json")
    boss_phases = load(DATA / "boss_phase_knowledge_v1.json")

    valid_species = {
        item["id"]
        for family in species["families"]
        for item in family["species"]
    }
    valid_synergies = {row["id"] for row in synergies["records"]}
    valid_bosses = {row["runtime_id"] for row in bosses["bosses"]}

    acts = parallel["acts_ii_v_preparation"]
    assert [row["act"] for row in acts] == ["II", "III", "IV", "V"]
    assert [row["encounter_ids"]["count"] for row in acts] == [12, 12, 12, 12]
    assert [row["refuge_capacity"] for row in acts] == [6, 8, 10, 12]
    assert all(set(row["species_ids"]).issubset(valid_species) for row in acts)
    assert all(set(row["synergy_ids"]).issubset(valid_synergies) for row in acts)
    assert all(row["boss_id"] in valid_bosses for row in acts)
    assert all(boss_phases["boss_phase_counts"][row["boss_id"]] == row["boss_phase_count"] for row in acts)


def test_refuge_hooks_use_exact_12_canonical_families_and_only_known_relationship_axes():
    parallel = load(PARALLEL)
    rules = load(DATA / "canonical_prepc_2026_09_03" / "system_rules_v1.json")
    refuge = parallel["refuge_event_hooks"]

    family_ids = [row["id"] for row in refuge["families"]]
    assert family_ids == rules["refuge"]["event_families"]
    assert len(family_ids) == len(set(family_ids)) == 12
    allowed_axes = set(rules["relationships"]["axes"])
    assert all(set(row["primary_axes"]).issubset(allowed_axes) for row in refuge["families"])
    assert refuge["resolution_contract"]["can_reset_persistent_injury"] is False
    assert refuge["resolution_contract"]["can_make_boss_recruitable"] is False


def test_remanence_nemesis_templates_never_create_artificial_or_stat_sponge_nemesis():
    parallel = load(PARALLEL)
    rem = parallel["remanence_nemesis_variants"]
    assert rem["tiers"] == ["Normal", "Mémoriel", "Vétéran", "Élite", "Némésis"]
    assert all(row["requires_shared_history"] is True for row in rem["templates"])
    assert rem["nemesis_rules"]["rare"] is True
    assert rem["nemesis_rules"]["requires_shared_history"] is True
    assert rem["nemesis_rules"]["artificial_spawn"] is False
    assert rem["nemesis_rules"]["hp_sponge_multiplier_forbidden"] is True
    assert rem["nemesis_rules"]["omniscient_counters_forbidden"] is True


def test_alterations_and_balance_are_candidate_only_and_cannot_change_current_defaults():
    parallel = load(PARALLEL)
    alterations = parallel["expedition_alteration_pool"]
    balance = parallel["balance_option_registry"]

    assert alterations["status"] == "design_candidates_not_canon_until_validated"
    assert alterations["enabled_by_default"] is False
    assert alterations["scope"] == "single_expedition_only"
    assert alterations["selection_rules"]["max"] <= 2
    assert balance["status"] == "telemetry_knobs_post_playtest_only"
    assert balance["enabled_by_default"] is False
    assert balance["active_values_mutated"] is False
    assert len(balance["knobs"]) == len({row["id"] for row in balance["knobs"]})


def test_future_archive_and_ux_rules_preserve_uncertainty_without_erasing_knowledge():
    parallel = load(PARALLEL)
    archives = parallel["archives_future_hooks"]
    ux = parallel["ux_microcopy_fr"]

    assert set(archives["sections"]) == {
        "identite_connaissance", "corps", "combat", "histoire", "traces"
    }
    assert archives["boss_rules"]["phase_scoped"] is True
    assert archives["boss_rules"]["unseen_phase_hidden"] is True
    assert "never erase stored knowledge" in archives["perception_rule"]
    assert ux["status"] == "candidate_copy_post_playtest"
    assert "capture percentage" in ux["forbidden_copy"]
    assert "hidden future boss phase details" in ux["forbidden_copy"]
