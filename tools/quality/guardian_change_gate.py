#!/usr/bin/env python3
"""Guardian gate for governed LITD change candidates.

The gate converts an approved Veilleur review resolution into either a rejection,
a request for more evidence, or a bounded implementation plan. It verifies the
LITD project boundary, never edits Core/gameplay/targets itself and never treats
approval as proof that tests passed.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path, PurePosixPath
from typing import Any

from tools.quality.veilleur_v2_ingest import PROJECT_ID, TARGET_ROUTE

ALLOWED_DECISIONS = {"ACCEPT_FOR_IMPLEMENTATION", "REJECT_CHANGE", "REQUEST_MORE_EVIDENCE"}
FORBIDDEN_PREFIXES = (
    "docs/knowledge/design-targets.json",
    "docs/knowledge/guardian-rules.yml",
    "docs/knowledge/target-drift-baseline-v1.json",
)


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


def _canonical_paths(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not value or not all(isinstance(x, str) and x.strip() for x in value):
        raise ValueError(f"{field} must be a non-empty string list")
    if len(value) != len(set(value)):
        raise ValueError(f"{field} must not contain duplicates")
    for raw in value:
        path = PurePosixPath(raw)
        if "\x00" in raw or "\\" in raw or path.is_absolute() or path.as_posix() != raw or ".." in path.parts or any(part.casefold() == ".git" for part in path.parts):
            raise ValueError(f"{field} contains a non-canonical path")
    return value


def _unique_strings(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not value or not all(isinstance(x, str) and x.strip() for x in value):
        raise ValueError(f"{field} must be a non-empty string list")
    if len(value) != len(set(value)):
        raise ValueError(f"{field} must not contain duplicates")
    return value


def _aware_iso(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return dt.tzinfo is not None and dt.utcoffset() is not None


def evaluate(receipt: dict[str, Any], submission: dict[str, Any]) -> dict[str, Any]:
    _verify_embedded_hash(receipt, "receipt_hash")
    if receipt.get("kind") != "LITD_VEILLEUR_REVIEW_RESOLUTION_RECEIPT":
        raise ValueError("invalid resolution receipt kind")
    if receipt.get("project_id") != PROJECT_ID:
        raise ValueError("resolution receipt project scope mismatch")
    if receipt.get("target_route") != TARGET_ROUTE:
        raise ValueError("resolution receipt route scope mismatch")
    if receipt.get("outcome") != "LITD_CHANGE_CANDIDATE_APPROVED_PENDING_GUARDIAN":
        raise ValueError("receipt is not a Guardian-pending LITD change candidate")
    if receipt.get("requires_guardian_review") is not True:
        raise ValueError("receipt must require Guardian review")
    for key in ("core_write_allowed", "library_write_allowed", "automatic_target_change_allowed"):
        if receipt.get(key) is not False:
            raise ValueError(f"receipt authority violation:{key}")

    required = {
        "receipt_hash", "decision", "decided_by", "decided_at", "rationale",
        "change_summary", "player_value", "technical_value", "risk", "reversibility",
        "affected_paths", "required_tests", "rollback_plan", "evidence_refs",
    }
    missing = sorted(required - set(submission))
    if missing:
        raise ValueError("missing Guardian submission fields:" + ",".join(missing))
    if submission["receipt_hash"] != receipt.get("receipt_hash"):
        raise ValueError("resolution receipt hash mismatch")
    decision = submission["decision"]
    if decision not in ALLOWED_DECISIONS:
        raise ValueError("unsupported Guardian decision")
    if not _aware_iso(submission["decided_at"]):
        raise ValueError("decided_at must be timezone-aware ISO-8601")
    for field in ("decided_by", "rationale", "change_summary", "player_value", "technical_value", "risk", "reversibility", "rollback_plan"):
        value = submission.get(field)
        if not isinstance(value, str) or len(value.strip()) < (20 if field != "decided_by" else 1):
            raise ValueError(f"invalid or too-short field:{field}")

    paths = _canonical_paths(submission["affected_paths"], "affected_paths")
    tests = _unique_strings(submission["required_tests"], "required_tests")
    evidence_refs = _unique_strings(submission["evidence_refs"], "evidence_refs")
    if any(path == prefix or path.startswith(prefix + "/") for path in paths for prefix in FORBIDDEN_PREFIXES):
        raise ValueError("target/Guardian policy changes require their dedicated governance path")

    accepted = decision == "ACCEPT_FOR_IMPLEMENTATION"
    status = {
        "ACCEPT_FOR_IMPLEMENTATION": "READY_FOR_BOUNDED_IMPLEMENTATION_PR",
        "REJECT_CHANGE": "CHANGE_REJECTED",
        "REQUEST_MORE_EVIDENCE": "MORE_EVIDENCE_REQUIRED",
    }[decision]

    plan = {
        "kind": "LITD_GUARDIAN_CHANGE_GATE_RECEIPT",
        "project_id": PROJECT_ID,
        "target_route": TARGET_ROUTE,
        "source_resolution_receipt_hash": receipt["receipt_hash"],
        "source_candidate_hash": receipt.get("candidate_hash"),
        "evidence_id": receipt.get("evidence_id"),
        "decision": decision,
        "status": status,
        "decided_by": submission["decided_by"].strip(),
        "decided_at": submission["decided_at"],
        "rationale": submission["rationale"].strip(),
        "implementation_plan": {
            "change_summary": submission["change_summary"].strip(),
            "player_value": submission["player_value"].strip(),
            "technical_value": submission["technical_value"].strip(),
            "risk": submission["risk"].strip(),
            "reversibility": submission["reversibility"].strip(),
            "affected_paths": paths,
            "required_tests": tests,
            "rollback_plan": submission["rollback_plan"].strip(),
            "evidence_refs": evidence_refs,
        } if accepted else None,
        "implementation_pr_allowed": accepted,
        "implementation_must_be_separate": True,
        "tests_must_pass_before_application": True,
        "rollback_evidence_required": True,
        "core_write_allowed": False,
        "automatic_code_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "guardian_gate_plan_only_separate_implementation_and_ci_required",
    }
    plan["gate_receipt_hash"] = _hash(plan)
    return plan


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--submission", required=True)
    parser.add_argument("--output", default="reports/guardian-change-gate.json")
    args = parser.parse_args()
    receipt = json.loads(Path(args.receipt).read_text(encoding="utf-8"))
    submission = json.loads(Path(args.submission).read_text(encoding="utf-8"))
    result = evaluate(receipt, submission)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": result["decision"], "status": result["status"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
