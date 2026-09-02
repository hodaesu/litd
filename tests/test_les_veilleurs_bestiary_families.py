import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load_bestiary():
    return json.loads((ROOT / "data/canon/les_veilleurs_bestiary_families.json").read_text(encoding="utf-8"))


def test_first_bestiary_wave_has_seven_distinct_families():
    data = load_bestiary()
    families = data["families"]
    assert data["id"] == "les_veilleurs_bestiary_families"
    assert data["status"] == "design_locked"
    assert data["family_count"] == 7
    assert len(families) == 7
    assert len({family["id"] for family in families}) == 7


def test_six_families_are_recruitable_and_manifestations_are_not():
    data = load_bestiary()
    families = data["families"]
    recruitable = [family for family in families if family["recruitable"]]
    assert len(recruitable) == data["recruitable_family_count"] == 6
    manifestations = next(family for family in families if family["id"] == "manifestations_destructrices")
    assert manifestations["recruitable"] is False
    assert manifestations["non_recruitable_trait"] == "manifestation_destructrice"
    assert manifestations["origin_classification"] == "unresolved"


def test_every_recruitable_family_has_three_paths_of_five_skills():
    data = load_bestiary()
    for family in data["families"]:
        if not family["recruitable"]:
            continue
        paths = family["progression_paths"]
        assert len(paths) == 3, family["id"]
        assert all(len(path["skills"]) == 5 for path in paths), family["id"]
        skill_ids = [skill["id"] for path in paths for skill in path["skills"]]
        assert len(skill_ids) == 15
        assert len(set(skill_ids)) == 15


def test_every_family_has_anatomy_combat_narrative_and_remanence_contract():
    data = load_bestiary()
    for family in data["families"]:
        assert family["anatomy"]["zones"], family["id"]
        assert family["combat_role"], family["id"]
        assert family["ai_priorities"], family["id"]
        assert family["narrative_reactions"], family["id"]
        assert family["remanence_hooks"], family["id"]
        if family["recruitable"]:
            assert family["hub_behavior"], family["id"]
            assert family["evolution"], family["id"]
            assert family["recruitment_vectors"], family["id"]


def test_les_veilleurs_cannot_use_post_chute_origin_category():
    data = load_bestiary()
    for family in data["families"]:
        assert "post_chute" not in family.get("origin_categories", []), family["id"]
    assert any("post_chute" in rule and "interdit" in rule for rule in data["canon_rules"])


def test_known_act_specific_families_match_locked_act_themes():
    data = load_bestiary()
    by_id = {family["id"]: family for family in data["families"]}
    assert by_id["porteurs_des_veines"]["presence"]["primary_act"] == "III"
    assert by_id["fouisseurs_des_veines"]["presence"]["primary_act"] == "III"
    assert by_id["brules_de_porte_cendres"]["presence"]["primary_act"] == "IV"
    assert by_id["gardiens_des_versions"]["presence"]["primary_act"] == "V"


def test_data_loader_exposes_bestiary_runtime_queries():
    loader = (ROOT / "scripts/core/data_loader.gd").read_text(encoding="utf-8")
    for token in (
        'res://data/canon/les_veilleurs_bestiary_families.json',
        'func les_veilleurs_bestiary_family(',
        'func les_veilleurs_bestiary_all_families(',
        'func les_veilleurs_bestiary_recruitable_families(',
        'func les_veilleurs_bestiary_roles(',
    ):
        assert token in loader
