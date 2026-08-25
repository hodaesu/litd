#!/usr/bin/env python3
"""Supervised one-command pipeline for the LITD opening cinematic."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "data/cinematics/opening_pipeline.json"
STATE = ROOT / "local/reports/opening_bird_intro/pipeline_state.json"
PLAN = ROOT / "local/cinematics/opening_bird_intro/pipeline_plan.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_binary(env_name: str, candidates: list[str]) -> str | None:
    explicit = os.environ.get(env_name)
    if explicit:
        found = shutil.which(explicit)
        if found:
            return found
        if Path(explicit).exists():
            return str(Path(explicit))
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
        if Path(candidate).exists():
            return str(Path(candidate))
    return None


def toolchain() -> dict[str, str | None]:
    return {
        "python": sys.executable,
        "blender": resolve_binary("BLENDER_BIN", ["blender", r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"]),
        "godot": resolve_binary("GODOT_BIN", ["godot4", "godot", "Godot_v4.3-stable_win64_console.exe"]),
        "musescore": resolve_binary("MUSESCORE_BIN", ["MuseScore4", "musescore4", r"C:\Program Files\MuseScore 4\bin\MuseScore4.exe"]),
        "reaper": resolve_binary("REAPER_BIN", ["reaper", r"C:\Program Files\REAPER (x64)\reaper.exe"]),
    }


def build_plan(tools: dict[str, str | None]) -> list[dict]:
    python = tools["python"] or sys.executable
    blender = tools["blender"] or "blender"
    godot = tools["godot"] or "godot"
    local = "local/cinematics/opening_bird_intro"
    return [
        {"id":"validate_storyboard","kind":"command","command":[python,"tools/cinematics/build_opening_storyboard.py","--check"]},
        {"id":"validate_audio_plan","kind":"command","command":[python,"tools/cinematics/prepare_opening_audio.py","--check"]},
        {"id":"storyboard","kind":"command","command":[python,"tools/cinematics/build_opening_storyboard.py"],"outputs":[f"{local}/storyboard/storyboard.json",f"{local}/storyboard/storyboard.html"]},
        {"id":"audio_sessions","kind":"command","command":[python,"tools/cinematics/prepare_opening_audio.py"],"outputs":[f"{local}/music/opening_bird_intro.musicxml",f"{local}/audio/opening_bird_intro.rpp",f"{local}/audio/cue_sheet.json"]},
        {"id":"preproduction_review","kind":"gate","approval":"preproduction"},
        {"id":"blender_proxy","kind":"command","approval":"preproduction","requires_tool":"blender","command":[blender,"--background","--python","tools/blender/build_opening_cinematic.py","--","--output",f"{local}/blender/opening_bird_intro.blend","--export-glb",f"{local}/exports/opening_bird_intro.glb","--report","local/reports/opening_bird_intro/blender_proxy.json"],"outputs":[f"{local}/blender/opening_bird_intro.blend",f"{local}/exports/opening_bird_intro.glb","local/reports/opening_bird_intro/blender_proxy.json"]},
        {"id":"visual_review","kind":"gate","approval":"art"},
        {"id":"publish_glb","kind":"copy","approval":"art","source":f"{local}/exports/opening_bird_intro.glb","target":"assets/3d/cinematics/opening_bird_intro/opening_bird_intro.glb","outputs":["assets/3d/cinematics/opening_bird_intro/opening_bird_intro.glb"]},
        {"id":"godot_import","kind":"command","approval":"art","requires_tool":"godot","command":[godot,"--headless","--path",str(ROOT),"--import"],"outputs":[]},
        {"id":"audio_listening_review","kind":"gate","approval":"audio"},
        {"id":"final_handoff_review","kind":"gate","approval":"final"},
    ]


def approved(stage: dict, args: argparse.Namespace) -> bool:
    key = stage.get("approval")
    if not key:
        return True
    return {
        "preproduction": args.approve_preproduction,
        "art": args.approve_art,
        "audio": args.approve_audio,
        "final": args.approve_final,
    }[key]


def outputs_exist(stage: dict) -> bool:
    outputs = stage.get("outputs", [])
    return bool(outputs) and all((ROOT / value).exists() for value in outputs)


def save_state(completed: list[str], blocked_at: str = "", status: str = "running") -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({
        "version": 1,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "completed": completed,
        "blocked_at": blocked_at,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def execute(plan: list[dict], tools: dict[str, str | None], args: argparse.Namespace) -> dict:
    previous = load(STATE) if STATE.exists() and not args.no_resume else {"completed": []}
    completed = list(previous.get("completed", []))
    for stage in plan:
        sid = stage["id"]
        if args.stage and sid != args.stage:
            continue
        if not approved(stage, args):
            save_state(completed, sid, "awaiting_human_review")
            return {"status":"awaiting_human_review","blocked_at":sid,"completed":completed}
        required_tool = stage.get("requires_tool")
        if required_tool and not tools.get(required_tool):
            save_state(completed, sid, "missing_tool")
            return {"status":"missing_tool","blocked_at":sid,"tool":required_tool,"completed":completed}
        if not args.no_resume and sid in completed and (stage["kind"] == "gate" or outputs_exist(stage)):
            continue
        if stage["kind"] == "command":
            subprocess.run(stage["command"], cwd=ROOT, check=True)
        elif stage["kind"] == "copy":
            source = ROOT / stage["source"]
            target = ROOT / stage["target"]
            if not source.exists():
                raise FileNotFoundError(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() and not args.overwrite_approved:
                raise FileExistsError(f"approved target already exists: {target}")
            shutil.copy2(source, target)
        elif stage["kind"] != "gate":
            raise ValueError(f"unknown stage kind: {stage['kind']}")
        if sid not in completed:
            completed.append(sid)
        save_state(completed)
    save_state(completed, status="complete")
    return {"status":"complete","completed":completed}


def validate() -> list[str]:
    errors: list[str] = []
    config = load(CONFIG)
    if config.get("version") != 1:
        errors.append("opening pipeline version must be 1")
    for path in [
        "data/cinematics/opening_bird_intro.json",
        "tools/cinematics/build_opening_storyboard.py",
        "tools/cinematics/prepare_opening_audio.py",
        "tools/blender/build_opening_cinematic.py",
        "scripts/cinematics/opening_bird_intro_director.gd",
    ]:
        if not (ROOT / path).exists():
            errors.append("missing: " + path)
    ids = [stage["id"] for stage in build_plan(toolchain())]
    if len(ids) != len(set(ids)):
        errors.append("pipeline stage ids must be unique")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Automate Le Dernier Vol from storyboard to Godot")
    parser.add_argument("command", choices=("doctor","plan","prepare","execute","check"))
    parser.add_argument("--stage")
    parser.add_argument("--approve-preproduction", action="store_true")
    parser.add_argument("--approve-art", action="store_true")
    parser.add_argument("--approve-audio", action="store_true")
    parser.add_argument("--approve-final", action="store_true")
    parser.add_argument("--overwrite-approved", action="store_true")
    parser.add_argument("--no-resume", action="store_true")
    args = parser.parse_args()
    errors = validate()
    if errors:
        print("\n".join("ERROR: " + item for item in errors), file=sys.stderr)
        return 1
    tools = toolchain()
    plan = build_plan(tools)
    if args.command == "doctor":
        print(json.dumps({"pipeline":"opening_bird_intro","tools":tools}, ensure_ascii=False, indent=2))
        return 0 if all(tools.values()) else 2
    if args.command == "check":
        subprocess.run([sys.executable,"tools/cinematics/build_opening_storyboard.py","--check"],cwd=ROOT,check=True)
        subprocess.run([sys.executable,"tools/cinematics/prepare_opening_audio.py","--check"],cwd=ROOT,check=True)
        print("OPENING_PIPELINE_OK")
        return 0
    PLAN.parent.mkdir(parents=True, exist_ok=True)
    PLAN.write_text(json.dumps({"version":1,"stages":plan},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if args.command == "plan":
        print(PLAN.read_text(encoding="utf-8"), end="")
        return 0
    if args.command == "prepare":
        for command in [
            [sys.executable,"tools/cinematics/build_opening_storyboard.py"],
            [sys.executable,"tools/cinematics/prepare_opening_audio.py"],
        ]:
            subprocess.run(command,cwd=ROOT,check=True)
        print("OPENING_PIPELINE_PREPARED")
        return 0
    result = execute(plan, tools, args)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] in ("complete","awaiting_human_review") else 2


if __name__ == "__main__":
    raise SystemExit(main())
