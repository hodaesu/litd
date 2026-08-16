#!/usr/bin/env python3
"""Generate Blender jobs for equipment and reusable Ashlands gameplay props."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/blender/prop_jobs.json"

GAMEPLAY_PROPS = (
    ("campfire", "Feu de camp", "gameplay", "ember_emissive", [1.2, 1.0, 1.2], "SOCKET_interact"),
    ("resource_cache", "Cache de ressources", "gameplay", "wood_charred", [1.0, 0.8, 0.8], "SOCKET_loot"),
    ("shortcut_gate", "Porte de raccourci", "architecture", "iron_tarnished", [2.4, 3.0, 0.35], "SOCKET_interact"),
    ("abbey_teleporter", "Téléporteur ancestral", "gameplay", "stone_ash", [3.0, 0.45, 3.0], "SOCKET_teleport"),
    ("harvestable_corpse", "Cadavre récoltable", "gameplay", "cloth_soot", [1.8, 0.45, 0.65], "SOCKET_harvest"),
)

SLOT_PROFILES = {
    "weapon": ("iron_tarnished", [1.05, 0.08, 0.12], "SOCKET_grip"),
    "armor": ("cloth_soot", [0.65, 0.95, 0.3], "SOCKET_spine"),
    "ring": ("bone_old", [0.06, 0.02, 0.06], "SOCKET_finger"),
}


def _job(identifier: str, name: str, category: str, material: str,
         dimensions: list[float], socket: str) -> dict:
    return {
        "job_id": f"prop_{identifier}", "prop_id": identifier, "name": name,
        "category": category, "dimensions_m": dimensions, "material_profile": material,
        "collections": ["PROP", "COLLISION", "SOCKETS", "LIGHTING", "CAMERA"],
        "lod_levels": [0, 1, 2], "collision": "convex", "socket": socket,
        "output": f"builds/props/{category}/{identifier}",
    }


def build_jobs(root: Path = ROOT) -> list[dict]:
    equipment = json.loads((root / "data/equipment.json").read_text(encoding="utf-8"))
    jobs = []
    for item in equipment:
        material, dimensions, socket = SLOT_PROFILES[item["slot"]]
        job = _job(item["id"], item["name"], "equipment", material, dimensions, socket)
        job["equipment_slot"] = item["slot"]
        jobs.append(job)
    jobs.extend(_job(*spec) for spec in GAMEPLAY_PROPS)
    return jobs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    payload = {"version": 1, "generator": "tools/blender/generate_prop_jobs.py", "jobs": build_jobs()}
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit("prop Blender jobs are out of date")
        print(f"{len(payload['jobs'])} prop Blender jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"generated {len(payload['jobs'])} prop Blender jobs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
