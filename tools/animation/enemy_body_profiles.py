#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILES = ROOT / "data" / "enemy_body_profiles.json"
ENEMIES = ROOT / "data" / "enemies.json"

REQUIRED_PROFILE = {
    "enemy_id", "owner", "name", "archetype", "temperament", "asymmetry",
    "tactical_role", "tempo_scale", "phase_offset", "boss",
    "capture_compatible", "signature_key",
}

def load():
    return (
        json.loads(PROFILES.read_text(encoding="utf-8")),
        json.loads(ENEMIES.read_text(encoding="utf-8")),
    )

def audit(data, enemies):
    errors = []
    profiles = data.get("profiles", [])
    if len(profiles) != len(enemies):
        errors.append(f"{len(profiles)} profiles for {len(enemies)} enemies")
    signatures = [item.get("signature_key") for item in profiles]
    if len(signatures) != len(set(signatures)):
        errors.append("enemy body signatures are not unique")
    expected_ids = {int(item["id"]) for item in enemies}
    actual_ids = {int(item.get("enemy_id", -1)) for item in profiles}
    if actual_ids != expected_ids:
        errors.append("enemy profile ids do not match enemies.json")
    archetypes = data.get("archetypes", {})
    temperaments = data.get("temperaments", {})
    roles = data.get("tactical_roles", {})
    for profile in profiles:
        missing = REQUIRED_PROFILE - set(profile)
        if missing:
            errors.append(f"{profile.get('owner')} missing {sorted(missing)}")
        enemy_id = int(profile.get("enemy_id", 0))
        expected_owner = f"enemy_{enemy_id:02d}"
        if profile.get("owner") != expected_owner:
            errors.append(f"{expected_owner} has invalid owner")
        if profile.get("archetype") not in archetypes:
            errors.append(f"{expected_owner} unknown archetype")
        if profile.get("temperament") not in temperaments:
            errors.append(f"{expected_owner} unknown temperament")
        if profile.get("tactical_role") not in roles:
            errors.append(f"{expected_owner} unknown tactical role")
        phase = float(profile.get("phase_offset", -1))
        if not 0 <= phase < 1:
            errors.append(f"{expected_owner} invalid phase offset")
        source = next((x for x in enemies if int(x["id"]) == enemy_id), None)
        if source and bool(source.get("boss", False)) != bool(profile.get("boss", False)):
            errors.append(f"{expected_owner} boss flag mismatch")
        if profile.get("boss") and profile.get("capture_compatible"):
            errors.append(f"{expected_owner} boss cannot be capture compatible")
    if len(archetypes) < 10:
        errors.append("not enough morphology archetypes")
    if len(temperaments) < 8:
        errors.append("not enough temperaments")
    if len(set(profile.get("tactical_role") for profile in profiles)) < 15:
        errors.append("not enough tactical posture roles")
    rules = data.get("rules", {})
    for key in ("unique_signature_per_enemy", "deterministic_phase_offset", "captured_enemy_keeps_signature", "bosses_never_use_generic_idle"):
        if rules.get(key) is not True:
            errors.append(f"missing diversity rule: {key}")
    return errors

def report(data):
    profiles = data["profiles"]
    return {
        "profiles": len(profiles),
        "unique_signatures": len({x["signature_key"] for x in profiles}),
        "archetypes": dict(Counter(x["archetype"] for x in profiles)),
        "temperaments": dict(Counter(x["temperament"] for x in profiles)),
        "roles": dict(Counter(x["tactical_role"] for x in profiles)),
    }

def main():
    data, enemies = load()
    errors = audit(data, enemies)
    if errors:
        print("\n".join(errors))
        return 1
    stats = report(data)
    print(f"ENEMY_BODY_DIVERSITY_OK: {stats['profiles']} unique profiles, {len(stats['archetypes'])} archetypes")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
