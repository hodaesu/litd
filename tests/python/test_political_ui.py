import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_political_data_has_three_playable_first_level_decisions():
    data = json.loads((ROOT / "data/levels/ashlands_politics.json").read_text())
    quests = {quest["id"]: quest for quest in data["quests"]}
    assert set(quests) == {
        "ashlands_refugee_gate",
        "ashlands_first_blood",
        "ashlands_conscious_creature",
    }
    assert quests["ashlands_refugee_gate"]["trigger"]["expedition_room_min"] == 1
    assert quests["ashlands_first_blood"]["trigger"]["quest_completed"] == "ashlands_refugee_gate"
    assert quests["ashlands_conscious_creature"]["trigger"]["recruited_creature_min"] == 1
    assert all(len(quest["choices"]) == 3 for quest in quests.values())


def test_political_runtime_supports_automatic_unlocks_and_persistent_consequences():
    runtime = (ROOT / "scripts/core/political_state.gd").read_text()
    for contract in (
        "func refresh_unlocks()",
        "func _trigger_satisfied(trigger: Dictionary)",
        "GameState.expedition_room",
        "CreatureManager.captured_creatures.size()",
        "func completed_consequence(quest_id: String)",
        "func dialogue_context_for(npc_id: String)",
        "func service_unlocked(service_id: String)",
        "func serialize()",
        "func deserialize(payload: Dictionary)",
    ):
        assert contract in runtime


def test_concord_ui_is_autoloaded_and_exposes_npcs_quests_and_social_state():
    project = (ROOT / "project.godot").read_text()
    ui = (ROOT / "scripts/ui/political_ui.gd").read_text()
    assert 'PoliticalUI="*res://scripts/ui/political_ui.gd"' in project
    assert '"CONCORDE\\nDécisions et habitants"' in ui
    assert "PoliticalState.data.get(\"npcs\", [])" in ui
    assert "PoliticalState.available_quests()" in ui
    assert "PoliticalState.complete_quest" in ui
    assert "PoliticalState.completed_consequence" in ui
    assert "CORPS %d   ·   ESPRIT %d   ·   CITÉ %d" in ui
    assert "PoliticalState.conversation_for" in ui
    assert "PoliticalState.active_rumors" in ui
    assert "PoliticalState.social_factions" in ui


def test_political_save_load_order_restores_progress_before_unlock_calculation():
    save_manager = (ROOT / "scripts/core/save_manager.gd").read_text()
    assert 'SAVE_VERSION := "0.19"' in save_manager
    assert '"politics": PoliticalState.serialize()' in save_manager
    expedition_load = save_manager.index('GameState.expedition_room = int(payload.get("expedition_room", 0))')
    politics_load = save_manager.index('PoliticalState.deserialize(payload.get("politics", {}))')
    assert expedition_load < politics_load


def test_decisions_change_material_and_civic_state_not_only_reputation():
    data = json.loads((ROOT / "data/levels/ashlands_politics.json").read_text())
    for quest in data["quests"]:
        for choice in quest["choices"].values():
            effects = choice["effects"]
            assert "trust" in effects
            assert "tension" in effects
            assert "three_awakenings" in effects
            assert set(effects["three_awakenings"]) == {"body", "spirit", "city"}
            assert choice["consequence"].strip()
