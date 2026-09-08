#!/usr/bin/env python3
"""Static safety/coverage gate for the Blender master scaffolder v53."""
from __future__ import annotations

from pathlib import Path

from tools.blender.build_master_scaffold_v53 import ROOT, load_descriptors, validate_descriptors
from tools.blender.run_master_scaffolds_v53 import build_plan

BUILDER = ROOT / "tools/blender/build_master_scaffold_v53.py"
RUNNER = ROOT / "tools/blender/run_master_scaffolds_v53.py"


def audit() -> list[str]:
    errors = list(validate_descriptors())
    descriptors = load_descriptors()
    if len(descriptors) != 12:
        errors.append("v53 must cover exactly 12 masters")
    if [item["order"] for item in descriptors] != list(range(1, 13)):
        errors.append("v53 must preserve production order 1..12")

    for item in descriptors:
        label = item["id"]
        if not item["safe_scaffold_blend"].startswith("art/blender/scaffolds_v53/"):
            errors.append(f"{label}: safe output escaped scaffolds_v53")
        if item["safe_scaffold_blend"] == item["source_blend"]:
            errors.append(f"{label}: safe output equals canonical source")
        if not item["runtime_objects"]:
            errors.append(f"{label}: no BODY targets")
        if not item["rig_steps"]:
            errors.append(f"{label}: no rig build steps")

    builder_text = BUILDER.read_text(encoding="utf-8")
    runner_text = RUNNER.read_text(encoding="utf-8")
    required_builder_guards = [
        "litd_not_production_asset",
        "TODO_",
        "REFUSING: v53 scaffold may not be saved over the canonical artist-authored source_blend",
        "unexpectedly contains Mesh objects",
        "unexpectedly contains Materials",
        "unexpectedly contains Actions",
        "unexpectedly contains Armatures",
        "bpy.ops.wm.read_factory_settings(use_empty=True)",
    ]
    for token in required_builder_guards:
        if token not in builder_text:
            errors.append(f"builder safety token missing: {token}")

    forbidden_generation_calls = [
        "bpy.ops.mesh.primitive_",
        "bpy.data.meshes.new(",
        "bpy.data.materials.new(",
        "bpy.data.armatures.new(",
        "bpy.data.actions.new(",
    ]
    for token in forbidden_generation_calls:
        if token in builder_text:
            errors.append(f"builder must not generate fake production data: {token}")

    for token in ("canonical_source_blends_written", "generated_meshes", "generated_materials", "generated_armature_bones", "generated_actions"):
        if token not in runner_text:
            errors.append(f"runner safety field missing: {token}")

    plan = build_plan("__definitely_missing_blender_v53__")
    if plan.get("pc_ready") is not False:
        errors.append("missing Blender executable must block execution")
    if plan.get("blocker_code") != "BLENDER_EXECUTABLE_REQUIRED":
        errors.append("wrong missing-Blender blocker code")
    safety = plan.get("safety", {})
    if safety.get("canonical_source_blends_written") is not False:
        errors.append("v53 must never write canonical source_blends")
    if any(safety.get(key) is not False for key in ("generated_meshes", "generated_materials", "generated_armature_bones", "generated_actions")):
        errors.append("v53 safety plan must reject generated production art/rig/Actions")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"MASTER_SCAFFOLDS_V53_AUDIT_ERROR: {error}")
        return 1
    print("MASTER_SCAFFOLDS_V53_AUDIT_OK masters=12 safe_outputs=12 fake_art=0 fake_actions=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
