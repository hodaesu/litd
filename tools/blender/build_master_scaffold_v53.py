#!/usr/bin/env python3
"""Create SAFE Blender scene scaffolds for the 12 LITD master models (v53).

The scaffold deliberately creates no Mesh, Material, Armature bone or Action data.
It only prepares collections, TODO empties, metadata and embedded instructions so a
real artist-authored asset cannot be confused with generated placeholder art.

Static modes run in normal Python. --execute must run inside Blender.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "data/blender/modeling_plans_v52/index.json"
COMMON = ROOT / "data/blender/modeling_plans_v52/common_contract.json"
DEFAULT_OUTPUT_DIR = ROOT / "art/blender/scaffolds_v53"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _walk_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from _walk_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from _walk_strings(item)


def _prefixed_strings(plan: dict[str, Any], prefix: str) -> list[str]:
    values = {text for text in _walk_strings(plan) if text.startswith(prefix)}
    return sorted(values)


def _safe_slug(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_]+", "_", value.strip())
    return re.sub(r"_+", "_", value).strip("_") or "unnamed"


def load_descriptors(root: Path = ROOT) -> list[dict[str, Any]]:
    index = _load(root / INDEX.relative_to(ROOT))
    descriptors: list[dict[str, Any]] = []
    for entry in index.get("production_order", []):
        plan_path = root / str(entry["plan"])
        plan = _load(plan_path)
        master_id = str(plan["id"])
        descriptors.append({
            "order": int(plan["order"]),
            "id": master_id,
            "plan_path": str(plan_path.relative_to(root)),
            "source_blend": str(plan["source_blend"]),
            "safe_scaffold_blend": f"art/blender/scaffolds_v53/{master_id}_scaffold.blend",
            "runtime_objects": list(plan.get("runtime_objects", [])),
            "stump_targets": _prefixed_strings(plan, "STUMP_"),
            "f3_pose_targets": _prefixed_strings(plan, "POSE_F3_"),
            "equipment_targets": _prefixed_strings(plan, "EQUIP_"),
            "socket_targets": _prefixed_strings(plan, "SOCKET_"),
            "rig_steps": list(plan.get("rig_build_order", [])),
            "truth": "Scaffold only: no generated mesh/material/bones/actions; artist must create the real asset",
        })
    return descriptors


def validate_descriptors(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    descriptors = load_descriptors(root)
    if len(descriptors) != 12:
        errors.append(f"expected 12 descriptors, got {len(descriptors)}")
    if [item["order"] for item in descriptors] != list(range(1, 13)):
        errors.append("master order must be exactly 1..12")
    ids = [item["id"] for item in descriptors]
    if len(ids) != len(set(ids)):
        errors.append("master ids must be unique")
    for item in descriptors:
        label = item["id"]
        if not item["source_blend"].endswith(".blend"):
            errors.append(f"{label}: source_blend must end in .blend")
        if not item["runtime_objects"]:
            errors.append(f"{label}: missing runtime BODY targets")
        if not all(str(name).startswith("BODY_") for name in item["runtime_objects"]):
            errors.append(f"{label}: runtime targets must use BODY_ names")
        if not item["rig_steps"] or not str(item["rig_steps"][0]).startswith("ROOT"):
            errors.append(f"{label}: rig plan must begin with ROOT")
        if item["safe_scaffold_blend"] == item["source_blend"]:
            errors.append(f"{label}: safe scaffold must never overwrite the canonical artist source")
    return errors


def _descriptor(master: str, root: Path = ROOT) -> dict[str, Any]:
    by_id = {item["id"]: item for item in load_descriptors(root)}
    if master not in by_id:
        raise SystemExit(f"unknown master id: {master}; choose one of: {', '.join(by_id)}")
    return by_id[master]


def _plan_for_descriptor(descriptor: dict[str, Any], root: Path = ROOT) -> dict[str, Any]:
    return _load(root / descriptor["plan_path"])


def _common(root: Path = ROOT) -> dict[str, Any]:
    return _load(root / COMMON.relative_to(ROOT))


def _execute_in_blender(descriptor: dict[str, Any], output: Path, root: Path = ROOT) -> None:
    try:
        import bpy  # type: ignore
    except ImportError as exc:  # pragma: no cover - Blender-only path
        raise SystemExit("--execute must be launched by Blender (bpy unavailable)") from exc

    output = output.resolve()
    canonical = (root / descriptor["source_blend"]).resolve()
    if output == canonical:
        raise SystemExit("REFUSING: v53 scaffold may not be saved over the canonical artist-authored source_blend")
    if output.exists():
        raise SystemExit(f"REFUSING: scaffold already exists: {output}; remove it explicitly before rebuilding")

    plan = _plan_for_descriptor(descriptor, root)
    common = _common(root)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["litd_master_id"] = descriptor["id"]
    scene["litd_scaffold_version"] = 53
    scene["litd_not_production_asset"] = True
    scene["litd_canonical_source_blend"] = descriptor["source_blend"]
    scene["litd_plan_v52"] = descriptor["plan_path"]

    root_collection = scene.collection
    collections: dict[str, Any] = {}
    for name in common.get("collection_layout", []):
        collection = bpy.data.collections.new(str(name))
        root_collection.children.link(collection)
        collections[str(name)] = collection

    def add_todo(name: str, collection_name: str, target: str, kind: str, index: int = 0) -> Any:
        obj = bpy.data.objects.new(name, None)
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = 0.12
        obj["litd_scaffold_v53"] = True
        obj["litd_not_production_asset"] = True
        obj["litd_target_name"] = target
        obj["litd_target_kind"] = kind
        obj["litd_master_id"] = descriptor["id"]
        obj["litd_sequence"] = index
        collections[collection_name].objects.link(obj)
        return obj

    for idx, target in enumerate(descriptor["runtime_objects"], 1):
        add_todo(f"TODO_{target}", "20_BODY", str(target), "BODY_MESH", idx)
    for idx, target in enumerate(descriptor["stump_targets"], 1):
        add_todo(f"TODO_{target}", "30_STUMPS", str(target), "STUMP_GEOMETRY", idx)
    for idx, target in enumerate(descriptor["equipment_targets"], 1):
        add_todo(f"TODO_{target}", "40_EQUIPMENT", str(target), "EQUIPMENT", idx)
    for idx, target in enumerate(descriptor["socket_targets"], 1):
        add_todo(f"TODO_{target}", "40_EQUIPMENT", str(target), "SOCKET", idx)
    for idx, target in enumerate(descriptor["f3_pose_targets"], 1):
        add_todo(f"TODO_{target}", "80_ANIMATIONS", str(target), "F3_POSE", idx)
    for idx, step in enumerate(descriptor["rig_steps"], 1):
        slug = _safe_slug(str(step))[:56]
        add_todo(f"TODO_RIG_{idx:02d}_{slug}", "50_RIG", str(step), "RIG_BUILD_STEP", idx)

    readme = bpy.data.texts.new("LITD_SCAFFOLD_v53_README.txt")
    readme.write(
        "LITD Les Veilleurs - SAFE SCAFFOLD v53\n\n"
        "This .blend contains NO production mesh, material, rig bones or animation Actions.\n"
        "TODO empties are instructions only. Replace them with artist-authored content.\n"
        f"Master: {descriptor['id']}\n"
        f"Canonical source: {descriptor['source_blend']}\n"
        f"Plan: {descriptor['plan_path']}\n\n"
        "Never rename a TODO empty into its canonical BODY/STUMP target unless the real geometry exists.\n"
        "Never export this scaffold as a game asset.\n"
    )
    embedded_plan = bpy.data.texts.new("LITD_MODELING_PLAN_v52.json")
    embedded_plan.write(json.dumps(plan, ensure_ascii=False, indent=2))

    if any(obj.type == "MESH" for obj in bpy.data.objects):
        raise SystemExit("internal safety failure: scaffold unexpectedly contains Mesh objects")
    if bpy.data.materials:
        raise SystemExit("internal safety failure: scaffold unexpectedly contains Materials")
    if bpy.data.actions:
        raise SystemExit("internal safety failure: scaffold unexpectedly contains Actions")
    if bpy.data.armatures:
        raise SystemExit("internal safety failure: scaffold unexpectedly contains Armatures")

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    print(f"MASTER_SCAFFOLD_V53_CREATED master={descriptor['id']} output={output}")


def _script_argv() -> list[str] | None:
    """Return only arguments after Blender's `--`, or normal Python argv."""
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1 :]
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Validate all v53 descriptors without Blender")
    parser.add_argument("--summary", action="store_true", help="Print the 12 safe scaffold descriptors")
    parser.add_argument("--master", help="Canonical master id")
    parser.add_argument("--execute", action="store_true", help="Create one safe scaffold .blend; must run inside Blender")
    parser.add_argument("--output", type=Path, help="Override safe scaffold output; canonical source_blend is forbidden")
    args = parser.parse_args(_script_argv())

    errors = validate_descriptors()
    if errors:
        for error in errors:
            print(f"MASTER_SCAFFOLD_V53_ERROR: {error}")
        return 1
    if args.check:
        print("MASTER_SCAFFOLD_V53_CHECK_OK masters=12 no_fake_mesh_material_bones_actions=true")
        return 0
    if args.summary:
        print(json.dumps({"version": 53, "masters": load_descriptors()}, ensure_ascii=False, indent=2))
        return 0
    if args.execute:
        if not args.master:
            parser.error("--execute requires --master")
        descriptor = _descriptor(args.master)
        output = args.output or (ROOT / descriptor["safe_scaffold_blend"])
        if not output.is_absolute():
            output = ROOT / output
        _execute_in_blender(descriptor, output)
        return 0
    parser.error("choose --check, --summary or --execute")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
