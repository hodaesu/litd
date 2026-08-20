from __future__ import annotations

from pathlib import Path

import pytest

from tools.voice.build_voice_direction_registry import build_registry
from tools.voice.openvoice_v2_pipeline import build_plan
from tools.voice.voice_take_review import build_template, validate

ROOT = Path(__file__).resolve().parents[1]


def test_registry_covers_demo_and_reactive_dialogues() -> None:
    registry = build_registry(ROOT)
    ids = {entry["line_id"] for entry in registry["entries"]}
    assert "demo_darius_ash_01" in ids
    assert "demo_narration_end" in ids
    assert "aur_discovery_01" in ids
    assert "fw_dar_abyss_02" in ids
    assert registry["entry_count"] == len(ids)


def test_demo_lines_have_explicit_direction() -> None:
    registry = build_registry(ROOT)
    demo = [entry for entry in registry["entries"] if entry["source"].startswith("data/demo_content_pack.json")]
    assert len(demo) == 12
    assert all(entry["direction_origin"] == "explicit_override" for entry in demo)
    assert all(entry["delivery_note"] for entry in demo)
    assert all(entry["emotion"] for entry in demo)


def test_intensity_five_is_always_manual() -> None:
    registry = build_registry(ROOT)
    extreme = [entry for entry in registry["entries"] if entry["intensity"] == 5]
    assert extreme
    assert all(entry["manual_review"] is True for entry in extreme)


def test_openvoice_plan_embeds_direction_and_speed_only_backend_control() -> None:
    plan = build_plan(ROOT)
    assert plan["version"] == 2
    assert plan["emotional_direction"]["enabled"] is True
    assert any(entry["line_id"] == "demo_darius_guard_01" for entry in plan["entries"])
    for entry in plan["entries"]:
        direction = entry["voice_direction"]
        assert direction["backend_controls"]["directly_applied"] == ["speed"]
        assert 0.65 <= entry["delivery"]["speed"] <= 1.25
        assert "pitch_bias" in direction["prosody"]
        assert entry["delivery"]["direction"]


def test_narration_is_directed_but_not_cloned_in_openvoice_plan() -> None:
    registry = build_registry(ROOT)
    plan = build_plan(ROOT)
    assert any(entry["speaker_id"] == "narration" for entry in registry["entries"])
    assert all(entry["speaker_id"] != "narration" for entry in plan["entries"])
    assert all(entry["speaker_id"] != "narrator" for entry in plan["entries"])


def test_calibration_corpus_is_valid_and_template_is_unapproved() -> None:
    assert validate(ROOT) == []
    template = build_template(ROOT)
    assert len(template["takes"]) >= 20
    assert all(take["approved"] is False for take in template["takes"])
    assert all(all(value is None for value in take["scores"].values()) for take in template["takes"])


def test_stress_words_are_validated() -> None:
    # The real registry build itself validates every authored stress phrase against its text.
    registry = build_registry(ROOT)
    directed = next(entry for entry in registry["entries"] if entry["line_id"] == "demo_darius_ghoul_01")
    assert "sortie" in directed["stress_words"]
    assert directed["emotion"] == "curiosity_wary"
