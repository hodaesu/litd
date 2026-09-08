#!/usr/bin/env python3
"""Valide un rapport réel de playtest du vertical slice Les Veilleurs."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/player_validation_contract.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _has_value(value: Any) -> bool:
    return value is not None and value != ""


def validate_report(
    report: dict[str, Any],
    contract: dict[str, Any],
    *,
    allow_incomplete: bool = False,
) -> list[str]:
    errors: list[str] = []
    status_values = set(contract["status_values"])
    required_gate_ids = list(contract["required_gate_ids"])
    contract_gates = {gate["id"]: gate for gate in contract["gates"]}
    rules = contract["rules"]

    if report.get("schema_version") != 1:
        errors.append("schema_version doit valoir 1")
    if report.get("contract") != "data/veilleurs/player_validation_contract.json":
        errors.append("référence de contrat invalide")
    if report.get("project") != contract["project"]:
        errors.append("projet incohérent avec le contrat")

    build_commit = report.get("build_commit", "")
    tested_at = report.get("tested_at", "")
    testers = report.get("testers", [])
    if not isinstance(testers, list):
        errors.append("testers doit être une liste d'identifiants non sensibles")
        testers = []
    elif len(testers) != len(set(testers)):
        errors.append("les identifiants de testeurs doivent être uniques")

    hardware_results = report.get("hardware_gate_results", {})
    if not isinstance(hardware_results, dict):
        errors.append("hardware_gate_results doit être un objet")
        hardware_results = {}
    for hardware_id, status in hardware_results.items():
        if status not in status_values:
            errors.append(f"hardware {hardware_id}: statut invalide {status}")

    report_gates = report.get("gates", [])
    if not isinstance(report_gates, list):
        errors.append("gates doit être une liste")
        return errors
    report_gate_ids = [gate.get("id") for gate in report_gates if isinstance(gate, dict)]
    if report_gate_ids != required_gate_ids:
        errors.append("la liste des gates ne correspond pas au contrat")

    all_pass = True
    for item in report_gates:
        if not isinstance(item, dict):
            errors.append("entrée de gate invalide")
            all_pass = False
            continue
        gate_id = item.get("id")
        gate_contract = contract_gates.get(gate_id)
        if gate_contract is None:
            errors.append(f"gate inconnu: {gate_id}")
            all_pass = False
            continue

        status = item.get("status")
        if status not in status_values:
            errors.append(f"{gate_id}: statut invalide {status}")
            all_pass = False
            continue
        if status != "PASS":
            all_pass = False

        evidence = item.get("evidence", [])
        notes = item.get("notes", [])
        if not isinstance(evidence, list):
            errors.append(f"{gate_id}: evidence doit être une liste")
            evidence = []
        if not isinstance(notes, list):
            errors.append(f"{gate_id}: notes doit être une liste")

        if status == "NOT_RUN":
            if evidence:
                errors.append(f"{gate_id}: NOT_RUN ne doit pas contenir de preuve")
            if not allow_incomplete:
                errors.append(f"{gate_id}: gate non exécuté")
            continue

        if status == "BLOCKED":
            if not notes:
                errors.append(f"{gate_id}: BLOCKED doit expliquer le blocage")
            if not allow_incomplete:
                errors.append(f"{gate_id}: gate bloqué")
            continue

        # PASS et FAIL représentent un test réellement exécuté.
        if not build_commit:
            errors.append(f"{gate_id}: build_commit global manquant")
        if not tested_at:
            errors.append(f"{gate_id}: tested_at global manquant")
        if not testers:
            errors.append(f"{gate_id}: aucun testeur déclaré")
        if not evidence:
            errors.append(f"{gate_id}: aucune preuve de playtest")
            continue

        required_fields = gate_contract["required_evidence"]
        distinct_evidence_testers: set[str] = set()
        naive_testers: set[str] = set()
        for index, record in enumerate(evidence):
            prefix = f"{gate_id}: preuve {index + 1}"
            if not isinstance(record, dict):
                errors.append(f"{prefix} invalide")
                continue
            for field in required_fields:
                if field not in record or not _has_value(record[field]):
                    # Les compteurs à zéro et les booléens False sont des valeurs valides.
                    if record.get(field) not in (0, False):
                        errors.append(f"{prefix}: champ requis manquant {field}")
            tester_id = record.get("tester_id")
            if tester_id:
                distinct_evidence_testers.add(str(tester_id))
                if tester_id not in testers:
                    errors.append(f"{prefix}: tester_id absent de la liste testers")
            if record.get("build_commit") != build_commit:
                errors.append(f"{prefix}: build_commit différent du rapport")
            blocking = record.get("blocking_issue_count")
            if not isinstance(blocking, int) or blocking < 0:
                errors.append(f"{prefix}: blocking_issue_count invalide")
            elif status == "PASS" and blocking > rules["blocking_issue_count_max"]:
                errors.append(f"{prefix}: PASS impossible avec un problème bloquant")

            if gate_id == "first_session_onboarding":
                prior = record.get("prior_litd_experience")
                if prior in (False, 0, "none", "naive", "aucune", "non") and tester_id:
                    naive_testers.add(str(tester_id))

        if status == "PASS" and not distinct_evidence_testers:
            errors.append(f"{gate_id}: PASS sans testeur de preuve")

        if gate_id == "first_session_onboarding" and status == "PASS":
            minimum = rules["minimum_naive_testers_for_lock"]
            if len(naive_testers) < minimum:
                errors.append(
                    f"{gate_id}: {len(naive_testers)} testeurs naïfs, minimum {minimum}"
                )

        if status == "PASS":
            for linked_id in gate_contract.get("linked_hardware_gate_ids", []):
                if hardware_results.get(linked_id) != "PASS":
                    errors.append(
                        f"{gate_id}: gate matériel lié {linked_id} doit être PASS"
                    )

    if not allow_incomplete and not all_pass:
        errors.append("montée en volume interdite: tous les gates joueur ne sont pas PASS")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument(
        "--allow-incomplete",
        action="store_true",
        help="valide la structure d'un rapport en cours sans exiger tous les PASS",
    )
    args = parser.parse_args()

    contract = _load(CONTRACT_PATH)
    report = _load(args.report)
    errors = validate_report(report, contract, allow_incomplete=args.allow_incomplete)
    if errors:
        for error in errors:
            print(f"FAIL - {error}")
        return 1
    print("VEILLEURS_PLAYER_VALIDATION_REPORT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
