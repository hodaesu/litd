#!/usr/bin/env python3
"""Governed resolution for Veilleur library review candidates.

A resolution can approve a library promotion, keep evidence quarantined, request
more evidence, link a cross-reference, propose supersession, or propose an LITD
change candidate. It never mutates the library, targets, gameplay data, or Core.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path
from typing import Any

ALLOWED_DECISIONS = {
    "PROMOTE_TO_LIBRARY",
    "KEEP_QUARANTINED",
    "REQUEST_MORE_EVIDENCE",
    "LINK_AS_CROSS_REFERENCE",
    "PROPOSE_SUPERSESSION",
    "PROPOSE_LITD_CHANGE_CANDIDATE",
}


def _hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _aware_iso(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return dt.tzinfo is not None and dt.utcoffset() is not None


def resolve_candidate(candidate: dict[str, Any], resolution: dict[str, Any]) -> dict[str, Any]:
    if candidate.get("kind") != "LITD_LIBRARY_REVIEW_CANDIDATE":
        raise ValueError("invalid review candidate kind")
    if candidate.get("core_write_allowed") is not False:
        raise ValueError("candidate attempted Core authority")
    if candidate.get("automatic_library_write_allowed") is not False:
        raise ValueError("candidate attempted library authority")

    required = {"candidate_hash", "decision", "rationale", "decided_by", "decided_at"}
    missing = sorted(required - set(resolution))
    if missing:
        raise ValueError("missing resolution fields:" + ",".join(missing))
    if resolution["candidate_hash"] != candidate.get("candidate_hash"):
        raise ValueError("candidate hash mismatch")
    decision = resolution["decision"]
    if decision not in ALLOWED_DECISIONS:
        raise ValueError("unsupported review decision")
    if not isinstance(resolution["rationale"], str) or len(resolution["rationale"].strip()) < 20:
        raise ValueError("resolution rationale too short")
    if not isinstance(resolution["decided_by"], str) or not resolution["decided_by"].strip():
        raise ValueError("decided_by required")
    if not _aware_iso(resolution["decided_at"]):
        raise ValueError("decided_at must be timezone-aware ISO-8601")

    route = candidate.get("route")
    if decision == "PROPOSE_LITD_CHANGE_CANDIDATE" and route != "LITD_LIBRARY":
        raise ValueError("LITD change candidate requires LITD_LIBRARY route")
    if decision == "LINK_AS_CROSS_REFERENCE" and candidate.get("cross_reference") is not True:
        raise ValueError("cross-reference decision requires cross_reference candidate")
    if decision == "PROPOSE_SUPERSESSION":
        target = resolution.get("supersedes_record_id")
        if not isinstance(target, str) or not target.strip():
            raise ValueError("supersedes_record_id required")

    outcome = {
        "PROMOTE_TO_LIBRARY": "LIBRARY_PROMOTION_APPROVED_PENDING_APPLICATION",
        "KEEP_QUARANTINED": "QUARANTINE_CONFIRMED",
        "REQUEST_MORE_EVIDENCE": "MORE_EVIDENCE_REQUIRED",
        "LINK_AS_CROSS_REFERENCE": "CROSS_REFERENCE_APPROVED_PENDING_APPLICATION",
        "PROPOSE_SUPERSESSION": "SUPERSESSION_APPROVED_PENDING_APPLICATION",
        "PROPOSE_LITD_CHANGE_CANDIDATE": "LITD_CHANGE_CANDIDATE_APPROVED_PENDING_GUARDIAN",
    }[decision]

    receipt = {
        "kind": "LITD_VEILLEUR_REVIEW_RESOLUTION_RECEIPT",
        "candidate_hash": candidate["candidate_hash"],
        "evidence_id": candidate.get("evidence_id"),
        "route": route,
        "decision": decision,
        "outcome": outcome,
        "rationale": resolution["rationale"].strip(),
        "decided_by": resolution["decided_by"].strip(),
        "decided_at": resolution["decided_at"],
        "evidence_refs": list(resolution.get("evidence_refs", [])),
        "supersedes_record_id": resolution.get("supersedes_record_id"),
        "requires_guardian_review": decision == "PROPOSE_LITD_CHANGE_CANDIDATE",
        "library_write_allowed": False,
        "core_write_allowed": False,
        "automatic_obsolescence_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "governed_resolution_receipt_only_application_is_separate",
    }
    receipt["receipt_hash"] = _hash(receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--resolution", required=True)
    parser.add_argument("--output", default="reports/veilleur-review-resolution.json")
    args = parser.parse_args()
    candidate = json.loads(Path(args.candidate).read_text(encoding="utf-8"))
    resolution = json.loads(Path(args.resolution).read_text(encoding="utf-8"))
    receipt = resolve_candidate(candidate, resolution)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": receipt["decision"], "outcome": receipt["outcome"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
