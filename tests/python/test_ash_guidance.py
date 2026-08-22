import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_ash_guidance_color_contract():
    config = json.loads((ROOT / "data" / "ash_guidance.json").read_text(encoding="utf-8"))
    assert config["version"] >= 3
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


def test_emotional_guidance_contract_has_fear_danger_and_safety():
    config = json.loads((ROOT / "data" / "ash_guidance.json").read_text(encoding="utf-8"))
    emotion = config["emotion"]
    assert emotion["fear"]["enter"] > emotion["fear"]["exit"]
    assert emotion["major_danger"]["enter"] > emotion["major_danger"]["exit"]
    assert emotion["safe"]["enter"] > emotion["safe"]["exit"]
    assert emotion["direction_fidelity_min"] >= 0.75
    assert config["accessibility"]["emotion_never_reverses_direction"] is True
    assert config["accessibility"]["fear_changes_motion_not_destination"] is True


def test_fear_makes_ash_hesitate_without_changing_objective_axis():
    trail = (ROOT / "scripts" / "world" / "ash_guidance_trail.gd").read_text(encoding="utf-8")
    assert 'emotional_mode == "fearful"' in trail
    assert 'max_spread_bonus_deg' in trail
    assert 'hesitation_hz' in trail
    assert 'side_bias = clampf' in trail
    assert 'look_at(global_position + current_direction' in trail


def test_major_danger_adds_forward_bursts():
    trail = (ROOT / "scripts" / "world" / "ash_guidance_trail.gd").read_text(encoding="utf-8")
    assert 'emotional_mode == "danger"' in trail
    assert '_danger_burst_value' in trail
    assert 'burst_speed_bonus' in trail
    assert 'burst_mote_bonus' in trail
    assert 'forward_spread_reduction_deg' in trail


def test_safe_context_calms_particle_motion():
    trail = (ROOT / "scripts" / "world" / "ash_guidance_trail.gd").read_text(encoding="utf-8")
    assert 'emotional_mode == "safe"' in trail
    assert 'speed_multiplier' in trail
    assert 'spread_multiplier' in trail
    assert 'angular_velocity_multiplier' in trail
    assert 'lifetime_multiplier' in trail


def test_emotions_are_fed_from_party_risk_and_room_context():
    trail = (ROOT / "scripts" / "world" / "ash_guidance_trail.gd").read_text(encoding="utf-8")
    explorer = (ROOT / "scripts" / "world" / "dungeon_proxy_explorer.gd").read_text(encoding="utf-8")
    assert 'hero.get("fear", 0)' in trail
    assert 'ExpeditionManager.current_risk_profile()' in trail
    assert 'configure_environment_for_room' in trail
    assert '_sync_ash_environment_from_parent' in explorer
    assert 'room_spec.get("type", "")' in explorer


def test_dungeon_environment_maps_major_danger_and_safe_rooms():
    config = json.loads((ROOT / "data" / "ash_guidance.json").read_text(encoding="utf-8"))
    danger = config["environment_context"]["danger_floor_by_role"]
    safety = config["environment_context"]["safety_by_room_type"]
    assert danger["boss"] == 1.0
    assert danger["preboss"] >= 0.85
    assert danger["elite"] >= 0.70
    assert safety["camp"] == 1.0
    assert safety["sanctuary"] >= 0.90


def test_ash_guidance_is_request_only_and_timed():
    config = json.loads((ROOT / "data" / "ash_guidance.json").read_text(encoding="utf-8"))
    activation = config["activation"]
    assert activation["request_only"] is True
    assert activation["visible_duration_s"] > 0.0
    trail = (ROOT / "scripts" / "world" / "ash_guidance_trail.gd").read_text(encoding="utf-8")
    assert "func request_guidance" in trail
    assert "reveal_time_remaining" in trail
    assert "_set_emitting(false)" in trail
    assert "_set_emitting(is_guidance_revealed())" in trail


def test_ash_guidance_can_be_requested_by_key_or_touch_double_tap():
    explorer = (ROOT / "scripts" / "world" / "dungeon_proxy_explorer.gd").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'event.is_action_pressed("ash_guidance")' in explorer
    assert "touch.double_tap" in explorer
    assert "_is_in_ash_touch_zone" in explorer
    assert "ash_touch_zone_min_x_ratio" in explorer
    assert "ash_touch_zone_max_y_ratio" in explorer
    assert "ash_guidance=" in project
