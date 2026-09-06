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

    encounters = data["encounters"]
    assert encounters["canonical_template_target"] == 64
    assert encounters["max_standard_enemies"] == 4
    assert encounters["max_memorial_enemy"] == 1
    assert encounters["artificial_nemesis_spawn_forbidden"] is True
    assert data["enemy_synergies"]["canonical_target"] == 21

    bosses = data["bosses"]
    assert bosses["count"] == 5
    assert bosses["recruitable"] is False
    assert [boss["act"] for boss in bosses["roster"]] == [1, 2, 3, 4, 5]
    assert len({boss["id"] for boss in bosses["roster"]}) == 5


def test_party_refuge_and_recruitment_guardrails():
    data = load("recruitment_refuge_contract_v1.json")
    assert data["party"]["max_combatants"] == 4
    assert data["party"]["min_watchers"] == 1
    assert data["refuge"]["recruit_capacity"] == 12
    assert data["eligibility"]["boss"] is False
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
