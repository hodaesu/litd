#!/usr/bin/env python3
"""Generate a deterministic demo-readiness report without pretending PC-only gates are validated."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROADMAP = ROOT / "data/demo_roadmap.json"
AUDIT_FILES = [
    ROOT / "data/visual_slice_choreography.json",
    ROOT / "data/visual_slice_animation_specs.json",
    ROOT / "data/visual_slice_presentation.json",
    ROOT / "data/demo_content_pack.json",
    ROOT / "data/demo_balance_targets.json",
    ROOT / "data/final_ui_contract.json",
    ROOT / "data/demo_roadmap.json",
    ROOT / "data/voice_direction_contract.json",
    ROOT / "data/emotional_voice_profiles.json",
    ROOT / "data/voice_emotion_calibration.json",
    ROOT / "data/voice_acting_contract.json",
    ROOT / "data/voice_acting_study_protocol.json",
    ROOT / "data/dramatic_voice_overrides.json",
    ROOT / "data/physical_bible.json",
    ROOT / "data/nonverbal_language_contract.json",
    ROOT / "data/relationship_proxemics.json",
    ROOT / "data/cinematic_grammar.json",
    ROOT / "data/demo_cinematic_blocking.json",
    ROOT / "data/staging_study_protocol.json",
]


def build_report(root: Path = ROOT) -> dict:
    roadmap = json.loads((root / "data/demo_roadmap.json").read_text(encoding="utf-8"))
    resolved = [root / path.relative_to(ROOT) for path in AUDIT_FILES]
    missing = [path.relative_to(root).as_posix() for path in resolved if not path.exists()]
    static_ready = not missing
    phases = []
    for phase in roadmap["phases"]:
        requires_pc = bool(phase.get("requires_pc", False))
        if phase["id"] == "P0_prepc_locked":
            status = "ready" if static_ready else "blocked"
            blockers = [] if static_ready else ["missing_static_contract", *missing]
        elif requires_pc:
            status = "awaiting_pc_validation"
            blockers = list(phase.get("exit_gate", []))
        else:
            status = "planned"
            blockers = list(phase.get("exit_gate", []))
        phases.append({"id": phase["id"], "status": status, "blockers": blockers})
    return {
        "version": 2,
        "milestone": roadmap["milestone"],
        "static_prepc_ready": static_ready,
        "static_contract_count": len(AUDIT_FILES),
        "missing_static_contracts": missing,
        "current_phase": "P1_vertical_slice_pc" if static_ready else "P0_prepc_locked",
        "phases": phases,
        "truth_rule": "PC-only visual, animation, staging, voice-listening and device-performance gates are never marked complete by this report.",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "reports/demo_readiness.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    report = build_report(ROOT)
    if args.check:
        if not report["static_prepc_ready"]:
            print("DEMO_PREPC_READINESS_BLOCKED " + ",".join(report["missing_static_contracts"]))
            return 1
        print(
            "DEMO_PREPC_READINESS_OK "
            f"contracts={report['static_contract_count']} current_phase=P1_vertical_slice_pc"
        )
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
