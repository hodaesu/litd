#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V06 = ROOT / "data" / "veilleurs" / "v06"
V08 = ROOT / "data" / "veilleurs" / "v08"
CANONICAL = {
    "ENT_WATCHER_NAYRA": "Nayra Orun",
    "ENT_WATCHER_TAREK": "Tarek Senn",
    "ENT_WATCHER_AISHA": "Aïsha Maren",
    "ENT_WATCHER_IDRIS": "Idris Vael",
}
OBSOLETE = ["ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA"]
ACTIVE_RUNTIME_FILES = [
    V06 / "watchers.json",
    V06 / "starter_loadouts_watchers.json",
    V06 / "watcher_tree_catalog.json",
    ROOT / "scripts" / "core" / "content_db.gd",
    ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime.gd",
    ROOT / "scripts" / "core" / "veilleurs_content_db_v081_canonical.gd",
    ROOT / "scripts" / "core" / "veilleurs_content_db_v07_runtime.gd",
    ROOT / "scripts" / "core" / "veilleurs_campaign_runtime_v07.gd",
    V08 / "canonical_watcher_ultimates_12.json",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    watchers = load(V06 / "watchers.json").get("watchers", [])
    ids = {str(row.get("entity_id", "")) for row in watchers}
    if ids != set(CANONICAL):
        errors.append(f"watcher_ids:{sorted(ids)}")
    for row in watchers:
        entity_id = str(row.get("entity_id", ""))
        if str(row.get("name_fr", "")) != CANONICAL.get(entity_id, ""):
            errors.append(f"watcher_name:{entity_id}:{row.get('name_fr')}")

    manifest = load(V06 / "watcher_tree_catalog.json")
    if manifest.get("unlock_levels") != [1,4,7,10,13,16,19,22,25,28,31,35,39,44,49]:
        errors.append("watcher_unlock_schedule")
    if manifest.get("tree_count") != 12 or manifest.get("skill_count") != 180:
        errors.append("watcher_manifest_counts")

    ultimate_payload = load(V08 / "canonical_watcher_ultimates_12.json")
    rows = ultimate_payload.get("ultimates", [])
    if ultimate_payload.get("count") != 12 or len(rows) != 12:
        errors.append("canonical_ultimate_count")
    partitions = {entity_id: [] for entity_id in CANONICAL}
    for row in rows:
        entity_id = str(row.get("entity_id", ""))
        if entity_id not in partitions:
            errors.append(f"canonical_ultimate_owner:{entity_id}")
            continue
        partitions[entity_id].append(row)
        if row.get("profile") != "canonical_resolver_required" or row.get("resolver_required") is not True:
            errors.append(f"generic_watcher_ultimate:{row.get('ultimate_id')}")
        if row.get("charges_by_level") != {"16":1,"32":2,"48":3}:
            errors.append(f"ultimate_charges:{row.get('ultimate_id')}")
    for entity_id, values in partitions.items():
        if len(values) != 3 or sorted(int(v.get("tree_slot", 0)) for v in values) != [1,2,3]:
            errors.append(f"ultimate_partition:{entity_id}")

    for path in ACTIVE_RUNTIME_FILES:
        if not path.is_file():
            errors.append(f"missing_active_file:{path.relative_to(ROOT)}")
            continue
        text = path.read_text(encoding="utf-8")
        for token in OBSOLETE:
            if token in text:
                errors.append(f"obsolete_active_token:{path.relative_to(ROOT)}:{token}")

    ultimate_runtime = (ROOT / "scripts" / "core" / "veilleurs_ultimate_runtime.gd").read_text(encoding="utf-8")
    compact = ultimate_runtime.replace(" ", "")
    if 'reason":"ultimate_resolver_required"' not in compact:
        errors.append("generic_ultimate_guard_missing")
    if 'charge_spent":false' not in compact:
        errors.append("generic_ultimate_charge_guard_missing")

    overlay = (ROOT / "scripts" / "core" / "veilleurs_content_db_v081_canonical.gd").read_text(encoding="utf-8")
    if 'begins_with("ENT_WATCHER_")' not in overlay or "canonical_watcher_ultimates_12.json" not in overlay:
        errors.append("production_overlay_contract")

    campaign = (ROOT / "scripts" / "core" / "veilleurs_campaign_runtime_v07.gd").read_text(encoding="utf-8")
    for entity_id in CANONICAL:
        if entity_id not in campaign:
            errors.append(f"campaign_missing:{entity_id}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V081_CANONICAL_PRODUCTION_AUDIT_FAILED: {len(errors)}")
        return 1
    print("VEILLEURS_V081_CANONICAL_PRODUCTION_AUDIT_OK: quartet=4 skills=180 watcher_ultimates=12 legacy_quartet_active=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
