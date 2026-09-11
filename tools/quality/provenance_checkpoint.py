#!/usr/bin/env python3
"""Build and validate deterministic LITD provenance checkpoints.

The checkpoint anchors one successful Measurement Provenance run to the exact
Git commit, latest canonical target-history snapshot, and hashes of every
retained provenance artifact. Cryptographic signing is intentionally delegated
to a standard external signer (Sigstore/Cosign); this module never implements
cryptography beyond SHA-256 content addressing and never writes Core state.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

from tools.quality.target_history import validate_chain

KIND = "LITD_PROVENANCE_CHECKPOINT"
VERSION = 1
HEX64 = set("0123456789abcdef")


def canonical_hash(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def file_hash(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def checkpoint_body(checkpoint: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in checkpoint.items() if key != "checkpoint_hash"}


def compute_checkpoint_hash(checkpoint: dict[str, Any]) -> str:
    return canonical_hash(checkpoint_body(checkpoint))


def artifact_manifest(root: Path) -> list[dict[str, Any]]:
    if not root.is_dir():
        raise ValueError("artifact_root_required")
    rows: list[dict[str, Any]] = []
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        rows.append({
            "path": path.relative_to(root).as_posix(),
            "sha256": file_hash(path),
            "size_bytes": path.stat().st_size,
        })
    if not rows:
        raise ValueError("artifact_manifest_empty")
    return rows


def build_checkpoint(
    snapshots: list[dict[str, Any]],
    artifact_root: Path,
    *,
    repository: str,
    source_run_id: str,
    source_run_attempt: str,
    source_commit_sha: str,
    source_ref: str,
    source_completed_at: str,
) -> dict[str, Any]:
    errors = validate_chain(snapshots)
    if errors:
        raise ValueError("invalid_target_history:" + ",".join(errors))
    if not repository or "/" not in repository:
        raise ValueError("repository_required")
    if len(source_commit_sha) != 40 or any(c not in HEX64 for c in source_commit_sha):
        raise ValueError("invalid_source_commit_sha")

    ordered = sorted(snapshots, key=lambda row: row["sequence"])
    latest = ordered[-1]
    checkpoint = {
        "kind": KIND,
        "version": VERSION,
        "repository": repository,
        "source": {
            "workflow": "Measurement Provenance",
            "run_id": str(source_run_id),
            "run_attempt": str(source_run_attempt),
            "commit_sha": source_commit_sha,
            "ref": source_ref,
            "completed_at": source_completed_at,
        },
        "target_anchor": {
            "sequence": latest["sequence"],
            "snapshot_hash": latest["snapshot_hash"],
            "registry_hash": latest["registry_hash"],
            "recorded_at": latest.get("recorded_at"),
        },
        "artifact_manifest": artifact_manifest(artifact_root),
        "signature_policy": {
            "scheme": "sigstore_keyless_oidc",
            "oidc_issuer": "https://token.actions.githubusercontent.com",
            "transparency_log_required": True,
            "external_verification_required": True,
        },
        "authority": "evidence_anchor_only_core_or_human_decision_required",
        "core_write_allowed": False,
        "automatic_target_change_allowed": False,
    }
    checkpoint["checkpoint_hash"] = compute_checkpoint_hash(checkpoint)
    return checkpoint


def validate_checkpoint(checkpoint: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if checkpoint.get("kind") != KIND:
        errors.append("invalid_kind")
    if checkpoint.get("version") != VERSION:
        errors.append("invalid_version")
    if checkpoint.get("core_write_allowed") is not False:
        errors.append("direct_core_write_forbidden")
    if checkpoint.get("automatic_target_change_allowed") is not False:
        errors.append("automatic_target_change_forbidden")
    policy = checkpoint.get("signature_policy")
    if not isinstance(policy, dict) or policy.get("scheme") != "sigstore_keyless_oidc":
        errors.append("invalid_signature_policy")
    elif policy.get("transparency_log_required") is not True:
        errors.append("transparency_log_required")
    manifest = checkpoint.get("artifact_manifest")
    if not isinstance(manifest, list) or not manifest:
        errors.append("artifact_manifest_required")
    else:
        seen: set[str] = set()
        for row in manifest:
            if not isinstance(row, dict):
                errors.append("invalid_artifact_entry")
                continue
            path = row.get("path")
            digest = row.get("sha256")
            if not isinstance(path, str) or not path or path in seen:
                errors.append("invalid_or_duplicate_artifact_path")
            else:
                seen.add(path)
            if not isinstance(digest, str) or len(digest) != 64 or any(c not in HEX64 for c in digest):
                errors.append("invalid_artifact_hash")
    value = checkpoint.get("checkpoint_hash")
    if not isinstance(value, str) or len(value) != 64 or any(c not in HEX64 for c in value):
        errors.append("invalid_checkpoint_hash")
    elif value != compute_checkpoint_hash(checkpoint):
        errors.append("checkpoint_hash_mismatch")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a signable LITD provenance checkpoint")
    parser.add_argument("--snapshots", nargs="+", type=Path, required=True)
    parser.add_argument("--artifact-root", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--source-run-id", required=True)
    parser.add_argument("--source-run-attempt", required=True)
    parser.add_argument("--source-commit-sha", required=True)
    parser.add_argument("--source-ref", required=True)
    parser.add_argument("--source-completed-at", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snapshots = [json.loads(path.read_text(encoding="utf-8")) for path in args.snapshots]
    checkpoint = build_checkpoint(
        snapshots,
        args.artifact_root,
        repository=args.repository,
        source_run_id=args.source_run_id,
        source_run_attempt=args.source_run_attempt,
        source_commit_sha=args.source_commit_sha,
        source_ref=args.source_ref,
        source_completed_at=args.source_completed_at,
    )
    errors = validate_checkpoint(checkpoint)
    if errors:
        raise SystemExit("checkpoint validation failed: " + ",".join(errors))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(checkpoint, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "READY_FOR_EXTERNAL_SIGNATURE", "checkpoint_hash": checkpoint["checkpoint_hash"], "artifact_count": len(checkpoint["artifact_manifest"])}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
