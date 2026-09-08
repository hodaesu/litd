#!/usr/bin/env python3
"""Orchestre le premier playtest Windows des Veilleurs : preflight, session, export et lancement."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEVELOPER_SELFTEST_ID = "developer-selftest"


def _run(command: list[str], *, cwd: Path) -> int:
    print("+", " ".join(str(part) for part in command))
    return subprocess.run(command, cwd=cwd, check=False).returncode


def _resolve_godot() -> str | None:
    from tools.workstation.veilleurs_pc_preflight import REQUIRED_TOOLS, WINDOWS_HINTS, resolve

    return resolve(REQUIRED_TOOLS["godot"], WINDOWS_HINTS.get("godot"))


def _latest_session_for_tester(root: Path, tester_id: str) -> Path | None:
    playtests_root = root / "local/playtests"
    if not playtests_root.is_dir():
        return None
    candidates: list[tuple[float, Path]] = []
    for target in playtests_root.iterdir():
        metadata_path = target / "session.json"
        if not target.is_dir() or not metadata_path.is_file():
            continue
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            continue
        if metadata.get("tester_id") != tester_id:
            continue
        try:
            modified = metadata_path.stat().st_mtime
        except OSError:
            continue
        candidates.append((modified, target))
    if not candidates:
        return None
    return max(candidates, key=lambda row: row[0])[1]


def _drive_candidate_roots() -> list[Path]:
    candidates: list[Path] = []
    env_root = os.environ.get("LITD_GOOGLE_DRIVE_ROOT", "").strip()
    if env_root:
        candidates.append(Path(env_root))

    user_profile = Path(os.environ.get("USERPROFILE", str(Path.home())))
    candidates += [
        user_profile / "Google Drive",
        user_profile / "My Drive",
        user_profile / "Mon Drive",
    ]
    for letter in "DEFGHIJKLMNOPQRSTUVWXYZ":
        drive = Path(f"{letter}:/")
        candidates += [drive / "My Drive", drive / "Mon Drive", drive / "Google Drive"]
    return candidates


def _resolve_google_drive_root() -> Path | None:
    for candidate in _drive_candidate_roots():
        try:
            if candidate.is_dir():
                return candidate
        except OSError:
            continue
    return None


def _sync_developer_session_to_drive(session_dir: Path) -> Path | None:
    drive_root = _resolve_google_drive_root()
    if drive_root is None:
        print("DEVELOPER_SELFTEST_DRIVE_SYNC=unavailable")
        print("DEVELOPER_SELFTEST_DRIVE_HINT=Install Google Drive for desktop or set LITD_GOOGLE_DRIVE_ROOT")
        return None

    target_root = drive_root / "LITD" / "Playtests" / "Developer"
    target = target_root / session_dir.name
    try:
        target_root.mkdir(parents=True, exist_ok=True)
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(session_dir, target)
    except OSError as exc:
        print(f"DEVELOPER_SELFTEST_DRIVE_SYNC_FAILED={exc}")
        return None
    print(f"DEVELOPER_SELFTEST_DRIVE_SYNCED={target}")
    return target


def _finalize_developer_session(session_dir: Path, telemetry_path: Path, game_exit_code: int) -> None:
    metadata_path = session_dir / "session.json"
    if not metadata_path.is_file():
        return
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return

    metadata["game_exit_code"] = game_exit_code
    metadata["telemetry"] = telemetry_path.name
    if telemetry_path.is_file():
        try:
            telemetry = json.loads(telemetry_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            telemetry = {}
        metadata["selftest_completed"] = bool(telemetry.get("completed", False))
        metadata["selftest_elapsed_seconds"] = telemetry.get("elapsed_seconds", 0)
        metadata["analysis_flag_count"] = len(telemetry.get("analysis_flags", []))
        metadata["status"] = (
            "DEVELOPER_SELFTEST_COMPLETED"
            if metadata["selftest_completed"] and game_exit_code == 0
            else "DEVELOPER_SELFTEST_ENDED_REVIEW_REQUIRED"
        )
    else:
        metadata["status"] = "DEVELOPER_SELFTEST_TELEMETRY_MISSING"

    metadata_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(ROOT))
    parser.add_argument("--tester-id", default=DEVELOPER_SELFTEST_ID)
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
        root / "data/veilleurs/developer_selftest_contract.json",
        root / "scripts/qa/developer_selftest_overlay.gd",
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

    session_dir = _latest_session_for_tester(root, args.tester_id)
    if session_dir is None:
        print("FIRST_PLAYTEST_SESSION_NOT_FOUND_AFTER_PREPARE")
        return 2

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
    print(f"FIRST_PLAYTEST_SESSION_DIR={session_dir}")
    print("VALIDATION_STATUS=NOT_RUN")

    if not args.no_launch:
        try:
            launch_command = [str(output)]
            if args.tester_id == DEVELOPER_SELFTEST_ID:
                telemetry_path = (session_dir / "developer_selftest_telemetry.json").resolve()
                launch_command += [
                    "--",
                    "--developer-selftest",
                    f"--selftest-report={telemetry_path}",
                ]
                print("DEVELOPER_SELFTEST_OVERLAY=enabled")
                print(f"DEVELOPER_SELFTEST_TELEMETRY={telemetry_path}")
                game_run = subprocess.run(launch_command, cwd=output.parent, check=False)
                _finalize_developer_session(session_dir, telemetry_path, game_run.returncode)
                if telemetry_path.is_file():
                    print(f"DEVELOPER_SELFTEST_TELEMETRY_READY={telemetry_path}")
                else:
                    print(f"DEVELOPER_SELFTEST_TELEMETRY_MISSING={telemetry_path}")
                _sync_developer_session_to_drive(session_dir)
                print(f"FIRST_PLAYTEST_GAME_EXIT_CODE={game_run.returncode}")
                return game_run.returncode

            subprocess.Popen(launch_command, cwd=output.parent)
            print("FIRST_PLAYTEST_GAME_LAUNCHED")
        except OSError as exc:
            print(f"FIRST_PLAYTEST_LAUNCH_FAILED={exc}")
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
