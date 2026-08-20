#!/usr/bin/env python3
from __future__ import annotations

import argparse

from tools.blender.automation_common import ROOT, VISUAL_CONTRACT, bpy_module, load_json, script_argv


def expected_target(asset_id: str) -> str:
    root = str(load_json(VISUAL_CONTRACT)["asset_ingest"]["roots"].get(asset_id, ""))
    return root.removeprefix("res://")


def publish(asset_id: str, target: str) -> None:
    bpy = bpy_module()
    expected = expected_target(asset_id)
    if not expected or target != expected:
        raise SystemExit("Publish target does not match the validated Godot ingest contract")
    if not bool(bpy.context.scene.get("litd_mobile_optimized", False)):
        raise SystemExit("Asset must pass the mobile optimization stage before publishing")
    path = ROOT / target
    path.parent.mkdir(parents=True, exist_ok=True)
    kwargs = {
        "filepath": str(path),
        "export_format": "GLB",
        "export_animations": True,
        "export_cameras": False,
        "export_lights": False,
    }
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        kwargs.pop("export_cameras", None)
        kwargs.pop("export_lights", None)
        bpy.ops.export_scene.gltf(**kwargs)
    print("LITD_PUBLISH_OK", asset_id, target)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--target", required=True)
    args = parser.parse_args(script_argv())
    publish(args.asset_id, args.target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
