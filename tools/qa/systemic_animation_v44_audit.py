#!/usr/bin/env python3
"""Static audit for LITD systemic body-animation pipeline v44."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/blender/systemic_animation_v44.json"


def main() -> int:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert contract.get("version") == 44
    assert contract.get("gameplay_neutral") is True
    assert set(contract.get("state_contract", {})) == {"F0", "F1", "F2", "F3", "F4"}
    assert contract["equipment_adaptation"]["never_invent_missing_manipulators"] is True
    assert contract["validation"]["block_final_export_if_placeholder_action_remains"] is True

    from tools.blender.generate_systemic_animation_v44 import build_payload
    payload = build_payload(ROOT)
    assert payload.get("version") == 44
    jobs = payload.get("jobs", [])
    assert len(jobs) >= 4
    assert all(job.get("gameplay_neutral") is True for job in jobs)
    assert all(job.get("actions") for job in jobs)

    by_name = {str(job.get("name", "")): job for job in jobs}
    if "Ver des profondeurs" in by_name:
        assert by_name["Ver des profondeurs"]["morphology"] == "SERPENTINE_ORGANIC"
    if "Loup du Voile" in by_name:
        assert by_name["Loup du Voile"]["morphology"] == "QUADRUPED_ORGANIC"

    for job in jobs:
        names = {str(action["name"]) for action in job.get("actions", [])}
        assert "body_f0" in names
        assert "body_f1" in names
        assert "body_f2" in names
        for part in job.get("locomotion_parts", []):
            matching = [a for a in job.get("actions", []) if a.get("part") == part]
            assert matching
        if job.get("weapon_sockets"):
            for fallback in contract.get("one_hand_actions", []):
                assert fallback in names

    print(f"SYSTEMIC_ANIMATION_V44_AUDIT_OK jobs={len(jobs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
