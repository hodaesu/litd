from tools.quality.measurement_target_binding import build_binding


def snap(seq, recorded_at, h):
    return {
        "sequence": seq,
        "recorded_at": recorded_at,
        "snapshot_hash": h * 64,
        "registry_hash": h * 64,
    }


def history(*rows):
    return {
        "kind": "LITD_MEASUREMENT_HISTORY",
        "groups": [{
            "comparison_identity": {"metric_family": "x", "model_version": 1, "scenario": "s", "seed_policy": "fixed", "seed_value": 1},
            "measurements": list(rows),
        }],
    }


def row(at, value=1.0):
    return {"recorded_at": at, "candidate_hash": "c" * 64, "run_id": "1", "report": "r.json", "canonical_metrics": {"x": value}}


def test_binds_measurement_to_latest_effective_snapshot():
    result = build_binding(
        [snap(1, "2026-09-01T00:00:00+00:00", "a"), snap(2, "2026-09-10T00:00:00+00:00", "b")],
        history(row("2026-09-11T00:00:00+00:00")),
    )
    assert result["status"] == "OK"
    assert result["bindings"][0]["binding_status"] == "BOUND"
    assert result["bindings"][0]["target_sequence"] == 2


def test_measurement_before_first_snapshot_is_unbound():
    result = build_binding([snap(1, "2026-09-10T00:00:00+00:00", "a")], history(row("2026-09-01T00:00:00+00:00")))
    assert result["bindings"][0]["binding_status"] == "UNBOUND"
    assert result["bindings"][0]["reason"] == "measurement_precedes_first_target_snapshot"


def test_naive_measurement_time_fails_closed():
    result = build_binding([snap(1, "2026-09-01T00:00:00+00:00", "a")], history(row("2026-09-11T00:00:00")))
    assert result["bindings"][0]["binding_status"] == "UNBOUND"
    assert result["bindings"][0]["reason"] == "invalid_or_naive_measurement_time"


def test_naive_snapshot_time_invalidates_timeline():
    result = build_binding([snap(1, "2026-09-01T00:00:00", "a")], history(row("2026-09-11T00:00:00+00:00")))
    assert result["status"] == "INVALID_TARGET_TIMELINE"
    assert result["bindings"][0]["reason"] == "invalid_target_timeline"


def test_duplicate_effective_time_is_ambiguous_and_invalid():
    result = build_binding(
        [snap(1, "2026-09-01T00:00:00+00:00", "a"), snap(2, "2026-09-01T00:00:00+00:00", "b")],
        history(row("2026-09-11T00:00:00+00:00")),
    )
    assert result["status"] == "INVALID_TARGET_TIMELINE"


def test_binding_never_writes_core_or_targets():
    result = build_binding([snap(1, "2026-09-01T00:00:00+00:00", "a")], history(row("2026-09-11T00:00:00+00:00")))
    assert result["core_write_allowed"] is False
    assert result["automatic_target_change_allowed"] is False
