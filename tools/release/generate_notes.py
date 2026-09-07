#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def resolve_version() -> str:
    if len(sys.argv) > 1:
        return sys.argv[1]
    try:
        result = subprocess.run(
            ["git", "describe", "--tags", "--always", "--dirty"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        version = result.stdout.strip()
        if version:
            return version
    except (OSError, subprocess.CalledProcessError):
        pass
    return "development"


version = resolve_version()
changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
print(f"# Light in the Dark {version}\n")
print("Build automatisé par GitHub Actions.\n")
print("## Changements\n")
print(changelog[:6000])
