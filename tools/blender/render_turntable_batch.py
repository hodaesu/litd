#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
from pathlib import Path

from tools.blender.automation_common import AUTOMATION_CONTRACT, ROOT, bpy_module, load_json, scene_meshes, script_argv, write_json


def render(asset_id: str, output_dir: str) -> dict:
    bpy = bpy_module()
    from mathutils import Vector  # type: ignore

    config = load_json(AUTOMATION_CONTRACT)
    angles = [int(v) for v in config.get("turntable_angles", [0,45,90,135,180,225,270,315])]
    meshes = scene_meshes(bpy)
    if not meshes:
        raise SystemExit("No mesh to render")
    corners = []
    for obj in meshes:
        corners.extend([obj.matrix_world @ Vector(corner) for corner in obj.bound_box])
    center = sum(corners, Vector()) / len(corners)
    radius = max((point - center).length for point in corners)
    distance = max(3.0, radius * 3.2)

    scene = bpy.context.scene
    camera = scene.camera
    if camera is None:
        camera_data = bpy.data.cameras.new("CAM_LITD_Turntable")
        camera = bpy.data.objects.new("CAM_LITD_Turntable", camera_data)
        scene.collection.objects.link(camera)
        scene.camera = camera
    camera.data.lens = 65
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    output = ROOT / output_dir
    output.mkdir(parents=True, exist_ok=True)
    files = []
    for angle in angles:
        rad = math.radians(angle)
        camera.location = center + Vector((math.sin(rad) * distance, -math.cos(rad) * distance, radius * 0.45 + 0.4))
        direction = center - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        filepath = output / ("%s_%03d.png" % (asset_id, angle))
        scene.render.filepath = str(filepath)
        bpy.ops.render.render(write_still=True)
        files.append(str(filepath.relative_to(ROOT)))
    manifest = {"version": 1, "asset_id": asset_id, "angles": angles, "files": files, "human_review_required": True}
    write_json(output / "manifest.json", manifest)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args(script_argv())
    render(args.asset_id, args.output_dir)
    print("LITD_TURNTABLE_OK", args.asset_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
