#!/usr/bin/env python3
"""One-command supervised build for the LITD Darius vs Hungry Ghoul slice."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "data/blender/vertical_slice_automation.json"
VISUAL = ROOT / "data/visual_vertical_slice.json"
STATE = ROOT / "reports/vertical_slice_automation_state.json"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _python(*args: str) -> list[str]:
    return [sys.executable, *args]


def _blender(binary: str, blend: str | None, script: str, *args: str) -> list[str]:
    cmd = [binary, "--background"]
    if blend:
        cmd.append(blend)
    return [*cmd, "--python", script, "--", *args]


def build_plan(blender: str = "blender", godot: str = "godot") -> list[dict]:
    p = {
        "d0": "builds/vertical_slice/darius/darius_proxy.blend",
        "dr": "builds/vertical_slice/darius/darius_rigged.blend",
        "dl": "builds/vertical_slice/darius/darius_lod.blend",
        "dm": "builds/vertical_slice/darius/darius_mobile.blend",
        "g0": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_proxy.blend",
        "gr": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_rigged.blend",
        "gl": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_lod.blend",
        "gm": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_mobile.blend",
        "a0": "builds/vertical_slice/arena/ashlands_visual_arena_proxy.blend",
        "am": "builds/vertical_slice/arena/ashlands_visual_arena_mobile.blend",
    }
    return [
        {"id": "preflight", "kind": "python", "command": _python("tools/blender/vertical_slice_session.py", "--preflight")},
        {"id": "materials", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_material_library.py", "--output", "builds/vertical_slice/materials/litd_materials.blend"), "outputs": ["builds/vertical_slice/materials/litd_materials.blend"]},
        {"id": "build_darius", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_character_scene.py", "character_darius", "--output", p["d0"]), "outputs": [p["d0"]]},
        {"id": "build_ghoul", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_character_scene.py", "character_enemy_01_goule_affamee", "--output", p["g0"]), "outputs": [p["g0"]]},
        {"id": "build_arena", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_vertical_slice_arena.py", "--output", p["a0"]), "outputs": [p["a0"]]},
        {"id": "rig_darius", "kind": "blender", "command": _blender(blender, p["d0"], "tools/blender/auto_rig_litd.py", "--asset-id", "darius", "--output", p["dr"]), "outputs": [p["dr"]]},
        {"id": "rig_ghoul", "kind": "blender", "command": _blender(blender, p["g0"], "tools/blender/auto_rig_litd.py", "--asset-id", "enemy_01_goule_affamee", "--output", p["gr"]), "outputs": [p["gr"]]},
        {"id": "validate_darius", "kind": "blender", "command": _blender(blender, p["dr"], "tools/blender/validate_asset.py", "--asset-id", "darius", "--report", "reports/vertical_slice/darius_validation.json", "--strict"), "outputs": ["reports/vertical_slice/darius_validation.json"]},
        {"id": "validate_ghoul", "kind": "blender", "command": _blender(blender, p["gr"], "tools/blender/validate_asset.py", "--asset-id", "enemy_01_goule_affamee", "--report", "reports/vertical_slice/ghoul_validation.json", "--strict"), "outputs": ["reports/vertical_slice/ghoul_validation.json"]},
        {"id": "validate_arena", "kind": "blender", "command": _blender(blender, p["a0"], "tools/blender/validate_asset.py", "--asset-id", "ashlands_visual_arena", "--report", "reports/vertical_slice/arena_validation.json", "--strict"), "outputs": ["reports/vertical_slice/arena_validation.json"]},
        {"id": "lod_darius", "kind": "blender", "command": _blender(blender, p["dr"], "tools/blender/generate_lods.py", "--asset-id", "darius", "--output", p["dl"]), "outputs": [p["dl"]]},
        {"id": "lod_ghoul", "kind": "blender", "command": _blender(blender, p["gr"], "tools/blender/generate_lods.py", "--asset-id", "enemy_01_goule_affamee", "--output", p["gl"]), "outputs": [p["gl"]]},
        {"id": "optimize_darius", "kind": "blender", "command": _blender(blender, p["dl"], "tools/blender/optimize_for_mobile.py", "--asset-id", "darius", "--output", p["dm"], "--report", "reports/vertical_slice/darius_mobile.json"), "outputs": [p["dm"], "reports/vertical_slice/darius_mobile.json"]},
        {"id": "optimize_ghoul", "kind": "blender", "command": _blender(blender, p["gl"], "tools/blender/optimize_for_mobile.py", "--asset-id", "enemy_01_goule_affamee", "--output", p["gm"], "--report", "reports/vertical_slice/ghoul_mobile.json"), "outputs": [p["gm"], "reports/vertical_slice/ghoul_mobile.json"]},
        {"id": "optimize_arena", "kind": "blender", "command": _blender(blender, p["a0"], "tools/blender/optimize_for_mobile.py", "--asset-id", "ashlands_visual_arena", "--output", p["am"], "--report", "reports/vertical_slice/arena_mobile.json"), "outputs": [p["am"], "reports/vertical_slice/arena_mobile.json"]},
        {"id": "turntable_darius", "kind": "blender", "command": _blender(blender, p["dm"], "tools/blender/render_turntable_batch.py", "--asset-id", "darius", "--output-dir", "reports/vertical_slice/previews/darius"), "outputs": ["reports/vertical_slice/previews/darius/manifest.json"]},
        {"id": "turntable_ghoul", "kind": "blender", "command": _blender(blender, p["gm"], "tools/blender/render_turntable_batch.py", "--asset-id", "enemy_01_goule_affamee", "--output-dir", "reports/vertical_slice/previews/hungry_ghoul"), "outputs": ["reports/vertical_slice/previews/hungry_ghoul/manifest.json"]},
        {"id": "turntable_arena", "kind": "blender", "command": _blender(blender, p["am"], "tools/blender/render_turntable_batch.py", "--asset-id", "ashlands_visual_arena", "--output-dir", "reports/vertical_slice/previews/arena"), "outputs": ["reports/vertical_slice/previews/arena/manifest.json"]},
        {"id": "art_review", "kind": "approval", "command": [], "requires_approval": True},
        {"id": "publish_darius", "kind": "blender", "command": _blender(blender, p["dm"], "tools/blender/publish_to_godot.py", "--asset-id", "darius", "--target", "assets/3d/characters/darius/darius.glb"), "requires_approval": True, "outputs": ["assets/3d/characters/darius/darius.glb"]},
        {"id": "publish_ghoul", "kind": "blender", "command": _blender(blender, p["gm"], "tools/blender/publish_to_godot.py", "--asset-id", "enemy_01_goule_affamee", "--target", "assets/3d/characters/enemies/hungry_ghoul.glb"), "requires_approval": True, "outputs": ["assets/3d/characters/enemies/hungry_ghoul.glb"]},
        {"id": "publish_arena", "kind": "blender", "command": _blender(blender, p["am"], "tools/blender/publish_to_godot.py", "--asset-id", "ashlands_visual_arena", "--target", "assets/3d/environments/ashlands/vertical_slice_arena.glb"), "requires_approval": True, "outputs": ["assets/3d/environments/ashlands/vertical_slice_arena.glb"]},
        {"id": "capture_godot", "kind": "godot", "command": _python("tools/godot/capture_vertical_slice.py", "--godot", godot, "--execute"), "requires_approval": True, "outputs": ["reports/vertical_slice/captures/manifest.json"]},
        {"id": "profile_godot", "kind": "godot", "command": _python("tools/godot/profile_vertical_slice.py", "--godot", godot, "--execute"), "requires_approval": True, "outputs": ["reports/vertical_slice/profile.json"]},
        {"id": "final_report", "kind": "python", "command": _python("tools/blender/vertical_slice_final_report.py", "--strict"), "requires_approval": True, "outputs": ["reports/vertical_slice/final_report.json"]},
    ]


def validate_contract() -> list[str]:
    errors: list[str] = []
    config = load_json(CONFIG)
    visual = load_json(VISUAL)
    if config.get("version") != 1:
        errors.append("automation contract version must be 1")
    if visual.get("version") != 2:
        errors.append("visual slice contract version must be 2")
    ids = [stage["id"] for stage in build_plan()]
    if len(ids) != len(set(ids)):
        errors.append("automation stage ids must be unique")
    gate = ids.index("art_review")
    if any(not stage.get("requires_approval", False) for stage in build_plan()[gate + 1:]):
        errors.append("all post-review stages must require explicit art approval")
    required = [
        "tools/blender/build_vertical_slice_arena.py", "tools/blender/auto_rig_litd.py", "tools/blender/validate_asset.py",
        "tools/blender/generate_lods.py", "tools/blender/optimize_for_mobile.py", "tools/blender/retarget_animations.py",
        "tools/blender/render_turntable_batch.py", "tools/blender/publish_to_godot.py", "tools/blender/vertical_slice_final_report.py",
        "tools/godot/capture_vertical_slice.py", "tools/godot/profile_vertical_slice.py"
    ]
    for rel in required:
        if not (ROOT / rel).exists():
            errors.append("missing automation script: " + rel)
    return errors


def _outputs_exist(stage: dict) -> bool:
    outputs = stage.get("outputs", [])
    return bool(outputs) and all((ROOT / output).exists() for output in outputs)


def _write_state(completed: list[str], blocked: str = "") -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({"version": 1, "completed": completed, "blocked_at": blocked}, indent=2) + "\n", encoding="utf-8")


def execute_plan(plan: list[dict], approve_art: bool, resume: bool) -> dict:
    previous = load_json(STATE) if resume and STATE.exists() else {"completed": []}
    completed = list(previous.get("completed", []))
    for stage in plan:
        sid = stage["id"]
        if stage.get("requires_approval") and not approve_art:
            _write_state(completed, sid)
            return {"status": "awaiting_art_review", "blocked_at": sid, "completed": completed}
        if stage["kind"] == "approval":
            if sid not in completed:
                completed.append(sid)
            _write_state(completed)
            continue
        if resume and sid in completed and _outputs_exist(stage):
            continue
        subprocess.run(stage["command"], cwd=ROOT, check=True)
        if sid not in completed:
            completed.append(sid)
        _write_state(completed)
    return {"status": "complete", "completed": completed}


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the LITD visual vertical slice with one supervised command")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--approve-art", action="store_true")
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    errors = validate_contract()
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    if args.check:
        print("VERTICAL_SLICE_AUTOMATION_OK")
        return 0
    plan = build_plan(args.blender, args.godot)
    rendered = json.dumps({"version": 1, "approved_art": args.approve_art, "stages": plan}, ensure_ascii=False, indent=2) + "\n"
    if args.plan:
        args.plan.parent.mkdir(parents=True, exist_ok=True)
        args.plan.write_text(rendered, encoding="utf-8")
    if not args.execute:
        print(rendered, end="")
        return 0
    if shutil.which(args.blender) is None:
        print("ERROR: Blender executable not found")
        return 2
    if args.approve_art and shutil.which(args.godot) is None:
        print("ERROR: Godot executable not found")
        return 2
    result = execute_plan(plan, args.approve_art, not args.no_resume)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
