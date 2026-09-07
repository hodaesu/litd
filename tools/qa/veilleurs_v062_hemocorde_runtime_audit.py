from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = {
    "ultimate_state": ROOT / "scripts/core/veilleurs_ultimate_state_runtime.gd",
    "hemocorde": ROOT / "scripts/core/veilleurs_hemocorde_ultimate_runtime_v2.gd",
    "runtime": ROOT / "scripts/core/veilleurs_tactical_combat_runtime_v062.gd",
    "authored": ROOT / "scripts/core/veilleurs_authored_encounter_runtime_v062.gd",
    "session": ROOT / "scripts/core/veilleurs_tactical_session_v062.gd",
    "dungeon": ROOT / "scripts/core/veilleurs_dungeon_slice_runtime_v062.gd",
    "smoke": ROOT / "scripts/core/veilleurs_v062_hemocorde_ultimate_smoke_test.gd",
    "scene": ROOT / "scenes/tests/veilleurs_v062_hemocorde_ultimate_smoke.tscn",
}
CONTRACT = ROOT / "data/veilleurs/ultimate_choreography_contract.json"


def main() -> int:
    errors: list[str] = []
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing:{name}:{path}")
    if errors:
        for error in errors:
            print("FAIL", error)
        return 1

    source = {name: path.read_text(encoding="utf-8") for name, path in FILES.items() if path.suffix == ".gd"}
    isolated = source["ultimate_state"] + source["hemocorde"] + source["runtime"] + source["authored"] + source["session"] + source["dungeon"]
    for forbidden in ["GameState", "ExpeditionManager", "AnatomyRuntime", "InjuryRuntime"]:
        if forbidden in isolated:
            errors.append(f"legacy_dependency:{forbidden}")

    required_hemocorde = [
        'AISHA_ID := "ENT_WATCHER_AISHA"',
        'BRANCH := "hemocorde"',
        'ULTIMATE_NAME := "Le Dernier Battement"',
        '"vascular_known_zones"',
        '"circulatory_shock"',
        '"hemorrhage_risk"',
        '"open_wound_count"',
        '"CIRCULATORY_COLLAPSE"',
        '"ULTIMATE_RESOLVE"',
        '"boss_floor_applied"',
    ]
    for token in required_hemocorde:
        if token not in source["hemocorde"]:
            errors.append(f"hemocorde_contract:{token}")

    required_state = [
        '"16"' if False else "level >= 16",
        "level >= 32",
        "level >= 48",
        '"ultimate_already_used_this_encounter"',
        '"encounters_used"',
    ]
    for token in required_state:
        if token not in source["ultimate_state"]:
            errors.append(f"charge_state:{token}")

    if "watcher_aftermath" not in source["session"] or "_apply_watcher_state" not in source["session"]:
        errors.append("session_watcher_state_bridge")
    if 'payload["watcher_state"]' not in source["dungeon"] or "watcher_state_persisted" not in source["dungeon"]:
        errors.append("dungeon_watcher_state_bridge")
    if "super.resolve_skill" not in source["runtime"] or "post_skill_result" not in source["runtime"]:
        errors.append("canonical_skill_to_hemocorde_bridge")
    if "VeilleursAuthoredEncounterRuntimeV062" not in source["authored"]:
        errors.append("authored_runtime_v062")

    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    row = contract.get("ultimates", {}).get("aisha_maren:hemocorde", {})
    if row.get("name") != "Le Dernier Battement":
        errors.append("contract_name")
    if row.get("charge_commit_state") != "ULTIMATE_RESOLVE":
        errors.append("contract_commit_state")
    if "ULTIMATE_RESOLVE" not in row.get("authoritative_resolve_states", []):
        errors.append("contract_authoritative_state")
    if contract.get("rules", {}).get("consume_charge_policy") != "first_authoritative_effect_successfully_applied":
        errors.append("contract_charge_policy")

    smoke = source["smoke"]
    for token in [
        "charges_for_level(16) == 1",
        "charges_for_level(32) == 2",
        "charges_for_level(48) == 3",
        "failed activation does not consume charge",
        "same ultimate cannot be used twice in one encounter",
        "ultimate charge survives save/load",
        "remaining charge is reusable in a different encounter",
        "boss survives decisive collapse",
    ]:
        if token not in smoke:
            errors.append(f"smoke_guardrail:{token}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V062_HEMOCORDE_RUNTIME_AUDIT_FAILED: {len(errors)}")
        return 1
    print("VEILLEURS_V062_HEMOCORDE_RUNTIME_AUDIT_OK: charge_state physiology tactical authored session dungeon smoke")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
