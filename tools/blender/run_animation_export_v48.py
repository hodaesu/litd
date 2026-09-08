#!/usr/bin/env python3
"""PC runner for canonical P0 Blender animation export v48."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

from tools.blender.generate_animation_export_plan_v48 import build_payload, render

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PLAN = ROOT / "build/animation_export_plan_v48.json"
BLENDER_SCRIPT = ROOT / "tools/blender/animation_export_bundle_v48.py"


def _resolve_tool(value: str) -> str | None:
    candidate = Path(value)
    if candidate.exists():
        return str(candidate.resolve())
    return shutil.which(value)


def _selected(plan: dict, bundle_ids: list[str]) -> list[dict]:
    if not bundle_ids:
        return list(plan.get("bundles", []))
    wanted = set(bundle_ids)
    result = [item for item in plan.get("bundles", []) if str(item.get("bundle_id")) in wanted]
    missing = wanted - {str(item.get("bundle_id")) for item in result}
    if missing:
        raise SystemExit(f"unknown bundle ids: {sorted(missing)}")
    return result


def build_commands(root: Path, plan_path: Path, blender: str, bundles: list[dict]) -> list[list[str]]:
    commands = []
    for item in bundles:
        commands.append([
            blender,
            "--background",
            str(root / item["source_blend"]),
            "--python",
            str(BLENDER_SCRIPT),
            "--",
            "--manifest",
            str(plan_path),
            "--bundle-id",
            str(item["bundle_id"]),
            "--output",
            str(root / item["output_glb"]),
        ])
    return commands


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    parser.add_argument("--bundle", action="append", default=[])
    args = parser.parse_args()

    plan = build_payload(ROOT)
    plan_path = args.plan if args.plan.is_absolute() else (ROOT / args.plan)
    plan_path.parent.mkdir(parents=True, exist_ok=True)
    plan_path.write_text(render(plan), encoding="utf-8")
    bundles = _selected(plan, args.bundle)
    blender_resolved = _resolve_tool(args.blender)
    missing_sources = [
        str(item["source_blend"]) for item in bundles
        if not (ROOT / item["source_blend"]).exists()
    ]
    report = {
        "version": 48,
        "bundle_count": len(bundles),
        "clip_count": sum(int(item["clip_count"]) for item in bundles),
        "blender": blender_resolved,
        "missing_source_blends": missing_sources,
        "ready": bool(blender_resolved) and not missing_sources,
    }

    if args.preflight:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0 if report["ready"] else 2

    command_blender = blender_resolved or args.blender
    commands = build_commands(ROOT, plan_path, command_blender, bundles)
    if args.dry_run:
        print(json.dumps({"preflight": report, "commands": commands}, ensure_ascii=False, indent=2))
        return 0

    if not report["ready"]:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 2
    for command in commands:
        subprocess.run(command, cwd=ROOT, check=True)
    print(f"V48_EXPORT_COMPLETE bundles={len(bundles)} clips={report['clip_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
