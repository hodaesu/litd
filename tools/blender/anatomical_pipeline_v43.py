#!/usr/bin/env python3
"""Prepare and validate Blender character scenes against LITD anatomy v43.

Run inside Blender for scene mutation/validation. Static plan inspection works in Python.
Preparation is non-destructive and may leave artistic geometry tasks pending; validation
is the hard export gate.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.blender.generate_anatomical_pipeline_v43 import build_payload

JOBS_PATH = ROOT / "data/blender/anatomical_pipeline_jobs_v43.json"
CONTRACT_PATH = ROOT / "data/blender/anatomical_pipeline_v43.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_job(job_id: str, jobs_path: Path = JOBS_PATH) -> dict:
    payload = _load(jobs_path) if jobs_path.exists() else build_payload()
    for job in payload.get("jobs", []):
        if job_id in (job.get("job_id"), job.get("character_id")):
            return job
    raise KeyError(f"unknown anatomical v43 job: {job_id}")


def _all_scene_objects(bpy):
    return list(bpy.data.objects)


def _ensure_collection(bpy, name: str):
    existing = bpy.data.collections.get(name)
    if existing is not None:
        return existing
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def _link_only(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def _ensure_socket(bpy, name: str, collection):
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, None)
        obj.empty_display_type = "PLAIN_AXES"
        collection.objects.link(obj)
    obj["litd_socket"] = name
    return obj


def _ensure_guide(bpy, part: str, collection):
    name = f"GUIDE_BODY_{part}"
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, None)
        obj.empty_display_type = "CUBE"
        obj.empty_display_size = 0.08
        collection.objects.link(obj)
    obj["litd_required_body_part"] = part
    obj["litd_export"] = False
    return obj


def _tag_named_markers(bpy, job: dict, contract: dict) -> None:
    marker_contract = contract["marker_contract"]
    body_states = _ensure_collection(bpy, "BODY_STATES")
    guides = _ensure_collection(bpy, "BODY_GUIDES")
    sockets = _ensure_collection(bpy, "SOCKETS")
    objects = _all_scene_objects(bpy)

    for part_spec in job.get("parts", []):
        part = str(part_spec["part"])
        segment = bpy.data.objects.get(part_spec["segment"])
        stump_name = str(part_spec.get("stump", ""))
        stump = bpy.data.objects.get(stump_name) if stump_name else None
        f3 = bpy.data.objects.get(part_spec["f3_pose"])

        if segment is not None:
            segment[marker_contract["segment_property"]] = part
            segment[marker_contract["functional_state_property"]] = "F0"
        else:
            _ensure_guide(bpy, part, guides)

        if stump is not None:
            stump[marker_contract["stump_property"]] = part
            stump[marker_contract["functional_state_property"]] = "F0"
            stump.hide_viewport = True
            stump.hide_render = True
            if body_states not in stump.users_collection:
                _link_only(stump, body_states)

        if f3 is not None:
            f3[marker_contract["segment_property"]] = part
            f3[marker_contract["functional_state_property"]] = "F0"
            f3.hide_viewport = True
            f3.hide_render = True
            if body_states not in f3.users_collection:
                _link_only(f3, body_states)

    for side, socket_name in job.get("weapon_sockets", {}).items():
        socket = _ensure_socket(bpy, str(socket_name), sockets)
        socket["litd_weapon_side"] = str(side)

    for obj in objects:
        if obj.name.startswith(marker_contract["equipment_prefix"]):
            obj[marker_contract["equipment_role_property"]] = obj.get(marker_contract["equipment_role_property"], "equipment")

    scene = bpy.context.scene
    scene["litd_anatomy_pipeline_version"] = 43
    scene["litd_anatomy_character_id"] = job["character_id"]
    scene["litd_anatomy_morphology"] = job["morphology"]
    scene["litd_gameplay_neutral"] = True


def validate_scene(bpy, job: dict, contract: dict) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    if not str(job.get("morphology", "")):
        errors.append("unknown morphology")

    for part_spec in job.get("parts", []):
        segment_name = str(part_spec["segment"])
        if segment_name in seen:
            errors.append(f"marker collision: {segment_name}")
        seen.add(segment_name)
        if bpy.data.objects.get(segment_name) is None:
            errors.append(f"missing body segment: {segment_name}")
        stump_name = str(part_spec.get("stump", ""))
        if bool(part_spec.get("supports_f4", False)) and stump_name and bpy.data.objects.get(stump_name) is None:
            errors.append(f"missing F4 presentation: {stump_name}")

    for _side, socket_name in job.get("weapon_sockets", {}).items():
        if bpy.data.objects.get(str(socket_name)) is None:
            errors.append(f"missing weapon socket: {socket_name}")

    if contract.get("validation", {}).get("require_custom_properties_in_glb", False):
        if int(bpy.context.scene.get("litd_anatomy_pipeline_version", 0)) != 43:
            errors.append("scene not prepared by anatomy pipeline v43")
    return errors


def prepare_scene(job: dict, save: bool) -> list[str]:
    import bpy  # type: ignore
    contract = _load(CONTRACT_PATH)
    for collection_name in contract.get("required_collections", []):
        _ensure_collection(bpy, str(collection_name))
    _tag_named_markers(bpy, job, contract)
    if save:
        if not bpy.data.filepath:
            raise RuntimeError("cannot --save an unsaved Blender file; provide a .blend file")
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    return validate_scene(bpy, job, contract)


def run_validation(job: dict) -> list[str]:
    import bpy  # type: ignore
    return validate_scene(bpy, job, _load(CONTRACT_PATH))


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--jobs", type=Path, default=JOBS_PATH)
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--save", action="store_true")
    parser.add_argument("--print-plan", action="store_true")
    args = parser.parse_args(argv)
    job = load_job(args.job_id, args.jobs)
    if args.print_plan:
        print(json.dumps(job, ensure_ascii=False, indent=2))
    if args.prepare:
        pending = prepare_scene(job, args.save)
        if pending:
            print("ANATOMY_V43_PREPARED_PENDING_ART")
            for item in pending:
                print(f"- {item}")
        else:
            print("ANATOMY_V43_PREPARED_OK")
        return 0
    if args.validate:
        errors = run_validation(job)
        if errors:
            print("ANATOMY_V43_BLOCKED")
            for error in errors:
                print(f"- {error}")
            return 2
        print("ANATOMY_V43_OK")
        return 0
    if not args.print_plan:
        parser.error("choose --prepare, --validate or --print-plan")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
