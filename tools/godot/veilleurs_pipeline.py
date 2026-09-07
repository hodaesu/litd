#!/usr/bin/env python3
"""LITD: Les Veilleurs - Godot production automation orchestrator.

Standard-library only so it can run locally on Windows/macOS/Linux and in CI.
The script validates incoming content, runs the current Veilleurs contract audits,
performs strict Godot import/smoke checks, and emits a machine-readable report.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "tools/godot/veilleurs_pipeline_config.json"
RES_REF_RE = re.compile(r"res://[A-Za-z0-9_./@+\-]+")
TEXT_RESOURCE_SUFFIXES = {".tscn", ".tres", ".gdshader", ".cfg", ".godot"}


def load_config() -> dict[str, Any]:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def git_changed_files(base_ref: str) -> list[str]:
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{base_ref}...HEAD"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git diff failed against {base_ref}")
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def classify(paths: list[str], config: dict[str, Any]) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {name: [] for name in config["categories"]}
    for path in paths:
        for category, patterns in config["categories"].items():
            if any(fnmatch.fnmatch(path, pattern) for pattern in patterns):
                result[category].append(path)
    return {key: value for key, value in result.items() if value}


def watched_files(config: dict[str, Any]) -> list[str]:
    files: list[str] = []
    for root_name in config["watched_roots"]:
        root = ROOT / root_name
        if not root.exists():
            continue
        if root.is_file():
            files.append(rel(root))
            continue
        files.extend(rel(path) for path in root.rglob("*") if path.is_file())
    for special in ("project.godot", "export_presets.cfg"):
        path = ROOT / special
        if path.exists():
            files.append(special)
    return sorted(set(files))


def validate_json(paths: list[str]) -> list[str]:
    errors: list[str] = []
    for path_str in paths:
        path = ROOT / path_str
        if path.suffix.lower() != ".json" or not path.exists():
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001 - report exact malformed content
            errors.append(f"JSON invalide: {path_str}: {exc}")
    return errors


def case_collisions(paths: list[str]) -> list[str]:
    by_lower: dict[str, list[str]] = {}
    for item in paths:
        by_lower.setdefault(item.lower(), []).append(item)
    return [
        "Collision de casse: " + " | ".join(values)
        for values in by_lower.values()
        if len(set(values)) > 1
    ]


def validate_static_res_references(paths: list[str], config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    ignored = tuple(config.get("ignored_reference_prefixes", []))
    for path_str in paths:
        path = ROOT / path_str
        if not path.exists() or path.suffix.lower() not in TEXT_RESOURCE_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for ref in sorted(set(RES_REF_RE.findall(text))):
            if ref.startswith(ignored):
                continue
            disk_path = ROOT / ref.removeprefix("res://")
            if not disk_path.exists():
                errors.append(f"Référence Godot manquante: {path_str} -> {ref}")
    return errors


def find_command(name: str) -> str | None:
    return shutil.which(name)


def resolve_godot() -> str | None:
    env = os.environ.get("GODOT_BIN")
    if env:
        return env
    for name in ("godot", "godot4", "godot4.7"):
        found = find_command(name)
        if found:
            return found
    return None


def run_command(
    label: str,
    command: list[str],
    report: dict[str, Any],
    *,
    timeout: int | None = None,
    fatal_patterns: list[str] | None = None,
) -> bool:
    started = time.time()
    print(f"\n==> {label}")
    print("    " + " ".join(command))
    try:
        proc = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        output = (proc.stdout or "") + (proc.stderr or "")
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        pattern_hit = None
        for pattern in fatal_patterns or []:
            if pattern in output:
                pattern_hit = pattern
                break
        ok = proc.returncode == 0 and pattern_hit is None
        report["steps"].append(
            {
                "label": label,
                "command": command,
                "returncode": proc.returncode,
                "seconds": round(time.time() - started, 3),
                "fatal_pattern": pattern_hit,
                "ok": ok,
            }
        )
        return ok
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT après {timeout}s: {label}", file=sys.stderr)
        report["steps"].append(
            {
                "label": label,
                "command": command,
                "returncode": None,
                "seconds": round(time.time() - started, 3),
                "timeout": timeout,
                "ok": False,
            }
        )
        return False


def write_content_index(paths: list[str], report_dir: Path) -> Path:
    index = {
        "generated_at_unix": int(time.time()),
        "file_count": len(paths),
        "files": paths,
    }
    path = report_dir / "veilleurs_content_index.json"
    path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("quick", "changed", "full"), default="quick")
    parser.add_argument("--base-ref", default="origin/main")
    parser.add_argument("--skip-godot", action="store_true")
    parser.add_argument("--skip-python", action="store_true")
    parser.add_argument("--require-godot", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config()
    report_dir = ROOT / config["report_dir"]
    report_dir.mkdir(parents=True, exist_ok=True)

    if args.mode == "changed":
        selected = git_changed_files(args.base_ref)
    else:
        selected = watched_files(config)

    selected = sorted(set(selected))
    categories = classify(selected, config)
    report: dict[str, Any] = {
        "pipeline_version": config["version"],
        "mode": args.mode,
        "base_ref": args.base_ref if args.mode == "changed" else None,
        "selected_file_count": len(selected),
        "categories": categories,
        "errors": [],
        "warnings": [],
        "steps": [],
        "ok": False,
    }

    print("LITD : Les Veilleurs — pipeline de production Godot")
    print(f"Mode: {args.mode} | fichiers suivis: {len(selected)}")
    if categories:
        print("Catégories touchées: " + ", ".join(sorted(categories)))

    report["errors"].extend(validate_json(selected))
    report["errors"].extend(case_collisions(selected))
    report["errors"].extend(validate_static_res_references(selected, config))
    index_path = write_content_index(selected, report_dir)
    report["content_index"] = rel(index_path)

    if args.dry_run:
        report["warnings"].append("dry-run: audits Python et Godot non exécutés")
    else:
        relevant = bool(categories) or args.mode != "changed"
        if relevant and not args.skip_python:
            for audit in config["python_audits"]:
                audit_path = ROOT / audit
                if not audit_path.exists():
                    report["warnings"].append(f"Audit absent, ignoré: {audit}")
                    continue
                if not run_command(f"Audit: {audit}", [sys.executable, audit], report):
                    report["errors"].append(f"Échec de l'audit: {audit}")

        if relevant and not args.skip_godot:
            godot = resolve_godot()
            if godot is None:
                message = "Godot introuvable. Définir GODOT_BIN ou installer Godot 4.7.x."
                if args.require_godot:
                    report["errors"].append(message)
                else:
                    report["warnings"].append(message)
            else:
                fatal_patterns = config["fatal_log_patterns"]
                import_ok = run_command(
                    "Import Godot strict",
                    [godot, "--headless", "--path", ".", "--import", "--quit"],
                    report,
                    timeout=180,
                    fatal_patterns=fatal_patterns,
                )
                if not import_ok:
                    report["errors"].append("Échec de l'import Godot strict")
                else:
                    if args.mode == "full":
                        suite = ROOT / config["full_suite"]
                        if suite.exists():
                            if not run_command(
                                "Suite Godot complète",
                                ["bash", config["full_suite"]],
                                report,
                                timeout=1800,
                                fatal_patterns=fatal_patterns,
                            ):
                                report["errors"].append("Échec de la suite Godot complète")
                        else:
                            report["errors"].append(f"Suite complète absente: {config['full_suite']}")
                    else:
                        for smoke in config["quick_godot_smokes"]:
                            scene_path = ROOT / smoke["scene"].removeprefix("res://")
                            if not scene_path.exists():
                                report["warnings"].append(f"Smoke absent, ignoré: {smoke['scene']}")
                                continue
                            command = [godot, "--headless", "--path", "."]
                            if smoke.get("quit_after"):
                                command.extend(["--quit-after", str(smoke["quit_after"])])
                            command.append(smoke["scene"])
                            if not run_command(
                                f"Smoke: {smoke['scene']}",
                                command,
                                report,
                                timeout=int(smoke.get("timeout", 120)),
                                fatal_patterns=fatal_patterns,
                            ):
                                report["errors"].append(f"Échec du smoke: {smoke['scene']}")

    report["ok"] = not report["errors"]
    report_path = report_dir / "veilleurs_pipeline_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("\n=== Résultat ===")
    print(f"Rapport: {rel(report_path)}")
    for warning in report["warnings"]:
        print(f"AVERTISSEMENT: {warning}")
    for error in report["errors"]:
        print(f"ERREUR: {error}", file=sys.stderr)
    print("VEILLEURS_PIPELINE_OK" if report["ok"] else "VEILLEURS_PIPELINE_FAILED")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
