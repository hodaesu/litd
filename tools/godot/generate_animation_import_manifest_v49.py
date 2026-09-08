#!/usr/bin/env python3
"""Generate Godot-side validation manifest for canonical P0 animation GLBs v49."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from tools.blender.generate_animation_export_plan_v48 import build_payload as build_v48

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/godot/animation_import_manifest_v49.json"


def build_payload(root: Path = ROOT) -> dict:
    v48 = build_v48(root)
    bundles = []
    for item in v48.get("bundles", []):
        bundles.append({
            "bundle_id": str(item["bundle_id"]),
            "resource_path": "res://" + str(item["output_glb"]).replace("\\", "/"),
            "sidecar_path": "res://" + str(item["sidecar_json"]).replace("\\", "/"),
            "expected_animation_count": int(item["clip_count"]),
            "expected_animations": list(item["expected_actions"]),
            "retarget_family": str(item["retarget_family"]),
            "owner_character_id": str(item.get("owner_character_id", "")),
        })
    return {
        "version": 49,
        "generator": "tools/godot/generate_animation_import_manifest_v49.py",
        "source_version": 48,
        "priority": "P0",
        "bundle_count": len(bundles),
        "master_clip_count": sum(item["expected_animation_count"] for item in bundles),
        "godot_import_contract": {
            "preserve_blender_action_names": True,
            "validate_every_expected_animation": True,
            "block_on_missing_glb": True,
            "block_on_missing_animation": True,
            "root_motion_remains_gameplay_authoritative": True,
        },
        "pc_commands": {
            "generate": "python -m tools.godot.generate_animation_import_manifest_v49",
            "force_import": "godot --headless --path . --editor --quit",
            "validate": "godot --headless --path . --script tools/godot/animation_import_validator_v49.gd -- --manifest data/godot/animation_import_manifest_v49.json",
        },
        "bundles": bundles,
        "gameplay_neutral": True,
    }


def render(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    payload = build_payload()
    if args.summary:
        print(json.dumps({
            "bundle_count": payload["bundle_count"],
            "master_clip_count": payload["master_clip_count"],
        }, indent=2))
        return 0
    expected = render(payload)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("animation import manifest v49 output is out of date")
        print("animation import manifest v49 is current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"generated Godot animation import manifest for {payload['bundle_count']} bundles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
