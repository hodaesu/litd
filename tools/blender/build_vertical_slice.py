#!/usr/bin/env python3
"""One-command orchestrator for the LITD Darius vs Hungry Ghoul vertical slice.

CI uses --check/--plan only. On a workstation, --execute runs every technical
stage that can be automated and stops at the explicit art-review gate unless
--approve-art is supplied.
"""
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
    cmd += ["--python", script, "--", *args]
    return cmd


def build_plan(blender: str = "blender", godot: str = "godot") -> list[dict]:
    d = {
        "darius_blend": "builds/vertical_slice/darius/darius_proxy.blend",
        "darius_rig": "builds/vertical_slice/darius/darius_rigged.blend",
        "darius_lod": "builds/vertical_slice/darius/darius_lod.blend",
        "darius_mobile": "builds/vertical_slice/darius/darius_mobile.blend",
        "ghoul_blend": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_proxy.blend",
        "ghoul_rig": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_rigged.blend",
        "ghoul_lod": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_lod.blend",
        "ghoul_mobile": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_mobile.blend",
        "arena_blend": "builds/vertical_slice/arena/ashlands_visual_arena_proxy.blend",
        "arena_mobile": "builds/vertical_slice/arena/ashlands_visual_arena_mobile.blend",
    }
    stages: list[dict] = [
        {"id": "preflight", "kind": "python", "command": _python("tools/blender/vertical_slice_session.py", "--preflight")},
        {"id": "materials", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_material_library.py", "--output", "builds/vertical_slice/materials/litd_materials.blend"), "outputs": ["builds/vertical_slice/materials/litd_materials.blend"]},
        {"id": "build_darius", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_character_scene.py", "character_darius", "--output", d["darius_blend"]), "outputs": [d["darius_blend"]]},
        {"id": "build_ghoul", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_character_scene.py", "character_enemy_01_goule_affamee", "--output", d["ghoul_blend"]), "outputs": [d["ghoul_blend"]]},
        {"id": "build_arena", "kind": "blender", "command": _blender(blender, None, "tools/blender/build_ashlands_scene.py", "--output", d["arena_blend"]), "outputs": [d["arena_blend"]]},
        {"id": "rig_darius", "kind": "blender", "command": _blender(blender, d["darius_blend"], "tools/blender/auto_rig_litd.py", "--asset-id", "darius", "--output", d["darius_rig"]), "outputs": [d["darius_rig"]]},
        {"id": "rig_ghoul", "kind": "blender", "command": _blender(blender, d["ghoul_blend"], "tools/blender/auto_rig_litd.py", "--asset-id", "enemy_01_goule_affamee", "--output", d["ghoul_rig"]), "outputs": [d["ghoul_rig"]]},
        {"id": "validate_darius", "kind": "blender", "command": _blender(blender, d["darius_rig"], "tools/blender/validate_asset.py", "--asset-id", "darius", "--report", "reports/vertical_slice/darius_validation.json", "--strict"), "outputs": ["reports/vertical_slice/darius_validation.json"]},
        {"id": "validate_ghoul", "kind": "blender", "command": _blender(blender, d["ghoul_rig"], "tools/blender/validate_asset.py", "--asset-id", "enemy_01_goule_affamee", "--report", "reports/vertical_slice/ghoul_validation.json", "--strict"), "outputs": ["reports/vertical_slice/ghoul_validation.json"]},
        {"id": "validate_arena", "kind": "blender", "command": _blender(blender, d["arena_blend"], "tools/blender/validate_asset.py", "--asset-id", "ashlands_visual_arena", "--report", "reports/vertical_slice/arena_validation.json", "--strict"), "outputs": ["reports/vertical_slice/arena_validation.json"]},
        {"id": "lod_darius", "kind": "blender", "command": _blender(blender, d["darius_rig"], "tools/blender/generate_lods.py", "--asset-id", "darius", "--output", d["darius_lod"]), "outputs": [d["darius_lod"]]},
        {"id": "lod_ghoul", "kind": "blender", "command": _blender(blender, d["ghoul_rig"], "tools/blender/generate_lods.py", "--asset-id", "enemy_01_goule_affamee", "--output", d["ghoul_lod"]), "outputs": [d["ghoul_lod"]]},
        {"id": "optimize_darius", "kind": "blender", "command": _blender(blender, d["darius_lod"], "tools/blender/optimize_for_mobile.py", "--asset-id", "darius", "--output", d["darius_mobile"], "--report", "reports/vertical_slice/darius_mobile.json"), "outputs": [d["darius_mobile"], "reports/vertical_slice/darius_mobile.json"]},
        {"id": "optimize_ghoul", "kind": "blender", "command": _blender(blender, d["ghoul_lod"], "tools/blender/optimize_for_mobile.py", "--asset-id", "enemy_01_goule_affamee", "--output", d["ghoul_mobile"], "--report", "reports/vertical_slice/ghoul_mobile.json"), "outputs": [d["ghoul_mobile"], "reports/vertical_slice/ghoul_mobile.json"]},
        {"id": "optimize_arena", "kind": "blender", "command": _blender(blender, d["arena_blend"], "tools/blender/optimize_for_mobile.py", "--asset-id", "ashlands_visual_arena", "--output", d["arena_mobile"], "--report", "reports/vertical_slice/arena_mobile.json"), "outputs": [d["arena_mobile"], "reports/vertical_slice/arena_mobile.json"]},
        {"id": "turntable_darius", "kind": "blender", "command": _blender(blender, d["darius_mobile"], "tools/blender/render_turntable_batch.py", "--asset-id", "darius", "--output-dir", "reports/vertical_slice/previews/darius"), "outputs": ["reports/vertical_slice/previews/darius/manifest.json"]},
        {"id": "turntable_ghoul", "kind": "blender", "command": _blender(blender, d["ghoul_mobile"], "tools/blender/render_turntable_batch.py", "--asset-id", "enemy_01_goule_affamee", "--output-dir", "reports/vertical_slice/previews/hungry_ghoul"), "outputs": ["reports/vertical_slice/previews/hungry_ghoul/manifest.json"]},
        {"id": "turntable_arena", "kind": "blender", "command": _blender(blender, d["arena_mobile"], "tools/blender/render_turntable_batch.py", "--asset-id", "ashlands_visual_arena", "--output-dir", "reports/vertical_slice/previews/arena"), "outputs": ["reports/vertical_slice/previews/arena/manifest.json"]},
        {"id": "art_review", "kind": "approval", "command": [], "requires_approval": True},
        {"id": "publish_darius", "kind": "blender", "command": _blender(blender, d["darius_mobile"], "tools/blender/publish_to_godot.py", "--asset-id", "darius", "--target", "assets/3d/characters/darius/darius.glb"), "requires_approval": True, "outputs": ["assets/3d/characters/darius/darius.glb"]},
        {"id": "publish_ghoul", "kind": "blender", "command": _blender(blender, d["ghoul_mobile"], "tools/blender/publish_to_godot.py", "--asset-id", "enemy_01_goule_affamee", "--target", "assets/3d/characters/enemies/hungry_ghoul.glb"), "requires_approval": True, "outputs": ["assets/3d/characters/enemies/hungry_ghoul.glb"]},
        {"id": "publish_arena", "kind": "blender", "command": _blender(blender, d["arena_mobile"], "tools/blender/publish_to_godot.py", "--asset-id", "ashlands_visual_arena", "--target", "assets/3d/environments/ashlands/vertical_slice_arena.glb"), "requires_approval": True, "outputs": ["assets/3d/environments/ashlands/vertical_slice_arena.glb"]},
        {"id": "capture_godot", "kind": "godot", "command": _python("tools/godot/capture_vertical_slice.py", "--godot", godot, "--execute"), "requires_approval": True, "outputs": ["reports/vertical_slice/captures/manifest.json"]},
        {"id": "profile_godot", "kind": "godot", "command": _python("tools/godot/profile_vertical_slice.py", "--godot", godot, "--execute"), "requires_approval": True, "outputs": ["reports/vertical_slice/profile.json"]},
    ]
    return stages


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
    required = [
        "tools/blender/auto_rig_litd.py", "tools/blender/validate_asset.py", "tools/blender/generate_lods.py",
        "tools/blender/optimize_for_mobile.py", "tools/blender/retarget_animations.py", "tools/blender/render_turntable_batch.py",
        "tools/blender/publish_to_godot.py", "tools/godot/capture_vertical_slice.py", "tools/godot/profile_vertical_slice.py",
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
            if approve_art:
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
    payload = {"version": 1, "approved_art": args.approve_art, "stages": plan}
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
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
    return 0 if result["status"] in {"complete", "awaiting_art_review"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
