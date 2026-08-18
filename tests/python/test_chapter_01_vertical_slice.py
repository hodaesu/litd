import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _data():
    return json.loads((ROOT / "data/levels/chapter_01_vertical_slice.json").read_text())


def test_chapter_one_vertical_slice_has_complete_eight_stage_loop():
    data = _data(); stages = data["stages"]
    assert data["chapter_id"] == "chapter_01_ashlands"
    assert data["start_zone"] == "zone_01_faubourg_cendreux"
    assert len(stages) == 8
    assert [stage["type"] for stage in stages] == ["exploration", "rescue", "campfire", "creature", "miniboss", "investigation", "boss", "return"]


def test_vertical_slice_is_autoloaded_reset_saved_and_visible_in_journal():
    project = (ROOT / "project.godot").read_text(); game_state = (ROOT / "scripts/core/game_state.gd").read_text(); save = (ROOT / "scripts/core/save_manager.gd").read_text(); journal = (ROOT / "scripts/ui/quest_journal_ui.gd").read_text()
    assert 'Chapter01Runtime="*res://scripts/world/chapter_01_runtime.gd"' in project
    assert "Chapter01Runtime.reset_new_game()" in game_state
    assert 'SAVE_VERSION := "0.29"' in save
    assert '"chapter_01": Chapter01Runtime.serialize()' in save
    assert '_stage_header(parent,"CHAPITRE I",Chapter01Runtime)' in journal


def test_ash_witness_contract():
    data = _data(); boss = data["boss"]
    assert boss["name"] == "Le Témoin des Cendres"
    assert len(boss["phases"]) == 3
    assert boss["signature"] == "Dernier Souvenir du Jour"
