from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_every_starter_hero_has_original_voice_profile() -> None:
    heroes = _load("data/heroes.json")
    profiles = _load("data/voice_profiles.json")
    hero_ids = {str(item["id"]) for item in heroes}
    profile_ids = {str(item["hero_id"]) for item in profiles["profiles"]}
    assert hero_ids <= profile_ids
    assert all("fourth_wall_style" in item for item in profiles["profiles"])
    assert "acteur" not in json.dumps(profiles, ensure_ascii=False).lower()


def test_fourth_wall_is_rare_bounded_and_noncritical() -> None:
    data = _load("data/reactive_dialogues.json")
    policy = data["fourth_wall"]
    assert 1 <= int(policy["max_per_expedition"]) <= 2
    assert int(policy["minimum_gap_events"]) >= 6
    assert float(policy["default_probability"]) <= 0.08
    assert policy["never_for_critical_story_information"] is True
    assert policy["never_replace_death_silence"] is True

    meta = [line for line in data["lines"] if line.get("fourth_wall")]
    assert len(meta) >= 10
    assert {line.get("meta_level") for line in meta} >= {"fissure", "direct", "abyssal"}
    assert all(line.get("event") != "critical_story" for line in meta)
    assert all(line.get("speaker_id") != "narrator" for line in meta)


def test_dialogue_contract_protects_permadeath_story() -> None:
    data = _load("data/reactive_dialogues.json")
    rules = data["rules"]
    assert rules["critical_story_never_depends_on_mortal_hero"] is True
    assert rules["dead_speakers_forbidden"] is True
    assert rules["hero_death_removes_unique_voice"] is True
    assert rules["fallback_order"] == ["specific_hero", "compatible_hero", "narration", "silence"]
    assert rules["runtime_text_is_authored_not_generated"] is True

    critical = [line for line in data["lines"] if line.get("event") == "critical_story"]
    assert critical
    assert all(line.get("speaker_id") == "narrator" for line in critical)
    assert all(line.get("critical_safe") is True for line in critical)


def test_fourth_wall_lines_keep_dark_tone_and_distinct_voices() -> None:
    data = _load("data/reactive_dialogues.json")
    meta = [line for line in data["lines"] if line.get("fourth_wall")]
    speakers = {line["speaker_id"] for line in meta}
    assert {"aurelien", "malvor", "lysandra", "darius"} <= speakers
    joined = " ".join(str(line["text"]) for line in meta).lower()
    assert "code source" not in joined
    assert "bouton start" not in joined
    assert "interface" not in joined
    assert "deuxième corps" in joined
    assert "nous ne recommençons pas" in joined
