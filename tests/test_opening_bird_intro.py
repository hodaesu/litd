from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "data" / "cinematics" / "opening_bird_intro.json"
DIRECTOR_PATH = ROOT / "scripts" / "cinematics" / "opening_bird_intro_director.gd"
BUILDER_PATH = ROOT / "scripts" / "world" / "ashlands_blockout_builder.gd"


def _contract() -> dict:
    return json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))


def test_opening_is_continuous_bird_point_of_view() -> None:
    data = _contract()
    assert data["point_of_view"]["camera"] == "first_person_bird"
    assert data["point_of_view"]["continuous_until_occlusion"] is True
    assert data["handoff"]["same_scene_required"] is True
    assert data["handoff"]["load_screen"] is False
    assert data["handoff"]["mask_event"] == "hero_hand_full_occlusion"


def test_opening_route_presents_core_lore_through_world_actions() -> None:
    data = _contract()
    route = {entry["id"]: entry for entry in data["lore_route"]}
    assert {
        "cosmopolitan_quarter",
        "arts_square",
        "martial_arena",
        "civic_assembly",
        "three_awakenings",
        "foreign_warning",
        "gate_tower",
    }.issubset(route)
    assert all(entry["meaning"] and entry["world_action"] for entry in route.values())


def test_fall_last_breath_heroes_and_handoff_are_authored() -> None:
    data = _contract()
    beats = {beat["id"] for beat in data["beats"]}
    assert {"shockwave", "impact", "last_breath", "heroes_approach", "compassion_choice", "handoff"}.issubset(beats)
    assert data["handoff"]["audio_bridge"] == "bird_last_exhale_to_ash_wind"
    assert "healing_capability" in data["approach_selection"]["priority"]


def test_opening_supports_comfort_skip_and_replay() -> None:
    data = _contract()
    comfort = data["point_of_view"]["comfort"]
    assert comfort["no_permanent_bobbing"] is True
    assert comfort["roll_degrees_max"] <= 7
    assert comfort["reduced_motion_path"] is True
    accessibility = data["accessibility"]
    assert accessibility["skippable"] is True
    assert accessibility["skip_requires_confirmation"] is True
    assert accessibility["replay_from_journal"] is True


def test_runtime_locks_only_party_controls_and_returns_to_exploration_camera() -> None:
    runtime = DIRECTOR_PATH.read_text(encoding="utf-8")
    assert 'const INTRO_FLAG := "opening_bird_intro_seen"' in runtime
    assert "_set_party_controls(false)" in runtime
    assert "_set_party_controls(true)" in runtime
    assert "exploration_camera.make_current()" in runtime
    assert 'HUDDirector.set_screen_context("exploration")' in runtime
    assert 'CampaignState.set_chapter_flag(INTRO_FLAG, true)' in runtime
    assert "get_tree().change_scene_to_file" not in runtime


def test_first_zone_injects_opening_only_once() -> None:
    builder = BUILDER_PATH.read_text(encoding="utf-8")
    assert 'OPENING_BIRD_INTRO := preload("res://scripts/cinematics/opening_bird_intro_director.gd")' in builder
    assert 'zone_id != "zone_01_faubourg_cendreux"' in builder
    assert 'CampaignState.chapter_flags.get("opening_bird_intro_seen", false)' in builder
    assert "_build_opening_intro()" in builder
