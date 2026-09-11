from tools.quality.target_drift_budget import evaluate_drift_budget, relaxation_ratio


def reg(targets):
    return {"status": "CANONICAL_DESIGN_TARGETS", "targets": targets}


def budgets(rows=None):
    return {"status": "TARGET_DRIFT_BUDGETS", "targets": rows or {}}


def test_max_relaxation_detected():
    result = relaxation_ratio({"type": "max", "max": 10}, {"type": "max", "max": 12})
    assert result["status"] == "MORE_PERMISSIVE"
    assert round(result["ratio"], 3) == 0.2


def test_min_relaxation_detected():
    result = relaxation_ratio({"type": "min", "min": 10}, {"type": "min", "min": 8})
    assert result["status"] == "MORE_PERMISSIVE"
    assert round(result["ratio"], 3) == 0.2


def test_window_relaxation_uses_frozen_baseline_width():
    result = relaxation_ratio(
        {"type": "window", "min": 5, "max": 10},
        {"type": "window", "min": 4, "max": 12},
    )
    assert result["status"] == "MORE_PERMISSIVE"
    assert round(result["ratio"], 3) == 0.6


def test_missing_budget_requires_review_not_invented_limit():
    result = evaluate_drift_budget(
        reg({"combat.boss_rounds": {"type": "max", "max": 10, "severity": "high"}}),
        reg({"combat.boss_rounds": {"type": "max", "max": 11, "severity": "high"}}),
        budgets(),
    )
    assert result["status"] == "REVIEW_REQUIRED"
    assert result["summary"]["blocking_count"] == 0
    assert result["core_write_allowed"] is False


def test_approved_budget_can_be_exceeded():
    result = evaluate_drift_budget(
        reg({"x": {"type": "max", "max": 10}}),
        reg({"x": {"type": "max", "max": 12}}),
        budgets({"x": {"status": "APPROVED", "max_cumulative_relaxation_ratio": 0.1}}),
    )
    assert result["status"] == "DRIFT_BUDGET_EXCEEDED"
    assert result["summary"]["blocking_targets"] == ["x"]


def test_approved_budget_can_contain_small_relaxation():
    result = evaluate_drift_budget(
        reg({"x": {"type": "max", "max": 10}}),
        reg({"x": {"type": "max", "max": 10.5}}),
        budgets({"x": {"status": "APPROVED", "max_cumulative_relaxation_ratio": 0.1}}),
    )
    assert result["status"] == "WITHIN_APPROVED_BUDGET"


def test_stricter_target_does_not_consume_drift_budget():
    result = evaluate_drift_budget(
        reg({"x": {"type": "max", "max": 10}}),
        reg({"x": {"type": "max", "max": 9}}),
        budgets(),
    )
    assert result["status"] == "NO_PERMISSIVE_DRIFT"
