from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "data" / "cinematics" / "opening_bird_intro.json"
DIRECTOR_PATH = ROOT / "scripts" / "cinematics" / "opening_bird_intro_director.gd"
CITY_PATH = ROOT / "scripts" / "cinematics" / "opening_city_proxy_builder.gd"
TUTORIAL_PATH = ROOT / "scripts" / "tutorials" / "opening_exploration_tutorial.gd"
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


def test_opening_route_matches_the_authored_city_sequence() -> None:
    data = _contract()
    route_ids = [entry["id"] for entry in data["lore_route"]]
    assert route_ids == [
        "living_alley", "rooftop_rise", "martial_tournament",
        "arts_workshop", "cinematic_musicians", "political_debate",
        "foreign_fleet", "veil_gate",
    ]
    waypoint_ids = [entry["id"] for entry in data["runtime_waypoints"]]
    required = [
        "living_alley", "children_play", "rooftop_rise", "martial_tournament",
        "arts_entry", "arts_workshop", "cinematic_musicians", "arts_exit",
        "political_debate", "sea_climb", "foreign_fleet", "veil_gate",
        "shockwave", "collision", "fall",
    ]
    assert all(waypoint_ids.index(a) < waypoint_ids.index(b) for a, b in zip(required, required[1:]))


def test_proxy_contains_people_arts_fleet_and_four_heroes() -> None:
    proxy = CITY_PATH.read_text(encoding="utf-8")
    assert "ChildPlaying_%02d" in proxy
    assert "MartialTournament" in proxy
    assert "perform_opening_theme" in proxy
    assert "CivicAssembly" in proxy
    assert "ForeignShip_%02d" in proxy
    assert "for index in range(4):" in proxy
    assert "approach_kneel_close_bird_eyes" in proxy


def test_fall_last_breath_heroes_and_handoff_are_authored() -> None:
    data = _contract()
    beats = {beat["id"] for beat in data["beats"]}
    assert {"shockwave", "impact", "last_breath", "heroes_approach", "compassion_choice", "handoff"}.issubset(beats)
    assert data["handoff"]["audio_bridge"] == "bird_last_exhale_to_ash_wind"


def test_runtime_connects_city_heroes_and_contextual_tutorial() -> None:
    runtime = DIRECTOR_PATH.read_text(encoding="utf-8")
    assert "CITY_PROXY.new()" in runtime
    assert 'beat_id == "shockwave"' in runtime
    assert "city_proxy.hero_group" in runtime
    assert "city_proxy.approach_hero" in runtime
    assert "exploration_camera.make_current()" in runtime
    assert "OPENING_TUTORIAL.new()" in runtime
    assert "get_tree().change_scene_to_file" not in runtime
    tutorial = TUTORIAL_PATH.read_text(encoding="utf-8")
    assert "PROCESS_MODE_ALWAYS" in tutorial
    assert "get_tree().paused" not in tutorial
    assert '"ash_guidance"' in tutorial


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


def test_first_zone_injects_opening_only_once() -> None:
    builder = BUILDER_PATH.read_text(encoding="utf-8")
    assert 'OPENING_BIRD_INTRO := preload("res://scripts/cinematics/opening_bird_intro_director.gd")' in builder
    assert 'zone_id != "zone_01_faubourg_cendreux"' in builder
    assert 'CampaignState.chapter_flags.get("opening_bird_intro_seen", false)' in builder
    assert "_build_opening_intro()" in builder
