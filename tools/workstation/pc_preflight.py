#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

TOOLS = {
    "git": ["git"],
    "python": [sys.executable, "python", "py"],
    "godot": ["godot4", "godot", "Godot_v4.3-stable_win64_console.exe", "Godot_v4.3-stable_win64.exe"],
    "blender": ["blender"],
    "musescore": ["musescore4", "MuseScore4.exe", "mscore"],
    "reaper": ["reaper", "reaper.exe"],
}

WINDOWS_HINTS = {
    "godot": [r"C:\Program Files\Godot\Godot.exe"],
    "blender": [r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"],
    "musescore": [r"C:\Program Files\MuseScore 4\bin\MuseScore4.exe"],
    "reaper": [r"C:\Program Files\REAPER (x64)\reaper.exe"],
}

REQUIRED_FILES = [
    "project.godot",
    "tools/music_pipeline/build_music.py",
    "tools/audio/source_sfx_library.py",
    "tools/production/validate_preblender.py",
]

def resolve_tool(name):
    for candidate in TOOLS[name]:
        found = shutil.which(candidate)
        if found:
            return found
    for candidate in WINDOWS_HINTS.get(name, []):
        if Path(candidate).exists():
            return candidate
    return None

def version(executable):
    if not executable:
        return None
    for args in (["--version"], ["-v"]):
        try:
            run = subprocess.run([executable, *args], capture_output=True, text=True, timeout=20)
            text = (run.stdout or run.stderr).strip().splitlines()
            if text:
                return text[0][:240]
        except (OSError, subprocess.SubprocessError):
            pass
    return "installed"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--run-tests", action="store_true")
    args = parser.parse_args()
    root = Path(args.repo).resolve()

    tools = {}
    for name in TOOLS:
        executable = resolve_tool(name)
        tools[name] = {"found": bool(executable), "path": executable, "version": version(executable)}

    files = {path: (root / path).exists() for path in REQUIRED_FILES}
    local_dirs = [
        "local/audio_library/sources",
        "local/audio_library/derived",
        "local/music_pipeline/renders",
        "local/music_pipeline/reaper_projects",
        "local/blender/jobs",
        "local/blender/exports",
        "local/reports",
        "local/backups",
    ]
    for path in local_dirs:
        (root / path).mkdir(parents=True, exist_ok=True)

    checks = []
    if args.run_tests:
        commands = [
            [sys.executable, "-m", "pytest", "tests/python", "-q"],
            [sys.executable, "tools/audio/source_sfx_library.py", "audit"],
            [sys.executable, "tools/music_pipeline/build_music.py", "doctor"],
        ]
        for command in commands:
            run = subprocess.run(command, cwd=root, capture_output=True, text=True)
            checks.append({
                "command": command,
                "returncode": run.returncode,
                "stdout": run.stdout[-4000:],
                "stderr": run.stderr[-4000:],
            })

    ready = all(item["found"] for item in tools.values()) and all(files.values())
    if checks:
        ready = ready and all(item["returncode"] == 0 for item in checks)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo": str(root),
        "ready": ready,
        "tools": tools,
        "required_files": files,
        "local_directories": local_dirs,
        "checks": checks,
        "pc_only_validation": [
            "Godot visual playtest",
            "real touchscreen double-tap",
            "audio render and listening review",
            "Blender mesh rig animation and GLB deformation review",
            "Windows and mobile performance profiling",
        ],
    }
    target = root / "local/reports/pc_preflight.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if ready else 2

if __name__ == "__main__":
    raise SystemExit(main())
