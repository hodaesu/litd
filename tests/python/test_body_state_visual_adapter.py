from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def test_visual_adapter_supports_animation_tree_and_procedural_fallback():
    code = (ROOT / "scripts/visual/body_state_visual_adapter.gd").read_text(encoding="utf-8")
    assert "AnimationTree" in code
    assert "AnimationNodeStateMachinePlayback" in code
    assert "procedural_preview_enabled" in code
    assert "_find_pose_target" in code
    assert "_apply_animation_tree_parameters" in code

def test_visual_adapter_receives_all_body_layers():
    code = (ROOT / "scripts/visual/body_state_visual_adapter.gd").read_text(encoding="utf-8")
    for key in ["psychological_state","physical_state","locomotion_state","relation_state"]:
        assert key in code
    for blend in ["fear_blend","madness_blend","injury_blend","stride_scale"]:
        assert blend in code

def test_visual_slice_controller_is_connected_to_body_adapter():
    code = (ROOT / "scripts/visual/visual_slice_animation_controller.gd").read_text(encoding="utf-8")
    assert "BodyStateVisualAdapter" in code
    assert "update_body_state" in code
    assert "set_hit_reaction" in code
    assert "body_adapter.set_action" in code

def test_runtime_updates_visible_bodies_after_damage_and_psychology():
    code = (ROOT / "scripts/visual/visual_slice_runtime.gd").read_text(encoding="utf-8")
    assert "_sync_body_states" in code
    assert "set_actor_psychology" in code
    assert "darius_fear" in code
    assert "ghoul_fear" in code
