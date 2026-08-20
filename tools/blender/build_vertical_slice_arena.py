#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from tools.blender.automation_common import ROOT, VISUAL_CONTRACT, bpy_module, load_json, script_argv


def _cube(bpy, name: str, location: tuple[float,float,float], scale: tuple[float,float,float]):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build(output: str) -> None:
    bpy = bpy_module()
    contract = load_json(VISUAL_CONTRACT)
    arena = contract["arena"]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    width, length = [float(v) for v in arena["size_m"]]
    bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0,0,0))
    ground = bpy.context.object
    ground.name = "ENV_AshGround_LOD0"
    ground.scale = (width/2.0, length/2.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    _cube(bpy, "ENV_BrokenSteps_LOD0", (0, 4.8, 0.35), (3.8, 1.25, 0.35))
    _cube(bpy, "ENV_RuinedGate_Left_LOD0", (-4.8, 7.0, 2.1), (0.7, 0.7, 2.1))
    _cube(bpy, "ENV_RuinedGate_Right_LOD0", (4.8, 7.0, 2.1), (0.7, 0.7, 2.1))
    _cube(bpy, "ENV_RuinedGate_Top_LOD0", (0, 7.0, 4.0), (5.5, 0.7, 0.35))
    for index, x in enumerate((-7.0, 0.0, 7.0)):
        _cube(bpy, "ENV_Pillar_%02d_LOD0" % index, (x, -6.5, 1.7), (0.55, 0.55, 1.7))
    _cube(bpy, "ENV_Brazier_LOD0", (5.8, -2.5, 0.6), (0.55, 0.55, 0.6))
    for index, (x,y) in enumerate(((-7.5,5.0),(7.2,4.0),(-7.0,-2.0),(7.0,-7.0))):
        _cube(bpy, "ENV_Debris_%02d_LOD0" % index, (x,y,0.25), (0.8,0.45,0.25))
    scene["litd_environment_id"] = "ashlands_visual_arena"
    scene["litd_clutter_rule"] = arena["clutter_rule"]
    path = ROOT / output
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args(script_argv())
    build(args.output)
    print("LITD_VERTICAL_SLICE_ARENA_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
