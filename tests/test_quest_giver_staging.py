import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
GIVERS = json.loads((ROOT / "data" / "quest_givers.json").read_text(encoding="utf-8"))["quest_givers"]
PRESENTATION = (ROOT / "scripts" / "ui" / "quest_giver_presentation.gd").read_text(encoding="utf-8")
JOURNAL = (ROOT / "scripts" / "ui" / "quest_journal_ui.gd").read_text(encoding="utf-8")
MENU = (ROOT / "scripts" / "ui" / "game_menu_ui.gd").read_text(encoding="utf-8")

def test_quest_giver_presentation_is_registered():
    assert 'QuestGiverPresentation="*res://scripts/ui/quest_giver_presentation.gd"' in PROJECT
    assert "extends CanvasLayer" in PRESENTATION

def test_every_quest_giver_has_a_unique_body_contract():
    postures = set()
    gestures = set()
    for giver in GIVERS:
        profile = giver["body_profile"]
        staging = giver["staging"]
        for field in ["posture", "stance_height", "lean", "gesture", "tempo", "stillness", "orientation", "distance", "asymmetry"]:
            assert field in profile
        for state in ["idle", "offered", "active", "completed", "failed", "camera", "blender_status"]:
            assert staging.get(state)
        postures.add(profile["posture"])
        gestures.add(profile["gesture"])
    assert len(postures) == len(GIVERS)
    assert len(gestures) == len(GIVERS)

def test_giver_cards_have_entrance_idle_focus_and_dialogue_staging():
    for function in ["bind_card", "open_dialogue", "_apply_profile", "_emphasize", "_stage_dialogue_entrance"]:
        assert f"func {function}" in PRESENTATION
    assert "create_tween().set_loops()" in PRESENTATION
    assert 'staging.get(state, staging.get("idle", ""))' in PRESENTATION
    assert "get_tree().paused" not in PRESENTATION

def test_journals_open_staged_giver_encounters():
    assert "QuestGiverPresentation.bind_card(giver_button, giver" in JOURNAL
    assert "QuestGiverPresentation.open_dialogue(g, q" in JOURNAL
    assert "QuestGiverPresentation.bind_card(bounty_button, bounty_giver" in JOURNAL
    assert "QuestGiverPresentation.open_dialogue(bounty_giver, bounty_dialogue" in JOURNAL
    assert "QuestGiverPresentation.bind_card(giver_button, giver" in MENU
    assert "QuestGiverPresentation.open_dialogue(g, q" in MENU

def test_dialogue_scene_uses_written_quest_lines():
    assert "NarrativeLibrary.quest_dialogue_lines(quest, state)" in PRESENTATION
    assert "NarrativeLibrary.quest_state_text(quest, state)" in PRESENTATION
    assert 'narrative.get("player_accept", "")' in PRESENTATION
    assert 'narrative.get("player_decline", "")' in PRESENTATION
