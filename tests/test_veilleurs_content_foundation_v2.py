import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
CANON = DATA / "canonical_prepc_2026_09_03"
CURRENT = CANON / "current"
PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_verified_canonical_source_manifest():
    data = load(CANON / "canonical_source_manifest_v1.json")
    assert data["status"] == "verified_from_library_zip_and_pr163"
    assert data["source_workbook"] == "LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx"
    assert data["recovered_date"] == "2026-09-03"
    assert data["zip_sha256"] == PACK_SHA
    assert data["counts"] == {
        "ordinary_enemies": 24,
        "bosses": 5,
        "combat_entities": 29,
        "encounters": 64,
        "enemy_synergies": 21,
        "boss_phases": 16,
        "bestiary_narrative": 29,
        "watcher_barks": 68,
        "boss_dialogue_lines": 30,
        "narrative_events": 15,
        "regional_encounter_narratives": 64,
    }


def test_foundation_uses_verified_master_canon():
    data = load(DATA / "content_foundation_v2.json")
    assert data["canonical_source"]["zip_sha256"] == PACK_SHA
    assert data["principles"]["main_protagonists_exact"] == 4
    assert data["watchers"] == ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"]
    assert data["skills"]["total_watcher_skills"] == 180
    assert data["skills"]["max_level"] == 50
    assert data["bestiary"]["ordinary_species_target"] == 24
    assert data["bestiary"]["combat_families_target"] == 8
    assert data["bestiary"]["species_names_status"] == "24_locked"
    assert data["bestiary"]["normalization_manifest"].endswith("canonical_bestiary_normalization_v2.json")
    assert data["encounters"]["canonical_template_target"] == 64
    assert data["enemy_synergies"]["canonical_target"] == 21
    assert data["bosses"]["phase_count"] == 16
    assert data["bosses"]["recruitable"] is False
    assert data["recruitment"]["capture_is_recruitment"] is False
    assert data["recruitment"]["injuries_reset_on_rally"] is False
    assert data["refuge"]["capacity_by_act"] == {"I": 4, "II": 6, "III": 8, "IV": 10, "V": 12}


def test_species_catalog_is_complete_and_unique():
    data = load(DATA / "species_catalog_recovered_v1.json")
    assert data["status"] == "canonical_complete"
    assert data["target_species"] == 24
    assert data["recovered_species"] == 24
    assert data["unresolved_species"] == 0
    assert len(data["families"]) == 8
    species = [species for family in data["families"] for species in family["species"]]
    assert len(species) == 24
    assert len({item["id"] for item in species}) == 24
    assert len({item["name"] for item in species}) == 24
    assert {family["id"]: len(family["species"]) for family in data["families"]} == {
        "delies": 2,
        "pelerins_fendus": 2,
        "gardiens_de_pierre": 2,
        "betes_de_suie": 2,
        "silencieux": 4,
        "veines": 4,
        "porte_cendres": 4,
        "gardiens_de_version": 4,
    }


def test_canonical_registry_and_bosses_are_not_recruitable():
    source = load(CANON / "bestiary_registry_v1.json")
    assert source["ordinary_enemy_count"] == 24
    assert source["boss_count"] == 5
    assert source["entity_count"] == 29
    assert len(source["entities"]) == 29
    bosses = [entity for entity in source["entities"] if entity["id"].startswith("boss.")]
    assert [boss["name"] for boss in bosses] == [
        "Ishar, Gardien du Passage",
        "Orateur Sans Voix",
        "Mère des Veines",
        "Porte-Cendres Blanc",
        "Le Copiste",
    ]
    assert all(boss["recruitment"] == "Non" for boss in bosses)

    normalized = load(DATA / "canonical_bestiary_normalization_v2.json")
    assert normalized["counts"] == {"ordinary_species": 24, "families": 8, "bosses": 5, "total_entities": 29}
    assert all(boss["recruitable"] is False for boss in normalized["bosses"])
    assert normalized["ordinary_recruitment"]["act_i_numeric_conditions"] == "undefined_do_not_invent"


def test_refuge_and_rallying_rules_match_system_baseline():
    source = load(CANON / "system_rules_v1.json")
    contract = load(DATA / "recruitment_refuge_contract_v1.json")
    expected_capacity = {"I": 4, "II": 6, "III": 8, "IV": 10, "V": 12}
    assert source["party"] == {"max_size": 4, "min_veilleurs": 1}
    assert source["refuge"]["capacity_by_level"] == expected_capacity
    assert contract["party"]["max_combatants"] == 4
    assert contract["party"]["min_watchers"] == 1
    assert contract["refuge"]["capacity_by_act"] == expected_capacity
    assert contract["refuge"]["max_recruit_capacity"] == 12
    assert len(contract["refuge"]["event_families"]) == 12
    assert contract["refuge"]["relationship_axes"] == ["CONFIANCE", "RESPECT", "PEUR", "RESSENTIMENT"]
    assert contract["rallying"]["capture_is_recruitment"] is False
    assert contract["rallying"]["injuries_reset_on_rally"] is False
    assert contract["rallying"]["bosses_recruitable"] is False
    assert contract["eligibility"]["boss"] is False
    assert contract["ui"]["capture_probability_visible"] is False


def test_64_canonical_encounters_are_locked_and_mobile_bounded():
    data = load(DATA / "encounter_index_v1.json")
    assert data["count"] == 64
    assert data["source_sha256"] == "2a3246778559b6750a9afe37e9a304c5d80c8c9801fba6a626aed73bba46dc92"
    records = [record for records in data["acts"].values() for record in records]
    assert len(records) == 64
    assert len({record["name"] for record in records}) == 64
    assert max(record["actors"] for record in records) == 4
    assert min(record["actors"] for record in records) == 1
    assert sum(1 for record in records if record["type"] == "Pré-boss") == 6


def test_21_enemy_synergies_have_explicit_counterplay():
    data = load(DATA / "enemy_synergy_catalog_v1.json")
    assert data["count"] == 21
    assert len(data["records"]) == 21
    assert all(record["pair"] for record in data["records"])
    assert all(record["strength"] in (2, 3) for record in data["records"])
    assert all(record["function"] for record in data["records"])
    assert all(record["counterplay"] for record in data["records"])


def test_five_bosses_have_16_exact_phases():
    data = load(DATA / "boss_phase_catalog_v1.json")
    assert data["boss_count"] == 5
    assert data["count"] == 16
    counts = {}
    for record in data["records"]:
        counts[record["boss"]] = counts.get(record["boss"], 0) + 1
        assert record["mechanics"]
        assert record["counterplay"]
        assert record["transition"]
    assert counts == {
        "Ishar, Gardien du Passage": 3,
        "Orateur Sans Voix": 3,
        "Mère des Veines": 3,
        "Porte-Cendres Blanc": 3,
        "Le Copiste": 4,
    }


def test_narrative_and_dialogue_corpus_is_locked():
    events = load(DATA / "narrative_event_catalog_v1.json")
    boss_dialogues = load(CURRENT / "dialogues_boss.json")
    barks = load(CURRENT / "barks_veilleurs.json")
    bestiary = load(CURRENT / "bestiaire_narratif_29.json")
    remanence = load(CURRENT / "remanence_ii_v.json")

    assert events["count"] == 15
    assert len({event["id"] for event in events["records"]}) == 15
    assert boss_dialogues["row_count"] == 30
    assert len({line["Clé"] for line in boss_dialogues["records"]}) == 30
    assert barks["row_count"] == 68
    assert len({line["Clé"] for line in barks["records"]}) == 68
    assert bestiary["row_count"] == 29
    boss_entries = [row for row in bestiary["records"] if row["Catégorie"] == "boss"]
    assert len(boss_entries) == 5
    assert all(row["Note recrutement"] == "Boss non recruté." for row in boss_entries)
    assert remanence["row_count"] == 16
    assert all("ne donne jamais une vérité absolue" in row["Utilisation"] for row in remanence["records"])


def test_archives_ui_uses_source_knowledge_states_and_platform_parity():
    data = load(DATA / "archives_refuge_ui_contract_v1.json")
    assert data["principles"]["same_gameplay_all_platforms"] is True
    assert data["principles"]["touch_target_min_points"] == 48
    assert data["principles"]["long_press_required"] is False
    assert data["principles"]["hover_required"] is False
    assert data["refuge"]["capacity_by_act"] == {"I": 4, "II": 6, "III": 8, "IV": 10, "V": 12}
    assert data["archives"]["knowledge_source_states"] == ["UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"]
    assert data["archives"]["knowledge_is_currency"] is False
    assert data["archives"]["unseen_boss_phase_reveal_forbidden"] is True
    assert data["recruitment_interaction"]["boss_recruitment_available"] is False
    assert data["profiles"]["controller"]["pointer_dependency"] is False


def test_remanence_rank_order_and_persistence_rules():
    data = load(DATA / "remanence_entity_contract_v1.json")
    assert list(data["memory_ranks"]) == ["normal", "memorial", "veteran", "elite", "nemesis"]
    assert data["memory_ranks"]["normal"]["persistent_individual"] is False
    assert data["memory_ranks"]["memorial"]["persistent_individual"] is True
    assert data["memory_ranks"]["nemesis"]["requires_shared_history"] is True
    assert data["memory_ranks"]["nemesis"]["hp_sponge_design_forbidden"] is True
    assert data["adaptation_guardrails"]["omniscient_learning_forbidden"] is True
    assert data["world_persistence"]["full_scene_snapshot_forbidden"] is True


def test_narrative_contract_preserves_four_text_only_voices():
    data = load(DATA / "narrative_continuity_contract_v1.json")
    assert data["dialogue_mode"] == "text_only"
    assert data["voice_acting"] is False
    assert data["main_protagonists_exact"] == 4
    assert data["protagonists"] == ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"]
    assert len(data["narrative_pillars"]) == 7
    assert data["epistemic_rules"]["distinguish_fact_hypothesis"] is True
    assert data["epistemic_rules"]["omniscient_exposition_forbidden"] is True
    assert data["writing_guardrails"]["main_cast_cannot_expand_beyond_four"] is True
