import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_main_campaign_has_ten_ordered_chapters_with_quests_and_bosses():
    data = json.loads((ROOT / "data/world/main_campaign.json").read_text())
    chapters = data["chapters"]
    assert len(chapters) == 10
    assert [chapter["number"] for chapter in chapters] == list(range(1, 11))
    assert chapters[2]["id"] == "chapter_03_threshold"
    assert chapters[2]["unlock"] == "chapter_04_first_rupture"
    assert chapters[3]["id"] == "chapter_04_first_rupture"
    assert chapters[3]["unlock"] == "chapter_05_great_closure"


def test_campaign_is_autoloaded_reset_saved_and_shown_in_journal():
    project = (ROOT / "project.godot").read_text(); game_state = (ROOT / "scripts/core/game_state.gd").read_text(); save = (ROOT / "scripts/core/save_manager.gd").read_text(); journal = (ROOT / "scripts/ui/quest_journal_ui.gd").read_text()
    assert 'CampaignState="*res://scripts/core/campaign_state.gd"' in project
    assert "CampaignState.reset_new_game()" in game_state
    assert 'SAVE_VERSION := "0.23"' in save
    assert '"campaign": CampaignState.serialize()' in save
    assert "CampaignState.current_chapter()" in journal


def test_final_chapter_keeps_non_binary_resolution():
    data = json.loads((ROOT / "data/world/main_campaign.json").read_text())
    boss = data["chapters"][-1]["bosses"][0]
    assert boss["name"] == "La Rupture Commune"
    assert "crise" in boss["truth"].lower()
