#!/usr/bin/env python3
"""Final static gate for the P0 animation production handoff v50."""
from __future__ import annotations

from pathlib import Path

from tools.pipeline.run_p0_animation_pipeline_v50 import build_plan

ROOT = Path(__file__).resolve().parents[2]


def audit() -> list[str]:
    errors: list[str] = []
    plan = build_plan(ROOT, "__missing_blender_for_ci__", "__missing_godot_for_ci__")
    if int(plan.get("version", 0)) != 50:
        errors.append("pipeline plan version must be 50")
    if plan.get("source_versions") != [46, 47, 48, 49]:
        errors.append("v50 must chain v46 -> v47 -> v48 -> v49")
    if int(plan.get("bundle_count", 0)) != 12:
        errors.append("v50 must execute 12 export/import bundles")
    if int(plan.get("master_clip_count", 0)) != 320:
        errors.append("v50 must cover exactly 320 P0 master clips")
    if len(plan.get("phases", [])) != 6:
        errors.append("v50 must declare all six execution phases")
    if len(plan.get("definition_of_done", [])) < 8:
        errors.append("v50 definition of done is incomplete")
    if plan.get("pc_ready") is not False:
        errors.append("CI sentinel tools must not report PC-ready")
    if plan.get("blocker_code") != "PC_ART_ASSETS_OR_TOOLS_REQUIRED":
        errors.append("missing local art/tools must be an explicit blocker, never faked")
    required_scripts = [
        "tools/blender/animation_export_bundle_v48.py",
        "tools/blender/run_animation_export_v48.py",
        "tools/godot/animation_import_validator_v49.gd",
        "tools/pipeline/run_p0_animation_pipeline_v50.py",
    ]
    for path in required_scripts:
        if not (ROOT / path).exists():
            errors.append(f"required pipeline script missing: {path}")
    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"V50_AUDIT_ERROR: {error}")
        return 1
    plan = build_plan(ROOT, "__missing_blender_for_ci__", "__missing_godot_for_ci__")
    print(
        "P0_ANIMATION_PIPELINE_V50_AUDIT_OK "
        f"bundles={plan['bundle_count']} clips={plan['master_clip_count']} "
        f"blocker={plan['blocker_code']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
