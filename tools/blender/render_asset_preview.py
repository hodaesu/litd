#!/usr/bin/env python3
"""Render deterministic multi-angle review images from a Blender production file."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "data/blender/visual_review_queue.json"


def load_review(job_id: str, path: Path = QUEUE) -> dict:
    for review in json.loads(path.read_text(encoding="utf-8"))["reviews"]:
        if review["job_id"] == job_id:
            return review
    raise KeyError(f"unknown visual review job: {job_id}")


def build_render_plan(review: dict) -> dict:
    preview = review["preview"]
    distance = 36.0 if review["category"] == "environments" else 4.8
    target_height = 3.0 if review["category"] == "environments" else 1.0
    shots = []
    for angle in preview["angles_degrees"]:
        radians = math.radians(angle)
        elevation = math.radians(preview["elevation_degrees"])
        shots.append({
            "name": f"{review['job_id']}_{angle:03d}", "angle_degrees": angle,
            "camera_location": [round(math.cos(radians) * distance, 4), round(math.sin(radians) * distance, 4), round(math.tan(elevation) * distance, 4)],
            "target": [0.0, 0.0, target_height],
            "output": f"{preview['output_dir']}/{review['job_id']}_{angle:03d}.png",
        })
    return {
        "version": 1, "job_id": review["job_id"], "category": review["category"],
        "blend_path": review["blend_path"], "resolution": preview["resolution"],
        "transparent": True, "shots": shots,
    }


def execute_in_blender(plan: dict) -> None:
    import bpy  # type: ignore
    from mathutils import Vector  # type: ignore

    blend_path = ROOT / plan["blend_path"]
    if not blend_path.exists():
        raise FileNotFoundError(blend_path)
    if Path(bpy.data.filepath).resolve() != blend_path.resolve():
        bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = plan["resolution"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = plan["transparent"]
    camera_data = bpy.data.cameras.get("CAM_review") or bpy.data.cameras.new("CAM_review")
    camera = bpy.data.objects.get("CAM_review") or bpy.data.objects.new("CAM_review", camera_data)
    if not camera.users_collection:
        scene.collection.objects.link(camera)
    scene.camera = camera
    for shot in plan["shots"]:
        camera.location = shot["camera_location"]
        camera.rotation_euler = (Vector(shot["target"]) - camera.location).to_track_quat("-Z", "Y").to_euler()
        output = ROOT / shot["output"]
        output.parent.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("job_id")
    parser.add_argument("--queue", type=Path, default=QUEUE)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(argv)
    plan = build_render_plan(load_review(args.job_id, args.queue))
    if args.plan_only:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    execute_in_blender(plan)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
