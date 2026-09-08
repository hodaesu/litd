#!/usr/bin/env python3
"""End-to-end PC orchestrator for canonical P0 animation production v50.

Static planning is CI-safe. --execute requires the artist-authored Blender masters
and local Blender/Godot executables; it never manufactures fake animation data.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from tools.blender.generate_animation_export_plan_v48 import build_payload as build_v48
from tools.godot.generate_animation_import_manifest_v49 import build_payload as build_v49, render as render_v49

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "build/p0_animation_pipeline_v50_report.json"
MANIFEST_V49 = ROOT / "data/godot/animation_import_manifest_v49.json"


def _tool(name: str) -> str | None:
    candidate = Path(name)
    if candidate.exists():
        return str(candidate.resolve())
    return shutil.which(name)


def build_plan(root: Path = ROOT, blender: str = "blender", godot: str = "godot") -> dict:
    v48 = build_v48(root)
    v49 = build_v49(root)
    blender_path = _tool(blender)
    godot_path = _tool(godot)
    missing_sources = [
        str(item["source_blend"])
        for item in v48.get("bundles", [])
        if not (root / item["source_blend"]).exists()
    ]
    return {
        "version": 50,
        "source_versions": [46, 47, 48, 49],
        "priority": "P0",
        "bundle_count": int(v48["bundle_count"]),
        "master_clip_count": int(v48["master_clip_count"]),
        "blender": blender_path,
        "godot": godot_path,
        "missing_source_blends": missing_sources,
        "pc_ready": bool(blender_path and godot_path and not missing_sources),
        "blocker_code": "" if blender_path and godot_path and not missing_sources else "PC_ART_ASSETS_OR_TOOLS_REQUIRED",
        "phases": [
            "STATIC_AUDITS",
            "BLENDER_SOURCE_PREFLIGHT",
            "BLENDER_VALIDATE_AND_EXPORT_12_BUNDLES",
            "GODOT_FORCE_IMPORT",
            "GODOT_VALIDATE_320_ANIMATIONS",
            "GODOT_SMOKE",
        ],
        "definition_of_done": [
            "12_of_12_blender_bundles_exported",
            "320_of_320_p0_master_animations_present",
            "all_shared_family_consumers_retargetable",
            "f3_and_f4_visual_states_reviewed",
            "equipment_fallback_after_limb_loss_reviewed",
            "five_boss_p0_bundles_reviewed",
            "godot_import_validator_green",
            "godot_headless_smoke_green",
        ],
        "godot_manifest": v49,
    }


def _run(command: list[str]) -> None:
    print("+", " ".join(command))
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--report", type=Path, default=REPORT)
    args = parser.parse_args()

    plan = build_plan(ROOT, args.blender, args.godot)
    report_path = args.report if args.report.is_absolute() else ROOT / args.report
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.preflight:
        print(json.dumps({key: plan[key] for key in (
            "version", "bundle_count", "master_clip_count", "blender", "godot",
            "missing_source_blends", "pc_ready", "blocker_code",
        )}, ensure_ascii=False, indent=2))
        return 0 if plan["pc_ready"] else 2

    static_commands = [
        [sys.executable, "-m", "tools.qa.canonical_cast_v46_audit"],
        [sys.executable, "-m", "tools.qa.animation_batches_v47_audit"],
        [sys.executable, "-m", "tools.qa.animation_export_v48_audit"],
        [sys.executable, "-m", "tools.qa.animation_import_v49_audit"],
    ]
    if args.dry_run:
        print(json.dumps({
            "plan": {key: plan[key] for key in ("bundle_count", "master_clip_count", "pc_ready", "blocker_code")},
            "static_commands": static_commands,
            "pc_commands": [
                [sys.executable, "-m", "tools.blender.run_animation_export_v48", "--execute", "--blender", args.blender],
                [args.godot, "--headless", "--path", ".", "--editor", "--quit"],
                [args.godot, "--headless", "--path", ".", "--script", "tools/godot/animation_import_validator_v49.gd", "--", "--manifest", "data/godot/animation_import_manifest_v49.json"],
                [args.godot, "--headless", "--path", ".", "--quit-after", "1"],
            ],
        }, ensure_ascii=False, indent=2))
        return 0

    for command in static_commands:
        _run(command)
    if not plan["pc_ready"]:
        print(json.dumps({
            "status": "BLOCKED",
            "blocker_code": plan["blocker_code"],
            "missing_source_blends": plan["missing_source_blends"],
            "blender": plan["blender"],
            "godot": plan["godot"],
        }, ensure_ascii=False, indent=2))
        return 2

    MANIFEST_V49.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_V49.write_text(render_v49(plan["godot_manifest"]), encoding="utf-8")
    _run([sys.executable, "-m", "tools.blender.run_animation_export_v48", "--execute", "--blender", str(plan["blender"])])
    _run([str(plan["godot"]), "--headless", "--path", ".", "--editor", "--quit"])
    _run([
        str(plan["godot"]), "--headless", "--path", ".",
        "--script", "tools/godot/animation_import_validator_v49.gd", "--",
        "--manifest", "data/godot/animation_import_manifest_v49.json",
    ])
    _run([str(plan["godot"]), "--headless", "--path", ".", "--quit-after", "1"])
    print("P0_ANIMATION_PIPELINE_V50_COMPLETE bundles=12 clips=320")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
