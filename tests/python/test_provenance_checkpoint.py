import json
from pathlib import Path

import pytest

from tools.quality.provenance_checkpoint import (
    build_checkpoint,
    compute_checkpoint_hash,
    validate_checkpoint,
)
from tools.quality.target_history import compute_snapshot_hash


def snapshot() -> dict:
    row = {
        "kind": "LITD_TARGET_HISTORY_SNAPSHOT",
        "sequence": 1,
        "recorded_at": "2026-09-11T09:26:38+00:00",
        "source_ref": "a" * 40,
        "registry_hash": "b" * 64,
        "previous_snapshot_hash": None,
        "evidence_refs": ["test"],
        "targets": {"x": {"type": "max", "max": 10.0}},
        "core_write_allowed": False,
    }
    row["snapshot_hash"] = compute_snapshot_hash(row)
    return row


def build(tmp_path: Path) -> dict:
    root = tmp_path / "artifacts"
    root.mkdir()
    (root / "measurement-history.json").write_text('{"kind":"history"}\n', encoding="utf-8")
    return build_checkpoint(
        [snapshot()], root,
        repository="hodaesu/litd",
        source_run_id="123",
        source_run_attempt="1",
        source_commit_sha="c" * 40,
        source_ref="main",
        source_completed_at="2026-09-11T13:00:00+00:00",
    )


def test_checkpoint_is_deterministic_and_valid(tmp_path):
    first = build(tmp_path)
    assert validate_checkpoint(first) == []
    assert first["checkpoint_hash"] == compute_checkpoint_hash(first)
    assert first["core_write_allowed"] is False
    assert first["automatic_target_change_allowed"] is False


def test_checkpoint_anchors_latest_target_snapshot(tmp_path):
    checkpoint = build(tmp_path)
    assert checkpoint["target_anchor"]["sequence"] == 1
    assert checkpoint["target_anchor"]["snapshot_hash"] == snapshot()["snapshot_hash"]


def test_manifest_hashes_artifact_bytes(tmp_path):
    checkpoint = build(tmp_path)
    row = checkpoint["artifact_manifest"][0]
    assert row["path"] == "measurement-history.json"
    assert len(row["sha256"]) == 64
    assert row["size_bytes"] > 0


def test_tampering_is_detected_even_if_shape_remains_valid(tmp_path):
    checkpoint = build(tmp_path)
    checkpoint["source"]["run_id"] = "999"
    assert "checkpoint_hash_mismatch" in validate_checkpoint(checkpoint)


def test_direct_core_write_is_forbidden_even_with_recomputed_hash(tmp_path):
    checkpoint = build(tmp_path)
    checkpoint["core_write_allowed"] = True
    checkpoint["checkpoint_hash"] = compute_checkpoint_hash(checkpoint)
    assert "direct_core_write_forbidden" in validate_checkpoint(checkpoint)


def test_transparency_log_requirement_cannot_be_disabled(tmp_path):
    checkpoint = build(tmp_path)
    checkpoint["signature_policy"]["transparency_log_required"] = False
    checkpoint["checkpoint_hash"] = compute_checkpoint_hash(checkpoint)
    assert "transparency_log_required" in validate_checkpoint(checkpoint)


def test_empty_artifact_directory_fails_closed(tmp_path):
    root = tmp_path / "empty"
    root.mkdir()
    with pytest.raises(ValueError, match="artifact_manifest_empty"):
        build_checkpoint(
            [snapshot()], root,
            repository="hodaesu/litd",
            source_run_id="123",
            source_run_attempt="1",
            source_commit_sha="c" * 40,
            source_ref="main",
            source_completed_at="2026-09-11T13:00:00+00:00",
        )
