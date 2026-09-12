#!/usr/bin/env python3
"""Validate bounded implementation evidence produced after Guardian approval.

The contract checks that implementation changes stay within the Guardian-approved
path set, required tests are explicitly evidenced as passed, pre/post measurements
are bound to the same metric identity, and rollback evidence exists. It never
merges code or writes to Core/targets.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any


def _hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _nonempty_strings(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(x, str) and x.strip() for x in value)


def evaluate(gate: dict[str, Any], evidence: dict[str, Any]) -> dict[str, Any]:
    if gate.get("kind") != "LITD_GUARDIAN_CHANGE_GATE_RECEIPT":
        raise ValueError("invalid Guardian gate receipt kind")
    if gate.get("status") != "READY_FOR_BOUNDED_IMPLEMENTATION_PR" or gate.get("implementation_pr_allowed") is not True:
        raise ValueError("Guardian gate does not authorize bounded implementation")
    for key in ("core_write_allowed", "automatic_code_write_allowed", "automatic_merge_allowed", "automatic_target_change_allowed"):
        if gate.get(key) is not False:
            raise ValueError(f"Guardian gate authority violation:{key}")

    plan = gate.get("implementation_plan")
    if not isinstance(plan, dict):
        raise ValueError("missing implementation plan")
    allowed_paths = set(plan.get("affected_paths", []))
    required_tests = set(plan.get("required_tests", []))
    if not allowed_paths or not required_tests:
        raise ValueError("implementation plan missing paths/tests")

    required = {"gate_receipt_hash", "changed_paths", "test_results", "pre_measurement", "post_measurement", "rollback_evidence_refs", "implementation_commit_sha"}
    missing = sorted(required - set(evidence))
    if missing:
        raise ValueError("missing implementation evidence fields:" + ",".join(missing))
    if evidence["gate_receipt_hash"] != gate.get("gate_receipt_hash"):
        raise ValueError("Guardian gate receipt hash mismatch")

    changed_paths = evidence["changed_paths"]
    if not _nonempty_strings(changed_paths):
        raise ValueError("changed_paths must be a non-empty string list")
    unexpected = sorted(set(changed_paths) - allowed_paths)

    test_results = evidence["test_results"]
    if not isinstance(test_results, list):
        raise ValueError("test_results must be a list")
    by_command = {r.get("command"): r for r in test_results if isinstance(r, dict) and isinstance(r.get("command"), str)}
    missing_tests = sorted(required_tests - set(by_command))
    failed_tests = sorted(command for command in required_tests if command in by_command and by_command[command].get("status") != "PASS")

    pre = evidence["pre_measurement"]
    post = evidence["post_measurement"]
    if not isinstance(pre, dict) or not isinstance(post, dict):
        raise ValueError("measurements must be objects")
    identity_keys = ("metric_family", "model_version", "scenario", "seed_policy", "seed_value")
    pre_identity = {k: pre.get(k) for k in identity_keys if k in pre}
    post_identity = {k: post.get(k) for k in identity_keys if k in post}
    comparable = bool(pre_identity) and pre_identity == post_identity
    if not isinstance(pre.get("artifact_hash"), str) or len(pre["artifact_hash"]) != 64:
        raise ValueError("pre measurement artifact_hash required")
    if not isinstance(post.get("artifact_hash"), str) or len(post["artifact_hash"]) != 64:
        raise ValueError("post measurement artifact_hash required")

    rollback_refs = evidence["rollback_evidence_refs"]
    if not _nonempty_strings(rollback_refs):
        raise ValueError("rollback evidence refs required")
    sha = evidence["implementation_commit_sha"]
    if not isinstance(sha, str) or len(sha) != 40 or any(c not in "0123456789abcdef" for c in sha):
        raise ValueError("implementation_commit_sha must be 40 lowercase hex")

    blockers = []
    if unexpected:
        blockers.append("unexpected_changed_paths")
    if missing_tests:
        blockers.append("missing_required_tests")
    if failed_tests:
        blockers.append("failed_required_tests")
    if not comparable:
        blockers.append("measurements_not_comparable")

    status = "READY_FOR_APPLICATION_REVIEW" if not blockers else "IMPLEMENTATION_BLOCKED"
    result = {
        "kind": "LITD_BOUNDED_IMPLEMENTATION_EVALUATION",
        "status": status,
        "source_gate_receipt_hash": gate["gate_receipt_hash"],
        "source_candidate_hash": gate.get("source_candidate_hash"),
        "implementation_commit_sha": sha,
        "unexpected_changed_paths": unexpected,
        "missing_required_tests": missing_tests,
        "failed_required_tests": failed_tests,
        "measurements_comparable": comparable,
        "pre_measurement_hash": pre["artifact_hash"],
        "post_measurement_hash": post["artifact_hash"],
        "rollback_evidence_refs": list(rollback_refs),
        "blockers": blockers,
        "application_requires_separate_decision": True,
        "rollback_verification_required_before_application": True,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_application_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "implementation_evidence_only_separate_application_decision_required",
    }
    result["evaluation_hash"] = _hash(result)
    return result


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--gate", required=True)
    p.add_argument("--evidence", required=True)
    p.add_argument("--output", default="reports/bounded-implementation-evaluation.json")
    a = p.parse_args()
    gate = json.loads(Path(a.gate).read_text(encoding="utf-8"))
    evidence = json.loads(Path(a.evidence).read_text(encoding="utf-8"))
    result = evaluate(gate, evidence)
    out = Path(a.output); out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "blockers": result["blockers"]}, sort_keys=True))
    return 0 if result["status"] == "READY_FOR_APPLICATION_REVIEW" else 2


if __name__ == "__main__":
    raise SystemExit(main())
