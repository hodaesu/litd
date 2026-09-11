from tools.quality.baseline_selector import (
    candidate_is_compatible,
    comparison_identity,
    select_latest_compatible_baseline,
)


def report_identity(*, scenario="first_veil_crypts", model=2, seed=20260821):
    return {
        "metric_family": "litd_balance_telemetry",
        "scenario": scenario,
        "model_version": model,
        "seed_policy": "fixed",
        "seed_value": seed,
    }


def candidate(hash_value, run_id, recorded_at, identity):
    return {
        "kind": "MEASUREMENT_CANDIDATE",
        "candidate_hash": hash_value,
        "run_id": str(run_id),
        "recorded_at": recorded_at,
        "reports": [{
            "report": "roguelike-telemetry.json",
            "comparison_identity": identity,
            "canonical_metrics": {"outcomes.retreat_rate": 0.5},
        }],
    }


def test_identity_uses_scenario_model_and_fixed_seed():
    identity = comparison_identity({
        "dungeon_id": "first_veil_crypts",
        "model_version": 2,
        "seed": 20260821,
    })
    assert identity == report_identity()


def test_same_scenario_model_and_seed_is_compatible():
    current = candidate("current", 3, "2026-09-11T08:00:00+00:00", report_identity())
    prior = candidate("prior", 2, "2026-09-11T07:00:00+00:00", report_identity())
    assert candidate_is_compatible(current, prior) is True


def test_different_model_is_rejected():
    current = candidate("current", 3, "2026-09-11T08:00:00+00:00", report_identity(model=2))
    prior = candidate("prior", 2, "2026-09-11T07:00:00+00:00", report_identity(model=1))
    assert candidate_is_compatible(current, prior) is False


def test_different_fixed_seed_is_rejected():
    current = candidate("current", 3, "2026-09-11T08:00:00+00:00", report_identity(seed=20260821))
    prior = candidate("prior", 2, "2026-09-11T07:00:00+00:00", report_identity(seed=123))
    assert candidate_is_compatible(current, prior) is False


def test_latest_compatible_candidate_wins():
    current = candidate("current", 4, "2026-09-11T09:00:00+00:00", report_identity())
    old = candidate("old", 1, "2026-09-11T06:00:00+00:00", report_identity())
    latest = candidate("latest", 3, "2026-09-11T08:00:00+00:00", report_identity())
    incompatible = candidate("wrong", 2, "2026-09-11T08:30:00+00:00", report_identity(model=1))
    selected = select_latest_compatible_baseline(current, [old, incompatible, latest])
    assert selected is latest


def test_no_compatible_baseline_returns_none():
    current = candidate("current", 3, "2026-09-11T08:00:00+00:00", report_identity())
    prior = candidate("wrong", 2, "2026-09-11T07:00:00+00:00", report_identity(scenario="other"))
    assert select_latest_compatible_baseline(current, [prior]) is None
