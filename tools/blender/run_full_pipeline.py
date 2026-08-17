#!/usr/bin/env python3
"""Plan or execute every Blender production job for Light in the Dark."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "data/blender/full_pipeline_manifest.json"


def _load(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))["jobs"]


def build_pipeline_plan(root: Path = ROOT) -> dict:
    stages = []
    material_output = "builds/materials/litd_material_library.blend"
    stages.append({
        "stage": "materials", "job_id": "material_library", "depends_on": [],
        "command": ["tools/blender/build_material_library.py", "--output", material_output],
        "outputs": [material_output],
    })
    for job in _load(root / "data/levels/ashlands_blender_jobs.json"):
        blend = f"{job['output']}/{job['job_id']}.blend"
        glb = f"{job['output']}/{job['job_id']}.glb"
        stages.append({
            "stage": "environments", "job_id": job["job_id"], "depends_on": ["material_library"],
            "command": ["tools/blender/build_ashlands_scene.py", job["job_id"], "--output", blend, "--export-glb", glb],
            "outputs": [blend, glb],
        })
    for job in _load(root / "data/blender/character_jobs.json"):
        blend = f"{job['output']}/{job['character_id']}.blend"
        glb = f"{job['output']}/{job['character_id']}.glb"
        stages.append({
            "stage": "characters", "job_id": job["job_id"], "depends_on": ["material_library"],
            "command": ["tools/blender/build_character_scene.py", job["character_id"], "--output", blend, "--export-glb", glb],
            "outputs": [blend, glb],
        })
    prop_jobs = _load(root / "data/blender/prop_jobs.json")
    for job in prop_jobs:
        blend = f"{job['output']}/{job['prop_id']}.blend"
        glb = f"{job['output']}/{job['prop_id']}.glb"
        stages.append({
            "stage": "props", "job_id": job["job_id"], "depends_on": ["material_library"],
            "command": ["tools/blender/build_prop_scene.py", job["prop_id"], "--output", blend, "--export-glb", glb],
            "outputs": [blend, glb],
        })
    return {
        "version": 1, "generator": "tools/blender/run_full_pipeline.py",
        "summary": {
            "total_jobs": len(stages),
            "materials": 1, "environments": 15, "characters": 52, "props": len(prop_jobs),
        },
        "stages": stages,
    }


def render_manifest(plan: dict) -> str:
    return json.dumps(plan, ensure_ascii=False, indent=2) + "\n"


def execute(plan: dict, blender: str, only_stage: str | None = None) -> None:
    for item in plan["stages"]:
        if only_stage and item["stage"] != only_stage:
            continue
        command = [blender, "--background", "--python", str(ROOT / item["command"][0]), "--", *item["command"][1:]]
        subprocess.run(command, cwd=ROOT, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--stage", choices=("materials", "environments", "characters", "props"))
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args()
    plan = build_pipeline_plan()
    rendered = render_manifest(plan)
    if args.check:
        if not args.manifest.exists() or args.manifest.read_text(encoding="utf-8") != rendered:
            raise SystemExit("full Blender pipeline manifest is out of date")
        print(f"{plan['summary']['total_jobs']} Blender pipeline jobs are current")
        return 0
    if args.plan_only:
        print(rendered, end="")
        return 0
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(rendered, encoding="utf-8")
    print(f"wrote {plan['summary']['total_jobs']} jobs to {args.manifest}")
    if args.execute:
        execute(plan, args.blender, args.stage)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
