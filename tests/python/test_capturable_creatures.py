import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(name):
    return json.loads((ROOT / "data" / name).read_text())


def test_only_regular_first_level_creatures_are_capturable():
    definitions = _load("capturable_creatures.json")
    enemies = {enemy["id"]: enemy for enemy in _load("enemies.json")}
    assert {definition["enemy_id"] for definition in definitions} == {1, 8, 10}
    assert all(not enemies[definition["enemy_id"]].get("boss", False) for definition in definitions)


def test_creature_runtime_and_save_contracts():
    manager = (ROOT / "scripts/core/creature_manager.gd").read_text()
    save_manager = (ROOT / "scripts/core/save_manager.gd").read_text()
    assert "func serialize()" in manager
    assert "func deserialize(data: Dictionary)" in manager
    assert 'SAVE_VERSION := "0.31"' in save_manager
    assert '"creatures": CreatureManager.serialize()' in save_manager
    assert 'CreatureManager.deserialize(payload.get("creatures",{}))' in save_manager


def test_creatures_share_the_hero_level_cap():
    game_state = (ROOT / "scripts/core/game_state.gd").read_text(); manager = (ROOT / "scripts/core/creature_manager.gd").read_text()
    assert "const MAX_CHARACTER_LEVEL: int = 50" in game_state
    assert "GameState.MAX_CHARACTER_LEVEL" in manager
