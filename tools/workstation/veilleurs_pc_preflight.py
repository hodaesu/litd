#!/usr/bin/env python3
"""Préflight poste de travail dédié à LITD : Les Veilleurs.

Contrairement au préflight général de LITD Universe, celui-ci ne demande ni
Unreal, ni Blender, ni Reaper, ni MuseScore. Les Veilleurs ciblent Godot 4.3 et
mobile : Git, Python et Godot suffisent pour la première session technique.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED_TOOLS = {
    "git": ["git"],
    "python": [sys.executable, "python", "py"],
    "godot": [
        "godot4",
        "godot",
        "Godot_v4.3-stable_win64_console.exe",
        "Godot_v4.3-stable_win64.exe",
    ],
}
OPTIONAL_TOOLS = {
    "adb": ["adb", "adb.exe"],
}
WINDOWS_HINTS = {
    "godot": [
        r"C:\Program Files\Godot\Godot_v4.3-stable_win64.exe",
        r"C:\Program Files\Godot\Godot.exe",
    ],
}
REQUIRED_FILES = [
    "project.godot",
    "export_presets.cfg",
    "data/veilleurs/pre_pc_gate.json",
    "tools/qa/veilleurs_pre_pc_audit.py",
    "tools/godot/veilleurs_pipeline.py",
    "tools/godot/veilleurs_pipeline_config.json",
    "addons/veilleurs_pipeline/plugin.cfg",
    "addons/veilleurs_pipeline/plugin.gd",
]


def resolve(candidates: list[str], hints: list[str] | None = None) -> str | None:
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
    for candidate in hints or []:
        if Path(candidate).exists():
            return candidate
    return None


def first_version(executable: str | None) -> str | None:
    if not executable:
        return None
    for args in (["--version"], ["-v"]):
        try:
            run = subprocess.run(
                [executable, *args],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        lines = (run.stdout or run.stderr).strip().splitlines()
        if lines:
            return lines[0][:240]
    return "installed"


def hardware_snapshot(root: Path) -> dict:
    usage = shutil.disk_usage(root)
    result = {
        "os": platform.platform(),
        "processor": platform.processor() or os.environ.get("PROCESSOR_IDENTIFIER") or "unknown",
        "logical_cpu_count": os.cpu_count(),
        "ram_gb": None,
        "gpu": [],
        "disk_free_gb": round(usage.free / (1024 ** 3), 1),
        "disk_total_gb": round(usage.total / (1024 ** 3), 1),
    }
    if os.name == "nt":
        command = (
            "$c=Get-CimInstance Win32_ComputerSystem;"
            "$g=Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM;"
            "[pscustomobject]@{Ram=$c.TotalPhysicalMemory;Gpu=$g}|ConvertTo-Json -Compress -Depth 4"
        )
        try:
            run = subprocess.run(
                ["powershell", "-NoProfile", "-Command", command],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            data = json.loads(run.stdout)
            result["ram_gb"] = round(int(data["Ram"]) / (1024 ** 3), 1)
            gpu = data.get("Gpu") or []
            result["gpu"] = gpu if isinstance(gpu, list) else [gpu]
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):
            pass
    return result


def run_check(label: str, command: list[str], root: Path) -> dict:
    try:
        run = subprocess.run(command, cwd=root, capture_output=True, text=True, check=False)
        return {
            "label": label,
            "command": command,
            "returncode": run.returncode,
            "stdout": run.stdout[-5000:],
            "stderr": run.stderr[-5000:],
            "ok": run.returncode == 0,
        }
    except OSError as exc:
        return {
            "label": label,
            "command": command,
            "returncode": None,
            "stderr": str(exc),
            "ok": False,
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(ROOT))
    parser.add_argument("--run-tests", action="store_true")
    parser.add_argument("--full", action="store_true", help="Lance la suite Godot complète via le pipeline Veilleurs.")
    parser.add_argument("--minimum-free-gb", type=float, default=20.0)
    args = parser.parse_args()

    root = Path(args.repo).resolve()
    required_tools: dict[str, dict] = {}
    optional_tools: dict[str, dict] = {}

    for name, candidates in REQUIRED_TOOLS.items():
        executable = resolve(candidates, WINDOWS_HINTS.get(name))
        required_tools[name] = {
            "found": bool(executable),
            "path": executable,
            "version": first_version(executable),
        }
    for name, candidates in OPTIONAL_TOOLS.items():
        executable = resolve(candidates)
        optional_tools[name] = {
            "found": bool(executable),
            "path": executable,
            "version": first_version(executable),
        }

    files = {path: (root / path).exists() for path in REQUIRED_FILES}
    hardware = hardware_snapshot(root)
    godot_version = str(required_tools["godot"].get("version") or "")
    godot_compatible = "4.3" in godot_version

    checks = [
        run_check(
            "pre_pc_contract",
            [sys.executable, "tools/qa/veilleurs_pre_pc_audit.py"],
            root,
        )
    ]
    if args.run_tests or args.full:
        mode = "full" if args.full else "quick"
        checks.append(
            run_check(
                f"veilleurs_pipeline_{mode}",
                [
                    sys.executable,
                    "tools/godot/veilleurs_pipeline.py",
                    "--mode",
                    mode,
                    "--require-godot",
                ],
                root,
            )
        )

    ready = all(row["found"] for row in required_tools.values())
    ready = ready and all(files.values())
    ready = ready and godot_compatible
    ready = ready and hardware["disk_free_gb"] >= args.minimum_free_gb
    ready = ready and all(row["ok"] for row in checks)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "project": "LITD : Les Veilleurs",
        "engine": "Godot 4.3",
        "repo": str(root),
        "ready": ready,
        "required_tools": required_tools,
        "optional_tools": optional_tools,
        "required_files": files,
        "godot_43_compatible": godot_compatible,
        "hardware": hardware,
        "minimum_free_gb": args.minimum_free_gb,
        "checks": checks,
        "not_required_for_first_veilleurs_session": [
            "Unreal Engine",
            "Blender",
            "Reaper",
            "MuseScore",
            "Visual Studio",
        ],
        "hardware_only_after_preflight": [
            "real_mobile_touch",
            "safe_areas_real_devices",
            "haptics_real_devices",
            "gpu_cpu_thermal_performance",
            "final_visual_readability",
            "physical_controller",
            "real_audio_output",
            "ios_signed_device_build",
        ],
    }

    target = root / "local/reports/veilleurs_pc_preflight.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if ready else 2


if __name__ == "__main__":
    raise SystemExit(main())
