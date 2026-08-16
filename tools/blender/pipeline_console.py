#!/usr/bin/env python3
"""Unified operator console for the Light in the Dark Blender pipeline."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data/blender/full_pipeline_manifest.json"
VALID_STAGES = ("materials", "environments", "characters", "props")
DEFAULT_STATE = "reports/blender_pipeline_state.json"


def load_manifest(path: Path = MANIFEST) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_request(request: dict) -> dict:
    stages = request.get("stages") or list(VALID_STAGES)
    if isinstance(stages, str):
        stages = [stages]
    job_ids = request.get("job_ids") or []
    if isinstance(job_ids, str):
        job_ids = [job_ids]
    unknown = sorted(set(stages) - set(VALID_STAGES))
    if unknown:
        raise ValueError(f"unknown pipeline stages: {', '.join(unknown)}")
    return {
        "stages": list(dict.fromkeys(stages)), "job_ids": list(dict.fromkeys(job_ids)),
        "execute": bool(request.get("execute", False)), "resume": bool(request.get("resume", True)),
        "blender": str(request.get("blender", "blender")),
        "state_path": str(request.get("state_path", DEFAULT_STATE)),
    }


def request_from_json(path: Path) -> dict:
    return normalize_request(json.loads(path.read_text(encoding="utf-8")))


def interactive_request(input_fn: Callable[[str], str] = input) -> dict:
    stages = input_fn("Catégories (materials,environments,characters,props ou all) : ").strip()
    jobs = input_fn("Identifiants précis, séparés par des virgules (vide = tous) : ").strip()
    execute = input_fn("Lancer Blender maintenant ? (o/N) : ").strip().lower() in ("o", "oui", "y", "yes")
    return normalize_request({
        "stages": list(VALID_STAGES) if stages in ("", "all", "tout") else _split(stages),
        "job_ids": _split(jobs), "execute": execute, "resume": True,
    })


def _split(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def select_jobs(manifest: dict, request: dict) -> list[dict]:
    request = normalize_request(request)
    known_ids = {job["job_id"] for job in manifest["stages"]}
    unknown_ids = sorted(set(request["job_ids"]) - known_ids)
    if unknown_ids:
        raise ValueError(f"unknown pipeline jobs: {', '.join(unknown_ids)}")
    selected = [
        job for job in manifest["stages"]
        if job["stage"] in request["stages"] and (not request["job_ids"] or job["job_id"] in request["job_ids"])
    ]
    if request["job_ids"] and not selected:
        raise ValueError("requested jobs do not belong to the selected stages")
    if any(job["depends_on"] for job in selected):
        material = next(job for job in manifest["stages"] if job["job_id"] == "material_library")
        if material not in selected:
            selected.insert(0, material)
    return selected


def build_session(manifest: dict, request: dict, root: Path = ROOT) -> dict:
    request = normalize_request(request)
    state_path = root / request["state_path"]
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {"completed": []}
    completed = set(state.get("completed", []))
    selected, pending, skipped = select_jobs(manifest, request), [], []
    for job in selected:
        outputs_exist = all((root / output).exists() for output in job["outputs"])
        if request["resume"] and job["job_id"] in completed and outputs_exist:
            skipped.append(job)
        else:
            pending.append(job)
    return {
        "request": request,
        "summary": {"selected": len(selected), "pending": len(pending), "skipped": len(skipped)},
        "pending": pending, "skipped": skipped,
    }


def blender_command(job: dict, blender: str, root: Path = ROOT) -> list[str]:
    return [blender, "--background", "--python", str(root / job["command"][0]), "--", *job["command"][1:]]


def execute_session(session: dict, root: Path = ROOT, runner=subprocess.run) -> dict:
    request = session["request"]
    state_path = root / request["state_path"]
    state_path.parent.mkdir(parents=True, exist_ok=True)
    completed = {job["job_id"] for job in session["skipped"]}
    for job in session["pending"]:
        runner(blender_command(job, request["blender"], root), cwd=root, check=True)
        completed.add(job["job_id"])
        state_path.write_text(json.dumps({"version": 1, "completed": sorted(completed)}, indent=2) + "\n", encoding="utf-8")
    return {"completed": sorted(completed), "state_path": str(state_path)}


def printable_plan(session: dict, root: Path = ROOT) -> dict:
    return {
        "request": session["request"], "summary": session["summary"],
        "commands": [blender_command(job, session["request"]["blender"], root) for job in session["pending"]],
        "skipped_job_ids": [job["job_id"] for job in session["skipped"]],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Console unifiée du pipeline Blender Light in the Dark")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--request", type=Path, help="fichier de demande JSON")
    source.add_argument("--interactive", action="store_true", help="questions guidées")
    parser.add_argument("--stage", action="append", choices=VALID_STAGES)
    parser.add_argument("--job", action="append", dest="job_ids")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--state", default=DEFAULT_STATE)
    parser.add_argument("--plan", type=Path)
    args = parser.parse_args()
    if args.request:
        request = request_from_json(args.request)
    elif args.interactive:
        request = interactive_request()
    else:
        request = normalize_request({"stages": args.stage, "job_ids": args.job_ids, "execute": args.execute,
                                     "resume": not args.no_resume, "blender": args.blender, "state_path": args.state})
    if args.execute:
        request["execute"] = True
    session = build_session(load_manifest(), request)
    rendered = json.dumps(printable_plan(session), ensure_ascii=False, indent=2) + "\n"
    if args.plan:
        args.plan.parent.mkdir(parents=True, exist_ok=True)
        args.plan.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    if request["execute"]:
        execute_session(session)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
