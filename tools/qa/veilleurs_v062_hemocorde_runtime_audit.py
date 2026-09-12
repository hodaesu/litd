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
CURRENT_CONTRACT = ROOT / "data/veilleurs/current_quartet_ultimate_sheets.json"

EXPECTED_CURRENT = {
    "mathilde": ["Cœur inébranlable", "Katana éternel", "Volonté transcendante"],
    "marec": ["Force primordiale", "Instinct parfait", "Légende vivante"],
    "anouk": ["Trame absolue", "Esprit transcendant", "Ange de la Trame"],
    "aurelien": ["Réminiscence du Sang", "Miroir du Jugement", "Réforme éternelle"],
}


def main() -> int:
    errors: list[str] = []
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing:{name}:{path}")
    if not CURRENT_CONTRACT.is_file():
        errors.append(f"missing:current_contract:{CURRENT_CONTRACT}")
    if errors:
        for error in errors:
            print("FAIL", error)
        return 1

    source = {name: path.read_text(encoding="utf-8") for name, path in FILES.items() if path.suffix == ".gd"}
    isolated = source["ultimate_state"] + source["hemocorde"] + source["runtime"] + source["authored"] + source["session"] + source["dungeon"]
    for forbidden in ["GameState", "ExpeditionManager", "AnatomyRuntime", "InjuryRuntime"]:
        if forbidden in isolated:
            errors.append(f"legacy_dependency:{forbidden}")

    # Hemocorde is retained only as an isolated historical/prototype resolver.
    # It must never be used as the authority for the current quartet identities.
    legacy_tokens = [
        'BRANCH := "hemocorde"',
        'ULTIMATE_NAME := "Le Dernier Battement"',
        '"vascular_known_zones"',
        '"CIRCULATORY_COLLAPSE"',
    ]
    for token in legacy_tokens:
        if token not in source["hemocorde"]:
            errors.append(f"legacy_hemocorde_contract_missing:{token}")

    required_state = [
        "level >= 16",
        "level >= 32",
        "level >= 48",
        '"ultimate_already_used_this_encounter"',
        '"encounters_used"',
    ]
    for token in required_state:
        if token not in source["ultimate_state"]:
            errors.append(f"charge_state:{token}")

    contract = json.loads(CURRENT_CONTRACT.read_text(encoding="utf-8"))
    if contract.get("status") != "CURRENT_QUARTET_AUTHORED_IDENTITY_LOCK":
        errors.append("current_contract_status")
    if contract.get("charge_progression") != {"16": 1, "32": 2, "48": 3}:
        errors.append("current_charge_progression")

    heroes = contract.get("heroes", [])
    actual_ids = {str(hero.get("hero_id", "")) for hero in heroes}
    if actual_ids != set(EXPECTED_CURRENT):
        errors.append(f"current_quartet_ids:{sorted(actual_ids)}")

    ultimate_count = 0
    for hero in heroes:
        hero_id = str(hero.get("hero_id", ""))
        ultimates = hero.get("ultimates", [])
        names = [str(row.get("name", "")) for row in ultimates]
        if names != EXPECTED_CURRENT.get(hero_id, []):
            errors.append(f"current_ultimate_names:{hero_id}:{names}")
        for row in ultimates:
            ultimate_count += 1
            if row.get("identity_locked") is not True:
                errors.append(f"identity_not_locked:{hero_id}:{row.get('name')}")
            if row.get("runtime_effect_status") != "PENDING_RESOLVER_BINDING":
                errors.append(f"legacy_effect_rebound:{hero_id}:{row.get('name')}")
    if ultimate_count != 12:
        errors.append(f"current_ultimate_count:{ultimate_count}")

    serialized = json.dumps(contract, ensure_ascii=False)
    if "Le Dernier Battement" in serialized or "aisha_maren" in serialized:
        errors.append("legacy_hemocorde_leaked_into_current_authority")

    smoke = source["smoke"]
    for token in [
        "charges_for_level(16) == 1",
        "charges_for_level(32) == 2",
        "charges_for_level(48) == 3",
        "PENDING_RESOLVER_BINDING",
        "legacy Hemocorde ultimate is not rebound into the current quartet",
    ]:
        if token not in smoke:
            errors.append(f"smoke_guardrail:{token}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V062_HEMOCORDE_RUNTIME_AUDIT_FAILED: {len(errors)}")
        return 1

    print("VEILLEURS_V062_HEMOCORDE_RUNTIME_AUDIT_OK: legacy resolver isolated; current quartet identity lock authoritative")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
