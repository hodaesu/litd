#!/usr/bin/env python3
"""Blender-side validator/exporter for one canonical P0 animation bundle v48.

Run with:
blender --background SOURCE.blend --python tools/blender/animation_export_bundle_v48.py -- \
  --manifest PLAN.json --bundle-id P0B-... --output OUTPUT.glb
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _user_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _keyframe_count(action) -> int:
    try:
        count = sum(len(fc.keyframe_points) for fc in action.fcurves)
        if count:
            return int(count)
    except Exception:
        pass
    try:
        start, end = action.frame_range
        return 2 if float(end) > float(start) else 0
    except Exception:
        return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args(_user_args())

    import bpy

    plan = json.loads(args.manifest.read_text(encoding="utf-8"))
    bundle = next((item for item in plan.get("bundles", []) if item.get("bundle_id") == args.bundle_id), None)
    if bundle is None:
        raise SystemExit(f"unknown bundle id: {args.bundle_id}")

    action_by_key = {}
    duplicates = set()
    for action in bpy.data.actions:
        key = str(action.get("litd_canonical_clip_key", action.name))
        if key in action_by_key:
            duplicates.add(key)
        action_by_key[key] = action

    expected = [str(value) for value in bundle.get("expected_actions", [])]
    missing = [key for key in expected if key not in action_by_key]
    empty = [key for key in expected if key in action_by_key and _keyframe_count(action_by_key[key]) < 2]
    duplicate_expected = sorted(set(expected) & duplicates)
    if missing or empty or duplicate_expected:
        print(json.dumps({
            "bundle_id": args.bundle_id,
            "missing_actions": missing,
            "empty_actions": empty,
            "duplicate_action_keys": duplicate_expected,
        }, ensure_ascii=False, indent=2))
        return 2

    for key in expected:
        action_by_key[key].use_fake_user = True
        action_by_key[key]["litd_canonical_clip_key"] = key

    if args.validate_only:
        print(f"V48_BUNDLE_VALID {args.bundle_id} clips={len(expected)}")
        return 0

    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=True,
        export_nla_strips=False,
    )
    sidecar = output.with_suffix(".clips.json")
    sidecar.write_text(json.dumps({
        "version": 48,
        "bundle_id": args.bundle_id,
        "source_blend": bpy.data.filepath,
        "output_glb": str(output),
        "clips": expected,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"V48_BUNDLE_EXPORTED {args.bundle_id} clips={len(expected)} output={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
