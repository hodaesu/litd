#!/usr/bin/env python3
"""Build an Ashlands Blender scene from a generated production job.

The planning layer runs in normal Python. Scene creation runs inside Blender and
imports bpy lazily so the repository tests do not require Blender.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JOBS_PATH = ROOT / "data/levels/ashlands_blender_jobs.json"
COLLECTIONS = ("ENVIRONMENT", "COLLISION", "GAMEPLAY_SOCKETS", "LIGHTING", "CAMERA")


def load_job(job_id: str, jobs_path: Path = JOBS_PATH) -> dict:
    payload = json.loads(jobs_path.read_text(encoding="utf-8"))
    for job in payload["jobs"]:
        if job["job_id"] == job_id or job["zone_id"] == job_id:
            return job
    raise KeyError(f"unknown Blender job: {job_id}")


def build_scene_plan(job: dict) -> dict:
    width, depth = map(float, job["zone_size_m"])
    deliverables = job["deliverables"]
    objects: list[dict] = []
    objects.extend(_modular_grid(job, "building", deliverables["buildings"], width, depth, (8.0, 5.0, 7.0)))
    objects.extend(_modular_grid(job, "wall", deliverables["walls_or_blockers"], width, depth, (7.0, 2.8, 1.0)))
    objects.extend(_modular_grid(job, "platform", deliverables["platforms"], width, depth, (7.0, 0.6, 6.0)))
    objects.append({
        "name": f"SM_{job['kit_id']}_{_safe(job['landmark'])}_a_LOD0",
        "kind": "box", "collection": "ENVIRONMENT",
        "location": [0.0, 6.0, -depth * 0.12], "dimensions": [10.0, 12.0, 10.0],
        "asset_slot": "architecture/landmark",
    })
    visual_objects = list(objects)
    for visual in visual_objects:
        objects.append({
            "name": "COL_" + visual["name"].removeprefix("SM_"),
            "kind": "box", "collection": "COLLISION",
            "location": visual["location"], "dimensions": visual["dimensions"],
            "source": visual["name"],
        })
    sockets = job["gameplay_sockets"]
    for purpose in ("encounters", "resources", "ash_volumes", "shortcuts"):
        for index in range(int(sockets[purpose])):
            objects.append({
                "name": f"SOCKET_{purpose}_{index + 1:02d}", "kind": "empty",
                "collection": "GAMEPLAY_SOCKETS", "location": _socket_position(index, int(sockets[purpose]), width, depth),
            })
    if sockets["campfire"]:
        objects.append({"name": "SOCKET_campfire", "kind": "empty", "collection": "GAMEPLAY_SOCKETS", "location": [0.0, 0.0, 0.0]})
    if sockets["boss"]:
        objects.append({"name": "SOCKET_boss", "kind": "empty", "collection": "GAMEPLAY_SOCKETS", "location": [0.0, 0.0, -depth * 0.32]})
    return {
        "version": 1,
        "job_id": job["job_id"],
        "zone_id": job["zone_id"],
        "kit_id": job["kit_id"],
        "collections": list(COLLECTIONS),
        "objects": objects,
        "camera": {"name": "CAM_isometric_preview", "location": [14.0, 18.0, 14.0], "ortho_scale": 16.0},
        "lighting": {"name": "SUN_ashlands_preview", "rotation_degrees": [-54.0, 0.0, -34.0], "energy": 2.0},
        "output_folder": job["output"],
    }


def _modular_grid(job: dict, asset: str, count: int, width: float, depth: float, dimensions: tuple[float, float, float]) -> list[dict]:
    result = []
    columns = max(1, math.ceil(math.sqrt(max(1, count))))
    for index in range(count):
        row, column = divmod(index, columns)
        x = -width * 0.3 + column * min(14.0, width * 0.6 / max(1, columns - 1))
        z = -depth * 0.28 + row * 13.0
        y = dimensions[1] * 0.5
        result.append({
            "name": f"SM_{job['kit_id']}_{asset}_{index + 1:02d}_LOD0",
            "kind": "box", "collection": "ENVIRONMENT",
            "location": [x, y, z], "dimensions": list(dimensions),
            "asset_slot": f"architecture/{asset}",
        })
    return result


def _socket_position(index: int, count: int, width: float, depth: float) -> list[float]:
    angle = math.tau * index / max(1, count)
    return [math.cos(angle) * width * 0.28, 0.0, math.sin(angle) * depth * 0.28]


def _safe(value: str) -> str:
    return "".join(char.lower() if char.isalnum() else "_" for char in value).strip("_")


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
    scene["litd_zone_id"] = plan["zone_id"]
    collections = {}
    for name in plan["collections"]:
        collection = bpy.data.collections.new(name)
        scene.collection.children.link(collection)
        collections[name] = collection
    for spec in plan["objects"]:
        if spec["kind"] == "box":
            bpy.ops.mesh.primitive_cube_add(location=spec["location"])
            obj = bpy.context.object
            obj.name = spec["name"]
            obj.dimensions = spec["dimensions"]
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        else:
            obj = bpy.data.objects.new(spec["name"], None)
            obj.empty_display_type = "SPHERE"
            obj.empty_display_size = 0.5
            obj.location = spec["location"]
            scene.collection.objects.link(obj)
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        collections[spec["collection"]].objects.link(obj)
        for key in ("asset_slot", "source"):
            if key in spec:
                obj[f"litd_{key}"] = spec[key]
    _create_camera(bpy, plan["camera"], collections["CAMERA"])
    _create_light(bpy, plan["lighting"], collections["LIGHTING"])
    output_blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend))
    if export_glb is not None:
        export_glb.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(export_glb), export_format="GLB", use_selection=False)


def _create_camera(bpy, spec: dict, collection) -> None:
    data = bpy.data.cameras.new(spec["name"])
    data.type = "ORTHO"
    data.ortho_scale = spec["ortho_scale"]
    camera = bpy.data.objects.new(spec["name"], data)
    camera.location = spec["location"]
    camera.rotation_euler = (math.radians(55.0), 0.0, math.radians(45.0))
    collection.objects.link(camera)
    bpy.context.scene.camera = camera


def _create_light(bpy, spec: dict, collection) -> None:
    data = bpy.data.lights.new(spec["name"], type="SUN")
    data.energy = spec["energy"]
    light = bpy.data.objects.new(spec["name"], data)
    light.rotation_euler = tuple(math.radians(value) for value in spec["rotation_degrees"])
    collection.objects.link(light)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("job_id")
    parser.add_argument("--jobs", type=Path, default=JOBS_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--export-glb", type=Path)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(argv)
    plan = build_scene_plan(load_job(args.job_id, args.jobs))
    if args.plan_only:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    if args.output is None:
        parser.error("--output is required unless --plan-only is used")
    execute_in_blender(plan, args.output, args.export_glb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
