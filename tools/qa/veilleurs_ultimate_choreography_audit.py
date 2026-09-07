from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data" / "veilleurs" / "ultimate_choreography_contract.json"
CANON = ROOT / "data" / "veilleurs" / "skills"
SOURCES = {
    "nayra_orun": "nayra_orun.json",
    "tarek_senn": "tarek_senn.json",
    "aisha_maren": "aisha_maren.json",
    "idris_vael": "idris_vael.json",
}
EXPECTED_BRANCHES = {
    "nayra_orun": ["bastion", "brisure", "serment"],
    "tarek_senn": ["traque", "entaille", "disparition"],
    "aisha_maren": ["anatomie", "suture", "hemocorde"],
    "idris_vael": ["sentence", "concorde", "dissidence"],
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_ultimates() -> dict[str, str]:
    result: dict[str, str] = {}
    for watcher_id, filename in SOURCES.items():
        payload = load(CANON / filename)
        order = payload.get("tree_order", [])
        if order != EXPECTED_BRANCHES[watcher_id]:
            raise AssertionError(f"tree_order:{watcher_id}:{order}")
        for branch in order:
            ultimate = payload.get("trees", {}).get(branch, {}).get("ultimate", {})
            result[f"{watcher_id}:{branch}"] = str(ultimate.get("name", ""))
    return result


def main() -> int:
    errors: list[str] = []
    if not CONTRACT_PATH.is_file():
        print("VEILLEURS_ULTIMATE_CHOREOGRAPHY_AUDIT_FAILED: missing_contract")
        return 1
    contract = load(CONTRACT_PATH)
    rules = contract.get("rules", {})
    rows = contract.get("ultimates", {})
    expected = canonical_ultimates()

    if int(contract.get("schema_version", 0)) < 2:
        errors.append("schema_version<2")
    if set(rows) != set(expected):
        errors.append(f"ultimate_keys:{sorted(rows)}")
    if rules.get("charges_by_level") != {"16": 1, "32": 2, "48": 3}:
        errors.append("charges_by_level")
    if int(rules.get("max_same_ultimate_per_encounter", 0)) != 1:
        errors.append("encounter_limit")
    if rules.get("consume_charge_policy") != "first_authoritative_effect_successfully_applied":
        errors.append("charge_commit_policy")
    for flag in ["presentation_never_decides_gameplay", "no_free_invulnerability", "no_resurrection", "body_state_remains_causal"]:
        if rules.get(flag) is not True:
            errors.append(f"rule:{flag}")
    if rules.get("short_mode_changes_mechanics") is not False:
        errors.append("short_mode_changes_mechanics")
    required_access = {"reduced_motion", "no_screen_shake", "haptics_off", "reduced_gore", "short_ultimate_mode"}
    if not required_access.issubset(set(rules.get("accessibility", []))):
        errors.append("accessibility")

    for key, canonical_name in expected.items():
        row = rows.get(key, {})
        if row.get("name") != canonical_name or not canonical_name:
            errors.append(f"name:{key}:{row.get('name')}:{canonical_name}")
        full = float(row.get("full_duration_s", 0.0))
        short = float(row.get("short_duration_s", 0.0))
        if not (2.0 <= full <= 4.5):
            errors.append(f"full_duration:{key}:{full}")
        if not (1.0 <= short <= 2.1 and short < full):
            errors.append(f"short_duration:{key}:{short}")
        states = row.get("states", [])
        if not isinstance(states, list) or len(states) < 4 or len(states) != len(set(states)):
            errors.append(f"states:{key}")
            continue
        commit = str(row.get("charge_commit_state", ""))
        resolves = row.get("authoritative_resolve_states", [])
        if commit not in states:
            errors.append(f"commit_state_not_in_sequence:{key}:{commit}")
        if commit not in resolves:
            errors.append(f"commit_state_not_authoritative:{key}:{commit}")
        if not resolves or any(state not in states for state in resolves):
            errors.append(f"authoritative_states:{key}")
        if not str(row.get("signature", "")).strip():
            errors.append(f"signature:{key}")
        if not str(row.get("camera", "")).strip():
            errors.append(f"camera:{key}")
        if not row.get("audio"):
            errors.append(f"audio:{key}")
        if not str(row.get("haptics", "")).strip():
            errors.append(f"haptics:{key}")
        if not row.get("variants"):
            errors.append(f"variants:{key}")

    # Identity-specific semantic anchors protect each signature from collapsing into a generic cinematic.
    anchors = {
        "nayra_orun:bastion": ("ULTIMATE_INTERCEPT_RESOLVE", "multi_real_impacts"),
        "nayra_orun:brisure": ("ULTIMATE_COLLISION", "mass_ramp_then_collision"),
        "nayra_orun:serment": ("ULTIMATE_RESCUE_WINDOW", "wounded_breath_and_shield_reposition"),
        "tarek_senn:traque": ("ULTIMATE_RESOLVE", "confirmed_clues_reconnect"),
        "tarek_senn:entaille": ("ULTIMATE_CHAIN", "conditional_staccato_hits"),
        "tarek_senn:disparition": ("ULTIMATE_CERTAINTY_RESOLVE", "old_position_empty_and_missing_steps"),
        "aisha_maren:anatomie": ("ULTIMATE_PARTY_READ", "observable_body_signs_shared"),
        "aisha_maren:suture": ("ULTIMATE_INTERVENTIONS", "triage_gestures_and_stabilized_breath"),
        "aisha_maren:hemocorde": ("ULTIMATE_SILENCE", "silence_then_heartbeat"),
        "idris_vael:sentence": ("ULTIMATE_REORDER", "staff_strike_and_timeline_reorder"),
        "idris_vael:concorde": ("ULTIMATE_ACTOR_4_RESOLVE", "one_shared_rhythm_four_real_actions"),
        "idris_vael:dissidence": ("ULTIMATE_BREAK_LINKS", "enemy_collective_rhythm_desynchronizes"),
    }
    for key, (state, signature) in anchors.items():
        row = rows.get(key, {})
        if state not in row.get("states", []):
            errors.append(f"signature_state:{key}:{state}")
        if row.get("signature") != signature:
            errors.append(f"signature_value:{key}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_ULTIMATE_CHOREOGRAPHY_AUDIT_FAILED: {len(errors)}")
        return 1
    print("VEILLEURS_ULTIMATE_CHOREOGRAPHY_AUDIT_OK: ultimates=12 names=12 commit_states=12 accessibility=5")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
