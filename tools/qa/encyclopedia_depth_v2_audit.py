from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LORE = ROOT / "universe" / "lore"


def load(name: str):
    with (LORE / name).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    manifest = load("encyclopedia_depth_v2_manifest.json")
    families = load("political_families_genealogies.json")
    npcs = load("living_world_npcs_microhistory.json")
    languages = load("language_depth_v2.json")
    culture = load("cultural_depth_v2.json")
    bestiary = load("bestiary_depth_v2.json")
    quests = load("quest_seed_library_v2.json")

    require(manifest.get("depth_v2_complete") is True, "Depth V2 must be declared complete")
    require(manifest.get("litd2_status") == "paused_no_new_litd2_narrative_in_this_pass", "LITD2 pause guard missing")

    require(len(families.get("families", [])) == 18, "Expected 18 political family networks")
    require(families.get("guardrails", {}).get("blood_confers_office") is False, "No hereditary office by blood")
    require(families.get("guardrails", {}).get("family_is_ethnicity") is False, "Family must not equal ethnicity")

    require(len(npcs.get("npcs", [])) == 48, "Expected 48 named ordinary NPCs")
    require(len(npcs.get("microhistory", [])) == 18, "Expected 18 microhistory events")
    for npc in npcs.get("npcs", []):
        for key in ("role", "daily_detail", "tension", "hook", "post_fall"):
            require(bool(npc.get(key)), f"NPC {npc.get('id')} missing {key}")

    lang_entries = languages.get("languages", [])
    require(len(lang_entries) == 13, "Expected 13 spoken varieties")
    lexeme_count = sum(len(item.get("lexicon", [])) for item in lang_entries)
    require(lexeme_count == 195, f"Expected 195 core lexemes, got {lexeme_count}")
    require(languages.get("rules", {}).get("effrie_tribe_language_excluded") is True, "Effrie language must remain protected")
    require(languages.get("rules", {}).get("nonhuman_languages_excluded") is True, "Nonhuman languages must remain open")

    require(len(culture.get("martial_micro_lineages", [])) == 24, "Expected 24 martial micro-lineages")
    require(len(culture.get("artists_and_works", [])) == 24, "Expected 24 artists/works")
    require(len(culture.get("recipes", [])) == 18, "Expected 18 recipes")
    require(len(culture.get("festival_programs", [])) == 6, "Expected six festival programs")
    require(culture.get("rules", {}).get("litd2_mature_forms_retrojected") is False, "Mature culture must not be retrojected into LITD2")

    species = bestiary.get("species", [])
    require(len(species) == 70, f"Expected 70 new bestiary entries, got {len(species)}")
    allowed_origins = set(bestiary.get("origin_categories", []))
    for entry in species:
        require(entry.get("origin"), f"Species {entry.get('id')} missing origin evidence")
        for category, _evidence in entry.get("origin", []):
            require(category in allowed_origins, f"Species {entry.get('id')} uses invalid origin {category}")

    quest_entries = quests.get("quests", [])
    require(len(quest_entries) == 36, "Expected 36 encyclopedia-driven quest seeds")
    for quest in quest_entries:
        require(len(quest.get("sources", [])) >= 2, f"Quest {quest.get('id')} must cross at least two lore domains")
        require(len(quest.get("paths", [])) >= 3, f"Quest {quest.get('id')} must have at least three viable paths")
        require(bool(quest.get("remanence")), f"Quest {quest.get('id')} missing remanence")

    expected = manifest.get("counts", {})
    actual = {
        "political_family_networks": len(families.get("families", [])),
        "named_ordinary_npcs": len(npcs.get("npcs", [])),
        "microhistory_events": len(npcs.get("microhistory", [])),
        "spoken_language_varieties": len(lang_entries),
        "core_pronounceable_lexemes": lexeme_count,
        "martial_micro_lineages": len(culture.get("martial_micro_lineages", [])),
        "artists_and_named_works": len(culture.get("artists_and_works", [])),
        "regional_recipes": len(culture.get("recipes", [])),
        "full_festival_programs": len(culture.get("festival_programs", [])),
        "new_bestiary_entries": len(species),
        "encyclopedia_driven_quest_seeds": len(quest_entries),
    }
    require(expected == actual, f"Manifest counts mismatch: expected={expected} actual={actual}")

    print("Encyclopedia depth V2 audit: PASS")
    for key, value in actual.items():
        print(f"- {key}: {value}")


if __name__ == "__main__":
    main()
