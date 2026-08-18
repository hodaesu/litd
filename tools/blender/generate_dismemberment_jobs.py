#!/usr/bin/env python3
"""Generate deterministic Blender rig/VFX requirements from gameplay anatomy."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/blender/dismemberment_jobs.json"


def _expand_unique_part(part: dict, naming: dict) -> dict:
    part_id = str(part["id"])
    values = {"part_id": part_id, "state": "critical"}
    return {
        "part_id": part_id,
        "name": part.get("name", part_id),
        "severable": bool(part.get("severable", True)),
        "bone": naming["bone"].format(**values),
        "sever_socket": naming["sever_socket"].format(**values) if part.get("severable", True) else "",
        "detached_mesh": naming["detached_mesh"].format(**values) if part.get("severable", True) else "",
        "wound_cap": naming["wound_cap"].format(**values) if part.get("severable", True) else "",
        "vfx_socket": naming["vfx_socket"].format(**values),
        "injury_shape": naming["injury_shape"].format(**values),
        "animations": [f"hit_{part_id}", f"injury_{part_id}", f"critical_{part_id}", f"dismember_{part_id}"],
    }


def build_jobs(root: Path = ROOT) -> list[dict]:
    anatomy = json.loads((root / "data/combat_anatomy_v2.json").read_text(encoding="utf-8"))
    contract = json.loads((root / "data/blender/dismemberment_contract.json").read_text(encoding="utf-8"))
    jobs: list[dict] = []
    for profile_id, profile in anatomy["generic_profiles"].items():
        mapping = contract["generic_profiles"].get(profile_id, {})
        jobs.append({
            "job_id": f"dismemberment_profile_{profile_id}",
            "type": "generic_profile",
            "profile_id": profile_id,
            "collections": contract["required_collections"],
            "parts": [dict({"part_id": p["id"], "name": p["name"], "severable": p.get("severable", True)}, **mapping[p["id"]]) for p in profile["parts"]],
            "presentation_modes": contract["presentation_modes"],
            "required_animations": contract["animation_contract"]["required_generic"],
        })
    naming = contract["unique_boss_naming"]
    for boss_id, boss in anatomy.get("boss_anatomies", {}).items():
        jobs.append({
            "job_id": f"dismemberment_boss_{boss_id}",
            "type": "unique_boss",
            "boss_id": boss_id,
            "name": boss.get("name", boss_id),
            "collections": contract["required_collections"],
            "parts": [_expand_unique_part(part, naming) for part in boss["parts"]],
            "presentation_modes": contract["presentation_modes"],
            "required_animations": contract["animation_contract"]["required_generic"],
        })
    return jobs


def payload(root: Path = ROOT) -> dict:
    return {"version": 1, "generator": "tools/blender/generate_dismemberment_jobs.py", "jobs": build_jobs(root)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = json.dumps(payload(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit("dismemberment Blender jobs are out of date; run the generator")
        print("dismemberment Blender jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"generated {len(payload()['jobs'])} dismemberment Blender jobs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
