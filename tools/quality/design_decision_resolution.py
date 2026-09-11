#!/usr/bin/env python3
"""Validate and hash governed resolutions for LITD design review candidates.

A resolution is a traceable governance record. It may request follow-up work, but it
can never authorize or perform a direct Core mutation.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path
from typing import Any

ALLOWED_DECISIONS = {
    "REJECT_CHANGE",
    "REQUEST_IMPLEMENTATION_FIX",
    "REQUEST_MORE_EVIDENCE",
    "PROPOSE_TARGET_REVISION",
}

REQUIRED_FIELDS = {
    "candidate_hash",
    "decision",
    "rationale",
    "decided_by",
    "decided_at",
}


def _parse_iso8601(value: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("invalid_decided_at")
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ValueError("invalid_decided_at") from exc
    if parsed.tzinfo is None:
        raise ValueError("decided_at_requires_timezone")
    return parsed


def validate_resolution(payload: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("resolution_must_be_object")
    missing = sorted(field for field in REQUIRED_FIELDS if not payload.get(field))
    if missing:
        raise ValueError(f"missing_resolution_fields:{','.join(missing)}")

    decision = str(payload["decision"])
    if decision not in ALLOWED_DECISIONS:
        raise ValueError(f"unsupported_decision:{decision}")
    if payload.get("core_write_allowed") not in (None, False):
        raise ValueError("direct_core_write_forbidden")
    if payload.get("apply_core_change") not in (None, False):
        raise ValueError("direct_core_write_forbidden")
    if not isinstance(payload["rationale"], str) or len(payload["rationale"].strip()) < 12:
        raise ValueError("rationale_too_short")
    if not isinstance(payload["decided_by"], str) or not payload["decided_by"].strip():
        raise ValueError("invalid_decided_by")
    _parse_iso8601(str(payload["decided_at"]))

    receipt = {
        "kind": "LITD_DESIGN_DECISION_RESOLUTION",
        "candidate_hash": str(payload["candidate_hash"]),
        "decision": decision,
        "rationale": payload["rationale"].strip(),
        "decided_by": payload["decided_by"].strip(),
        "decided_at": str(payload["decided_at"]),
        "evidence_refs": list(payload.get("evidence_refs", [])),
        "follow_up": payload.get("follow_up"),
        "core_write_allowed": False,
        "requires_new_change_and_tests": decision in {
            "REQUEST_IMPLEMENTATION_FIX",
            "PROPOSE_TARGET_REVISION",
        },
    }
    canonical = json.dumps(receipt, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    receipt["resolution_hash"] = sha256(canonical.encode("utf-8")).hexdigest()
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a governed LITD design decision resolution")
    parser.add_argument("resolution", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    payload = json.loads(args.resolution.read_text(encoding="utf-8"))
    receipt = validate_resolution(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"decision": receipt["decision"], "resolution_hash": receipt["resolution_hash"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
