#!/usr/bin/env python3
"""Validate one real LITD Blender master scene against the canonical v52 plan.

Run from Blender, for example:

    blender --background art/blender/animation_masters/humanoid_standard.blend \
      --python tools/blender/validate_master_model_scene_v53.py -- \
      --master-id humanoid_standard --stage final \
      --report build/blender_validation/humanoid_standard.json

The validator NEVER creates geometry, rigs, Actions, LODs or placeholder .blend
files. It only inspects the open Blender scene and fails when the requested
production stage is incomplete.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable

try:
    import bpy  # type: ignore
except ImportError as exc:  # pragma: no cover - only Blender supplies bpy
    raise SystemExit(
        "BLENDER_SCENE_VALIDATOR_V53_ERROR: this script must run inside Blender (bpy unavailable)"
    ) from exc

ROOT = Path(__file__).resolve().parents[2]
INDEX_PATH = ROOT / "data/blender/modeling_plans_v52/index.json"
COMMON_PATH = ROOT / "data/blender/modeling_plans_v52/common_contract.json"
EXPORT_PLAN_PATH = ROOT / "data/blender/animation_export_plan_v48.json"

STAGE_ORDER = {
    "blockout": 10,
    "damage": 20,
    "rig": 30,
    "lod": 40,
    "animation": 50,
    "final": 60,
}

DAMAGE_KEYS = (
    "stump_objects",
    "stump_or_break_objects",
    "stump_or_scar_objects",
    "stump_or_breaks",
    "break_objects",
)

FORBIDDEN_ISSHAR_NAME_TOKENS = (
    "cable",
    "piston",
    "gun",
    "firearm",
    "exoskeleton",
    "neon",
    "servo",
)

COPISTE_FORBIDDEN_WORDS = ("purple", "violet", "magenta", "lilac", "pourpre")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def blender_args() -> list[str]:
    argv = sys.argv
    return argv[argv.index("--") + 1 :] if "--" in argv else []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master-id", required=True)
    parser.add_argument("--stage", choices=tuple(STAGE_ORDER), default="final")
    parser.add_argument("--report", type=Path)
    parser.add_argument(
        "--strict-budget",
        action="store_true",
        help="Treat a parsed LOD0 triangle budget overrun as an error instead of a warning.",
    )
    return parser.parse_args(blender_args())


def resolve_plan(master_id: str) -> tuple[dict[str, Any], Path]:
    index = load_json(INDEX_PATH)
    for entry in index.get("production_order", []):
        if str(entry.get("id")) == master_id:
            plan_path = ROOT / str(entry["plan"])
            return load_json(plan_path), plan_path
    raise SystemExit(f"BLENDER_SCENE_VALIDATOR_V53_ERROR: unknown master id {master_id!r}")


def stage_at_least(stage: str, minimum: str) -> bool:
    return STAGE_ORDER[stage] >= STAGE_ORDER[minimum]


def object_names() -> set[str]:
    return {obj.name for obj in bpy.data.objects}


def collection_names() -> set[str]:
    return {collection.name for collection in bpy.data.collections}


def armature_for(master_id: str) -> Any | None:
    exact = bpy.data.objects.get(f"RIG_{master_id}")
    if exact is not None and getattr(exact, "type", "") == "ARMATURE":
        return exact
    armatures = [obj for obj in bpy.data.objects if getattr(obj, "type", "") == "ARMATURE"]
    return armatures[0] if len(armatures) == 1 else None


def all_bone_names(armature: Any | None) -> set[str]:
    if armature is None:
        return set()
    data = getattr(armature, "data", None)
    bones = getattr(data, "bones", []) if data is not None else []
    return {bone.name for bone in bones}


def all_action_keys() -> dict[str, Any]:
    result: dict[str, Any] = {}
    for action in bpy.data.actions:
        result[action.name] = action
        try:
            canonical = action.get("litd_canonical_clip_key")
        except Exception:
            canonical = None
        if canonical:
            result[str(canonical)] = action
    return result


def action_has_real_keys(action: Any) -> bool:
    fcurves = getattr(action, "fcurves", None)
    if fcurves is not None:
        try:
            if sum(len(fc.keyframe_points) for fc in fcurves) >= 2:
                return True
        except Exception:
            pass
    try:
        start, end = action.frame_range
        return float(end) > float(start)
    except Exception:
        return False


def expected_actions(source_blend: str) -> list[str]:
    payload = load_json(EXPORT_PLAN_PATH)
    for bundle in payload.get("bundles", []):
        if str(bundle.get("source_blend")) == source_blend:
            return [str(name) for name in bundle.get("expected_actions", [])]
    return []


def expected_sockets(plan: dict[str, Any]) -> list[str]:
    spec_path = ROOT / str(plan["source_v51"])
    spec = load_json(spec_path)
    marker = spec.get("marker_contract", {})
    sockets = marker.get("weapon_sockets", [])
    return [str(name) for name in sockets]


def expected_damage_objects(plan: dict[str, Any]) -> list[str]:
    for key in DAMAGE_KEYS:
        values = plan.get(key)
        if values:
            return [str(value) for value in values]
    return []


def f3_marker_names(plan: dict[str, Any]) -> list[str]:
    explicit = plan.get("f3_pose_set")
    if explicit:
        return [str(value) for value in explicit]
    return [f"POSE_F3_{name.removeprefix('BODY_')}" for name in plan.get("runtime_objects", [])]


def marker_exists(name: str, bone_names: set[str], action_keys: dict[str, Any]) -> bool:
    return name in bpy.data.objects or name in bone_names or name in action_keys


def lod_variant_exists(base_name: str, level: int) -> bool:
    names = object_names()
    candidates = {
        f"{base_name}_LOD{level}",
        base_name.replace("BODY_", f"BODY_LOD{level}_", 1),
    }
    return any(candidate in names for candidate in candidates)


def mesh_triangle_count(obj: Any) -> int:
    if getattr(obj, "type", "") != "MESH":
        return 0
    mesh = obj.data
    try:
        mesh.calc_loop_triangles()
        return len(mesh.loop_triangles)
    except Exception:
        return len(getattr(mesh, "polygons", []))


def approximate_lod0_triangles(runtime_names: Iterable[str]) -> int:
    total = 0
    for name in runtime_names:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            total += mesh_triangle_count(obj)
    for obj in bpy.data.objects:
        if obj.name.startswith("EQUIP_") and "_LOD1" not in obj.name and "_LOD2" not in obj.name:
            total += mesh_triangle_count(obj)
    return total


def parse_triangle_budget(text: str) -> tuple[int | None, int | None]:
    match = re.search(r"(\d+)k\s*[-–]\s*(\d+)k", text.lower())
    if not match:
        return None, None
    return int(match.group(1)) * 1000, int(match.group(2)) * 1000


def material_rgb_values() -> list[tuple[str, tuple[float, float, float]]]:
    values: list[tuple[str, tuple[float, float, float]]] = []
    for mat in bpy.data.materials:
        diffuse = getattr(mat, "diffuse_color", None)
        if diffuse and len(diffuse) >= 3:
            values.append((f"material:{mat.name}:diffuse", (float(diffuse[0]), float(diffuse[1]), float(diffuse[2]))))
        tree = getattr(mat, "node_tree", None)
        if tree is None:
            continue
        for node in tree.nodes:
            for socket in getattr(node, "inputs", []):
                value = getattr(socket, "default_value", None)
                if value is None or not hasattr(value, "__len__"):
                    continue
                try:
                    if len(value) >= 3 and all(isinstance(float(value[i]), float) for i in range(3)):
                        values.append(
                            (
                                f"material:{mat.name}:{node.name}:{socket.name}",
                                (float(value[0]), float(value[1]), float(value[2])),
                            )
                        )
                except Exception:
                    continue
    for light in bpy.data.lights:
        color = getattr(light, "color", None)
        if color and len(color) >= 3:
            values.append((f"light:{light.name}", (float(color[0]), float(color[1]), float(color[2]))))
    world = bpy.context.scene.world
    if world and getattr(world, "color", None):
        color = world.color
        values.append(("world:color", (float(color[0]), float(color[1]), float(color[2]))))
    return values


def looks_purple(rgb: tuple[float, float, float]) -> bool:
    r, g, b = (max(0.0, min(1.0, channel)) for channel in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    degrees = h * 360.0
    return 258.0 <= degrees <= 338.0 and s >= 0.12 and v >= 0.05


def named_datablocks() -> list[str]:
    names: list[str] = []
    for collection in (
        bpy.data.objects,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.lights,
        bpy.data.node_groups,
    ):
        names.extend(item.name for item in collection)
    return names


def weight_influence_violations(runtime_names: Iterable[str], maximum: int = 4) -> list[str]:
    violations: list[str] = []
    for name in runtime_names:
        obj = bpy.data.objects.get(name)
        if obj is None or getattr(obj, "type", "") != "MESH":
            continue
        for vertex in obj.data.vertices:
            weighted = [group for group in vertex.groups if float(group.weight) > 1e-6]
            if len(weighted) > maximum:
                violations.append(f"{name}:vertex:{vertex.index}:influences={len(weighted)}")
                if len(violations) >= 25:
                    return violations
    return violations


def validate(args: argparse.Namespace) -> dict[str, Any]:
    plan, plan_path = resolve_plan(args.master_id)
    common = load_json(COMMON_PATH)
    stage = args.stage
    errors: list[str] = []
    warnings: list[str] = []
    stats: dict[str, Any] = {}

    scene = bpy.context.scene
    units = scene.unit_settings
    if str(units.system) != "METRIC":
        errors.append(f"unit system must be METRIC, got {units.system}")
    if abs(float(units.scale_length) - 1.0) > 1e-6:
        errors.append(f"unit scale must be 1.0, got {units.scale_length}")

    required_collections = [str(name) for name in common.get("collection_layout", [])]
    missing_collections = [name for name in required_collections if name not in collection_names()]
    if missing_collections:
        errors.append(f"missing canonical collections: {missing_collections}")

    runtime_objects = [str(name) for name in plan.get("runtime_objects", [])]
    missing_body = [name for name in runtime_objects if bpy.data.objects.get(name) is None]
    if missing_body:
        errors.append(f"missing BODY objects: {missing_body}")
    non_mesh_body = [
        name
        for name in runtime_objects
        if bpy.data.objects.get(name) is not None and getattr(bpy.data.objects.get(name), "type", "") != "MESH"
    ]
    if non_mesh_body:
        errors.append(f"BODY objects must be meshes: {non_mesh_body}")

    armature = armature_for(args.master_id)
    bone_names = all_bone_names(armature)
    action_keys = all_action_keys()

    if stage_at_least(stage, "damage"):
        damage_objects = expected_damage_objects(plan)
        missing_damage = [name for name in damage_objects if bpy.data.objects.get(name) is None]
        if missing_damage:
            errors.append(f"missing STUMP/break objects: {missing_damage}")
        f3_markers = f3_marker_names(plan)
        missing_f3 = [name for name in f3_markers if not marker_exists(name, bone_names, action_keys)]
        if missing_f3:
            errors.append(f"missing F3 pose markers (object, bone or Action accepted): {missing_f3}")

    if stage_at_least(stage, "rig"):
        if armature is None:
            errors.append(f"missing unambiguous armature; expected RIG_{args.master_id}")
        elif "ROOT" not in bone_names:
            errors.append("armature is missing ROOT bone")
        sockets = expected_sockets(plan)
        missing_sockets = [name for name in sockets if not marker_exists(name, bone_names, action_keys)]
        if missing_sockets:
            errors.append(f"missing weapon sockets: {missing_sockets}")
        influence_errors = weight_influence_violations(runtime_objects, 4)
        if influence_errors:
            errors.append(
                "more than four skin influences on BODY vertices; first violations: "
                + ", ".join(influence_errors[:10])
            )

    if stage_at_least(stage, "lod"):
        missing_lod1 = [name for name in runtime_objects if not lod_variant_exists(name, 1)]
        missing_lod2 = [name for name in runtime_objects if not lod_variant_exists(name, 2)]
        if missing_lod1:
            errors.append(f"missing LOD1 BODY variants: {missing_lod1}")
        if missing_lod2:
            errors.append(f"missing LOD2 BODY variants: {missing_lod2}")

    expected_p0 = expected_actions(str(plan.get("source_blend", "")))
    if stage_at_least(stage, "animation"):
        if not expected_p0:
            errors.append("no matching v48 animation bundle found for source_blend")
        missing_actions = [name for name in expected_p0 if name not in action_keys]
        empty_actions = [
            name
            for name in expected_p0
            if name in action_keys and not action_has_real_keys(action_keys[name])
        ]
        if missing_actions:
            errors.append(f"missing required P0 Actions: {missing_actions}")
        if empty_actions:
            errors.append(f"required P0 Actions have no real keyed duration: {empty_actions}")

    triangles = approximate_lod0_triangles(runtime_objects)
    stats["approx_lod0_triangles_body_plus_equipment"] = triangles
    lod0_text = str(plan.get("lod_plan", {}).get("lod0", ""))
    min_tri, max_tri = parse_triangle_budget(lod0_text)
    stats["lod0_budget_parsed"] = {"min": min_tri, "max": max_tri}
    if max_tri is not None and triangles > max_tri:
        message = f"approx LOD0 triangles {triangles} exceed plan maximum {max_tri}"
        if args.strict_budget:
            errors.append(message)
        else:
            warnings.append(message)
    if min_tri is not None and triangles and triangles < min_tri:
        warnings.append(
            f"approx LOD0 triangles {triangles} are below plan reference {min_tri}; confirm silhouette/detail quality"
        )

    if stage_at_least(stage, "final") and args.master_id == "boss_ishar":
        lower_names = [name.lower() for name in named_datablocks()]
        forbidden_hits = sorted(
            {
                token
                for token in FORBIDDEN_ISSHAR_NAME_TOKENS
                if any(token in name for name in lower_names)
            }
        )
        if forbidden_hits:
            errors.append(f"Ishar datablock names contain forbidden sci-fi tokens: {forbidden_hits}")
        warnings.append(
            "Ishar visual anti-sci-fi gate still requires human review: basalt/obsidian, forged iron, tarnished bronze, sacred reliquary, no robotic silhouette."
        )

    if stage_at_least(stage, "final") and args.master_id == "boss_le_copiste":
        lower_names = [name.lower() for name in named_datablocks()]
        word_hits = sorted(
            {
                word
                for word in COPISTE_FORBIDDEN_WORDS
                if any(word in name for name in lower_names)
            }
        )
        if word_hits:
            errors.append(f"Le Copiste contains forbidden color words in datablock names: {word_hits}")
        purple_values = [label for label, rgb in material_rgb_values() if looks_purple(rgb)]
        if purple_values:
            errors.append(
                "Le Copiste contains purple/violet/magenta/lilac-like RGB values: "
                + ", ".join(purple_values[:25])
            )
        warnings.append(
            "Le Copiste final color gate also requires human texture/VFX review: zero purple, violet, magenta or lilac; COPY_MATRIX must read as manuscript reliquary, never reactor."
        )

    suspicious_duplicates = [
        obj.name
        for obj in bpy.data.objects
        if any(token in obj.name.lower() for token in ("full_body_duplicate", "intact_duplicate", "hidden_full_body"))
    ]
    if suspicious_duplicates:
        errors.append(f"forbidden hidden intact-body duplicate naming detected: {suspicious_duplicates}")

    stats.update(
        {
            "master_id": args.master_id,
            "stage": stage,
            "plan": str(plan_path.relative_to(ROOT)),
            "source_blend": str(plan.get("source_blend", "")),
            "body_expected": len(runtime_objects),
            "actions_expected": len(expected_p0),
            "objects_total": len(bpy.data.objects),
            "materials_total": len(bpy.data.materials),
            "actions_total": len(bpy.data.actions),
        }
    )
    return {
        "version": 53,
        "validator": "tools/blender/validate_master_model_scene_v53.py",
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "warnings": warnings,
        "stats": stats,
        "truth_rule": "PASS validates the real open Blender scene at the requested stage; it does not replace human visual approval or Godot v49/v50 validation.",
    }


def main() -> int:
    args = parse_args()
    report = validate(args)
    if args.report:
        report_path = args.report if args.report.is_absolute() else ROOT / args.report
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if report["status"] == "PASS":
        print(
            "BLENDER_SCENE_VALIDATOR_V53_OK "
            f"master={args.master_id} stage={args.stage} errors=0 warnings={len(report['warnings'])}"
        )
        return 0
    print(
        "BLENDER_SCENE_VALIDATOR_V53_ERROR "
        f"master={args.master_id} stage={args.stage} errors={len(report['errors'])}"
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
