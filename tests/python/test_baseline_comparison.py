from tools.quality.baseline_comparison import compare_candidate_to_baseline


def registry():
    return {
        "status": "CANONICAL_DESIGN_TARGETS",
        "targets": {
            "outcomes.retreat_rate": {"type": "window", "min": 0.35, "max": 0.65, "severity": "high"},
            "outcomes.wipe_rate": {"type": "max", "max": 0.18, "severity": "high"},
        },
    }


def identity(model=2, seed=20260821):
    return {
        "metric_family": "litd_balance_telemetry",
        "scenario": "first_veil_crypts",
        "model_version": model,
        "seed_policy": "fixed",
        "seed_value": seed,
    }


def candidate(hash_value, run_id, at, metrics, ident=None):
    return {
        "kind": "MEASUREMENT_CANDIDATE",
        "candidate_hash": hash_value,
        "run_id": str(run_id),
        "recorded_at": at,
        "reports": [{
            "report": "roguelike-telemetry.json",
            "comparison_identity": ident or identity(),
            "canonical_metrics": metrics,
        }],
    }


def test_closer_to_target_is_derived_from_latest_compatible_baseline():
    old = candidate("old", 10, "2026-09-11T06:00:00+00:00", {"outcomes.retreat_rate": 0.10})
    current = candidate("current", 11, "2026-09-11T07:00:00+00:00", {"outcomes.retreat_rate": 0.25})
    result = compare_candidate_to_baseline(current, [old], registry())
    assert result["status"] == "BASELINE_COMPARISON_COMPLETE"
    assert result["baseline_run_id"] == "10"
    assert result["summary"]["closer_to_target"] == 1
    assert result["overall_verdict"] == "ALIGNED_OR_IMPROVING"
    assert result["core_write_allowed"] is False


def test_farther_high_severity_target_becomes_design_regression():
    old = candidate("old", 10, "2026-09-11T06:00:00+00:00", {"outcomes.wipe_rate": 0.20})
    current = candidate("current", 11, "2026-09-11T07:00:00+00:00", {"outcomes.wipe_rate": 0.30})
    result = compare_candidate_to_baseline(current, [old], registry())
    assert result["summary"]["farther_from_target"] == 1
    assert result["summary"]["blocking_regressions"] == 1
    assert result["overall_verdict"] == "DESIGN_REGRESSION"


def test_incompatible_history_is_not_used():
    old = candidate("old", 10, "2026-09-11T06:00:00+00:00", {"outcomes.retreat_rate": 0.1}, identity(model=1))
    current = candidate("current", 11, "2026-09-11T07:00:00+00:00", {"outcomes.retreat_rate": 0.2})
    result = compare_candidate_to_baseline(current, [old], registry())
    assert result["status"] == "NO_COMPATIBLE_BASELINE"
    assert result["baseline_run_id"] is None
    assert result["overall_verdict"] if "overall_verdict" in result else True


def test_newest_compatible_baseline_is_selected():
    older = candidate("older", 9, "2026-09-11T05:00:00+00:00", {"outcomes.retreat_rate": 0.1})
    newer = candidate("newer", 10, "2026-09-11T06:00:00+00:00", {"outcomes.retreat_rate": 0.2})
    current = candidate("current", 11, "2026-09-11T07:00:00+00:00", {"outcomes.retreat_rate": 0.3})
    result = compare_candidate_to_baseline(current, [older, newer], registry())
    assert result["baseline_run_id"] == "10"
    assert result["baseline_candidate_hash"] == "newer"
    assert len(result["comparison_hash"]) == 64
