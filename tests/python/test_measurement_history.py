from tools.quality.measurement_history import build_history


def candidate(hash_value, run_id, recorded_at, identity, metric, value):
    return {
        "kind": "MEASUREMENT_CANDIDATE",
        "candidate_hash": hash_value,
        "run_id": run_id,
        "recorded_at": recorded_at,
        "reports": [{
            "report": f"{run_id}.json",
            "comparison_identity": identity,
            "canonical_metrics": {metric: value},
        }],
    }


def test_groups_incompatible_histories_separately():
    rows = [
        candidate("a", "1", "2026-01-01T00:00:00+00:00", {"model_version": 1, "scenario": "a"}, "x", 1),
        candidate("b", "2", "2026-01-02T00:00:00+00:00", {"model_version": 2, "scenario": "a"}, "x", 2),
    ]
    result = build_history(rows)
    assert result["group_count"] == 2
    assert result["accepted_measurement_count"] == 2


def test_orders_measurements_chronologically():
    identity = {"model_version": 1, "scenario": "a"}
    rows = [
        candidate("b", "2", "2026-01-02T00:00:00+00:00", identity, "x", 2),
        candidate("a", "1", "2026-01-01T00:00:00+00:00", identity, "x", 1),
    ]
    result = build_history(rows)
    measurements = result["groups"][0]["measurements"]
    assert [row["run_id"] for row in measurements] == ["1", "2"]


def test_deduplicates_same_candidate_report_identity():
    identity = {"model_version": 1, "scenario": "a"}
    row = candidate("a", "1", "2026-01-01T00:00:00+00:00", identity, "x", 1)
    result = build_history([row, row])
    assert result["accepted_measurement_count"] == 1


def test_rejects_non_measurement_candidates():
    result = build_history([{"kind": "OTHER"}])
    assert result["status"] == "EMPTY"
    assert result["rejected_candidate_count"] == 1


def test_never_allows_core_or_target_writes():
    identity = {"model_version": 1}
    result = build_history([candidate("a", "1", "2026-01-01T00:00:00+00:00", identity, "x", 1)])
    assert result["core_write_allowed"] is False
    assert result["automatic_target_change_allowed"] is False
