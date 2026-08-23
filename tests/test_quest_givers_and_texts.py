import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUESTS = json.loads((ROOT / "data" / "quests.json").read_text(encoding="utf-8"))
GIVERS = json.loads((ROOT / "data" / "quest_givers.json").read_text(encoding="utf-8"))["quest_givers"]
NARRATIVE = (ROOT / "scripts" / "core" / "narrative_library.gd").read_text(encoding="utf-8")
JOURNAL = (ROOT / "scripts" / "ui" / "quest_journal_ui.gd").read_text(encoding="utf-8")
MENU = (ROOT / "scripts" / "ui" / "game_menu_ui.gd").read_text(encoding="utf-8")

def test_every_first_map_quest_has_a_real_giver():
    giver_ids = {giver["id"] for giver in GIVERS}
    assert len(GIVERS) >= 7
    for quest in QUESTS:
        assert quest["quest_giver_id"] in giver_ids
    assert "vara_kesh" in giver_ids
    for giver in GIVERS:
        for field in ["name", "role", "location", "personality", "history", "voice"]:
            assert giver.get(field)

def test_every_quest_has_complete_dialogue_states():
    for quest in QUESTS:
        narrative = quest["narrative"]
        assert narrative["hook"]
        assert len(narrative["offer_lines"]) >= 2
        assert narrative["player_accept"]
        assert narrative["player_decline"]
        assert len(narrative["progress_lines"]) >= 2
        assert len(narrative["completion_lines"]) >= 2
        assert narrative["failure_line"]

def test_every_objective_has_player_facing_text():
    for quest in QUESTS:
        for objective in quest["objectives"]:
            assert objective["journal_text"]
            assert objective["journal_text"] != objective["id"]

def test_narrative_library_exposes_givers_dialogues_and_objectives():
    assert 'const QUEST_GIVERS_PATH := "res://data/quest_givers.json"' in NARRATIVE
    for function in ["quest_giver", "quest_giver_for", "quest_dialogue_lines", "quest_objective_text"]:
        assert f"func {function}" in NARRATIVE

def test_both_journals_show_the_quest_giver():
    assert "NarrativeLibrary.quest_giver_for(quest)" in JOURNAL
    assert "NarrativeLibrary.quest_objective_text(objective)" in JOURNAL
    assert 'NarrativeLibrary.quest_giver("vara_kesh")' in JOURNAL
    assert "NarrativeLibrary.quest_giver_for(quest)" in MENU
