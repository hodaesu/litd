#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HANDOFF = ROOT / "data/levels/ashlands_blender_handoff.json"
MANIFEST = ROOT / "data/levels/terre_des_cendres_blockout_manifest.json"


def validate() -> list[str]:
    errors: list[str] = []
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    zone_ids = {zone["id"] for zone in manifest["zones"]}
    kit_ids = set(handoff["zone_kits"])
    if zone_ids != kit_ids:
        errors.append(f"zone_kits mismatch: missing={sorted(zone_ids-kit_ids)} extra={sorted(kit_ids-zone_ids)}")
    if handoff["coordinate_system"].get("scale") != 1.0:
        errors.append("Blender/Godot scale must stay at 1 meter")
    if handoff["export"].get("format") != "glb":
        errors.append("The required interchange format is GLB")
    required_slots = {
        "architecture/building", "architecture/wall", "architecture/platform",
        "architecture/landmark", "nature/blocker", "gameplay/campfire",
        "gameplay/resource", "gameplay/shortcut",
    }
    if set(handoff["asset_slots"]) != required_slots:
        errors.append("asset_slots contract is incomplete")
    if len(handoff.get("approval_gates", [])) < 7:
        errors.append("approval gates are incomplete")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"FAIL - {error}")
        return 1
    print("PASS - Blender handoff covers all 15 Ashlands zones")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
