from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_layered_music_profiles_cover_adaptive_cues() -> None:
    payload = json.loads((ROOT / "data/adaptive_music_layers.json").read_text(encoding="utf-8"))
    assert payload["version"] >= 1
    assert payload["layer_order"] == ["pulse", "percussion", "strings", "choir", "crisis"]
    profiles = payload["profiles"]
    assert set(profiles) == {
        "exploration_ashlands",
        "exploration_ruins",
        "exploration_threat",
        "combat_normal",
        "combat_elite",
        "combat_boss",
    }
    for profile in profiles.values():
        assert profile["duration_seconds"] > 0
        assert profile["tempo_hz"] > 0
        assert len(profile["frequencies"]) >= 3
        for layer_id in payload["layer_order"]:
            layer = profile["layers"][layer_id]
            assert 0 <= layer["exit"] <= layer["enter"] <= 1
            assert -80 < layer["db"] <= 0


def test_training_scenarios_define_orchestration_expectations() -> None:
    training = json.loads((ROOT / "data/adaptive_music_training.json").read_text(encoding="utf-8"))
    assert training["version"] >= 2
    scenarios = training["scenarios"]
    assert len(scenarios) >= 14
    for scenario in scenarios:
        assert "layers" in scenario["expect"]
    crisis = next(item for item in scenarios if item["id"] == "combat_normal_party_crisis")
    assert crisis["expect"]["layers"] == ["pulse", "percussion", "strings", "choir", "crisis"]
    boss = next(item for item in scenarios if item["id"] == "boss_final_phase_crisis")
    assert boss["expect"]["layers"][-1] == "crisis"


def test_runtime_keeps_stems_running_and_uses_two_banks() -> None:
    runtime = (ROOT / "scripts/core/layered_music_runtime.gd").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    godot_ci = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    assert 'LayeredMusicRuntime="*res://scripts/core/layered_music_runtime.gd"' in project
    assert "preview_layer_ids" in runtime
    assert "player.play(0.0)" in runtime
    assert "_banks" in runtime and "range(2)" in runtime
    assert "cue_generation" in runtime
    assert "narrative_override" in runtime
    assert "layered_music_smoke.tscn" in godot_ci
