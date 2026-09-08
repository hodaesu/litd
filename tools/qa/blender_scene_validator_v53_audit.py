#!/usr/bin/env python3
"""Static audit for the Blender-side master scene validator v53.

CI has no right to pretend Blender art exists. This audit only verifies that the
validator is wired to the canonical v52/v48 contracts and remains read-only with
respect to Blender scene/art asset creation.
"""
from __future__ import annotations

import ast
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "tools/blender/validate_master_model_scene_v53.py"
INDEX52 = ROOT / "data/blender/modeling_plans_v52/index.json"
EXPORT48 = ROOT / "data/blender/animation_export_plan_v48.json"

EXPECTED_IDS = [
    "humanoid_standard",
    "construct_biped",
    "humanoid_massive",
    "quadruped",
    "insectoid",
    "serpentine",
    "amorphous",
    "boss_ishar",
    "boss_orateur_sans_voix",
    "boss_mere_des_veines",
    "boss_porte_cendres_blanc",
    "boss_le_copiste",
]
EXPECTED_STAGES = {"blockout", "damage", "rig", "lod", "animation", "final"}
FORBIDDEN_MUTATING_BPY_CALLS = {
    "bpy.ops.mesh.primitive_cube_add",
    "bpy.ops.mesh.primitive_uv_sphere_add",
    "bpy.ops.mesh.primitive_ico_sphere_add",
    "bpy.ops.mesh.primitive_cylinder_add",
    "bpy.ops.object.armature_add",
    "bpy.ops.object.delete",
    "bpy.ops.wm.save_as_mainfile",
    "bpy.ops.wm.save_mainfile",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def dotted_name(node: ast.AST) -> str:
    parts: list[str] = []
    current: ast.AST | None = node
    while isinstance(current, ast.Attribute):
        parts.append(current.attr)
        current = current.value
    if isinstance(current, ast.Name):
        parts.append(current.id)
    return ".".join(reversed(parts))


def fail(message: str) -> None:
    raise SystemExit(f"BLENDER_SCENE_VALIDATOR_V53_AUDIT_ERROR: {message}")


def main() -> int:
    source = VALIDATOR.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(VALIDATOR))
    index = load(INDEX52)
    export = load(EXPORT48)

    ids = [str(item.get("id", "")) for item in index.get("production_order", [])]
    if ids != EXPECTED_IDS:
        fail(f"v52 canonical order drifted: {ids}")
    if int(export.get("bundle_count", 0)) != 12:
        fail("v48 must still expose exactly 12 Blender bundles")
    if int(export.get("master_clip_count", 0)) != 320:
        fail("v48 P0 master clip count must remain 320")

    required_source_tokens = [
        'INDEX_PATH = ROOT / "data/blender/modeling_plans_v52/index.json"',
        'EXPORT_PLAN_PATH = ROOT / "data/blender/animation_export_plan_v48.json"',
        '"blockout": 10',
        '"damage": 20',
        '"rig": 30',
        '"lod": 40',
        '"animation": 50',
        '"final": 60',
        'weight_influence_violations(runtime_objects, 4)',
        'expected_actions',
        'looks_purple',
        'boss_ishar',
        'boss_le_copiste',
        'purple',
        'violet',
        'magenta',
        'lilac',
        'BLENDER_SCENE_VALIDATOR_V53_OK',
        'BLENDER_SCENE_VALIDATOR_V53_ERROR',
    ]
    for token in required_source_tokens:
        if token not in source:
            fail(f"validator missing required contract token: {token}")

    stage_order = None
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "STAGE_ORDER":
                    stage_order = ast.literal_eval(node.value)
    if not isinstance(stage_order, dict) or set(stage_order) != EXPECTED_STAGES:
        fail(f"validator stages drifted: {stage_order}")

    mutating_calls: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            name = dotted_name(node.func)
            if name in FORBIDDEN_MUTATING_BPY_CALLS:
                mutating_calls.add(name)
    if mutating_calls:
        fail(f"validator must not create/delete/save Blender art: {sorted(mutating_calls)}")

    lower = source.lower()
    for forbidden_behavior in (
        "placeholder .blend",
        "never creates geometry",
        "human visual approval",
        "godot v49/v50 validation",
    ):
        if forbidden_behavior not in lower:
            fail(f"truth/read-only contract missing phrase: {forbidden_behavior}")

    if "--master-id" not in source or "--stage" not in source or "--report" not in source:
        fail("validator CLI is incomplete")
    if "--strict-budget" not in source:
        fail("validator must expose optional strict LOD budget enforcement")

    print(
        "BLENDER_SCENE_VALIDATOR_V53_AUDIT_OK "
        f"masters={len(ids)} bundles={export['bundle_count']} clips={export['master_clip_count']} stages={len(EXPECTED_STAGES)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
