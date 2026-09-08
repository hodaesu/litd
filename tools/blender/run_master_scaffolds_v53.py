#!/usr/bin/env python3
"""PC orchestrator for safe Blender master scaffolds v53.

This runner only creates non-production scaffold .blend files under
art/blender/scaffolds_v53/. It never writes the canonical artist source paths.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from tools.blender.build_master_scaffold_v53 import ROOT, load_descriptors, validate_descriptors

SCRIPT = ROOT / "tools/blender/build_master_scaffold_v53.py"


def _resolve_blender(value: str) -> str | None:
    candidate = Path(value)
    if candidate.exists():
        return str(candidate.resolve())
    return shutil.which(value)


def build_plan(blender: str = "blender") -> dict:
    descriptors = load_descriptors()
    blender_path = _resolve_blender(blender)
    return {
        "version": 53,
        "master_count": len(descriptors),
        "blender": blender_path,
        "pc_ready": blender_path is not None,
        "blocker_code": "" if blender_path else "BLENDER_EXECUTABLE_REQUIRED",
        "safety": {
            "canonical_source_blends_written": False,
            "generated_meshes": False,
            "generated_materials": False,
            "generated_armature_bones": False,
            "generated_actions": False,
            "safe_output_root": "art/blender/scaffolds_v53",
        },
        "masters": [
            {
                "order": item["order"],
                "id": item["id"],
                "canonical_source_blend": item["source_blend"],
                "safe_scaffold_blend": item["safe_scaffold_blend"],
            }
            for item in descriptors
        ],
    }


def _command(blender: str, master: str, output: str) -> list[str]:
    return [
        blender,
        "--background",
        "--factory-startup",
        "--python",
        str(SCRIPT),
        "--",
        "--master",
        master,
        "--execute",
        "--output",
        output,
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--master", default="all", help="one master id or 'all'")
    args = parser.parse_args()

    errors = validate_descriptors()
    if errors:
        for error in errors:
            print(f"MASTER_SCAFFOLD_V53_ERROR: {error}")
        return 1

    plan = build_plan(args.blender)
    selected = plan["masters"] if args.master == "all" else [item for item in plan["masters"] if item["id"] == args.master]
    if not selected:
        raise SystemExit(f"unknown master: {args.master}")

    if args.preflight:
        print(json.dumps({
            "version": 53,
            "master_count": len(selected),
            "blender": plan["blender"],
            "pc_ready": plan["pc_ready"],
            "blocker_code": plan["blocker_code"],
            "safety": plan["safety"],
        }, ensure_ascii=False, indent=2))
        return 0 if plan["pc_ready"] else 2

    display_blender = plan["blender"] or args.blender
    commands = [_command(display_blender, item["id"], item["safe_scaffold_blend"]) for item in selected]
    if args.dry_run:
        print(json.dumps({
            "version": 53,
            "pc_ready": plan["pc_ready"],
            "blocker_code": plan["blocker_code"],
            "commands": commands,
            "safety": plan["safety"],
        }, ensure_ascii=False, indent=2))
        return 0

    if not plan["pc_ready"]:
        print(json.dumps({"status": "BLOCKED", "blocker_code": plan["blocker_code"]}, ensure_ascii=False))
        return 2

    for item, command in zip(selected, commands):
        safe_output = (ROOT / item["safe_scaffold_blend"]).resolve()
        canonical = (ROOT / item["canonical_source_blend"]).resolve()
        if safe_output == canonical:
            raise SystemExit(f"safety failure for {item['id']}: scaffold output equals canonical source")
        print("+", " ".join(command))
        subprocess.run(command, cwd=ROOT, check=True)

    print(f"MASTER_SCAFFOLDS_V53_COMPLETE count={len(selected)} safe_only=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
