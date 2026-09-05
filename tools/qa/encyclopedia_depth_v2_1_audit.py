from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LORE = ROOT / "universe" / "lore"


def load(name: str) -> dict:
    return json.loads((LORE / name).read_text(encoding="utf-8"))


def run() -> dict:
    district = load("city_district_history_v2.json")
    foreign = load("late_foreign_microhistory_v2.json")
    daily = load("regional_daily_life_v2_1.json")
    manifest = load("encyclopedia_depth_v2_1_manifest.json")
    npc_data = load("living_world_npcs_microhistory.json")

    errors: list[str] = []
    warnings: list[str] = []

    cities = district.get("cities", [])
    if len(cities) != 6:
        errors.append(f"districts: expected 6 cities, got {len(cities)}")

    districts = [d for city in cities for d in city.get("districts", [])]
    if len(districts) != 36:
        errors.append(f"districts: expected 36 districts, got {len(districts)}")
    for city in cities:
        if len(city.get("districts", [])) != 6:
            errors.append(f"districts: {city.get('id')} must contain exactly 6 districts")

    npc_ids = {n.get("id") for n in npc_data.get("npcs", [])}
    linked = [npc for d in districts for npc in d.get("linked_npcs", [])]
    if len(linked) != 48 or len(set(linked)) != 48:
        errors.append(f"districts: expected 48 unique linked NPCs, got {len(linked)} refs / {len(set(linked))} unique")
    missing_npcs = sorted(set(linked) - npc_ids)
    if missing_npcs:
        errors.append(f"districts: unknown NPC refs: {missing_npcs}")

    district_rules = district.get("rules", {})
    for key in ["district_is_single_class", "district_is_single_language", "district_name_is_eternal"]:
        if district_rules.get(key) is not False:
            errors.append(f"districts: guardrail {key} must be false")
    if district.get("litd2_status") != "paused_no_retrojection_of_mature_district_forms":
        errors.append("districts: LITD2 pause/retrojection guardrail missing")

    polities = foreign.get("polities", [])
    expected_polities = {"late_varkhane", "late_namar", "late_azravel", "late_kor_em"}
    if {p.get("id") for p in polities} != expected_polities:
        errors.append("foreign: late polity IDs must be the four guarded IDs")
    if sum(len(p.get("cities", [])) for p in polities) != 16:
        errors.append("foreign: expected 16 major cities")
    if sum(len(p.get("events", [])) for p in polities) != 16:
        errors.append("foreign: expected 16 microhistory events")

    rules = foreign.get("core_rules", {})
    if rules.get("horizon_pact_is_single_cause_of_fall") is not False:
        errors.append("foreign: Horizon Pact must not be the single cause of the Fall")
    if rules.get("project_threshold_has_distributed_causality") is not True:
        errors.append("foreign: distributed Project Threshold causality missing")
    if rules.get("late_namar_equals_last_war_namar") != "unresolved":
        errors.append("foreign: late Namar continuity must remain unresolved")
    if rules.get("late_azravel_equals_last_war_azravel") != "unresolved":
        errors.append("foreign: late Azravel continuity must remain unresolved")
    if rules.get("collective_guilt_by_origin") is not False:
        errors.append("foreign: collective guilt guardrail missing")
    if foreign.get("litd2_status") != "paused_no_new_litd2_narrative":
        errors.append("foreign: LITD2 must remain paused")

    expected_daily = {
        "satellite_settlements": 18,
        "trades": 24,
        "everyday_objects": 30,
        "quest_bridges": 18,
    }
    for key, expected in expected_daily.items():
        actual = len(daily.get(key, []))
        if actual != expected:
            errors.append(f"daily: {key} expected {expected}, got {actual}")
    if daily.get("litd2_status") != "paused_no_new_litd2_narrative":
        errors.append("daily: LITD2 must remain paused")

    if manifest.get("depth_v2_1_complete") is not True:
        errors.append("manifest: depth_v2_1_complete must be true")
    if manifest.get("canon_version") != "1.1.0":
        errors.append("manifest: V2.1 extension must remain canon version 1.1.0")
    counts = manifest.get("counts", {})
    checks = {
        "concorde_cities": 6,
        "city_districts": 36,
        "existing_npcs_linked_to_districts": 48,
        "late_foreign_polities": 4,
        "late_foreign_major_cities": 16,
        "late_foreign_microhistory_events": 16,
        "satellite_settlements": 18,
        "trades": 24,
        "everyday_objects": 30,
        "quest_bridges": 18,
    }
    for key, expected in checks.items():
        if counts.get(key) != expected:
            errors.append(f"manifest: {key} expected {expected}, got {counts.get(key)}")

    return {"ok": not errors, "errors": errors, "warnings": warnings, "counts": checks}


def main() -> int:
    report = run()
    if report["ok"]:
        print("Encyclopedia depth V2.1 audit: PASS")
        for key, value in report["counts"].items():
            print(f"- {key}: {value}")
        return 0
    print("Encyclopedia depth V2.1 audit: FAIL")
    for error in report["errors"]:
        print(f"ERROR: {error}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
