import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load_recruitment():
    return json.loads(
        (ROOT / "data/canon/les_veilleurs_enemy_recruitment.json").read_text(encoding="utf-8")
    )


def test_mobile_scope_preserves_four_veilleurs_identity():
    data = load_recruitment()
    scope = data["mobile_scope"]
    assert scope["combat_party_size"] == 4
    assert scope["minimum_veilleurs_per_expedition"] == 2
    assert scope["maximum_enemy_recruits_per_expedition"] == 2
    assert scope["initial_enemy_roster_capacity"] == 3
    assert scope["maximum_enemy_roster_capacity"] == 8


def test_recruitment_is_not_a_gacha_collection_system():
    data = load_recruitment()
    vectors = {item["id"] for item in data["recruitment_vectors"]}
    assert vectors == {"surrender", "persuasion", "debt", "interest", "fear", "binding"}
    anti_collection = " ".join(data["anti_collection_rules"]).lower()
    assert "gacha" in anti_collection
    assert "fusion de doublons" in anti_collection
    assert "posséder toutes les familles" in anti_collection


def test_wounds_have_recruitment_consequences_without_becoming_optimal_abuse():
    data = load_recruitment()
    wounds = data["wounds_and_recruitment"]
    assert "réduit fortement le lien initial" in wounds["lost_part_effect"]
    assert "aucun bonus de capture" in wounds["prohibited_shortcut"]
    assert "cicatrices" in wounds["persistent_outputs"]
    assert "limitations fonctionnelles" in wounds["persistent_outputs"]


def test_recruited_enemy_progression_is_compact_and_distinct_from_heroes():
    data = load_recruitment()
    progression = data["progression"]
    assert progression["family_paths"] == 3
    assert progression["nodes_per_path"] == 5
    assert progression["total_nodes_per_recruitable_family"] == 15
    assert "ne devient pas un héros humain" in progression["principle"]


def test_departure_is_persistent_and_telegraphed_not_random_betrayal():
    data = load_recruitment()
    post = data["post_recruitment"]
    assert "pur jet aléatoire" in post["departure_rule"]
    assert "télégraphié" in post["departure_rule"]
    assert post["death_rule"].startswith("La mort en expédition est persistante")


def test_data_loader_exposes_les_veilleurs_recruitment_runtime_api():
    loader = (ROOT / "scripts/core/data_loader.gd").read_text(encoding="utf-8")
    for token in (
        'res://data/canon/les_veilleurs_enemy_recruitment.json',
        'func les_veilleurs_recruitment_vector(',
        'func les_veilleurs_recruitment_mobile_scope(',
        'func les_veilleurs_recruitment_progression(',
        'func les_veilleurs_recruitment_ui_flow(',
        'func les_veilleurs_recruitment_content_contract(',
    ):
        assert token in loader
