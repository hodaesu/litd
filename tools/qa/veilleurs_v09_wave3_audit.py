#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data" / "veilleurs" / "v09" / "wave3_contract.json"
REQUIRED_FILES = [
    "scripts/core/veilleurs_nemesis_return_director_v09.gd",
    "scripts/core/veilleurs_remanence_combat_bridge_v09.gd",
    "scripts/core/veilleurs_boss_phase_runtime_v09.gd",
    "scripts/core/veilleurs_tactical_combat_runtime_v09.gd",
    "scripts/core/veilleurs_authored_encounter_runtime_v09.gd",
    "scripts/core/veilleurs_vertical_slice_runtime_v09.gd",
    "scripts/core/veilleurs_vertical_slice_save_v09.gd",
    "scripts/ui/veilleurs_vertical_slice_qa_v09.gd",
    "scenes/veilleurs/v09_vertical_slice_qa.tscn",
]
EXPECTED_DUNGEONS = {
    "DUNGEON_KHAR_SEN",
    "DUNGEON_SEUIL_ERODE",
    "DUNGEON_CLOITRE_VOIX",
    "DUNGEON_JARDIN_MUES",
    "DUNGEON_TRIBUNAL_CENDRES",
    "DUNGEON_ARCHIVES_AVEUGLES",
}
EXPECTED_BOSSES = {
    "ENT_BOSS_GARDIEN_SEUIL",
    "ENT_BOSS_CHOEUR_FENDU",
    "ENT_BOSS_MERE_MUES",
    "ENT_BOSS_JUGE_SANS_VISAGE",
    "ENT_BOSS_ARCHIVISTE_AVEUGLE",
}


def main() -> int:
    errors: list[str] = []
    if not CONTRACT.is_file():
        print("VEILLEURS_V09_WAVE3_AUDIT_FAILED: missing_contract")
        return 1
    payload = json.loads(CONTRACT.read_text(encoding="utf-8"))
    if payload.get("schema_version") != "0.9.0":
        errors.append("schema_version")
    nemesis = payload.get("nemesis_return", {})
    if nemesis.get("max_injected_per_encounter") != 1:
        errors.append("nemesis_cap")
    if set(nemesis.get("eligible_stages", [])) != {"elite", "nemesis"}:
        errors.append("nemesis_stages")
    if nemesis.get("boss_encounters_allowed") is not False:
        errors.append("nemesis_boss_exclusion")
    recruitment = payload.get("recruitment_decision", {})
    if recruitment.get("actions") != ["recruit", "spare", "leave"]:
        errors.append("recruitment_actions")
    if recruitment.get("max_candidates_presented") != 3:
        errors.append("recruitment_cap")
    phases = payload.get("boss_phases", {})
    if phases.get("thresholds_percent") != [70, 35] or phases.get("phases") != 3:
        errors.append("boss_phase_thresholds")
    if set(phases.get("bosses", {})) != EXPECTED_BOSSES:
        errors.append("boss_phase_owners")
    for boss_id, names in phases.get("bosses", {}).items():
        if len(names) != 3 or len(set(names)) != 3:
            errors.append(f"boss_phase_names:{boss_id}")
    vertical = payload.get("vertical_slice", {})
    if set(vertical.get("dungeon_ids", [])) != EXPECTED_DUNGEONS:
        errors.append("six_dungeons")
    if vertical.get("save_version") != "0.9.0":
        errors.append("save_version")
    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing:{relative}")

    runtime_text = (ROOT / "scripts/core/veilleurs_vertical_slice_runtime_v09.gd").read_text(encoding="utf-8")
    for marker in ["nemesis_director.inject_returning_enemy", "expedition_watcher_state", "resolve_recruitment_decision", "v09_pending_recruit_candidates"]:
        if marker not in runtime_text:
            errors.append(f"runtime_marker:{marker}")
    phase_text = (ROOT / "scripts/core/veilleurs_boss_phase_runtime_v09.gd").read_text(encoding="utf-8")
    for marker in ["PHASE_2_HP := 0.70", "PHASE_3_HP := 0.35", '"state":"telegraph"']:
        if marker not in phase_text:
            errors.append(f"phase_marker:{marker}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V09_WAVE3_AUDIT_FAILED: {len(errors)}")
        return 1
    print("VEILLEURS_V09_WAVE3_AUDIT_OK: dungeons=6 bosses=5 phases=3 nemesis_cap=1 recruit_actions=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
