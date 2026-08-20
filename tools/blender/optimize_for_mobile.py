#!/usr/bin/env python3
from __future__ import annotations

import argparse

from tools.blender.automation_common import ROOT, VISUAL_CONTRACT, bpy_module, load_json, mesh_triangles, save_blend, scene_armatures, scene_meshes, script_argv, write_json


def _merge_duplicate_material_slots(bpy, meshes: list) -> int:
    changed = 0
    for obj in meshes:
        seen: dict[str, int] = {}
        for index, slot in enumerate(list(obj.material_slots)):
            material = slot.material
            if material is None:
                continue
            key = material.name
            if key in seen:
                for poly in obj.data.polygons:
                    if poly.material_index == index:
                        poly.material_index = seen[key]
                changed += 1
            else:
                seen[key] = index
    return changed


def optimize(asset_id: str, output: str, report_path: str) -> dict:
    bpy = bpy_module()
    contract = load_json(VISUAL_CONTRACT)
    meshes = scene_meshes(bpy)
    _merge_duplicate_material_slots(bpy, meshes)
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        try:
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        except RuntimeError:
            pass
        obj.select_set(False)
    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)

    is_character = asset_id in {"darius", "enemy_01_goule_affamee"}
    triangles = sum(mesh_triangles(obj) for obj in meshes)
    materials = len({slot.material.name for obj in meshes for slot in obj.material_slots if slot.material})
    bones = sum(len(arm.data.bones) for arm in scene_armatures(bpy))
    image_max = max([max(image.size) for image in bpy.data.images if image.size[0] and image.size[1]] or [0])
    if is_character:
        budgets = contract["mobile_budget"]["characters"]
        checks = {
            "triangles": {"value": triangles, "max": int(budgets["lod0_triangles_each"]), "pass": triangles <= int(budgets["lod0_triangles_each"])},
            "materials": {"value": materials, "max": int(budgets["materials_each_max"]), "pass": materials <= int(budgets["materials_each_max"])},
            "bones": {"value": bones, "max": int(budgets["bones_each_max"]), "pass": bones <= int(budgets["bones_each_max"])},
            "texture_px": {"value": image_max, "max": int(budgets["texture_max_px"]), "pass": image_max <= int(budgets["texture_max_px"])},
        }
    else:
        budgets = contract["mobile_budget"]["arena"]
        checks = {
            "triangles": {"value": triangles, "max": int(budgets["visible_triangles_max"]), "pass": triangles <= int(budgets["visible_triangles_max"])},
            "materials": {"value": materials, "max": int(budgets["materials_visible_max"]), "pass": materials <= int(budgets["materials_visible_max"])},
            "texture_px": {"value": image_max, "max": int(budgets["texture_max_px"]), "pass": image_max <= int(budgets["texture_max_px"])},
        }
    failed = [name for name, check in checks.items() if not check["pass"]]
    payload = {"version": 1, "asset_id": asset_id, "status": "pass" if not failed else "warn", "checks": checks, "failed": failed, "policy": "safe_non_destructive_defaults"}
    write_json(ROOT / report_path, payload)
    bpy.context.scene["litd_mobile_optimized"] = True
    bpy.context.scene["litd_mobile_asset_id"] = asset_id
    save_blend(bpy, output)
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args(script_argv())
    payload = optimize(args.asset_id, args.output, args.report)
    print("LITD_MOBILE", payload["status"].upper(), args.asset_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
