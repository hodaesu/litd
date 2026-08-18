import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _data():
    return json.loads((ROOT / "data/levels/chapter_01_vertical_slice.json").read_text())


def test_chapter_one_vertical_slice_has_complete_eight_stage_loop():
    data = _data()
    stages = data["stages"]
    assert data["chapter_id"] == "chapter_01_ashlands"
    assert len(stages) == 8
    assert [stage["type"] for stage in stages] == [
        "exploration", "rescue", "campfire", "creature",
        "miniboss", "investigation", "boss", "return"
    ]


def test_vertical_slice_covers_core_gameplay_pillars():
    data = _data()
    by_id = {stage["id"]: stage for stage in data["stages"]}
    assert by_id["c01_stage_03_campfire"]["completion"]["campfire_used"] == "ashlands_camp"
    assert by_id["c01_stage_04_creature"]["completion"]["creature_recruited_min"] == 1
    assert by_id["c01_stage_05_miniboss"]["completion"]["encounter_cleared"] == "c01_miniboss_warden"
    assert by_id["c01_stage_06_marker"]["completion"]["lore_min"] == 3
    assert by_id["c01_stage_08_return"]["completion"]["political_quests_completed_min"] == 2


def test_ash_witness_is_narrative_boss_with_three_phases_and_three_outcomes():
    data = _data()
    boss = data["boss"]
    assert boss["name"] == "Le Témoin des Cendres"
    assert len(boss["phases"]) == 3
    boss_stage = next(stage for stage in data["stages"] if stage["id"] == "c01_stage_07_witness")
    assert {choice["id"] for choice in boss_stage["boss_choices"]} == {"finish", "stabilize", "memory"}
    assert boss["signature"] == "Dernier Souvenir du Jour"


def test_three_main_chapter_quests_are_bound_to_playable_stages():
    bindings = _data()["main_quest_bindings"]
    assert set(bindings) == {"c01_embers", "c01_first_voices", "c01_broken_marker"}
    assert all(bindings.values())
    bound_stages = {stage_id for stage_ids in bindings.values() for stage_id in stage_ids}
    assert len(bound_stages) == 8


def test_chapter_one_runtime_listens_to_existing_gameplay_and_persists():
    runtime = (ROOT / "scripts/world/chapter_01_runtime.gd").read_text()
    for contract in (
        "AshlandsRuntime.zone_discovered.connect",
        "AshlandsRuntime.encounter_cleared.connect",
        "AshlandsRuntime.campfire_used.connect",
        "AshlandsRuntime.lore_discovered.connect",
        "CreatureManager.creatures_changed.connect",
        "PoliticalState.politics_changed.connect",
        "CampaignState.complete_main_quest",
        "func choose_boss_outcome(choice_id: String)",
        "func serialize()",
        "func deserialize(payload: Dictionary)",
    ):
        assert contract in runtime


def test_vertical_slice_is_autoloaded_reset_saved_and_visible_in_journal():
    project = (ROOT / "project.godot").read_text()
    game_state = (ROOT / "scripts/core/game_state.gd").read_text()
    save = (ROOT / "scripts/core/save_manager.gd").read_text()
    journal = (ROOT / "scripts/ui/quest_journal_ui.gd").read_text()
    assert 'Chapter01Runtime="*res://scripts/world/chapter_01_runtime.gd"' in project
    assert "Chapter01Runtime.reset_new_game()" in game_state
    assert 'SAVE_VERSION := "0.20"' in save
    assert '"chapter_01": Chapter01Runtime.serialize()' in save
    assert 'Chapter01Runtime.deserialize(payload.get("chapter_01", {}))' in save
    assert "PROGRESSION DU CHAPITRE I" in journal
    assert "Chapter01Runtime.active_stage()" in journal
    assert "Chapter01Runtime.choose_boss_outcome" in journal


def test_archive_scope_keeps_exploration_optional_beyond_required_clues():
    archive_targets = _data()["archive_targets"]
    assert archive_targets["minimum_for_stage"] == 3
    assert archive_targets["recommended_in_slice"] >= archive_targets["minimum_for_stage"]
    assert archive_targets["full_level_collection"] == 40
