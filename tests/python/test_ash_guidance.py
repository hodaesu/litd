import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_ash_guidance_color_contract():
    config = json.loads((ROOT / "data" / "ash_guidance.json").read_text(encoding="utf-8"))
    assert config["objective_modes"]["boss"]["far_color"] == "#85888D"
    assert config["objective_modes"]["boss"]["near_color"] == "#FF3B1F"
    assert config["objective_modes"]["quest"]["far_color"] == "#85888D"
    assert config["objective_modes"]["quest"]["near_color"] == "#45A8FF"
    assert config["accessibility"]["color_is_not_only_signal"] is True


def test_dungeon_guidance_points_to_route_not_through_walls():
    room = (ROOT / "scripts" / "world" / "dungeon_proxy_room.gd").read_text(encoding="utf-8")
    assert "route_to_boss(room_id, visible_targets)" in room
    assert "_portal_position" in room
    assert 'role == "boss"' in room
    assert 'set_boss_guidance_position' in room


def test_player_guidance_supports_boss_and_quest_modes():
    explorer = (ROOT / "scripts" / "world" / "dungeon_proxy_explorer.gd").read_text(encoding="utf-8")
    assert "set_boss_guidance_position" in explorer
    assert "set_quest_guidance_position" in explorer
    assert "set_quest_guidance_target" in explorer
    assert "AshGuidanceTrail" in explorer


def test_guidance_runtime_uses_swirl_layers_and_proximity():
    trail = (ROOT / "scripts" / "world" / "ash_guidance_trail.gd").read_text(encoding="utf-8")
    assert 'name = "AshWisps"' in trail
    assert 'name = "AshMotes"' in trail
    assert "angular_velocity_min" in trail
    assert "current_proximity" in trail
    assert "near_speed_bonus" in trail
    assert "emission_energy_multiplier" in trail


def test_boss_route_excludes_hidden_secret_rooms():
    policy = (ROOT / "scripts" / "core" / "ash_guidance_policy.gd").read_text(encoding="utf-8")
    assert 'target_room.get("secret", false)' in policy
    assert "shortest_public_path" in policy
    assert "boss_proximity_from_hops" in policy
