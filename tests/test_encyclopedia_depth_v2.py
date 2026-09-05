from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LORE = ROOT / "universe" / "lore"


def load(name: str):
    with (LORE / name).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def test_encyclopedia_depth_v2_counts_and_guards() -> None:
    manifest = load("encyclopedia_depth_v2_manifest.json")
    families = load("political_families_genealogies.json")
    living = load("living_world_npcs_microhistory.json")
    languages = load("language_depth_v2.json")
    culture = load("cultural_depth_v2.json")
    bestiary = load("bestiary_depth_v2.json")
    quests = load("quest_seed_library_v2.json")

    assert manifest["depth_v2_complete"] is True
    assert manifest["litd2_status"] == "paused_no_new_litd2_narrative_in_this_pass"
    assert len(families["families"]) == 18
    assert families["guardrails"]["blood_confers_office"] is False
    assert len(living["npcs"]) == 48
    assert len(living["microhistory"]) == 18
    assert len(languages["languages"]) == 13
    assert sum(len(language["lexicon"]) for language in languages["languages"]) == 195
    assert languages["rules"]["effrie_tribe_language_excluded"] is True
    assert len(culture["martial_micro_lineages"]) == 24
    assert len(culture["artists_and_works"]) == 24
    assert len(culture["recipes"]) == 18
    assert len(culture["festival_programs"]) == 6
    assert len(bestiary["species"]) == 70
    assert len(quests["quests"]) == 36


def test_quest_seeds_are_cross_domain_and_persistent() -> None:
    quests = load("quest_seed_library_v2.json")
    for quest in quests["quests"]:
        assert len(quest["sources"]) >= 2
        assert len(quest["paths"]) >= 3
        assert quest["remanence"]
