#!/usr/bin/env python3
"""Build the supervised Blender proxy scene for the LITD opening cinematic."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/cinematics/opening_bird_intro.json"


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def load_contract() -> dict:
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def _material(bpy, name: str, color: tuple[float, float, float, float]):
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    return material


def _cube(bpy, name: str, location, scale, material):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build_scene(output: Path, export_glb: Path, report: Path) -> dict:
    import bpy
    from mathutils import Vector

    contract = load_contract()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.fps = 30

    stone = _material(bpy, "M_CityStone", (0.25, 0.22, 0.20, 1.0))
    civic = _material(bpy, "M_CivicGold", (0.48, 0.34, 0.16, 1.0))
    gate = _material(bpy, "M_GateVoid", (0.08, 0.05, 0.12, 1.0))
    ash = _material(bpy, "M_Ash", (0.34, 0.35, 0.38, 1.0))

    districts = [
        ("CosmopolitanQuarter", (-22, 2.5, 12), (9, 2.5, 9), stone),
        ("ArtsSquare", (-7, 1.5, 0), (7, 1.5, 6), civic),
        ("MartialArena", (11, 1.0, -12), (8, 1.0, 7), stone),
        ("CivicAssembly", (26, 2.0, -25), (8, 2.0, 6), civic),
        ("ThreeAwakenings", (12, 5.0, -44), (7, 5.0, 5), civic),
        ("GateTower", (-17, 8.0, -65), (5, 8.0, 5), gate),
    ]
    for item in districts:
        _cube(bpy, *item)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(-38, 18, 28))
    bird = bpy.context.object
    bird.name = "BirdWitnessProxy"
    bird.scale = (0.32, 0.18, 0.55)
    bird.data.materials.append(ash)

    bpy.ops.object.empty_add(type="PLAIN_AXES")
    camera_rig = bpy.context.object
    camera_rig.name = "BirdPOVCameraRig"
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "BirdPOVCamera"
    camera.data.lens = 24
    camera.parent = camera_rig
    scene.camera = camera

    current_frame = 1
    shot_frames = []
    for waypoint in contract["runtime_waypoints"]:
        position = Vector(waypoint["position"])
        target = Vector(waypoint["look_at"])
        camera_rig.location = position
        direction = target - position
        camera_rig.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        camera_rig.keyframe_insert("location", frame=current_frame)
        camera_rig.keyframe_insert("rotation_euler", frame=current_frame)
        duration_frames = max(1, round(float(waypoint["duration"]) * scene.render.fps))
        shot_frames.append({"id": waypoint["id"], "frame": current_frame, "duration_frames": duration_frames})
        current_frame += duration_frames
    scene.frame_start = 1
    scene.frame_end = current_frame

    world = bpy.data.worlds.new("OpeningWorld") if bpy.data.worlds.get("OpeningWorld") is None else bpy.data.worlds["OpeningWorld"]
    scene.world = world
    world.color = (0.055, 0.05, 0.065)
    bpy.ops.object.light_add(type="SUN", location=(0, 30, 0))
    bpy.context.object.name = "OpeningSun"
    bpy.context.object.data.energy = 2.0
    bpy.context.object.rotation_euler = (math.radians(28), math.radians(-20), math.radians(35))

    scene["litd_cinematic_id"] = contract["id"]
    scene["litd_review_required"] = True
    scene["litd_gameplay_authority"] = "Godot"
    output.parent.mkdir(parents=True, exist_ok=True)
    export_glb.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    bpy.ops.export_scene.gltf(
        filepath=str(export_glb),
        export_format="GLB",
        export_animations=True,
        export_cameras=False,
        export_lights=False,
    )
    payload = {
        "version": 1,
        "cinematic_id": contract["id"],
        "blend": str(output),
        "glb": str(export_glb),
        "frame_start": scene.frame_start,
        "frame_end": scene.frame_end,
        "fps": scene.render.fps,
        "shots": shot_frames,
        "proxy_only": True,
        "human_visual_review_required": True,
    }
    report.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--export-glb", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args(script_args())
    build_scene(args.output, args.export_glb, args.report)
    print("OPENING_BLENDER_PROXY_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
