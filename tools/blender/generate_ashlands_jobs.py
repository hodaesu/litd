#!/usr/bin/env python3
"""Generate deterministic Blender production jobs from the Ashlands blockout contracts."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data/levels/terre_des_cendres_blockout_manifest.json"
LAYOUTS = ROOT / "data/levels/ashlands_layout_profiles.json"
HANDOFF = ROOT / "data/levels/ashlands_blender_handoff.json"
OUTPUT = ROOT / "data/levels/ashlands_blender_jobs.json"


def build_plan() -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    layouts = json.loads(LAYOUTS.read_text(encoding="utf-8"))
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    priorities = {
        1: "P0", 4: "P0", 7: "P0", 12: "P0", 13: "P0",
        2: "P1", 3: "P1", 8: "P1", 9: "P1", 14: "P1", 15: "P1",
    }
    jobs = []
    for index, zone in enumerate(manifest["zones"], start=1):
        zone_id = zone["id"]
        zone_profile = layouts["zones"][zone_id]
        profile_name = zone_profile["profile"]
        rules = layouts["profile_rules"][profile_name]
        jobs.append({
            "job_id": f"ashlands_{index:02d}_{handoff['zone_kits'][zone_id]}",
            "zone_id": zone_id,
            "priority": priorities.get(index, "P2"),
            "kit_id": handoff["zone_kits"][zone_id],
            "layout_profile": profile_name,
            "landmark": zone_profile["landmark"],
            "zone_size_m": zone["size_m"],
            "deliverables": {
                "buildings": rules["building_count"],
                "walls_or_blockers": rules["wall_count"],
                "platforms": rules["platform_count"],
                "landmarks": 1,
                "lod_policy": "LOD0_LOD1_LOD2",
                "collision_policy": "keep_blockout_until_approved",
            },
            "gameplay_sockets": {
                "encounters": zone["encounter_slots"],
                "resources": zone["resource_slots"],
                "ash_volumes": zone["ash_volumes"],
                "shortcuts": len(zone["shortcut_slots"]),
                "campfire": bool(zone.get("campfire", False)),
                "boss": zone.get("boss"),
            },
            "output": f"assets/3d/ashlands/zones/{zone_id}",
            "approval_gates": handoff["approval_gates"],
        })
    return {
        "version": 1,
        "source": "pre_blender_contracts",
        "export_format": handoff["export"]["format"],
        "jobs": jobs,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if the tracked plan is stale")
    args = parser.parse_args()
    rendered = json.dumps(build_plan(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != rendered:
            print("FAIL - ashlands_blender_jobs.json is stale")
            return 1
        print("PASS - Blender production jobs are current")
        return 0
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
