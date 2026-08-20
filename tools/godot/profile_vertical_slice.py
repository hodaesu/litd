#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts/visual/visual_slice_profile_runner.gd"
OUTPUT = ROOT / "reports/vertical_slice/profile.json"


def command(godot: str) -> list[str]:
    return [godot, "--path", str(ROOT), "--rendering-method", "gl_compatibility", "--disable-vsync", "--script", str(RUNNER)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not RUNNER.exists():
        raise SystemExit("profile runner missing")
    if args.check:
        print("VISUAL_SLICE_PROFILE_LAUNCHER_OK")
        return 0
    if not args.execute:
        print(json.dumps({"command": command(args.godot), "output": str(OUTPUT.relative_to(ROOT))}, indent=2))
        return 0
    if shutil.which(args.godot) is None:
        raise SystemExit("Godot executable not found")
    subprocess.run(command(args.godot), cwd=ROOT, check=True)
    if not OUTPUT.exists():
        raise SystemExit("Godot profile report was not produced")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
