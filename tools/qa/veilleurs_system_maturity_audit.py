#!/usr/bin/env python3
"""Audit du modèle de maturité des systèmes de LITD : Les Veilleurs."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data/veilleurs/system_maturity_registry.json"
PLAYER_CONTRACT = ROOT / "data/veilleurs/player_validation_contract.json"

EXPECTED_STAGES = (
    "implemented",
    "technically_validated",
    "player_validated",
    "mobile_validated",
    "production_locked",
)


def main() -> int:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    player_contract = json.loads(PLAYER_CONTRACT.read_text(encoding="utf-8"))

    assert data["schema_version"] == 1
    assert data["project"] == "LITD : Les Veilleurs"
    stages = data["stages"]
    assert tuple(stage["id"] for stage in stages) == EXPECTED_STAGES
    assert [stage["rank"] for stage in stages] == [1, 2, 3, 4, 5]

    rules = data["rules"]
    assert rules["stages_cannot_be_skipped"] is True
    assert rules["human_evidence_required_from_rank"] == 3
    assert rules["real_device_evidence_required_from_rank"] == 4
    assert rules["ci_must_not_promote_human_or_device_stages"] is True
    assert rules["regression_can_demote_a_system"] is True
    assert set(rules["production_lock_requires_four_proofs"]) == {"design", "player", "technical", "production"}

    rank_by_id = {stage["id"]: stage["rank"] for stage in stages}
    player_gate_ids = set(player_contract["required_gate_ids"])
    systems = data["systems"]
    ids = [system["id"] for system in systems]
    assert len(ids) == len(set(ids)), "duplicate system id"
    assert "combat_core" in ids

    for system in systems:
        stage_id = system["current_stage"]
        assert stage_id in rank_by_id, system["id"]
        rank = rank_by_id[stage_id]
        evidence = system["evidence"]
        for bucket in ("design", "technical", "player", "mobile", "production"):
            assert bucket in evidence, f"{system['id']}:{bucket}"
            assert isinstance(evidence[bucket], list), f"{system['id']}:{bucket}"
        assert evidence["design"], f"{system['id']}: missing design evidence"
        assert evidence["technical"], f"{system['id']}: missing technical evidence"

        for bucket in ("design", "technical", "player", "mobile", "production"):
            for rel in evidence[bucket]:
                assert (ROOT / rel).is_file(), f"{system['id']} missing evidence path: {rel}"

        if rank >= 3:
            assert evidence["player"], f"{system['id']}: player stage requires player evidence"
        if rank >= 4:
            assert evidence["mobile"], f"{system['id']}: mobile stage requires real-device evidence"
        if rank >= 5:
            assert evidence["production"], f"{system['id']}: production lock requires production evidence"
            assert evidence["player"], f"{system['id']}: production lock requires player evidence"

        next_gate = system.get("next_gate")
        if rank < 5:
            assert next_gate in player_gate_ids, f"{system['id']}: invalid next player gate {next_gate}"
            assert system.get("blocking_reason", "").strip(), f"{system['id']}: missing blocking reason"

    combat = next(system for system in systems if system["id"] == "combat_core")
    assert combat["current_stage"] == "technically_validated"
    assert combat["evidence"]["player"] == []
    assert combat["evidence"]["mobile"] == []
    assert combat["next_gate"] == "combat_decision_readability"

    print("VEILLEURS_SYSTEM_MATURITY_AUDIT_OK")
    print(f"Systems tracked: {len(systems)} | Combat stage: {combat['current_stage']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
