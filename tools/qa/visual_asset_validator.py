#!/usr/bin/env python3
"""Validate vertical-slice 3D asset metadata before Godot ingest.

The validator accepts a small JSON inspection report produced by Blender or another
inspection tool. It does not parse GLB binary data itself, so CI can run without
Blender. A failing report blocks promotion of an asset to the reviewed GLB path.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/visual_vertical_slice.json"


def load_contract(path: Path = CONTRACT_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_report(report: dict, contract: dict) -> list[str]:
    errors: list[str] = []
    asset_id = str(report.get("asset_id", ""))
    if not asset_id:
        return ["asset_id missing"]
    budgets = contract["mobile_budget"]
    ingest = contract["asset_ingest"]
    if asset_id in ("darius", "enemy_01_goule_affamee"):
        char_budget = budgets["characters"]
        if int(report.get("triangles_lod0", 0)) > int(char_budget["lod0_triangles_each"]):
            errors.append("LOD0 triangle budget exceeded")
        if int(report.get("triangles_lod1", 0)) > int(char_budget["lod1_triangles_each"]):
            errors.append("LOD1 triangle budget exceeded")
        if int(report.get("triangles_lod2", 0)) > int(char_budget["lod2_triangles_each"]):
            errors.append("LOD2 triangle budget exceeded")
        if int(report.get("materials", 0)) > int(char_budget["materials_each_max"]):
            errors.append("material budget exceeded")
        if int(report.get("bones", 0)) > int(char_budget["bones_each_max"]):
            errors.append("bone budget exceeded")
        if int(report.get("skinned_meshes", 0)) > int(char_budget["skinned_meshes_each_max"]):
            errors.append("skinned mesh budget exceeded")
        if int(report.get("max_texture_px", 0)) > int(char_budget["texture_max_px"]):
            errors.append("texture resolution budget exceeded")
        sockets = set(report.get("sockets", []))
        for required in ingest["required_sockets"]:
            if required not in sockets:
                errors.append(f"missing socket: {required}")
        bones = set(report.get("bone_names", []))
        for required in ingest["required_bones"]:
            if required not in bones:
                errors.append(f"missing bone: {required}")
        animation_names = set(report.get("animations", []))
        required_animations = set(contract["characters"][asset_id]["animation_minimum"])
        missing_anims = sorted(required_animations - animation_names)
        if missing_anims:
            errors.append("missing animations: " + ", ".join(missing_anims))
    elif asset_id == "ashlands_visual_arena":
        arena_budget = budgets["arena"]
        if int(report.get("visible_triangles", 0)) > int(arena_budget["visible_triangles_max"]):
            errors.append("arena visible triangle budget exceeded")
        if int(report.get("visible_materials", 0)) > int(arena_budget["materials_visible_max"]):
            errors.append("arena material budget exceeded")
        if int(report.get("max_texture_px", 0)) > int(arena_budget["texture_max_px"]):
            errors.append("arena texture resolution budget exceeded")
    else:
        errors.append(f"unknown validator profile: {asset_id}")
    if report.get("up_axis") not in ("Y", "+Y"):
        errors.append("asset must use Y-up export orientation")
    if abs(float(report.get("meters_per_unit", 0.0)) - 1.0) > 0.001:
        errors.append("asset scale must be 1 meter per unit")
    if report.get("negative_scale", False):
        errors.append("negative scale must be applied before export")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--contract", type=Path, default=CONTRACT_PATH)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    errors = validate_report(report, load_contract(args.contract))
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print(f"VISUAL_ASSET_VALIDATION_OK asset={report['asset_id']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
