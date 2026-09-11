from tools.quality.measurement_comparator import compare_metric, compare_measurement_sets


def metric(value, *, family="balance", model=2, scenario="vs001", seed_policy="fixed", samples=1000, stddev=1.0):
    return {
        "value": value,
        "metric_family": family,
        "model_version": model,
        "scenario": scenario,
        "seed_policy": seed_policy,
        "samples": samples,
        "stddev": stddev,
    }


def test_higher_is_better_can_improve():
    row = compare_metric(metric="success_rate", baseline=metric(0.50, stddev=0.05), current=metric(0.60, stddev=0.05), direction="higher_is_better", practical_threshold=0.02)
    assert row.verdict == "IMPROVED"


def test_lower_is_better_can_regress():
    row = compare_metric(metric="crash_rate", baseline=metric(0.01, stddev=0.001), current=metric(0.05, stddev=0.001), direction="lower_is_better", practical_threshold=0.005)
    assert row.verdict == "REGRESSED"


def test_small_delta_is_not_called_improvement():
    row = compare_metric(metric="success_rate", baseline=metric(0.50), current=metric(0.505), direction="higher_is_better", practical_threshold=0.01)
    assert row.verdict == "NO_SIGNIFICANT_CHANGE"


def test_sampling_uncertainty_prevents_overclaim():
    row = compare_metric(metric="rounds", baseline=metric(5.0, samples=20, stddev=2.0), current=metric(4.8, samples=20, stddev=2.0), direction="lower_is_better", practical_threshold=0.01)
    assert row.verdict == "NO_SIGNIFICANT_CHANGE"
    assert row.reason == "within_sampling_uncertainty"


def test_incompatible_baseline_is_inconclusive():
    row = compare_metric(metric="success_rate", baseline=metric(0.5, model=1), current=metric(0.6, model=2), direction="higher_is_better")
    assert row.verdict == "INCONCLUSIVE"


def test_regression_dominates_overall_verdict_and_never_writes_core():
    baseline = {
        "success_rate": metric(0.5, stddev=0.05),
        "crash_rate": metric(0.01, stddev=0.001),
    }
    current = {
        "success_rate": metric(0.6, stddev=0.05),
        "crash_rate": metric(0.04, stddev=0.001),
    }
    policy = {
        "success_rate": {"direction": "higher_is_better", "practical_threshold": 0.01},
        "crash_rate": {"direction": "lower_is_better", "practical_threshold": 0.005},
    }
    result = compare_measurement_sets(baseline, current, policy)
    assert result["overall_verdict"] == "REGRESSED"
    assert result["core_write_allowed"] is False
