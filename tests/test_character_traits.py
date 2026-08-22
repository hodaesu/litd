import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "data" / "character_traits.json").read_text(encoding="utf-8"))

def test_trait_caps_and_starter_tradeoff():
    assert DATA["max_positive"] == 2
    assert DATA["max_negative"] == 2
    assert DATA["starter_rules"]["manual_choice"] is True
    assert DATA["starter_rules"]["two_positive_requires_negative"] == 1

def test_random_traits_are_saved_not_rerolled():
    rules = DATA["random_rules"]
    assert rules["deterministic_from_character_seed"] is True
    assert rules["no_reroll_after_save"] is True
    assert rules["maximum_positive"] == 2
    assert rules["maximum_negative"] == 2

def test_arachnophobia_becomes_arachnid_fighter():
    negative = next(x for x in DATA["negatives"] if x["id"] == "arachnophobia")
    assert negative["evolution"]["exposure"] == "arachnid"
    assert negative["evolution"]["evolves_to"] == "arachnid_fighter"
    positive = next(x for x in DATA["positives"] if x["id"] == "arachnid_fighter")
    assert positive["name"] == "Combattant d’arachnides"
    assert positive["effects"]["damage_vs_arachnid"] > 0

def test_all_evolutions_target_positive_traits():
    positive_ids = {x["id"] for x in DATA["positives"]}
    for trait in DATA["negatives"]:
        evolution = trait.get("evolution")
        if evolution:
            assert evolution["threshold"] > 0
            assert evolution["evolves_to"] in positive_ids

def test_evolution_preserves_positive_cap():
    rules = DATA["evolution_rules"]
    assert rules["negative_is_removed"] is True
    assert rules["positive_cap_is_preserved"] is True
    assert rules["when_positive_slots_full"] == "ask_player_which_positive_to_replace"
    assert rules["no_automatic_player_trait_deletion"] is True
