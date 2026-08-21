import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_first_veil_declares_first_descent_reward():
    rules = json.loads((ROOT / "data/roguelike/roguelike_rules.json").read_text())
    challenge = rules["dungeons"]["first_veil_crypts"]["first_descent"]
    assert challenge["enabled"] is True
    assert challenge["title"] == "Celui qui n'a pas remonté"
    assert challenge["relic_name"] == "Éclat du Premier Voile"
    assert challenge["chronicle_title"] == "LA PREMIÈRE DESCENTE"
    assert challenge["reward_policy"] == "commemorative_only_no_required_power"


def test_first_descent_runtime_is_persistent_and_non_farmable():
    text = (ROOT / "scripts/core/first_descent_runtime.gd").read_text()
    assert "attempts_by_dungeon" in text
    assert "attempt_number == 1" in text
    assert 'reason == "boss_defeated"' in text
    assert "not claims.has(dungeon_id)" in text
    assert '"chronicles": chronicles' in text
    assert '"unlocked_titles": unlocked_titles' in text
    assert '"relic_collection": relic_collection' in text
    assert '"achievements": achievements' in text
    assert "GameState.new_game_reset.connect(reset_new_game)" in text


def test_expedition_manager_records_attempt_before_play_and_serializes_it():
    text = (ROOT / "scripts/core/expedition_manager.gd").read_text()
    start_marker = "first_descent_runtime.start_attempt"
    run_marker = "roguelike_runtime.start_run"
    assert start_marker in text
    assert run_marker in text
    assert text.index(start_marker) < text.index(run_marker)
    assert "SaveManager.save_game()" in text
    assert "first_descent_runtime.finish_attempt" in text
    assert '"first_descent": first_descent_runtime.serialize()' in text
    assert 'first_descent_runtime.deserialize(data.get("first_descent", {}))' in text


def test_first_descent_smoke_is_part_of_strict_godot_ci():
    script = (ROOT / "tools/build/run_godot_ci.sh").read_text()
    assert "first_descent_smoke.tscn" in script
