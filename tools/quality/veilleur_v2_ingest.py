#!/usr/bin/env python3
"""Strict ingress gate between VEILLEUR V2 and the LITD knowledge system.

The adapter validates project scope, route, structure, provenance, integrity and
 duplication before anything reaches the LITD Trieur. It never writes to Core.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from hashlib import sha256
from typing import Any, Iterable
from urllib.parse import urlparse

from tools.quality.evidence_ledger import EvidenceLedger

PROJECT_ID = "LITD"
TARGET_ROUTE = "LITD_LIBRARY"

REQUIRED_FIELDS = {
    "project_id",
    "target_route",
    "evidence_id",
    "title",
    "summary",
    "source_url",
    "source_verified",
    "source_confidence",
    "discovered_at",
    "published_at",
    "domain_hints",
    "content_hash",
}


@dataclass(frozen=True)
class IngestDecision:
    accepted: bool
    status: str
    reason: str
    canonical_hash: str | None = None


def canonical_content_hash(
    title: str,
    summary: str,
    source_url: str,
    project_id: str = PROJECT_ID,
    target_route: str = TARGET_ROUTE,
) -> str:
    """Hash evidence together with its project and routing boundary."""
    payload = "\n".join(
        (
            project_id.strip(),
            target_route.strip(),
            title.strip(),
            summary.strip(),
            source_url.strip(),
        )
    )
    return sha256(payload.encode("utf-8")).hexdigest()


def _valid_iso8601(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def _valid_https_url(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def validate_event(
    event: dict[str, Any],
    *,
    known_evidence_ids: Iterable[str] = (),
    known_hashes: Iterable[str] = (),
) -> IngestDecision:
    if not isinstance(event, dict):
        return IngestDecision(False, "REJECTED", "event_not_object")

    missing = sorted(REQUIRED_FIELDS - set(event))
    if missing:
        return IngestDecision(False, "REJECTED", f"missing_fields:{','.join(missing)}")

    project_id = event["project_id"]
    target_route = event["target_route"]
    if project_id != PROJECT_ID:
        return IngestDecision(False, "REJECTED", "project_scope_mismatch")
    if target_route != TARGET_ROUTE:
        return IngestDecision(False, "REJECTED", "route_scope_mismatch")

    evidence_id = event["evidence_id"]
    title = event["title"]
    summary = event["summary"]
    source_url = event["source_url"]

    if not all(isinstance(v, str) and v.strip() for v in (evidence_id, title, summary)):
        return IngestDecision(False, "REJECTED", "invalid_identity_or_content")

    if not _valid_https_url(source_url):
        return IngestDecision(False, "REJECTED", "invalid_or_unencrypted_source_url")

    if event["source_verified"] is not True:
        return IngestDecision(False, "QUARANTINED", "source_not_verified")

    confidence = event["source_confidence"]
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not 0.0 <= float(confidence) <= 1.0:
        return IngestDecision(False, "REJECTED", "invalid_source_confidence")

    if not _valid_iso8601(event["discovered_at"]) or not _valid_iso8601(event["published_at"]):
        return IngestDecision(False, "REJECTED", "invalid_timestamp")

    hints = event["domain_hints"]
    if not isinstance(hints, list) or not hints or not all(isinstance(x, str) and x.strip() for x in hints):
        return IngestDecision(False, "REJECTED", "invalid_domain_hints")

    expected_hash = canonical_content_hash(title, summary, source_url, project_id, target_route)
    supplied_hash = event["content_hash"]
    if not isinstance(supplied_hash, str) or supplied_hash.casefold() != expected_hash:
        return IngestDecision(False, "REJECTED", "content_hash_mismatch", expected_hash)

    if evidence_id in set(known_evidence_ids):
        return IngestDecision(False, "DUPLICATE", "duplicate_evidence_id", expected_hash)

    if expected_hash in set(known_hashes):
        return IngestDecision(False, "DUPLICATE", "duplicate_canonical_content", expected_hash)

    return IngestDecision(True, "ACCEPTED_FOR_ROUTING", "validated", expected_hash)


def validate_and_record(event: dict[str, Any], ledger: EvidenceLedger) -> IngestDecision:
    """Validate against durable LITD-scoped history and persist the decision."""
    decision = validate_event(
        event,
        known_evidence_ids=ledger.known_evidence_ids(),
        known_hashes=ledger.known_hashes(),
    )
    evidence_id = str(event.get("evidence_id", "<missing>")) if isinstance(event, dict) else "<invalid>"
    ledger.append_decision(evidence_id, decision.status, decision.reason)

    if decision.accepted and decision.canonical_hash is not None:
        ledger.register_evidence(
            evidence_id,
            decision.canonical_hash,
            str(event["source_url"]),
        )
    return decision


def can_write_core(_: IngestDecision) -> bool:
    """Hard boundary: the ingress gate cannot authorize Core mutation."""
    return False
