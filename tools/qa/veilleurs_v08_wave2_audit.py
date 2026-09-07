#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V06 = ROOT / "data" / "veilleurs" / "v06"
V07 = ROOT / "data" / "veilleurs" / "v07"
V08 = ROOT / "data" / "veilleurs" / "v08"

DOCTRINES = V08 / "enemy_doctrines_24.json"
PROFILE_FILE = V07 / "enemy_skill_profiles.json"
ROADMAP_FILE = V07 / "dungeon_roadmap.json"
ENEMIES_FILE = V06 / "enemies_24_definitions.json"

REQUIRED_RUNTIME_FILES = [
    ROOT / "scripts" / "core" / "veilleurs_enemy_doctrine_runtime.gd",
    ROOT / "scripts" / "core" / "veilleurs_enemy_skill_selector_v2.gd",
    ROOT / "scripts" / "core" / "veilleurs_remanence_combat_bridge_v08.gd",
    ROOT / "scripts" / "core" / "veilleurs_boss_director_v08.gd",
    ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime_v08.gd",
    ROOT / "scripts" / "core" / "veilleurs_authored_encounter_runtime_v08.gd",
    ROOT / "scripts" / "core" / "veilleurs_vertical_slice_runtime_v08.gd",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    for path in [DOCTRINES, PROFILE_FILE, ROADMAP_FILE, ENEMIES_FILE]:
        if not path.is_file():
            errors.append(f"missing:{path.relative_to(ROOT)}")
    for path in REQUIRED_RUNTIME_FILES:
        if not path.is_file():
            errors.append(f"missing_runtime:{path.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("FAIL", error)
        return 1

    doctrines = load(DOCTRINES)
    profiles = load(PROFILE_FILE).get("profiles", {})
    roadmap = load(ROADMAP_FILE)
    enemy_rows = load(ENEMIES_FILE).get("enemies", [])
    enemy_ids = {str(row.get("entity_id", "")) for row in enemy_rows}
    doctrine_rows = doctrines.get("enemies", {})

    if doctrines.get("schema_version") != "0.8.0":
        errors.append("schema_version")
    if len(enemy_ids) != 24:
        errors.append(f"enemy_count:{len(enemy_ids)}")
    if set(doctrine_rows) != enemy_ids:
        missing = sorted(enemy_ids - set(doctrine_rows))
        extra = sorted(set(doctrine_rows) - enemy_ids)
        errors.append(f"doctrine_partition:missing={missing}:extra={extra}")
    stages = doctrines.get("stage_modifiers", {})
    if set(stages) != {"normal", "memorial", "veteran", "elite", "nemesis"}:
        errors.append(f"stage_modifiers:{sorted(stages)}")

    used_profiles: set[str] = set()
    for enemy_id, row in doctrine_rows.items():
        if not str(row.get("doctrine", "")).strip():
            errors.append(f"doctrine_name:{enemy_id}")
        preferred = row.get("preferred_profiles", [])
        if not isinstance(preferred, list) or len(preferred) < 3:
            errors.append(f"preferred_profiles:{enemy_id}")
            continue
        used_profiles.update(map(str, preferred))
        priorities = row.get("target_priority", [])
        if not isinstance(priorities, list) or len(priorities) < 3:
            errors.append(f"target_priority:{enemy_id}")
        retreat = float(row.get("retreat_hp_ratio", -1.0))
        if not 0.0 <= retreat <= 0.35:
            errors.append(f"retreat_hp_ratio:{enemy_id}:{retreat}")

    unknown_profiles = sorted(profile for profile in used_profiles if profile not in profiles)
    if unknown_profiles:
        errors.append(f"unknown_profiles:{unknown_profiles}")

    dungeons = roadmap.get("dungeons", [])
    ids = [str(row.get("dungeon_id", "")) for row in dungeons]
    if len(ids) != 6 or len(set(ids)) != 6:
        errors.append(f"dungeons:{ids}")
    if roadmap.get("production_order") != ids:
        errors.append("production_order")

    obsolete_tokens = ["ENT_WATCHER_NAYRA", "ENT_WATCHER_TAREK", "ENT_WATCHER_AISHA", "ENT_WATCHER_IDRIS"]
    active_wave2_text = "\n".join(path.read_text(encoding="utf-8") for path in REQUIRED_RUNTIME_FILES)
    for token in obsolete_tokens:
        if token in active_wave2_text:
            errors.append(f"obsolete_watcher_in_wave2:{token}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V08_WAVE2_AUDIT_FAILED: {len(errors)}")
        return 1
    print(
        "VEILLEURS_V08_WAVE2_AUDIT_OK: "
        f"enemies={len(enemy_ids)} doctrines={len(doctrine_rows)} "
        f"profiles={len(used_profiles)} dungeons={len(ids)} runtimes={len(REQUIRED_RUNTIME_FILES)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
