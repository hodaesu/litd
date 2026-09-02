import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_pc_validation_contract_covers_all_pc_only_workstreams():
    plan = load("data/production/pc_validation_plan.json")
    assert plan["version"] == 1
    assert plan["target"]["platform"] == "Windows"
    assert plan["target"]["godot_required_prefix"] == "4.3"
    assert plan["target"]["export_preset"] == "Windows Desktop"

    groups = plan["godot_groups"]
    assert {"foundation", "visual_collision", "controls", "audio"}.issubset(groups)
    for scenes in groups.values():
        assert scenes
        for scene in scenes:
            assert (ROOT / scene).exists(), scene

    manual_ids = {item["id"] for item in plan["manual_acceptance"]}
    assert {
        "visual_review",
        "collision_review",
        "keyboard_mouse",
        "controller",
        "touch_device",
        "audio_listening",
        "windows_performance",
        "blender_art_gate",
    }.issubset(manual_ids)


def test_pc_validation_orchestrator_has_safety_gates_and_outputs():
    plan = load("data/production/pc_validation_plan.json")
    script = (ROOT / "tools/build/pc_validation.py").read_text(encoding="utf-8")
    for token in (
        "PC_VALIDATION_PLAN_OK",
        "PC_VALIDATION_AUTOMATED_OK_MANUAL_REVIEW_REQUIRED",
        "--build-blender",
        "--approve-art",
        "--export-release",
        "automated_passed_manual_pending",
    ):
        assert token in script

    assert "command.append(\"--approve-art\")" in script
    assert "status=\"pending\"" in script
    assert plan["automated_tools"] == {
        "capture": "tools/godot/capture_vertical_slice.py",
        "profile": "tools/godot/profile_vertical_slice.py",
        "blender_preflight": "tools/blender/vertical_slice_session.py",
        "blender_build": "tools/blender/build_vertical_slice.py",
    }


def test_pc_validation_static_contract_is_self_consistent():
    plan = load("data/production/pc_validation_plan.json")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    assert f'config/features=PackedStringArray("{plan["target"]["godot_required_prefix"]}")' in project
    assert f'name="{plan["target"]["export_preset"]}"' in presets
    for tool in plan["automated_tools"].values():
        assert (ROOT / tool).exists(), tool
