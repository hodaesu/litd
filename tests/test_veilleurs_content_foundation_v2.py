import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"


def load(name: str) -> dict:
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def test_content_foundation_counts_and_ids():
    data = load("content_foundation_v2.json")
    assert data["principles"]["main_protagonists_exact"] == 4
    assert data["watchers"] == [
        "nayra_orun",
        "tarek_senn",
        "aisha_maren",
        "idris_vael",
    ]
    assert data["skills"]["trees_per_watcher"] == 3
    assert data["skills"]["nodes_per_tree"] == 15
    assert data["skills"]["total_watcher_skills"] == 180
    assert data["skills"]["max_level"] == 50

    bestiary = data["bestiary"]
    assert bestiary["ordinary_species_target"] == 24
    assert bestiary["combat_families_target"] == 8
    assert len(bestiary["family_ids"]) == 8
    assert len(set(bestiary["family_ids"])) == 8
    assert len(bestiary["family_names"]) == 8
    assert bestiary["species_names_status"] == "24_locked"
    assert bestiary["normalization_manifest"].endswith(
        "canonical_bestiary_normalization_v1.json"
    )

    encounters = data["encounters"]
    assert encounters["canonical_template_target"] == 64
    assert encounters["max_standard_enemies"] == 4
    assert encounters["max_memorial_enemy"] == 1
    assert encounters["artificial_nemesis_spawn_forbidden"] is True
    assert data["enemy_synergies"]["canonical_target"] == 21

    bosses = data["bosses"]
    assert bosses["count"] == 5
    assert bosses["recruitable"] is True
    assert [boss["act"] for boss in bosses["roster"]] == [1, 2, 3, 4, 5]
    assert all(boss["recruitable"] is True for boss in bosses["roster"])
    assert len({boss["id"] for boss in bosses["roster"]}) == 5


def test_species_catalog_is_complete_canonical_and_unique():
    data = load("species_catalog_recovered_v1.json")
    assert data["status"] == "canonical_complete"
    assert data["target_species"] == 24
    assert data["recovered_species"] == 24
    assert data["unresolved_species"] == 0
    assert data["placeholder_names_forbidden"] is True
    assert len(data["families"]) == 8
    assert all(family["species_names_locked"] is True for family in data["families"])

    species = [
        species
        for family in data["families"]
        for species in family["species"]
    ]
    assert len(species) == 24
    assert len({item["id"] for item in species}) == 24
    assert len({item["name"] for item in species}) == 24
    assert all(item["name"].strip() for item in species)

    family_counts = {family["id"]: len(family["species"]) for family in data["families"]}
    assert family_counts == {
        "delies": 2,
        "pelerins_fendus": 2,
        "gardiens_de_pierre": 2,
        "betes_de_suie": 2,
        "silencieux": 4,
        "veines": 4,
        "porte_cendres": 4,
        "gardiens_de_version": 4,
    }

    assert [s["name"] for s in data["families"][0]["species"]] == [
        "Délié Affamé",
        "Délié Boursouflé",
    ]
    assert [s["name"] for s in data["families"][1]["species"]] == [
        "Censeur Fendu",
        "Flagellant Fendu",
    ]
    assert [s["name"] for s in data["families"][2]["species"]] == [
        "Sentinelle du Seuil",
        "Exécuteur de Pierre",
    ]
    assert [s["name"] for s in data["families"][3]["species"]] == [
        "Traque-Suie",
        "Brise-Os de Suie",
    ]


def test_canonical_bestiary_normalization_is_complete_and_bindable():
    data = load("canonical_bestiary_normalization_v1.json")
    assert data["status"] == "canonical_production_binding"
    assert data["counts"] == {
        "ordinary_species": 24,
        "families": 8,
        "bosses": 5,
        "total_entities": 29,
    }
    assert len(data["intent_taxonomy"]) == 8
    assert list(data["knowledge_scale"]) == ["0", "1", "2", "3", "4", "5"]
    assert data["global_rules"]["knowledge_never_overrides_current_perception"] is True
    assert data["global_rules"]["unseen_boss_phase_never_revealed"] is True
    assert data["global_rules"]["remanence_learning_only_from_lived_events"] is True

    ordinary = data["ordinary_species"]
    assert len(ordinary) == 24
    assert len({item["id"] for item in ordinary}) == 24
    for item in ordinary:
        assert item["family_id"] in data["family_defaults"]
        assert item["act"] == data["family_defaults"][item["family_id"]]["act"]
        assert item["role"]
        assert item["anatomy_profile"]
        assert 2 <= len(item["intent_classes"]) <= 4
        assert set(item["intent_classes"]).issubset(set(data["intent_taxonomy"]))
        assert set(item["telegraphs"]) == {"visual", "audio", "environmental"}
        assert all(item["telegraphs"][channel] for channel in item["telegraphs"])
        assert set(item["knowledge"]) == {"1", "2", "3", "4", "5"}
        assert item["recruitment_profile"]
        assert item["memory_ceiling"] == "nemesis"

    catalog = load("species_catalog_recovered_v1.json")
    catalog_ids = {
        species["id"]
        for family in catalog["families"]
        for species in family["species"]
    }
    assert {item["id"] for item in ordinary} == catalog_ids

    bosses = data["bosses"]
    foundation = load("content_foundation_v2.json")
    assert len(bosses) == 5
    assert [boss["id"] for boss in bosses] == [
        boss["id"] for boss in foundation["bosses"]["roster"]
    ]
    assert all(boss["phase_knowledge_scoped"] is True for boss in bosses)
    assert all(boss["recruitment"] == "canonical_story_rule_only" for boss in bosses)
    assert all(set(boss["intent_classes"]).issubset(set(data["intent_taxonomy"])) for boss in bosses)


def test_party_refuge_and_recruitment_guardrails():
    data = load("recruitment_refuge_contract_v1.json")
    assert data["party"]["max_combatants"] == 4
    assert data["party"]["min_watchers"] == 1
    assert data["refuge"]["recruit_capacity"] == 12
    assert data["eligibility"]["boss"] is True
    assert data["eligibility"]["boss_rule"] == "canonical_story_rule_only"
    assert data["eligibility"]["miniboss"] is False
    assert data["ui"]["capture_probability_visible"] is False
    assert data["monetization_guardrails"] == {
        "gacha": False,
        "paid_reroll": False,
        "paid_recruitment": False,
    }
    assert set(data["paths"]) == {
        "soumission",
        "reddition",
        "sauvetage",
        "pacte",
        "apprivoisement",
    }


def test_remanence_rank_order_and_persistence_rules():
    data = load("remanence_entity_contract_v1.json")
    assert list(data["memory_ranks"]) == [
        "normal",
        "memorial",
        "veteran",
        "elite",
        "nemesis",
    ]
    assert data["memory_ranks"]["normal"]["persistent_individual"] is False
    assert data["memory_ranks"]["memorial"]["persistent_individual"] is True
    assert data["memory_ranks"]["nemesis"]["requires_shared_history"] is True
    assert data["memory_ranks"]["nemesis"]["hp_sponge_design_forbidden"] is True
    assert data["adaptation_guardrails"]["omniscient_learning_forbidden"] is True
    assert data["world_persistence"]["full_scene_snapshot_forbidden"] is True


def test_encounter_generation_contract():
    data = load("encounter_generation_contract_v1.json")
    assert data["canonical_template_target"] == 64
    assert data["enemy_synergy_target"] == 21
    assert data["composition_rules"]["max_standard_enemies"] == 4
    assert data["composition_rules"]["max_memorial_enemies"] == 1
    assert data["composition_rules"]["artificial_nemesis_spawn_forbidden"] is True
    assert data["anti_repetition"]["same_template_twice_in_a_row_forbidden"] is True
    assert data["anti_repetition"]["history_window_rooms"] == 5
    assert data["anti_repetition"]["repeat_threshold_in_window"] == 2
    assert data["anti_repetition"]["weight_multiplier_after_threshold"] == 0.4
    assert data["synergy_rules"]["visible_to_player"] is True
    assert data["synergy_rules"]["breakable_by_player"] is True
    assert data["content_population"]["placeholder_names_forbidden"] is True


def test_archives_and_refuge_ui_keep_platform_parity():
    data = load("archives_refuge_ui_contract_v1.json")
    assert data["inherits"] == "res://data/veilleurs/vs001_ui_input_contract.json"
    assert data["principles"]["same_gameplay_all_platforms"] is True
    assert data["principles"]["touch_target_min_points"] == 48
    assert data["principles"]["long_press_required"] is False
    assert data["principles"]["hover_required"] is False
    assert data["refuge"]["recruit_capacity"] == 12
    assert data["refuge"]["party_max"] == 4
    assert data["refuge"]["party_min_watchers"] == 1
    assert data["archives"]["entity_primary_sections"] == [
        "identite_connaissance",
        "corps",
        "combat",
        "histoire",
        "traces",
    ]
    assert data["recruitment_interaction"]["show_capture_percentage"] is False
    assert data["profiles"]["controller"]["pointer_dependency"] is False


def test_narrative_contract_preserves_four_text_only_voices():
    data = load("narrative_continuity_contract_v1.json")
    assert data["dialogue_mode"] == "text_only"
    assert data["voice_acting"] is False
    assert data["main_protagonists_exact"] == 4
    assert data["protagonists"] == [
        "nayra_orun",
        "tarek_senn",
        "aisha_maren",
        "idris_vael",
    ]
    assert len(data["narrative_pillars"]) == 7
    assert data["epistemic_rules"]["distinguish_fact_hypothesis"] is True
    assert data["epistemic_rules"]["omniscient_exposition_forbidden"] is True
    assert data["writing_guardrails"]["main_cast_cannot_expand_beyond_four"] is True
    assert data["voice_contract_source"] == "res://data/veilleurs/vs001_dialogues.json"
