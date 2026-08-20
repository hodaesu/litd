#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from tools.blender.build_vertical_slice import build_plan, validate_contract

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    assert validate_contract() == []
    config = json.loads((ROOT / "data/blender/vertical_slice_automation.json").read_text(encoding="utf-8"))
    assert config["approval_gate"]["required"] is True
    assert config["lod_ratios"]["lod0"] > config["lod_ratios"]["lod1"] > config["lod_ratios"]["lod2"]
    required_files = [
        "tools/blender/build_vertical_slice.py",
        "tools/blender/build_vertical_slice_arena.py",
        "tools/blender/auto_rig_litd.py",
        "tools/blender/validate_asset.py",
        "tools/blender/generate_lods.py",
        "tools/blender/optimize_for_mobile.py",
        "tools/blender/retarget_animations.py",
        "tools/blender/render_turntable_batch.py",
        "tools/blender/publish_to_godot.py",
        "tools/blender/vertical_slice_final_report.py",
        "tools/godot/capture_vertical_slice.py",
        "tools/godot/profile_vertical_slice.py",
        "scripts/visual/visual_slice_capture_runner.gd",
        "scripts/visual/visual_slice_profile_runner.gd",
    ]
    for rel in required_files:
        assert (ROOT / rel).exists(), rel
    plan = build_plan()
    ids = [stage["id"] for stage in plan]
    assert ids.index("art_review") < ids.index("publish_darius") < ids.index("capture_godot") < ids.index("final_report")
    assert sum(1 for stage in plan if stage["id"].startswith("publish_")) == 3
    print("VERTICAL_SLICE_AUTOMATION_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
