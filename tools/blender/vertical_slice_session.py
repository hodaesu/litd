#!/usr/bin/env python3
"""First-PC-session helper for the Light in the Dark vertical slice.

This script intentionally does not launch Blender by itself in CI. It verifies the
contract, references and job plan, then prints deterministic commands to run locally.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/visual_vertical_slice.json"
JOBS = ROOT / "data/blender/visual_vertical_slice_jobs.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def preflight(require_references: bool = True) -> list[str]:
    errors: list[str] = []
    contract = load(CONTRACT)
    jobs = load(JOBS)
    if contract.get("version") != 2:
        errors.append("visual slice contract must be v2")
    if jobs.get("version") != 2:
        errors.append("visual slice jobs must be v2")
    if require_references:
        rules = contract["reference_rules"]
        for key in ("approved_art_bible_repo_target", "approved_darius_repo_target", "approved_ghoul_repo_target"):
            path = ROOT / rules[key]
            if not path.exists():
                errors.append(f"missing approved reference: {path.relative_to(ROOT)}")
    return errors


def blender_commands() -> list[str]:
    jobs = load(JOBS)["jobs"]
    commands: list[str] = []
    for job in jobs:
        if job["kind"] == "character":
            source = job["source_character_job"]
            commands.append(
                f"blender --background --python tools/blender/build_character_scene.py -- {source} "
                f"--output {job['output_blend']}"
            )
        else:
            commands.append(
                "blender --background --python tools/blender/build_ashlands_scene.py -- "
                f"--output {job['output_blend']}"
            )
    return commands


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--ci", action="store_true", help="skip presence of local approved images")
    parser.add_argument("--print-commands", action="store_true")
    args = parser.parse_args()

    if args.preflight:
        errors = preflight(require_references=not args.ci)
        if errors:
            for error in errors:
                print("ERROR:", error)
            return 1
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools/blender/generate_visual_vertical_slice_jobs.py"), "--check"],
            cwd=ROOT,
            check=False,
        )
        if result.returncode:
            return result.returncode
        print("VERTICAL_SLICE_PREFLIGHT_OK")
    if args.print_commands or not args.preflight:
        for command in blender_commands():
            print(command)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
