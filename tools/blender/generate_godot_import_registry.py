#!/usr/bin/env python3
"""Generate deterministic Blender-output to Godot-import mappings."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIPELINE = ROOT / "data/blender/full_pipeline_manifest.json"
OUTPUT = ROOT / "data/blender/godot_import_registry.json"


def build_registry(root: Path = ROOT) -> dict:
    pipeline = json.loads((root / "data/blender/full_pipeline_manifest.json").read_text(encoding="utf-8"))
    assets = []
    for job in pipeline["stages"]:
        if job["stage"] == "materials":
            continue
        source = next(path for path in job["outputs"] if path.endswith(".glb"))
        if job["stage"] == "environments":
            target = source
        else:
            relative = source.removeprefix("builds/")
            target = f"assets/3d/{relative}"
        assets.append({
            "job_id": job["job_id"], "category": job["stage"],
            "source_glb": source, "godot_path": f"res://{target}",
            "approval": "pending", "preserve_placeholder_collision": True,
        })
    return {
        "version": 1, "generator": "tools/blender/generate_godot_import_registry.py",
        "godot_version": "4.3", "asset_count": len(assets), "assets": assets,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = json.dumps(build_registry(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit("Godot import registry is out of date")
        print(f"{build_registry()['asset_count']} Godot GLB import mappings are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"generated {build_registry()['asset_count']} Godot GLB import mappings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
