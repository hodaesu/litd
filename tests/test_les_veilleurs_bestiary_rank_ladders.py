import json
from pathlib import Path

ROOT = Path(__file__).parents[1]
BASE = ROOT / "data/canon"


def load(name):
    return json.loads((BASE / name).read_text(encoding="utf-8"))


def all_family_ids():
    base = load("les_veilleurs_bestiary_families.json")
    missing = load("les_veilleurs_bestiary_missing_roles.json")
    return [f["id"] for f in base["families"]] + [f["id"] for f in missing["families"]]


def test_expansion_adds_four_missing_combat_roles():
    data = load("les_veilleurs_bestiary_missing_roles.json")
    assert data["family_count"] == 4
    assert data["recruitable_family_count"] == 4
    ids = {family["id"] for family in data["families"]}
    assert ids == {
        "chirurgiens_de_releve",
        "tireurs_de_relais",
        "meneurs_de_voix",
        "sapeurs_de_passage",
    }
    roles = {family["combat_role"] for family in data["families"]}
    assert roles == {
        "triage_healer_support",
        "ranged_precision_zone_pressure",
        "morale_pressure_coordination",
        "environment_control_traps_breach",
    }


def test_new_families_have_three_paths_and_fifteen_skills():
    data = load("les_veilleurs_bestiary_missing_roles.json")
    for family in data["families"]:
        assert family["recruitable"] is True
        assert len(family["progression_paths"]) == 3
        skills = [skill for path in family["progression_paths"] for skill in path["skills"]]
        assert len(skills) == 15, family["id"]
        assert len({skill["id"] for skill in skills}) == 15, family["id"]
        assert family["hard_refusal_conditions"], family["id"]


def test_every_family_has_five_rank_variants_in_exact_order():
    ladders = load("les_veilleurs_bestiary_rank_ladders.json")
    expected = ["common", "veteran", "elite", "mini_boss", "boss"]
    assert ladders["rank_order"] == expected
    families = ladders["families"]
    assert len(families) == 11
    assert {item["family_id"] for item in families} == set(all_family_ids())
    for family in families:
        assert [rank["rank"] for rank in family["ranks"]] == expected, family["family_id"]
        for rank in family["ranks"]:
            assert rank["name"]
            assert rank["attacks"]
            assert rank["behavior"]
            assert rank["wound_emphasis"]
            assert rank["appearance"]
            assert rank["narrative_text"]
            assert rank["recruitment_rule"] or rank.get("recruitment_vectors")


def test_rank_recruitment_rules_are_explicit_and_bosses_locked():
    data = load("les_veilleurs_bestiary_rank_ladders.json")
    for rank_id in ("common", "veteran", "elite", "mini_boss", "boss"):
        rule = data["rank_rules"][rank_id]
        assert rule["exact_conditions"]
        assert rule["defeat_reward"]
        assert rule["nonlethal_reward"]
    assert data["rank_rules"]["common"]["recruitable_by_default"] is True
    assert data["rank_rules"]["mini_boss"]["recruitable_by_default"] is True
    assert data["rank_rules"]["boss"]["recruitable_by_default"] is False
    for family in data["families"]:
        boss = next(rank for rank in family["ranks"] if rank["rank"] == "boss")
        assert boss["recruitment_rule"] in {"boss", "never"}


def test_manifestations_are_never_recruitable_at_any_rank():
    data = load("les_veilleurs_bestiary_rank_ladders.json")
    family = next(item for item in data["families"] if item["family_id"] == "manifestations_destructrices")
    assert family["recruitment_override"] == "never_recruitable"
    assert all(rank["recruitment_rule"] == "never" for rank in family["ranks"])


def test_new_family_vectors_match_locked_recruitment_contract():
    recruitment = load("les_veilleurs_enemy_recruitment.json")
    valid = {item["id"] for item in recruitment["recruitment_vectors"]}
    data = load("les_veilleurs_bestiary_missing_roles.json")
    for family in data["families"]:
        assert set(family["recruitment_vectors"]) <= valid, family["id"]
    ladders = load("les_veilleurs_bestiary_rank_ladders.json")
    for family in ladders["families"]:
        common = next(rank for rank in family["ranks"] if rank["rank"] == "common")
        if family["family_id"] != "manifestations_destructrices":
            assert set(common["recruitment_vectors"]) <= valid, family["family_id"]


def test_loader_combines_sources_and_exposes_rank_queries():
    loader = (ROOT / "scripts/core/data_loader.gd").read_text(encoding="utf-8")
    for token in (
        'res://data/canon/les_veilleurs_bestiary_missing_roles.json',
        'res://data/canon/les_veilleurs_bestiary_rank_ladders.json',
        'func les_veilleurs_normalize_recruitment_vector_id(',
        '"common_interest":',
        'return "interest"',
        '"constrained_bond":',
        'return "binding"',
        'func les_veilleurs_bestiary_rank_rule(',
        'func les_veilleurs_bestiary_rank_ladder(',
        'func les_veilleurs_bestiary_rank(',
        'func les_veilleurs_bestiary_rank_order(',
    ):
        assert token in loader
