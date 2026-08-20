from __future__ import annotations

from tools.blender.build_vertical_slice import build_plan, validate_contract
from tools.godot.capture_vertical_slice import command as capture_command
from tools.godot.profile_vertical_slice import command as profile_command


def test_automation_contract_is_complete() -> None:
    assert validate_contract() == []


def test_art_review_blocks_all_publish_and_runtime_validation() -> None:
    plan = build_plan("BLENDER", "GODOT")
    ids = [stage["id"] for stage in plan]
    gate = ids.index("art_review")
    assert ids[:5] == ["preflight", "materials", "build_darius", "build_ghoul", "build_arena"]
    assert ids[-1] == "final_report"
    assert all(stage.get("requires_approval", False) for stage in plan[gate + 1 :])


def test_pipeline_has_three_validated_godot_publications() -> None:
    plan = build_plan("BLENDER", "GODOT")
    publish = [stage for stage in plan if stage["id"].startswith("publish_")]
    assert len(publish) == 3
    targets = [stage["outputs"][0] for stage in publish]
    assert "assets/3d/characters/darius/darius.glb" in targets
    assert "assets/3d/characters/enemies/hungry_ghoul.glb" in targets
    assert "assets/3d/environments/ashlands/vertical_slice_arena.glb" in targets


def test_workstation_capture_and_profile_use_gl_compatibility() -> None:
    assert "gl_compatibility" in capture_command("GODOT")
    assert "gl_compatibility" in profile_command("GODOT")
    assert "--disable-vsync" in profile_command("GODOT")
