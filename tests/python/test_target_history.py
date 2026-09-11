from copy import deepcopy

from tools.quality.target_history import (
    build_trend_report,
    compute_snapshot_hash,
    snapshot_from_registry,
    validate_chain,
)


def registry(max_value=10.0):
    return {
        "targets": {
            "combat.boss_rounds": {
                "type": "max",
                "max": max_value,
                "severity": "high",
            }
        }
    }


def make_snapshot(reg, sequence, previous=None):
    return snapshot_from_registry(
        reg,
        sequence=sequence,
        previous_snapshot_hash=previous,
        recorded_at=f"2026-09-{sequence:02d}T12:00:00+02:00",
        source_ref=f"commit-{sequence}",
        evidence_refs=[f"evidence-{sequence}"],
    )


def test_single_snapshot_history_is_valid_and_stable():
    snap = make_snapshot(registry(), 1)
    assert validate_chain([snap]) == []
    report = build_trend_report([snap])
    assert report["status"] == "OK"
    assert report["snapshot_count"] == 1
    assert report["summary"]["changed_target_count"] == 0


def test_hash_chain_accepts_valid_second_snapshot():
    first = make_snapshot(registry(), 1)
    second = make_snapshot(registry(11.0), 2, first["snapshot_hash"])
    assert validate_chain([second, first]) == []


def test_hash_chain_rejects_wrong_previous_hash():
    first = make_snapshot(registry(), 1)
    second = make_snapshot(registry(11.0), 2, "0" * 64)
    errors = validate_chain([first, second])
    assert any("previous_hash_mismatch" in error for error in errors)


def test_snapshot_tampering_is_detected():
    snap = make_snapshot(registry(), 1)
    tampered = deepcopy(snap)
    tampered["targets"]["combat.boss_rounds"]["max"] = 99.0
    errors = validate_chain([tampered])
    assert any("snapshot_hash_mismatch" in error for error in errors)


def test_trajectory_reports_cumulative_permissive_drift():
    first = make_snapshot(registry(10.0), 1)
    second = make_snapshot(registry(10.5), 2, first["snapshot_hash"])
    third = make_snapshot(registry(11.0), 3, second["snapshot_hash"])
    report = build_trend_report([first, second, third])
    row = report["targets"][0]
    assert row["status"] == "MORE_PERMISSIVE"
    assert round(row["cumulative_relaxation_ratio"], 6) == 0.1
    assert row["revision_count"] == 2


def test_trajectory_reports_stricter_end_state():
    first = make_snapshot(registry(10.0), 1)
    second = make_snapshot(registry(9.0), 2, first["snapshot_hash"])
    report = build_trend_report([first, second])
    assert report["targets"][0]["status"] == "STRICTER"
    assert report["summary"]["stricter_count"] == 1


def test_direct_core_write_is_detected_even_with_recomputed_hash():
    snap = make_snapshot(registry(), 1)
    snap["core_write_allowed"] = True
    snap["snapshot_hash"] = compute_snapshot_hash(snap)
    errors = validate_chain([snap])
    assert any("direct_core_write_forbidden" in error for error in errors)
