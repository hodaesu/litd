#!/usr/bin/env python3
"""Prepare and validate systemic F0-F4 animation contracts inside Blender."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

CONTRACT_PATH = ROOT / "data/blender/systemic_animation_v44.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_job(job_id: str) -> dict:
    from tools.blender.generate_systemic_animation_v44 import build_payload
    for job in build_payload(ROOT).get("jobs", []):
        if job_id in (job.get("job_id"), job.get("character_id")):
            return job
    raise KeyError(f"unknown systemic animation v44 job: {job_id}")


def _ensure_action(bpy, spec: dict):
    name = str(spec["name"])
    action = bpy.data.actions.get(name)
    if action is None:
        action = bpy.data.actions.new(name=name)
        action["litd_v44_placeholder"] = True
    action["litd_animation_state"] = str(spec.get("state", ""))
    action["litd_animation_part"] = str(spec.get("part", ""))
    action["litd_animation_role"] = str(spec.get("role", ""))
    action["litd_animation_contract_version"] = 44
    return action


def prepare_scene(job: dict, save: bool = False) -> list[str]:
    import bpy  # type: ignore
    for spec in job.get("actions", []):
        _ensure_action(bpy, spec)
    scene = bpy.context.scene
    scene["litd_animation_pipeline_version"] = 44
    scene["litd_animation_character_id"] = job["character_id"]
    scene["litd_animation_morphology"] = job["morphology"]
    scene["litd_animation_gameplay_neutral"] = True
    scene["litd_animation_locomotion_parts"] = ",".join(job.get("locomotion_parts", []))
    scene["litd_animation_manipulators"] = ",".join(job.get("manipulators", []))
    if save and bpy.data.filepath:
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    return validate_scene(job, final=False)


def validate_scene(job: dict, final: bool = False) -> list[str]:
    import bpy  # type: ignore
    contract = _load(CONTRACT_PATH)
    errors: list[str] = []
    if int(bpy.context.scene.get("litd_animation_pipeline_version", 0)) != 44:
        errors.append("scene not prepared by animation pipeline v44")
    for spec in job.get("actions", []):
        if not bool(spec.get("required", True)):
            continue
        action = bpy.data.actions.get(str(spec["name"]))
        if action is None:
            errors.append(f"missing required action: {spec['name']}")
            continue
        if final and contract.get("validation", {}).get("block_final_export_if_placeholder_action_remains", False):
            if bool(action.get("litd_v44_placeholder", False)):
                errors.append(f"placeholder action not artist-approved: {spec['name']}")
    if job.get("weapon_sockets"):
        required = set(contract.get("one_hand_actions", []))
        existing = {action.name for action in bpy.data.actions}
        missing = sorted(required - existing)
        if missing:
            errors.append("missing single-hand fallbacks: " + ", ".join(missing))
    return errors


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--final-validate", action="store_true")
    parser.add_argument("--save", action="store_true")
    parser.add_argument("--print-plan", action="store_true")
    args = parser.parse_args(argv)
    job = load_job(args.job_id)
    if args.print_plan:
        print(json.dumps(job, ensure_ascii=False, indent=2))
    errors: list[str] = []
    if args.prepare:
        errors = prepare_scene(job, args.save)
    elif args.validate:
        errors = validate_scene(job, final=False)
    elif args.final_validate:
        errors = validate_scene(job, final=True)
    elif not args.print_plan:
        parser.error("choose --prepare, --validate, --final-validate or --print-plan")
    if errors:
        print("SYSTEMIC_ANIMATION_V44_BLOCKED")
        for error in errors:
            print(f"- {error}")
        return 2
    if args.prepare or args.validate or args.final_validate:
        print("SYSTEMIC_ANIMATION_V44_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
