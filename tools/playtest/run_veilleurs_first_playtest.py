#!/usr/bin/env python3
"""Orchestre le premier playtest Windows des Veilleurs : preflight, session, export et lancement."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _run(command: list[str], *, cwd: Path) -> int:
    print("+", " ".join(str(part) for part in command))
    return subprocess.run(command, cwd=cwd, check=False).returncode


def _resolve_godot() -> str | None:
    from tools.workstation.veilleurs_pc_preflight import REQUIRED_TOOLS, WINDOWS_HINTS, resolve

    return resolve(REQUIRED_TOOLS["godot"], WINDOWS_HINTS.get("godot"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(ROOT))
    parser.add_argument("--tester-id", default="developer-selftest")
    parser.add_argument("--device", default="PC Windows")
    parser.add_argument("--skip-preflight", action="store_true")
    parser.add_argument("--no-launch", action="store_true")
    parser.add_argument("--check", action="store_true", help="Vérifie seulement que le kit est cohérent.")
    args = parser.parse_args()

    root = Path(args.repo).resolve()
    required = [
        root / "project.godot",
        root / "export_presets.cfg",
        root / "reports/veilleurs_player_validation_template.json",
        root / "tools/playtest/prepare_veilleurs_first_playtest.py",
        root / "tools/qa/veilleurs_player_validation_report.py",
    ]
    missing = [str(path.relative_to(root)) for path in required if not path.is_file()]
    if missing:
        print("FIRST_PLAYTEST_KIT_MISSING", json.dumps(missing, ensure_ascii=False))
        return 2

    presets = (root / "export_presets.cfg").read_text(encoding="utf-8", errors="replace")
    if 'name="Windows Desktop"' not in presets:
        print("FIRST_PLAYTEST_KIT_MISSING_WINDOWS_PRESET")
        return 2

    if args.check:
        print("VEILLEURS_FIRST_PLAYTEST_KIT_CHECK_OK")
        return 0

    if not args.skip_preflight:
        code = _run(
            [sys.executable, "tools/workstation/veilleurs_pc_preflight.py", "--run-tests"],
            cwd=root,
        )
        if code != 0:
            print("FIRST_PLAYTEST_BLOCKED_BY_PREFLIGHT")
            return code

    godot = _resolve_godot()
    if not godot:
        print("FIRST_PLAYTEST_GODOT_47_NOT_FOUND")
        return 2

    code = _run(
        [
            sys.executable,
            "tools/playtest/prepare_veilleurs_first_playtest.py",
            "--tester-id",
            args.tester_id,
            "--platform",
            "windows",
            "--device",
            args.device,
        ],
        cwd=root,
    )
    if code != 0:
        return code

    output = root / "build/playtest/windows/LightInTheDark_Playtest.exe"
    output.parent.mkdir(parents=True, exist_ok=True)
    export_log = root / "local/reports/veilleurs_first_playtest_export.log"
    export_log.parent.mkdir(parents=True, exist_ok=True)

    command = [
        godot,
        "--headless",
        "--path",
        str(root),
        "--export-debug",
        "Windows Desktop",
        str(output),
    ]
    print("+", " ".join(command))
    run = subprocess.run(command, cwd=root, capture_output=True, text=True, check=False)
    export_log.write_text((run.stdout or "") + (run.stderr or ""), encoding="utf-8")
    if run.returncode != 0 or not output.is_file() or output.stat().st_size == 0:
        print(f"FIRST_PLAYTEST_WINDOWS_EXPORT_FAILED log={export_log}")
        return run.returncode or 2

    print(f"FIRST_PLAYTEST_WINDOWS_BUILD_READY={output}")
    print(f"FIRST_PLAYTEST_EXPORT_LOG={export_log}")
    print("VALIDATION_STATUS=NOT_RUN")

    if not args.no_launch:
        try:
            subprocess.Popen([str(output)], cwd=output.parent)
            print("FIRST_PLAYTEST_GAME_LAUNCHED")
        except OSError as exc:
            print(f"FIRST_PLAYTEST_LAUNCH_FAILED={exc}")
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
