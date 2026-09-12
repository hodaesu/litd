#!/usr/bin/env python3
"""Close an authorized LITD change only after post-merge measurement and provenance.

The contract binds the governed application authorization to the exact merged
source commit, the exact post-merge measurement provenance, and the exact signed
Sigstore checkpoint. It never merges, rolls back, writes Core, or changes targets.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

EXPECTED_ISSUER = "https://token.actions.githubusercontent.com"


def _hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _hex(value: Any, length: int) -> bool:
    return isinstance(value, str) and len(value) == length and all(c in "0123456789abcdef" for c in value)


def _verify_embedded_hash(payload: dict[str, Any], field: str) -> None:
    claimed = payload.get(field)
    if not _hex(claimed, 64):
        raise ValueError(f"invalid {field}")
    unsigned = {key: value for key, value in payload.items() if key != field}
    if claimed != _hash(unsigned):
        raise ValueError(f"{field} integrity mismatch")


def _nonempty_strings(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(x, str) and x.strip() for x in value)


def evaluate(decision: dict[str, Any], evidence: dict[str, Any]) -> dict[str, Any]:
    _verify_embedded_hash(decision, "application_decision_hash")
    if decision.get("kind") != "LITD_APPLICATION_DECISION_RECEIPT":
        raise ValueError("invalid application decision receipt kind")
    if decision.get("outcome") != "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE":
        raise ValueError("application was not authorized for separate merge")
    if decision.get("merge_authorized") is not True:
        raise ValueError("merge authorization invariant missing")
    if decision.get("merge_must_be_separate_action") is not True:
        raise ValueError("separate merge invariant missing")
    if decision.get("post_merge_measurement_required") is not True:
        raise ValueError("post-merge measurement invariant missing")
    if decision.get("provenance_checkpoint_required") is not True:
        raise ValueError("provenance checkpoint invariant missing")
    for key in ("core_write_allowed", "automatic_merge_allowed", "automatic_application_allowed", "automatic_target_change_allowed"):
        if decision.get(key) is not False:
            raise ValueError(f"application decision authority violation:{key}")

    required = {
        "application_decision_hash", "repository", "merged_source_commit_sha",
        "merged_commit_sha", "merge_evidence_refs", "post_merge_assessment",
        "measurement_provenance_run_id", "measurement_source_commit_sha",
        "measurement_artifact_hashes", "checkpoint_source_commit_sha",
        "checkpoint_source_run_id", "checkpoint_hash", "sigstore_bundle_hash",
        "checkpoint_signature_verified", "checkpoint_transparency_log_verified",
        "checkpoint_workflow_identity", "checkpoint_oidc_issuer", "checkpoint_evidence_refs",
    }
    missing = sorted(required - set(evidence))
    if missing:
        raise ValueError("missing application closure evidence fields:" + ",".join(missing))
    if evidence["application_decision_hash"] != decision.get("application_decision_hash"):
        raise ValueError("application decision hash mismatch")

    authorized_source = decision.get("implementation_commit_sha")
    merged_source = evidence["merged_source_commit_sha"]
    merged_commit = evidence["merged_commit_sha"]
    measured_commit = evidence["measurement_source_commit_sha"]
    checkpoint_commit = evidence["checkpoint_source_commit_sha"]
    for label, value in (
        ("authorized implementation SHA", authorized_source),
        ("merged source SHA", merged_source),
        ("merged commit SHA", merged_commit),
        ("measurement source SHA", measured_commit),
        ("checkpoint source SHA", checkpoint_commit),
    ):
        if not _hex(value, 40):
            raise ValueError(f"{label} must be 40 lowercase hex")

    repository = evidence["repository"]
    if not isinstance(repository, str) or repository.count("/") != 1:
        raise ValueError("repository must be owner/name")
    if not _nonempty_strings(evidence["merge_evidence_refs"]):
        raise ValueError("merge evidence refs required")
    if not _nonempty_strings(evidence["checkpoint_evidence_refs"]):
        raise ValueError("checkpoint evidence refs required")
    if not _nonempty_strings(evidence["measurement_artifact_hashes"]):
        raise ValueError("measurement artifact hashes required")
    if not all(_hex(x, 64) for x in evidence["measurement_artifact_hashes"]):
        raise ValueError("measurement artifact hashes must be sha256 hex")
    for field in ("checkpoint_hash", "sigstore_bundle_hash"):
        if not _hex(evidence[field], 64):
            raise ValueError(f"{field} must be sha256 hex")
    if not isinstance(evidence["measurement_provenance_run_id"], int) or evidence["measurement_provenance_run_id"] <= 0:
        raise ValueError("measurement_provenance_run_id must be positive integer")
    if not isinstance(evidence["checkpoint_source_run_id"], int) or evidence["checkpoint_source_run_id"] <= 0:
        raise ValueError("checkpoint_source_run_id must be positive integer")

    expected_identity = f"https://github.com/{repository}/.github/workflows/provenance-checkpoint.yml@refs/heads/main"
    blockers: list[str] = []
    if authorized_source != merged_source:
        blockers.append("merged_source_not_authorized_implementation")
    if measured_commit != merged_commit:
        blockers.append("post_merge_measurement_not_bound_to_merge_commit")
    if checkpoint_commit != merged_commit:
        blockers.append("checkpoint_not_bound_to_merge_commit")
    if evidence["checkpoint_source_run_id"] != evidence["measurement_provenance_run_id"]:
        blockers.append("checkpoint_not_bound_to_measurement_provenance_run")
    if evidence["post_merge_assessment"] != "NO_BLOCKING_REGRESSION":
        blockers.append("post_merge_measurement_not_acceptable")
    if evidence["checkpoint_signature_verified"] is not True:
        blockers.append("checkpoint_signature_not_verified")
    if evidence["checkpoint_transparency_log_verified"] is not True:
        blockers.append("checkpoint_transparency_log_not_verified")
    if evidence["checkpoint_workflow_identity"] != expected_identity:
        blockers.append("checkpoint_workflow_identity_mismatch")
    if evidence["checkpoint_oidc_issuer"] != EXPECTED_ISSUER:
        blockers.append("checkpoint_oidc_issuer_mismatch")

    status = "APPLIED_MEASURED_PROVENANCE_VERIFIED" if not blockers else "POST_MERGE_CLOSURE_BLOCKED"
    result = {
        "kind": "LITD_APPLICATION_CLOSURE_RECEIPT",
        "status": status,
        "source_application_decision_hash": decision["application_decision_hash"],
        "source_candidate_hash": decision.get("source_candidate_hash"),
        "authorized_implementation_commit_sha": authorized_source,
        "merged_source_commit_sha": merged_source,
        "merged_commit_sha": merged_commit,
        "measurement_provenance_run_id": evidence["measurement_provenance_run_id"],
        "measurement_source_commit_sha": measured_commit,
        "measurement_artifact_hashes": list(evidence["measurement_artifact_hashes"]),
        "post_merge_assessment": evidence["post_merge_assessment"],
        "checkpoint_source_commit_sha": checkpoint_commit,
        "checkpoint_source_run_id": evidence["checkpoint_source_run_id"],
        "checkpoint_hash": evidence["checkpoint_hash"],
        "sigstore_bundle_hash": evidence["sigstore_bundle_hash"],
        "checkpoint_signature_verified": evidence["checkpoint_signature_verified"],
        "checkpoint_transparency_log_verified": evidence["checkpoint_transparency_log_verified"],
        "checkpoint_workflow_identity": evidence["checkpoint_workflow_identity"],
        "checkpoint_oidc_issuer": evidence["checkpoint_oidc_issuer"],
        "merge_evidence_refs": list(evidence["merge_evidence_refs"]),
        "checkpoint_evidence_refs": list(evidence["checkpoint_evidence_refs"]),
        "blockers": blockers,
        "rollback_review_required": "post_merge_measurement_not_acceptable" in blockers,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_rollback_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "post_merge_closure_receipt_only_no_automatic_mutation",
    }
    result["closure_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--decision", required=True)
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--output", default="reports/application-closure.json")
    args = parser.parse_args()
    decision = json.loads(Path(args.decision).read_text(encoding="utf-8"))
    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
    result = evaluate(decision, evidence)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "blockers": result["blockers"]}, sort_keys=True))
    return 0 if result["status"] == "APPLIED_MEASURED_PROVENANCE_VERIFIED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
