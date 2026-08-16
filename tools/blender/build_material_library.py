#!/usr/bin/env python3
"""Build the portable dark-fantasy cel-shaded material library in Blender."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILES_PATH = ROOT / "data/blender/material_profiles.json"


def load_profiles(path: Path = PROFILES_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_material_plan(payload: dict) -> dict:
    shared = payload["shared"]
    materials = []
    for profile in payload["profiles"]:
        materials.append({
            **profile,
            "texture_set": {
                "name": f"T_{profile['id']}_palette",
                "width": int(shared["shade_steps"]), "height": 1,
                "colors": _shade_palette(profile["base_color"], profile["accent"], int(shared["shade_steps"])),
                "color_space": "sRGB", "packed": True,
            },
            "godot": {"shader": "StandardMaterial3D", "outline_pass": bool(shared["outline"]), "mobile_safe": True},
        })
    return {
        "version": payload["version"], "render_target": payload["render_target"],
        "art_direction": payload["art_direction"], "shared": shared, "materials": materials,
    }


def _shade_palette(base: list[float], accent: list[float], steps: int) -> list[list[float]]:
    shadow = [round(value * 0.38, 4) for value in base[:3]] + [1.0]
    if steps == 2:
        return [shadow, base]
    return [shadow, base, accent][:steps]


def execute_in_blender(plan: dict, output_blend: Path) -> None:
    import bpy  # type: ignore

    for spec in plan["materials"]:
        image_spec = spec["texture_set"]
        image = bpy.data.images.new(image_spec["name"], width=image_spec["width"], height=1, alpha=True)
        image.pixels = [channel for color in image_spec["colors"] for channel in color]
        image.pack()
        image["litd_color_space"] = image_spec["color_space"]
        material = bpy.data.materials.get(spec["material"]) or bpy.data.materials.new(spec["material"])
        material.use_nodes = True
        material.diffuse_color = spec["base_color"]
        material.roughness = spec["roughness"]
        material.metallic = spec["metallic"]
        material["litd_profile"] = spec["id"]
        material["litd_shade_steps"] = plan["shared"]["shade_steps"]
        material["litd_palette"] = image.name
        material["litd_outline"] = spec["godot"]["outline_pass"]
        material["litd_emission_strength"] = spec.get("emission_strength", 0.0)
    output_blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend))


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--profiles", type=Path, default=PROFILES_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(argv)
    plan = build_material_plan(load_profiles(args.profiles))
    if args.plan_only:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    if args.output is None:
        parser.error("--output is required unless --plan-only is used")
    execute_in_blender(plan, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
