#!/usr/bin/env python3
"""Final governed application decision for bounded LITD implementations.

This gate consumes a READY_FOR_APPLICATION_REVIEW evaluation and records a
human/governed decision. Even APPLY_CHANGE only authorizes a later separate
merge/application action; this module never merges, deploys, edits Core, or
changes canonical targets.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path
from typing import Any

ALLOWED_DECISIONS = {"APPLY_CHANGE", "REJECT_IMPLEMENTATION", "REQUEST_MORE_EVIDENCE"}
ALLOWED_MEASUREMENT_ASSESSMENTS = {"NO_BLOCKING_REGRESSION", "BLOCKING_REGRESSION", "INCONCLUSIVE"}


def _hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _verify_embedded_hash(payload: dict[str, Any], field: str) -> None:
    claimed = payload.get(field)
    if not isinstance(claimed, str) or len(claimed) != 64 or any(ch not in "0123456789abcdef" for ch in claimed):
        raise ValueError(f"invalid {field}")
    unsigned = {key: value for key, value in payload.items() if key != field}
    if claimed != _hash(unsigned):
        raise ValueError(f"{field} integrity mismatch")


def _aware_iso(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return dt.tzinfo is not None and dt.utcoffset() is not None


def _nonempty_strings(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(x, str) and x.strip() for x in value)


def evaluate(evaluation: dict[str, Any], decision: dict[str, Any]) -> dict[str, Any]:
    _verify_embedded_hash(evaluation, "evaluation_hash")
    if evaluation.get("kind") != "LITD_BOUNDED_IMPLEMENTATION_EVALUATION":
        raise ValueError("invalid bounded implementation evaluation kind")
    if evaluation.get("status") != "READY_FOR_APPLICATION_REVIEW":
        raise ValueError("implementation is not ready for application review")
    if evaluation.get("blockers") != []:
        raise ValueError("application review requires zero blockers")
    for key in ("core_write_allowed", "automatic_merge_allowed", "automatic_application_allowed", "automatic_target_change_allowed"):
        if evaluation.get(key) is not False:
            raise ValueError(f"implementation evaluation authority violation:{key}")
    if evaluation.get("application_requires_separate_decision") is not True:
        raise ValueError("separate application decision invariant missing")
    if evaluation.get("rollback_verification_required_before_application") is not True:
        raise ValueError("rollback verification invariant missing")

    required = {
        "evaluation_hash", "decision", "decided_by", "decided_at", "rationale",
        "implementation_commit_sha", "pre_measurement_hash", "post_measurement_hash",
        "measurement_assessment", "rollback_verified", "evidence_refs",
    }
    missing = sorted(required - set(decision))
    if missing:
        raise ValueError("missing application decision fields:" + ",".join(missing))
    if decision["evaluation_hash"] != evaluation.get("evaluation_hash"):
        raise ValueError("implementation evaluation hash mismatch")
    if decision["implementation_commit_sha"] != evaluation.get("implementation_commit_sha"):
        raise ValueError("implementation commit SHA mismatch")
    if decision["pre_measurement_hash"] != evaluation.get("pre_measurement_hash"):
        raise ValueError("pre measurement hash mismatch")
    if decision["post_measurement_hash"] != evaluation.get("post_measurement_hash"):
        raise ValueError("post measurement hash mismatch")

    choice = decision["decision"]
    if choice not in ALLOWED_DECISIONS:
        raise ValueError("unsupported application decision")
    if not isinstance(decision.get("decided_by"), str) or not decision["decided_by"].strip():
        raise ValueError("decided_by required")
    if not _aware_iso(decision.get("decided_at")):
        raise ValueError("decided_at must be timezone-aware ISO-8601")
    if not isinstance(decision.get("rationale"), str) or len(decision["rationale"].strip()) < 20:
        raise ValueError("decision rationale too short")
    if not _nonempty_strings(decision.get("evidence_refs")):
        raise ValueError("evidence_refs required")

    assessment = decision["measurement_assessment"]
    if assessment not in ALLOWED_MEASUREMENT_ASSESSMENTS:
        raise ValueError("unsupported measurement assessment")
    rollback_verified = decision["rollback_verified"]
    if not isinstance(rollback_verified, bool):
        raise ValueError("rollback_verified must be boolean")

    if choice == "APPLY_CHANGE":
        if assessment != "NO_BLOCKING_REGRESSION":
            raise ValueError("APPLY_CHANGE requires NO_BLOCKING_REGRESSION")
        if rollback_verified is not True:
            raise ValueError("APPLY_CHANGE requires verified rollback")

    outcome = {
        "APPLY_CHANGE": "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE",
        "REJECT_IMPLEMENTATION": "IMPLEMENTATION_REJECTED",
        "REQUEST_MORE_EVIDENCE": "MORE_EVIDENCE_REQUIRED",
    }[choice]

    receipt = {
        "kind": "LITD_APPLICATION_DECISION_RECEIPT",
        "source_evaluation_hash": evaluation["evaluation_hash"],
        "source_gate_receipt_hash": evaluation.get("source_gate_receipt_hash"),
        "source_candidate_hash": evaluation.get("source_candidate_hash"),
        "implementation_commit_sha": evaluation["implementation_commit_sha"],
        "pre_measurement_hash": evaluation["pre_measurement_hash"],
        "post_measurement_hash": evaluation["post_measurement_hash"],
        "measurement_assessment": assessment,
        "rollback_verified": rollback_verified,
        "rollback_evidence_refs": list(evaluation.get("rollback_evidence_refs", [])),
        "decision": choice,
        "outcome": outcome,
        "decided_by": decision["decided_by"].strip(),
        "decided_at": decision["decided_at"],
        "rationale": decision["rationale"].strip(),
        "evidence_refs": list(decision["evidence_refs"]),
        "merge_authorized": choice == "APPLY_CHANGE",
        "merge_must_be_separate_action": True,
        "post_merge_measurement_required": choice == "APPLY_CHANGE",
        "provenance_checkpoint_required": choice == "APPLY_CHANGE",
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_application_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "application_authorization_receipt_only_separate_merge_and_post_merge_verification_required",
    }
    receipt["application_decision_hash"] = _hash(receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evaluation", required=True)
    parser.add_argument("--decision", required=True)
    parser.add_argument("--output", default="reports/application-decision.json")
    args = parser.parse_args()
    evaluation = json.loads(Path(args.evaluation).read_text(encoding="utf-8"))
    decision = json.loads(Path(args.decision).read_text(encoding="utf-8"))
    result = evaluate(evaluation, decision)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": result["decision"], "outcome": result["outcome"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
