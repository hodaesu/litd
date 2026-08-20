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
]


def build_report(root: Path = ROOT) -> dict:
    roadmap = json.loads((root / "data/demo_roadmap.json").read_text(encoding="utf-8"))
    static_ready = all((root / path.relative_to(ROOT)).exists() for path in AUDIT_FILES)
    phases = []
    for phase in roadmap["phases"]:
        requires_pc = bool(phase.get("requires_pc", False))
        if phase["id"] == "P0_prepc_locked":
            status = "ready" if static_ready else "blocked"
            blockers = [] if static_ready else ["missing_static_contract"]
        elif requires_pc:
            status = "awaiting_pc_validation"
            blockers = list(phase.get("exit_gate", []))
        else:
            status = "planned"
            blockers = list(phase.get("exit_gate", []))
        phases.append({"id": phase["id"], "status": status, "blockers": blockers})
    return {
        "version": 1,
        "milestone": roadmap["milestone"],
        "static_prepc_ready": static_ready,
        "current_phase": "P1_vertical_slice_pc" if static_ready else "P0_prepc_locked",
        "phases": phases,
        "truth_rule": "PC-only visual, animation and performance gates are never marked complete by this report.",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "reports/demo_readiness.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    report = build_report(ROOT)
    if args.check:
        if not report["static_prepc_ready"]:
            print("DEMO_PREPC_READINESS_BLOCKED")
            return 1
        print("DEMO_PREPC_READINESS_OK current_phase=P1_vertical_slice_pc")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
