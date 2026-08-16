#!/usr/bin/env python3
"""Build a structured Blender character placeholder from a production job."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JOBS_PATH = ROOT / "data/blender/character_jobs.json"


def load_job(job_id: str, jobs_path: Path = JOBS_PATH) -> dict:
    payload = json.loads(jobs_path.read_text(encoding="utf-8"))
    for job in payload["jobs"]:
        if job_id in (job["job_id"], job["character_id"]):
            return job
    raise KeyError(f"unknown character Blender job: {job_id}")


def build_character_plan(job: dict) -> dict:
    prefix = job["character_id"]
    scale = float(job["body_scale"])
    objects = [
        {"name": f"SK_{prefix}_body_LOD0", "kind": "capsule", "collection": "BODY", "location": [0, 0, 0.95 * scale], "dimensions": [0.58 * scale, 0.42 * scale, 1.55 * scale]},
        {"name": f"SK_{prefix}_head_LOD0", "kind": "sphere", "collection": "BODY", "location": [0, 0, 1.78 * scale], "dimensions": [0.42 * scale] * 3},
        {"name": f"COL_{prefix}_capsule", "kind": "capsule", "collection": "COLLISION", "location": [0, 0, 0.9 * scale], "dimensions": [0.62 * scale, 0.62 * scale, 1.8 * scale]},
        {"name": f"RIG_{prefix}", "kind": "armature", "collection": "ARMATURE", "location": [0, 0, 0]},
    ]
    socket_positions = {
        "weapon_r": [0.48 * scale, 0, 1.08 * scale], "weapon_l": [-0.48 * scale, 0, 1.08 * scale],
        "head": [0, 0, 1.98 * scale], "back": [0, 0.24 * scale, 1.3 * scale], "fx_root": [0, 0, 0],
    }
    for socket in job["equipment_sockets"]:
        objects.append({"name": f"SOCKET_{socket}", "kind": "empty", "collection": "SOCKETS", "location": socket_positions[socket]})
    return {
        "version": 1, "job_id": job["job_id"], "character_id": prefix,
        "category": job["category"], "collections": job["collections"], "objects": objects,
        "bones": ["root", "hips", "spine", "chest", "neck", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"],
        "animations": job["animation_set"], "lod_levels": job["lod_levels"],
        "materials": job["material_slots"], "reference_art": job["reference_art"],
        "camera": {"name": "CAM_character_preview", "location": [3.6, -5.5, 2.4], "lens": 70},
        "output_folder": job["output"],
    }


def execute_in_blender(plan: dict, output_blend: Path, export_glb: Path | None = None) -> None:
    import bpy  # type: ignore

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["litd_job_id"] = plan["job_id"]
    scene["litd_character_id"] = plan["character_id"]
    collections = {}
    for name in plan["collections"]:
        collection = bpy.data.collections.new(name)
        scene.collection.children.link(collection)
        collections[name] = collection
    for spec in plan["objects"]:
        obj = _create_object(bpy, spec, plan["bones"])
        for current in list(obj.users_collection):
            current.objects.unlink(obj)
        collections[spec["collection"]].objects.link(obj)
    _create_preview(bpy, plan, collections)
    output_blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend))
    if export_glb:
        export_glb.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(export_glb), export_format="GLB", export_animations=True)


def _create_object(bpy, spec: dict, bones: list[str]):
    kind = spec["kind"]
    if kind == "capsule":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=spec["location"])
        obj = bpy.context.object
        obj.scale = [value / 2 for value in spec["dimensions"]]
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=spec["location"])
        obj = bpy.context.object
        obj.scale = [value / 2 for value in spec["dimensions"]]
    elif kind == "armature":
        data = bpy.data.armatures.new(spec["name"])
        obj = bpy.data.objects.new(spec["name"], data)
        bpy.context.scene.collection.objects.link(obj)
        obj["litd_bone_contract"] = ",".join(bones)
    else:
        obj = bpy.data.objects.new(spec["name"], None)
        obj.empty_display_type = "PLAIN_AXES"
        obj.location = spec["location"]
        bpy.context.scene.collection.objects.link(obj)
    obj.name = spec["name"]
    return obj


def _create_preview(bpy, plan: dict, collections: dict) -> None:
    camera_data = bpy.data.cameras.new(plan["camera"]["name"])
    camera_data.lens = plan["camera"]["lens"]
    camera = bpy.data.objects.new(plan["camera"]["name"], camera_data)
    camera.location = plan["camera"]["location"]
    camera.rotation_euler = (math.radians(72), 0, math.radians(34))
    collections["CAMERA"].objects.link(camera)
    bpy.context.scene.camera = camera
    light_data = bpy.data.lights.new("AREA_character_key", "AREA")
    light_data.energy = 900
    light_data.shape = "DISK"
    light_data.size = 4
    light = bpy.data.objects.new("AREA_character_key", light_data)
    light.location = [2.5, -2.5, 4]
    collections["LIGHTING"].objects.link(light)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("job_id")
    parser.add_argument("--jobs", type=Path, default=JOBS_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--export-glb", type=Path)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(argv)
    plan = build_character_plan(load_job(args.job_id, args.jobs))
    if args.plan_only:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    if args.output is None:
        parser.error("--output is required unless --plan-only is used")
    execute_in_blender(plan, args.output, args.export_glb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
