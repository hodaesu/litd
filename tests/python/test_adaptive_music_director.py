import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_adaptive_music_runtime_contract():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/core/adaptive_music_director.gd").read_text(encoding="utf-8")
    ci = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    data = json.loads((ROOT / "data/audio_director.json").read_text(encoding="utf-8"))
    training = json.loads((ROOT / "data/adaptive_music_training.json").read_text(encoding="utf-8"))

    assert 'AdaptiveMusicDirector="*res://scripts/core/adaptive_music_director.gd"' in project
    assert "func _combat_decision(" in runtime
    assert "func _exploration_decision(" in runtime
    assert "func _apply_adaptive_mix(" in runtime
    assert "NarrativeAudioDirector.dialogue_state_changed" in runtime
    assert "NarrativeAudioDirector.narrative_beat_started" in runtime
    assert "AshlandsCombatBridge.ashlands_combat_started" in runtime
    assert "AshlandsCombatBridge.ashlands_combat_finished" in runtime
    assert "adaptive_music_smoke.tscn" in ci

    adaptive = data["adaptive_music"]
    assert adaptive["combat_cues"] == {
        "normal": "combat_normal",
        "elite": "combat_elite",
        "miniboss": "combat_elite",
        "boss": "combat_boss",
    }
    assert adaptive["exploration_threat_release"] < adaptive["exploration_threat_enter"]
    assert adaptive["resolution_hold_seconds"] >= 4.0
    assert adaptive["cue_min_hold_seconds"] >= 2.0
    assert data["encounter_music"]["elite"] == "combat_elite"

    scenarios = training["scenarios"]
    assert len(scenarios) >= 12
    ids = {scenario["id"] for scenario in scenarios}
    required = {
        "exploration_calm_ashlands",
        "exploration_darkness_becomes_threat",
        "combat_normal_control",
        "combat_normal_party_crisis",
        "combat_last_enemy_release",
        "combat_elite",
        "combat_miniboss",
        "boss_phase_one",
        "boss_final_phase_crisis",
        "dialogue_never_overridden",
        "scripted_silence_never_overridden",
        "sanctuary_authored_space_priority",
    }
    assert required <= ids


def test_narrative_music_priority_contract():
    training = json.loads((ROOT / "data/adaptive_music_training.json").read_text(encoding="utf-8"))
    narrative = json.loads((ROOT / "data/narrative_audio.json").read_text(encoding="utf-8"))
    audio = json.loads((ROOT / "data/audio_director.json").read_text(encoding="utf-8"))

    contract = training["narrative_contract"]
    beats = narrative["beats"]
    assert beats["revelation"]["music"] == contract["revelation"]
    assert beats["loss"]["music"] == contract["loss"]
    assert beats["reunion"]["music"] == contract["reunion"]
    assert audio["combat_resolution_music"]["victory"] == contract["victory"]
    assert audio["combat_resolution_music"]["defeat"] == contract["defeat"]
    assert contract["dialogue_has_priority"] is True
    assert contract["scripted_silence_has_priority"] is True
