import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
CURRENT = DATA / "canonical_prepc_2026_09_03" / "current"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_runtime_synergy_binding_matches_21_source_pairs():
    source = load(DATA / "enemy_synergy_catalog_v1.json")
    bound = load(DATA / "enemy_synergy_binding_v1.json")
    species = load(DATA / "species_catalog_recovered_v1.json")

    valid_species = {
        item["id"]
        for family in species["families"]
        for item in family["species"]
    }
    assert source["count"] == bound["count"] == 21
    assert len(bound["records"]) == 21
    assert len({record["id"] for record in bound["records"]}) == 21
    assert [" + ".join(record["pair_names"]) for record in bound["records"]] == [
        record["pair"] for record in source["records"]
    ]
    assert [record["strength"] for record in bound["records"]] == [
        record["strength"] for record in source["records"]
    ]
    assert all(set(record["species_ids"]).issubset(valid_species) for record in bound["records"])
    assert all(record["visible_to_player"] is True for record in bound["records"])
    assert all(record["breakable"] is True for record in bound["records"])
    assert all(record["counterplay"] for record in bound["records"])


def test_runtime_encounter_catalog_matches_64_source_names_and_mobile_caps():
    source = load(DATA / "encounter_index_v1.json")
    manifest = load(DATA / "encounter_catalog_64_v1.json")
    synergy = load(DATA / "enemy_synergy_binding_v1.json")
    species = load(DATA / "species_catalog_recovered_v1.json")

    valid_synergies = {record["id"] for record in synergy["records"]}
    valid_species = {
        item["id"]
        for family in species["families"]
        for item in family["species"]
    }
    records = []
    for ref in manifest["act_files"]:
        path = ROOT / ref["path"].removeprefix("res://")
        act_data = load(path)
        assert act_data["count"] == ref["count"]
        records.extend(act_data["records"])

    source_records = [record for act_records in source["acts"].values() for record in act_records]
    assert manifest["count"] == len(records) == len(source_records) == 64
    assert manifest["act_distribution"] == {"1": 16, "2": 12, "3": 12, "4": 12, "5": 12}
    assert {record["name"] for record in records} == {record["name"] for record in source_records}
    assert len({record["id"] for record in records}) == 64
    assert max(record["actors"] for record in records) <= 4
    assert min(record["actors"] for record in records) >= 1
    assert sum(1 for record in records if record["type"] == "Pré-boss") == 6
    assert all(set(record["species_ids"]).issubset(valid_species) for record in records)
    assert all(set(record["synergy_ids"]).issubset(valid_synergies) for record in records)
    assert all(record["runtime_remanence"]["max_memorial_enemy"] == 1 for record in records)
    assert all(record["runtime_remanence"]["artificial_nemesis_spawn_forbidden"] is True for record in records)


def test_boss_phase_knowledge_projection_preserves_16_source_phases_and_nonrecruitment():
    source = load(DATA / "boss_phase_catalog_v1.json")
    manifest = load(DATA / "boss_phase_knowledge_v1.json")
    normalized = load(DATA / "canonical_bestiary_normalization_v2.json")

    expected_ids = {boss["runtime_id"] for boss in normalized["bosses"]}
    assert manifest["source_knowledge_states"] == [
        "UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"
    ]
    assert manifest["presentation_projection_levels"] == [0, 1, 2, 3, 4, 5]
    assert set(manifest["boss_phase_counts"]) == expected_ids
    assert sum(manifest["boss_phase_counts"].values()) == source["count"] == 16

    records = []
    for ref in manifest["boss_files"]:
        assert ref["boss_id"] in expected_ids
        assert ref["recruitable"] is False
        path = ROOT / ref["path"].removeprefix("res://")
        data = load(path)
        assert data["boss_id"] == ref["boss_id"]
        assert data["recruitable"] is False
        assert data["count"] == ref["count"]
        records.extend(data["records"])

    assert len(records) == 16
    assert len({record["id"] for record in records}) == 16
    assert all(record["phase_scoped"] is True for record in records)
    assert all(record["unseen_future_phase_hidden"] is True for record in records)
    assert all(set(record["knowledge_reveal"]) == {"0", "1", "2", "3", "4", "5"} for record in records)
    assert all(record["mechanics"] and record["counterplay"] and record["transition"] for record in records)


def test_archives_binding_maps_all_29_source_entities_without_recruitable_boss_regression():
    source = load(CURRENT / "bestiaire_narratif_29.json")
    archives = load(DATA / "archives_bestiary_29_v1.json")
    synergies = load(DATA / "enemy_synergy_binding_v1.json")

    valid_synergies = {record["id"] for record in synergies["records"]}
    source_names = {row["Entité"] for row in source["records"]}
    assert archives["entity_count"] == len(archives["records"]) == source["row_count"] == 29
    assert len({record["entity_id"] for record in archives["records"]}) == 29
    assert {record["source_name"] for record in archives["records"]} == source_names
    assert archives["source_knowledge_states"] == [
        "UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"
    ]
    assert set(archives["presentation_detail_projection"]) == {"0", "1", "2", "3", "4", "5"}
    assert all(set(record.get("related_synergy_ids", [])).issubset(valid_synergies) for record in archives["records"])

    bosses = [record for record in archives["records"] if record["category"] == "boss"]
    assert len(bosses) == 5
    assert all(record["recruitable"] is False for record in bosses)
    assert {record["display_name"] for record in bosses} == {
        "Ishar, Gardien du Passage",
        "Orateur Sans Voix",
        "Mère des Veines",
        "Porte-Cendres Blanc",
        "Le Copiste",
    }


def test_encounter_generation_contract_wires_all_runtime_catalogs():
    contract = load(DATA / "encounter_generation_contract_v1.json")
    assert contract["version"] == 3
    assert contract["runtime_catalogs"] == {
        "encounters": "res://data/veilleurs/encounter_catalog_64_v1.json",
        "synergies": "res://data/veilleurs/enemy_synergy_binding_v1.json",
        "boss_phases": "res://data/veilleurs/boss_phase_knowledge_v1.json",
        "archives": "res://data/veilleurs/archives_bestiary_29_v1.json",
    }
    assert contract["content_population"]["encounters_status"].endswith("runtime_bound")
    assert contract["content_population"]["synergies_status"].endswith("runtime_bound")
    assert contract["knowledge_rules"]["unseen_future_phase_hidden"] is True
    assert contract["knowledge_rules"]["stored_knowledge_is_not_erased_by_low_perception"] is True
