import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load(name):
    return json.loads((ROOT / f"data/canon/{name}.json").read_text(encoding="utf-8"))


def test_combat_catalog_has_exactly_55_unique_variants():
    data = load("les_veilleurs_combat_kits")
    variants = data["variants"]
    assert data["variant_count"] == 55
    assert len(variants) == 55
    assert len({v["id"] for v in variants}) == 55


def test_every_family_has_all_five_ranks():
    data = load("les_veilleurs_combat_kits")
    variants = data["variants"]
    families = set(data["family_profiles"])
    ranks = {"common", "veteran", "elite", "mini_boss", "boss"}
    assert len(families) == 11
    for family in families:
        family_variants = [v for v in variants if v["family"] == family]
        assert len(family_variants) == 5, family
        assert {v["rank"] for v in family_variants} == ranks, family
        assert all(v["signature_actions"] for v in family_variants), family


def test_family_profiles_cover_requested_combat_dimensions():
    data = load("les_veilleurs_combat_kits")
    required = {
        "role", "ranges", "preferred_body_zones", "damage_types",
        "ai_priorities", "synergies", "corpse_interactions",
        "environment_interactions", "collapse_condition",
    }
    for family_id, profile in data["family_profiles"].items():
        assert required <= set(profile), family_id
        assert profile["preferred_body_zones"], family_id
        assert profile["ai_priorities"], family_id
        assert profile["corpse_interactions"], family_id
        assert profile["environment_interactions"], family_id


def test_rank_profiles_define_damage_precision_resistance_and_ai():
    data = load("les_veilleurs_combat_kits")
    assert set(data["rank_profiles"]) == {"common", "veteran", "elite", "mini_boss", "boss"}
    for rank, profile in data["rank_profiles"].items():
        for key in ("damage", "precision", "resistances", "ai", "targeting", "reaction_budget"):
            assert key in profile, (rank, key)


def test_encounter_catalog_has_19_valid_compositions():
    kits = load("les_veilleurs_combat_kits")
    encounters = load("les_veilleurs_encounter_compositions")
    valid_ids = {v["id"] for v in kits["variants"]}
    flat = [e for act in encounters["acts"] for e in act["encounters"]]
    assert encounters["encounter_count"] == 19
    assert len(flat) == 19
    assert len({e["id"] for e in flat}) == 19
    for encounter in flat:
        assert 3 <= len(encounter["units"]) <= 5, encounter["id"]
        assert set(encounter["units"]) <= valid_ids, encounter["id"]
        assert encounter["collapse"], encounter["id"]
        assert encounter["nonlethal_resolution"], encounter["id"]


def test_every_act_is_covered_and_known_late_act_themes_are_preserved():
    data = load("les_veilleurs_encounter_compositions")
    acts = {act["act"]: act for act in data["acts"]}
    assert set(acts) == {"I", "II", "III", "IV", "V"}
    assert "Veines" in acts["III"]["theme"]
    assert "Porte-Cendres" in acts["IV"]["theme"]
    assert "copies" in acts["V"]["theme"]
    assert acts["I"]["narrative_zone_names"] == "pending"
    assert acts["II"]["narrative_zone_names"] == "pending"


def test_manifestations_are_concurrent_hazards_not_faction_allies():
    data = load("les_veilleurs_encounter_compositions")
    flat = [e for act in data["acts"] for e in act["encounters"]]
    mixed = [e for e in flat if any(u.startswith("manifestations_destructrices") for u in e["units"]) and len(e["units"]) > 1]
    assert mixed
    assert any("aucune alliance" in rule for rule in data["design_rules"])


def test_data_loader_exposes_combat_and_encounter_queries():
    loader = (ROOT / "scripts/core/data_loader.gd").read_text(encoding="utf-8")
    for token in (
        'res://data/canon/les_veilleurs_combat_kits.json',
        'res://data/canon/les_veilleurs_encounter_compositions.json',
        'func les_veilleurs_combat_variant(',
        'func les_veilleurs_combat_kit(',
        'func les_veilleurs_encounter(',
        'func les_veilleurs_encounters_for_act(',
    ):
        assert token in loader
