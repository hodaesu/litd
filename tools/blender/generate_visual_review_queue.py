#!/usr/bin/env python3
"""Generate visual-review jobs for every GLB expected by Godot."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/blender/visual_review_queue.json"

GATES = {
    "environments": ["silhouette", "critical_path", "miniboss_bypass", "camera_readability", "ash_fog_readability", "collision_alignment"],
    "characters": ["silhouette", "scale", "cel_shading_readability", "rig_deformation", "equipment_sockets", "animation_clarity"],
    "props": ["silhouette", "scale", "cel_shading_readability", "collision_alignment", "interaction_socket", "lod_readability"],
}


def build_queue(root: Path = ROOT) -> dict:
    registry = json.loads((root / "data/blender/godot_import_registry.json").read_text(encoding="utf-8"))
    pipeline = json.loads((root / "data/blender/full_pipeline_manifest.json").read_text(encoding="utf-8"))
    by_job = {job["job_id"]: job for job in pipeline["stages"]}
    reviews = []
    for asset in registry["assets"]:
        job = by_job[asset["job_id"]]
        blend = next(path for path in job["outputs"] if path.endswith(".blend"))
        is_environment = asset["category"] == "environments"
        angles = [45, 135, 225, 315] if is_environment else list(range(0, 360, 45))
        reviews.append({
            "job_id": asset["job_id"], "category": asset["category"],
            "blend_path": blend, "glb_path": asset["source_glb"],
            "preview": {
                "type": "isometric_quadrants" if is_environment else "turntable",
                "angles_degrees": angles, "elevation_degrees": 50 if is_environment else 15,
                "resolution": [1024, 1024] if is_environment else [512, 512],
                "output_dir": f"reports/visual_reviews/{asset['job_id']}",
            },
            "gates": GATES[asset["category"]], "status": "pending",
        })
    return {"version": 1, "generator": "tools/blender/generate_visual_review_queue.py", "review_count": len(reviews), "reviews": reviews}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = json.dumps(build_queue(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit("visual review queue is out of date")
        print(f"{build_queue()['review_count']} visual review jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"generated {build_queue()['review_count']} visual review jobs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
