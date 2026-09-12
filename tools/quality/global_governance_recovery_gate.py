#!/usr/bin/env python3
"""Fail-closed recovery gate for a compromised global governance control plane.

The gate validates containment and recovery evidence. It can only declare that a
separate human resume decision may be considered; it never restores credentials,
unfreezes automation, writes a project Core, or authorizes a merge.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path
from typing import Any

REQUIRED_ADVERSARIAL_TESTS = {
    "source_compromise",
    "ledger_tamper",
    "replay",
    "hash_substitution",
    "stale_sha",
    "target_change",
    "wrong_route",
    "bypass_attempt",
}


def _hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _hex(value: Any, length: int) -> bool:
    return isinstance(value, str) and len(value) == length and all(c in "0123456789abcdef" for c in value)


def _aware_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        return None
    return parsed


def _unique_strings(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not value or not all(isinstance(x, str) and x.strip() for x in value):
        raise ValueError(f"{field} must be a non-empty string list")
    normalized = [x.strip() for x in value]
    if len(normalized) != len(set(normalized)):
        raise ValueError(f"{field} must not contain duplicates")
    return normalized


def evaluate(report: dict[str, Any]) -> dict[str, Any]:
    required = {
        "kind", "evidence_scope", "incident_id", "severity", "detected_at", "containment_started_at",
        "recovery_verified_at", "source_commit_sha", "trusted_baseline_commit_sha",
        "compromised_components", "affected_projects", "global_automation_frozen",
        "all_mutation_credentials_revoked", "replacement_credentials_isolated",
        "credential_rotation_evidence_refs", "ledger_recovery", "adversarial_tests",
        "local_guardian_results", "independent_reviewers",
    }
    missing = sorted(required - set(report))
    if missing:
        raise ValueError("missing recovery fields:" + ",".join(missing))
    if report["kind"] != "GLOBAL_GOVERNANCE_COMPROMISE_RECOVERY":
        raise ValueError("invalid recovery report kind")
    if report["evidence_scope"] not in {"REAL", "ISOLATED_SYNTHETIC"}:
        raise ValueError("evidence_scope must be REAL or ISOLATED_SYNTHETIC")
    if report["severity"] != "CRITICAL":
        raise ValueError("total compromise recovery requires CRITICAL severity")
    if not isinstance(report["incident_id"], str) or not report["incident_id"].strip():
        raise ValueError("incident_id required")

    detected = _aware_datetime(report["detected_at"])
    contained = _aware_datetime(report["containment_started_at"])
    verified = _aware_datetime(report["recovery_verified_at"])
    if None in (detected, contained, verified):
        raise ValueError("recovery timestamps must be timezone-aware ISO-8601")
    if not detected <= contained <= verified:
        raise ValueError("recovery timestamps are not chronological")

    for field in ("source_commit_sha", "trusted_baseline_commit_sha"):
        if not _hex(report[field], 40):
            raise ValueError(f"{field} must be 40 lowercase hex")

    compromised = _unique_strings(report["compromised_components"], "compromised_components")
    projects = _unique_strings(report["affected_projects"], "affected_projects")
    rotation_refs = _unique_strings(report["credential_rotation_evidence_refs"], "credential_rotation_evidence_refs")
    reviewers = _unique_strings(report["independent_reviewers"], "independent_reviewers")
    if len(reviewers) < 2:
        raise ValueError("at least two independent reviewers are required")

    ledger = report["ledger_recovery"]
    if not isinstance(ledger, dict):
        raise ValueError("ledger_recovery must be an object")
    for field in ("trusted_checkpoint_hash", "restored_ledger_hash"):
        if not _hex(ledger.get(field), 64):
            raise ValueError(f"ledger_recovery.{field} must be 64 lowercase hex")

    tests = report["adversarial_tests"]
    if not isinstance(tests, list):
        raise ValueError("adversarial_tests must be a list")
    test_ids = [row.get("test_id") for row in tests if isinstance(row, dict)]
    if len(test_ids) != len(tests) or len(test_ids) != len(set(test_ids)):
        raise ValueError("adversarial_tests must have unique test_id values")
    missing_tests = sorted(REQUIRED_ADVERSARIAL_TESTS - set(test_ids))
    if missing_tests:
        raise ValueError("missing adversarial tests:" + ",".join(missing_tests))
    for row in tests:
        if row.get("status") not in {"PASS", "FAIL"} or not _hex(row.get("artifact_hash"), 64):
            raise ValueError("invalid adversarial test evidence")

    guardians = report["local_guardian_results"]
    if not isinstance(guardians, list):
        raise ValueError("local_guardian_results must be a list")
    guardian_ids = [row.get("project_id") for row in guardians if isinstance(row, dict)]
    if len(guardian_ids) != len(guardians) or len(guardian_ids) != len(set(guardian_ids)):
        raise ValueError("local_guardian_results must have unique project_id values")
    if set(guardian_ids) != set(projects):
        raise ValueError("every affected project requires exactly one local Guardian result")
    for row in guardians:
        _unique_strings(row.get("evidence_refs"), f"Guardian {row.get('project_id')} evidence_refs")
        if not isinstance(row.get("recovery_test_run_id"), int) or row["recovery_test_run_id"] <= 0:
            raise ValueError("local Guardian recovery_test_run_id must be positive")

    blockers: list[str] = []
    if report["global_automation_frozen"] is not True:
        blockers.append("global_automation_not_frozen")
    if report["all_mutation_credentials_revoked"] is not True:
        blockers.append("mutation_credentials_not_revoked")
    if report["replacement_credentials_isolated"] is not True:
        blockers.append("replacement_credentials_not_isolated")
    if ledger.get("chain_verified") is not True:
        blockers.append("restored_ledger_chain_not_verified")
    if ledger.get("replay_scan_passed") is not True:
        blockers.append("ledger_replay_scan_not_passed")
    if any(row["status"] != "PASS" for row in tests):
        blockers.append("adversarial_recovery_tests_failed")
    for row in guardians:
        project = row["project_id"]
        if row.get("decision") != "GREEN":
            blockers.append(f"local_guardian_not_green:{project}")
        if row.get("integrity_verified") is not True:
            blockers.append(f"local_integrity_not_verified:{project}")
        if row.get("cross_project_isolation_verified") is not True:
            blockers.append(f"cross_project_isolation_not_verified:{project}")

    if blockers:
        status = "RECOVERY_BLOCKED"
    elif report["evidence_scope"] == "ISOLATED_SYNTHETIC":
        status = "TABLETOP_MEASURED"
    else:
        status = "READY_FOR_SEPARATE_HUMAN_RESUME_DECISION"
    result = {
        "kind": "GLOBAL_GOVERNANCE_RECOVERY_GATE_RECEIPT",
        "incident_id": report["incident_id"].strip(),
        "evidence_scope": report["evidence_scope"],
        "status": status,
        "source_commit_sha": report["source_commit_sha"],
        "trusted_baseline_commit_sha": report["trusted_baseline_commit_sha"],
        "compromised_components": compromised,
        "affected_projects": projects,
        "credential_rotation_evidence_refs": rotation_refs,
        "independent_reviewers": reviewers,
        "blockers": blockers,
        "human_resume_decision_required": True,
        "automatic_resume_allowed": False,
        "automatic_credential_restore_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_core_write_allowed": False,
        "automatic_cross_project_propagation_allowed": False,
        "authority": "recovery_evidence_only_separate_human_resume_decision_required",
    }
    result["recovery_gate_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--output", default="reports/global-governance-recovery-gate.json")
    args = parser.parse_args()
    report = json.loads(Path(args.report).read_text(encoding="utf-8"))
    result = evaluate(report)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "blockers": result["blockers"]}, sort_keys=True))
    return 0 if result["status"] in {"READY_FOR_SEPARATE_HUMAN_RESUME_DECISION", "TABLETOP_MEASURED"} else 2


if __name__ == "__main__":
    raise SystemExit(main())
