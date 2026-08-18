import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_political_data_has_three_playable_first_level_decisions():
    data = json.loads((ROOT / "data/levels/ashlands_politics.json").read_text())
    quests = {quest["id"]: quest for quest in data["quests"]}
    assert set(quests) == {"ashlands_refugee_gate", "ashlands_first_blood", "ashlands_conscious_creature"}


def test_political_runtime_and_save_contracts():
    runtime = (ROOT / "scripts/core/political_state.gd").read_text()
    save_manager = (ROOT / "scripts/core/save_manager.gd").read_text()
    assert "func refresh_unlocks()" in runtime
    assert "func serialize()" in runtime
    assert "func deserialize(payload: Dictionary)" in runtime
    assert 'SAVE_VERSION := "0.25"' in save_manager
    assert '"politics": PoliticalState.serialize()' in save_manager
    expedition_load = save_manager.index('GameState.expedition_room = int(payload.get("expedition_room",0))')
    politics_load = save_manager.index('PoliticalState.deserialize(payload.get("politics",{}))')
    assert expedition_load < politics_load
