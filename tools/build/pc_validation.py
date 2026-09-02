#!/usr/bin/env python3
"""One-command first-PC validation for Light in the Dark.

The contract is intentionally split between automated checks and manual acceptance.
Automated checks can prove that Godot loads, smoke scenes execute, the Windows export
builds, profiling/capture runners produce reports, and the Blender pipeline is ready.
They cannot replace looking at the game, using physical controllers/touch hardware,
or listening to the real mix.
"""
from __future__ import annotations

import argparse
import json
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PLAN_PATH = ROOT / "data/production/pc_validation_plan.json"
REPORT_PATH = ROOT / "reports/pc_validation.json"
GODOT_ERROR_RE = re.compile(
    r"SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Failed to create an autoload|"
    r"ERROR: Failed to instantiate an autoload|ERROR: FATAL:|handle_crash: Program crashed"
)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_binary(value: str) -> str | None:
    candidate = Path(value)
    if candidate.exists():
        return str(candidate.resolve())
    return shutil.which(value)


def validate_contract() -> list[str]:
    errors: list[str] = []
    if not PLAN_PATH.exists():
        return ["missing data/production/pc_validation_plan.json"]
    plan = load_json(PLAN_PATH)
    if plan.get("version") != 1:
        errors.append("PC validation plan version must be 1")

    target = plan.get("target", {})
    expected_godot = str(target.get("godot_required_prefix", ""))
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    if not expected_godot or f'config/features=PackedStringArray("{expected_godot}")' not in project:
        errors.append("project.godot must declare the required Godot version")

    preset = str(target.get("export_preset", ""))
    export_presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    if not preset or f'name="{preset}"' not in export_presets:
        errors.append("Windows export preset is missing")

    groups = plan.get("godot_groups", {})
    required_groups = {"foundation", "visual_collision", "controls", "audio"}
    if not required_groups.issubset(groups):
        errors.append("Godot validation groups are incomplete")
    for group, scenes in groups.items():
        if not isinstance(scenes, list) or not scenes:
            errors.append(f"Godot group {group} must contain scenes")
            continue
        for scene in scenes:
            if not (ROOT / str(scene)).exists():
                errors.append(f"missing Godot validation scene: {scene}")

    for key, rel in plan.get("automated_tools", {}).items():
        if not (ROOT / str(rel)).exists():
            errors.append(f"missing automated tool {key}: {rel}")

    manual_ids = {str(item.get("id", "")) for item in plan.get("manual_acceptance", [])}
    expected_manual = {
        "visual_review",
        "collision_review",
        "keyboard_mouse",
        "controller",
        "touch_device",
        "audio_listening",
        "windows_performance",
        "blender_art_gate",
    }
    if not expected_manual.issubset(manual_ids):
        errors.append("manual PC acceptance checklist is incomplete")
    return errors


def run_step(label: str, command: list[str], timeout: int = 180, scan_godot_errors: bool = False) -> dict[str, Any]:
    print(f"==> {label}")
    started = datetime.now(timezone.utc)
    try:
        result = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        output = (result.stdout or "") + (result.stderr or "")
        if output.strip():
            print(output.rstrip())
        failed = result.returncode != 0 or (scan_godot_errors and GODOT_ERROR_RE.search(output) is not None)
        return {
            "label": label,
            "status": "failed" if failed else "passed",
            "returncode": result.returncode,
            "duration_seconds": round((datetime.now(timezone.utc) - started).total_seconds(), 3),
            "command": command,
        }
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT: {label}")
        return {
            "label": label,
            "status": "failed",
            "returncode": None,
            "duration_seconds": round((datetime.now(timezone.utc) - started).total_seconds(), 3),
            "command": command,
            "reason": "timeout",
        }


def binary_version(binary: str, kind: str) -> tuple[str, list[str]]:
    command = [binary, "--version"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False, timeout=30)
    text = ((result.stdout or "") + (result.stderr or "")).strip()
    if result.returncode != 0:
        raise RuntimeError(f"{kind} --version failed")
    return text, command


def write_report(report: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def execute(args: argparse.Namespace) -> int:
    plan = load_json(PLAN_PATH)
    report: dict[str, Any] = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "host": {"system": platform.system(), "release": platform.release(), "machine": platform.machine()},
        "tools": {},
        "steps": [],
        "manual_acceptance": [dict(item, status="pending") for item in plan["manual_acceptance"]],
    }

    godot = resolve_binary(args.godot)
    if godot is None:
        print("ERROR: Godot executable not found. Use --godot with the full path if necessary.")
        return 2
    godot_version, _ = binary_version(godot, "Godot")
    report["tools"]["godot"] = {"path": godot, "version": godot_version}
    required_prefix = str(plan["target"]["godot_required_prefix"])
    if not godot_version.startswith(required_prefix):
        print(f"ERROR: Godot {required_prefix} required; found: {godot_version}")
        write_report(report, Path(args.report))
        return 2

    blender: str | None = None
    if not args.skip_blender:
        blender = resolve_binary(args.blender)
        if blender is None:
            print("ERROR: Blender executable not found. Use --blender with the full path or --skip-blender.")
            return 2
        blender_version, _ = binary_version(blender, "Blender")
        report["tools"]["blender"] = {"path": blender, "version": blender_version}
        match = re.search(r"Blender\s+(\d+)", blender_version)
        if match and int(match.group(1)) < int(plan["target"]["blender_min_major"]):
            print(f"ERROR: Blender major version is too old: {blender_version}")
            write_report(report, Path(args.report))
            return 2

    if not args.skip_pytest:
        report["steps"].append(run_step("Tests Python", [sys.executable, "-m", "pytest", "-q", "--tb=short"], timeout=900))

    report["steps"].append(
        run_step(
            "Import strict Godot 4.3",
            [godot, "--headless", "--path", str(ROOT), "--import", "--quit"],
            timeout=300,
            scan_godot_errors=True,
        )
    )

    for group_name, scenes in plan["godot_groups"].items():
        for scene in scenes:
            res_scene = "res://" + str(scene).replace("\\", "/")
            report["steps"].append(
                run_step(
                    f"Godot {group_name}: {Path(scene).stem}",
                    [godot, "--headless", "--path", str(ROOT), res_scene],
                    timeout=240,
                    scan_godot_errors=True,
                )
            )

    if not args.skip_export:
        output_dir = ROOT / "build/windows"
        output_dir.mkdir(parents=True, exist_ok=True)
        report["steps"].append(
            run_step(
                "Export Windows Desktop",
                [godot, "--headless", "--path", str(ROOT), "--export-release", plan["target"]["export_preset"]],
                timeout=600,
                scan_godot_errors=True,
            )
        )

    tools = plan["automated_tools"]
    if not args.skip_capture:
        report["steps"].append(
            run_step(
                "Captures vertical slice Godot",
                [sys.executable, tools["capture"], "--godot", godot, "--execute"],
                timeout=300,
                scan_godot_errors=True,
            )
        )
    if not args.skip_profile:
        report["steps"].append(
            run_step(
                "Profiling vertical slice Godot",
                [sys.executable, tools["profile"], "--godot", godot, "--execute"],
                timeout=300,
                scan_godot_errors=True,
            )
        )

    if not args.skip_blender:
        report["steps"].append(
            run_step(
                "Préflight Blender vertical slice",
                [sys.executable, tools["blender_preflight"], "--preflight"],
                timeout=180,
            )
        )
        if args.build_blender and blender is not None:
            command = [
                sys.executable,
                tools["blender_build"],
                "--execute",
                "--blender",
                blender,
                "--godot",
                godot,
            ]
            if args.approve_art:
                command.append("--approve-art")
            report["steps"].append(run_step("Pipeline Blender vertical slice", command, timeout=7200))

    failed = [step for step in report["steps"] if step["status"] != "passed"]
    report["status"] = "failed" if failed else "automated_passed_manual_pending"
    report["failed_steps"] = [step["label"] for step in failed]
    write_report(report, Path(args.report))

    print(f"==> Rapport: {Path(args.report)}")
    if failed:
        print("PC_VALIDATION_FAILED")
        return 1
    print("PC_VALIDATION_AUTOMATED_OK_MANUAL_REVIEW_REQUIRED")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate LITD on the first Windows PC session")
    parser.add_argument("--check", action="store_true", help="validate the static contract without requiring local binaries")
    parser.add_argument("--execute", action="store_true", help="run automated PC validation")
    parser.add_argument("--godot", default="godot", help="Godot executable or full path")
    parser.add_argument("--blender", default="blender", help="Blender executable or full path")
    parser.add_argument("--report", default=str(REPORT_PATH), help="JSON report path")
    parser.add_argument("--skip-pytest", action="store_true")
    parser.add_argument("--skip-export", action="store_true")
    parser.add_argument("--skip-capture", action="store_true")
    parser.add_argument("--skip-profile", action="store_true")
    parser.add_argument("--skip-blender", action="store_true")
    parser.add_argument("--build-blender", action="store_true", help="build the vertical slice up to the art gate")
    parser.add_argument("--approve-art", action="store_true", help="allow post-art-review publication/capture stages")
    args = parser.parse_args()

    errors = validate_contract()
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    if args.check:
        print("PC_VALIDATION_PLAN_OK")
        return 0
    if not args.execute:
        plan = load_json(PLAN_PATH)
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        print("\nRun with --execute when Godot 4.3 and Blender are installed on the PC.")
        return 0
    return execute(args)


if __name__ == "__main__":
    raise SystemExit(main())
