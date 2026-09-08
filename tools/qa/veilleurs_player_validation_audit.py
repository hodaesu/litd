#!/usr/bin/env python3
"""Audit statique du gate de validation joueur pour LITD : Les Veilleurs.

La CI valide ici le contrat, les liaisons et le modèle de preuve. Elle ne doit
jamais considérer qu'un playtest humain a eu lieu simplement parce que la
structure est valide.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_GATES = (
    "combat_decision_readability",
    "anatomy_causality",
    "fear_madness_clarity",
    "exploration_route_clarity",
    "sanctuary_consequence_loop",
    "first_session_onboarding",
    "art_in_context_readability",
    "real_mobile_interaction",
)

REQUIRED_PATHS = (
    "docs/CHAPITRE_01_VERTICAL_SLICE.md",
    "docs/veilleurs/PRODUCTION_PLAYBOOK.md",
    "docs/veilleurs/PLAYTEST_PROTOCOL.md",
    "docs/veilleurs/ART_DIRECTION_PRODUCTION_BIBLE.md",
    "data/visual_vertical_slice.json",
    "data/veilleurs/hardware_validation_contract.json",
    "data/veilleurs/vs001_balance.json",
    "reports/veilleurs_player_validation_template.json",
)


def load_json(relative_path: str) -> dict:
    return json.loads((ROOT / relative_path).read_text(encoding="utf-8"))


def main() -> int:
    contract = load_json("data/veilleurs/player_validation_contract.json")
    hardware = load_json("data/veilleurs/hardware_validation_contract.json")
    template = load_json("reports/veilleurs_player_validation_template.json")

    assert contract["schema_version"] == 1
    assert contract["project"] == "LITD : Les Veilleurs"
    assert contract["engine_family"] == "Godot 4.7.x"
    assert contract["ci_godot_version"] == "4.7.2"
    assert contract["stage"] == "vertical_player_validation"
    assert contract["rules"]["human_evidence_required"] is True
    assert contract["rules"]["ci_must_not_convert_not_run_to_pass"] is True
    assert contract["rules"]["all_required_gates_must_pass_for_scale_up"] is True
    assert contract["rules"]["minimum_naive_testers_for_lock"] >= 3
    assert contract["rules"]["blocking_issue_count_max"] == 0

    # Le contrat matériel doit suivre la famille moteur active des Veilleurs.
    assert hardware["godot_version"] == "4.7.x", hardware["godot_version"]
    hardware_gate_ids = {gate["id"] for gate in hardware["gates"]}

    required = tuple(contract["required_gate_ids"])
    assert required == REQUIRED_GATES, required
    gates = contract["gates"]
    actual_gate_ids = tuple(gate["id"] for gate in gates)
    assert actual_gate_ids == REQUIRED_GATES, actual_gate_ids
    assert len(set(actual_gate_ids)) == len(actual_gate_ids)

    allowed_proof_types = {"player", "hybrid"}
    for gate in gates:
        for field in ("id", "proof_type", "contexts", "hypothesis", "required_evidence", "acceptance"):
            assert field in gate, f"{gate.get('id', '<unknown>')}:{field}"
        assert gate["proof_type"] in allowed_proof_types, gate["id"]
        assert gate["contexts"], gate["id"]
        assert gate["hypothesis"].strip(), gate["id"]
        assert gate["required_evidence"], gate["id"]
        assert "tester_id" in gate["required_evidence"], gate["id"]
        assert "build_commit" in gate["required_evidence"], gate["id"]
        assert "blocking_issue_count" in gate["required_evidence"], gate["id"]
        assert len(gate["acceptance"]) >= 3, gate["id"]
        for linked_id in gate.get("linked_hardware_gate_ids", []):
            assert linked_id in hardware_gate_ids, f"{gate['id']} -> {linked_id}"

    for relative_path in REQUIRED_PATHS:
        assert (ROOT / relative_path).is_file(), relative_path

    # Le modèle versionné doit rester neutre. Toute preuve réelle appartient à
    # un rapport de session distinct, jamais au template de référence.
    assert template["schema_version"] == 1
    assert template["contract"] == "data/veilleurs/player_validation_contract.json"
    assert template["build_commit"] == ""
    assert template["tested_at"] == ""
    assert template["testers"] == []
    template_gates = template["gates"]
    assert tuple(item["id"] for item in template_gates) == REQUIRED_GATES
    for item in template_gates:
        assert item["status"] == "NOT_RUN", item["id"]
        assert item["evidence"] == {}, item["id"]
        assert item["notes"] == [], item["id"]

    print("VEILLEURS_PLAYER_VALIDATION_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
