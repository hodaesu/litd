#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from tools.blender.automation_common import ROOT, VISUAL_CONTRACT, bpy_module, load_json, mesh_triangles, scene_armatures, scene_meshes, script_argv, write_json


def inspect(asset_id: str) -> dict:
    bpy = bpy_module()
    contract = load_json(VISUAL_CONTRACT)
    meshes = scene_meshes(bpy)
    armatures = scene_armatures(bpy)
    character = asset_id in {"darius", "enemy_01_goule_affamee"}
    checks: dict[str, dict] = {}

    tris = sum(mesh_triangles(obj) for obj in meshes)
    budget = contract["mobile_budget"]["characters"]["lod0_triangles_each"] if character else contract["mobile_budget"]["arena"]["visible_triangles_max"]
    checks["mesh_present"] = {"pass": bool(meshes), "count": len(meshes)}
    checks["triangle_budget"] = {"pass": tris <= int(budget), "value": tris, "max": int(budget)}
    checks["uv_layers"] = {"pass": all(len(obj.data.uv_layers) > 0 for obj in meshes), "missing": [obj.name for obj in meshes if len(obj.data.uv_layers) == 0]}
    checks["applied_scale"] = {"pass": all(max(abs(v - 1.0) for v in obj.scale) < 0.001 for obj in meshes), "offenders": [obj.name for obj in meshes if max(abs(v - 1.0) for v in obj.scale) >= 0.001]}

    material_count = len({slot.material.name for obj in meshes for slot in obj.material_slots if slot.material})
    material_budget = contract["mobile_budget"]["characters"]["materials_each_max"] if character else contract["mobile_budget"]["arena"]["materials_visible_max"]
    checks["materials"] = {"pass": material_count <= int(material_budget), "value": material_count, "max": int(material_budget)}

    if character:
        required_bones = list(contract["asset_ingest"]["required_bones"])
        required_sockets = list(contract["asset_ingest"]["required_sockets"])
        bone_names = {bone.name for arm in armatures for bone in arm.data.bones}
        object_names = {obj.name for obj in bpy.context.scene.objects}
        checks["armature"] = {"pass": len(armatures) == 1, "count": len(armatures)}
        checks["bones"] = {"pass": all(name in bone_names for name in required_bones), "missing": [name for name in required_bones if name not in bone_names]}
        checks["sockets"] = {"pass": all(name in object_names for name in required_sockets), "missing": [name for name in required_sockets if name not in object_names]}
        checks["bone_budget"] = {"pass": len(bone_names) <= int(contract["mobile_budget"]["characters"]["bones_each_max"]), "value": len(bone_names), "max": int(contract["mobile_budget"]["characters"]["bones_each_max"])}

    failed = [name for name, value in checks.items() if not value.get("pass", False)]
    return {"version": 1, "asset_id": asset_id, "status": "pass" if not failed else "fail", "checks": checks, "failed": failed}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(script_argv())
    payload = inspect(args.asset_id)
    write_json(ROOT / args.report, payload)
    print(payload["status"].upper(), args.asset_id)
    return 1 if args.strict and payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
