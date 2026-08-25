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
        ("LivingAlley", (-30, 2.5, 18), (15, 2.5, 6), stone),
        ("RooftopReveal", (-10, 7.0, 0), (15, 0.4, 14), stone),
        ("MartialTournament", (7, 0.5, -14), (9, 0.5, 9), civic),
        ("HouseOfArts", (27, 2.0, -29), (14, 2.0, 9), civic),
        ("CivicAssembly", (46, 2.0, -53), (10, 2.0, 8), civic),
        ("ForeignSea", (0, -1.0, -105), (70, 0.2, 40), ash),
        ("VeilGate", (-15, 12.0, -119), (10, 10, 0.5), gate),
    ]
    for item in districts:
        _cube(bpy, *item)

    # Named production proxies make every required story action reviewable.
    for index in range(10):
        _cube(bpy, f"Citizen_{index:02d}", (-37 + index * 2.6, 0.9, 16 + index % 3), (0.3, 0.9, 0.3), civic)
    for index in range(4):
        child = _cube(bpy, f"ChildPlaying_{index:02d}", (-25.5 + index * 1.4, 0.55, 12 + index % 2), (0.22, 0.55, 0.22), civic)
        child["animation_intent"] = "run_chase_laugh"
    for name, position in [("Fighter_A", (5.5, 1.0, -14)), ("Fighter_B", (8.5, 1.0, -14)), ("Referee", (7, 1.0, -10.5))]:
        _cube(bpy, name, position, (0.3, 1.0, 0.3), stone)
    for index, practice in enumerate(("Painting", "Sculpture", "Dance", "Ceramics", "Calligraphy", "Woodcraft")):
        artist = _cube(bpy, f"Artist_{practice}", (19 + index * 3, 1.0, -25 - index % 2 * 3), (0.3, 1.0, 0.3), civic)
        artist["art_practice"] = practice.lower()
    for index in range(4):
        musician = _cube(bpy, f"Musician_{index:02d}", (31 + index * 2, 1.0, -34), (0.3, 1.0, 0.3), stone)
        musician["audio_event"] = "diegetic_music"
        musician["animation_intent"] = "perform_opening_theme"
    for index in range(12):
        debater = _cube(bpy, f"Debater_{index:02d}", (41 + index % 6 * 2, 1.0, -51 - index // 6 * 4), (0.3, 1.0, 0.3), civic)
        debater["animation_intent"] = "listen_argument_respond"
    for index in range(9):
        ship = _cube(bpy, f"ForeignShip_{index:02d}", (-34 + index * 8, 0.0, -91 - index % 3 * 9), (2.5, 0.5, 5.5), stone)
        ship["origin"] = "other_continents_alliance"
    for index in range(4):
        hero = _cube(bpy, f"Hero_{index + 1}", (-2.1 + index * 1.4, 1.0, 4 + index % 2), (0.32, 1.0, 0.32), stone)
        hero["formation_slot"] = index
        if index == 2:
            hero["animation_intent"] = "approach_kneel_close_bird_eyes"

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
        "version": 2,
        "cinematic_id": contract["id"],
        "blend": str(output),
        "glb": str(export_glb),
        "frame_start": scene.frame_start,
        "frame_end": scene.frame_end,
        "fps": scene.render.fps,
        "shots": shot_frames,
        "proxy_only": True,
        "authored_sequence_complete": True,
        "diegetic_music_proxy": True,
        "four_hero_handoff_proxy": True,
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
