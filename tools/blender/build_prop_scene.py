#!/usr/bin/env python3
"""Build a structured equipment or gameplay prop scene in Blender."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JOBS_PATH = ROOT / "data/blender/prop_jobs.json"


def load_job(job_id: str, path: Path = JOBS_PATH) -> dict:
    for job in json.loads(path.read_text(encoding="utf-8"))["jobs"]:
        if job_id in (job["job_id"], job["prop_id"]):
            return job
    raise KeyError(f"unknown prop Blender job: {job_id}")


def build_prop_plan(job: dict) -> dict:
    identifier = job["prop_id"]
    return {
        "version": 1, "job_id": job["job_id"], "prop_id": identifier,
        "category": job["category"], "collections": job["collections"],
        "objects": [
            {"name": f"SM_prop_{identifier}_LOD0", "kind": "box", "collection": "PROP", "dimensions": job["dimensions_m"], "location": [0, 0, job["dimensions_m"][2] / 2]},
            {"name": f"COL_prop_{identifier}", "kind": "box", "collection": "COLLISION", "dimensions": job["dimensions_m"], "location": [0, 0, job["dimensions_m"][2] / 2]},
            {"name": job["socket"], "kind": "empty", "collection": "SOCKETS", "location": [0, 0, max(job["dimensions_m"][2] / 2, 0.08)]},
        ],
        "material_profile": job["material_profile"], "lod_levels": job["lod_levels"],
        "camera": {"name": "CAM_prop_preview", "location": [2.8, -3.5, 2.2], "lens": 60},
        "output_folder": job["output"],
    }


def execute_in_blender(plan: dict, output_blend: Path, export_glb: Path | None = None) -> None:
    import bpy  # type: ignore
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    collections = {}
    for name in plan["collections"]:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        collections[name] = collection
    for spec in plan["objects"]:
        if spec["kind"] == "box":
            bpy.ops.mesh.primitive_cube_add(location=spec["location"])
            obj = bpy.context.object
            obj.dimensions = spec["dimensions"]
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        else:
            obj = bpy.data.objects.new(spec["name"], None)
            obj.empty_display_type = "PLAIN_AXES"
            obj.location = spec["location"]
            bpy.context.scene.collection.objects.link(obj)
        obj.name = spec["name"]
        for current in list(obj.users_collection):
            current.objects.unlink(obj)
        collections[spec["collection"]].objects.link(obj)
        obj["litd_material_profile"] = plan["material_profile"]
    camera_data = bpy.data.cameras.new(plan["camera"]["name"])
    camera_data.lens = plan["camera"]["lens"]
    camera = bpy.data.objects.new(plan["camera"]["name"], camera_data)
    camera.location = plan["camera"]["location"]
    camera.rotation_euler = (math.radians(68), 0, math.radians(38))
    collections["CAMERA"].objects.link(camera)
    bpy.context.scene.camera = camera
    output_blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend))
    if export_glb:
        export_glb.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(export_glb), export_format="GLB")


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("job_id")
    parser.add_argument("--jobs", type=Path, default=JOBS_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--export-glb", type=Path)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(argv)
    plan = build_prop_plan(load_job(args.job_id, args.jobs))
    if args.plan_only:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    if args.output is None:
        parser.error("--output is required unless --plan-only is used")
    execute_in_blender(plan, args.output, args.export_glb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
