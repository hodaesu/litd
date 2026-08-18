import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _data():
    return json.loads((ROOT / "data/levels/chapter_01_vertical_slice.json").read_text())


def test_chapter_one_vertical_slice_has_complete_eight_stage_loop():
    data = _data()
    stages = data["stages"]
    assert data["chapter_id"] == "chapter_01_ashlands"
    assert data["start_zone"] == "zone_01_faubourg_cendreux"
    assert len(stages) == 8
    assert [stage["type"] for stage in stages] == ["exploration", "rescue", "campfire", "creature", "miniboss", "investigation", "boss", "return"]


def test_vertical_slice_covers_core_gameplay_pillars():
    data = _data(); by_id = {stage["id"]: stage for stage in data["stages"]}
    assert by_id["c01_stage_03_campfire"]["completion"]["campfire_used"] == "zone_03_moulin_calcine"
    assert by_id["c01_stage_04_creature"]["completion"]["creature_recruited_min"] == 1
    assert by_id["c01_stage_05_miniboss"]["completion"]["encounter_cleared"] == "c01_miniboss_warden"
    assert by_id["c01_stage_06_marker"]["completion"]["zone_discovered"] == "zone_10_hameau_deserte"
    assert by_id["c01_stage_06_marker"]["completion"]["lore_min"] == 3


def test_ash_witness_is_narrative_boss_with_three_phases_and_three_outcomes():
    data = _data(); boss = data["boss"]
    assert boss["name"] == "Le Témoin des Cendres"
    assert len(boss["phases"]) == 3
    boss_stage = next(stage for stage in data["stages"] if stage["id"] == "c01_stage_07_witness")
    assert {choice["id"] for choice in boss_stage["boss_choices"]} == {"finish", "stabilize", "memory"}
    assert boss["signature"] == "Dernier Souvenir du Jour"


def test_vertical_slice_is_autoloaded_reset_saved_and_visible_in_journal():
    project = (ROOT / "project.godot").read_text(); game_state = (ROOT / "scripts/core/game_state.gd").read_text(); save = (ROOT / "scripts/core/save_manager.gd").read_text(); journal = (ROOT / "scripts/ui/quest_journal_ui.gd").read_text()
    assert 'Chapter01Runtime="*res://scripts/world/chapter_01_runtime.gd"' in project
    assert "Chapter01Runtime.reset_new_game()" in game_state
    assert 'SAVE_VERSION := "0.21"' in save
    assert '"chapter_01": Chapter01Runtime.serialize()' in save
    assert "PROGRESSION DU CHAPITRE I" in journal


def test_chapter_boss_identity_and_three_phases_reach_combat_runtime():
    bridge = (ROOT / "scripts/world/ashlands_combat_bridge.gd").read_text(); boss_runtime = (ROOT / "scripts/world/chapter_01_boss_runtime.gd").read_text()
    assert 'encounter_id == "c01_boss_ash_witness"' in bridge
    assert 'e["name"] = "Le Témoin des Cendres"' in bridge
    assert "ratio <= 0.60" in boss_runtime
    assert "ratio <= 0.25" in boss_runtime


def test_exploration_hud_is_hidden_but_lore_reader_remains_contextual():
    hud = (ROOT / "scripts/world/ashlands_hud.gd").read_text()
    assert "margin.visible = false" in hud
    assert 'overlay.name = "LoreReader"' in hud


def test_archive_scope_keeps_exploration_optional_beyond_required_clues():
    archive_targets = _data()["archive_targets"]
    assert archive_targets["minimum_for_stage"] == 3
    assert archive_targets["full_level_collection"] == 40
