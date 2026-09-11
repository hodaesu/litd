from tools.quality.design_target_evaluator import evaluate_design_targets, evaluate_metric_against_target


def test_inside_window_is_in_target():
    rule = {"type": "window", "min": 35, "max": 45, "severity": "high"}
    row = evaluate_metric_against_target("expedition.duration_minutes", baseline=50, current=40, rule=rule)
    assert row.verdict == "IN_TARGET"
    assert row.current_distance == 0


def test_outside_window_can_move_closer():
    rule = {"type": "window", "min": 35, "max": 45, "severity": "high"}
    row = evaluate_metric_against_target("expedition.duration_minutes", baseline=55, current=49, rule=rule)
    assert row.verdict == "CLOSER_TO_TARGET"
    assert row.baseline_distance == 10
    assert row.current_distance == 4


def test_outside_window_can_move_farther():
    rule = {"type": "window", "min": 35, "max": 45, "severity": "high"}
    row = evaluate_metric_against_target("expedition.duration_minutes", baseline=49, current=55, rule=rule)
    assert row.verdict == "FARTHER_FROM_TARGET"


def test_max_target_works_for_wipe_rate():
    rule = {"type": "max", "max": 0.18, "severity": "high"}
    row = evaluate_metric_against_target("outcomes.wipe_rate", baseline=0.24, current=0.20, rule=rule)
    assert row.verdict == "CLOSER_TO_TARGET"


def test_missing_measurement_is_inconclusive():
    rule = {"type": "window", "min": 2, "max": 4, "severity": "medium"}
    row = evaluate_metric_against_target("combat.normal_rounds", baseline=3, current=None, rule=rule)
    assert row.verdict == "INCONCLUSIVE"


def test_high_non_provisional_regression_dominates():
    registry = {
        "targets": {
            "critical": {"type": "max", "max": 10, "severity": "high"},
            "provisional": {"type": "max", "max": 10, "severity": "high", "provisional": True},
        }
    }
    result = evaluate_design_targets(current={"critical": 20, "provisional": 30}, baseline={"critical": 11, "provisional": 20}, registry=registry)
    assert result["overall_verdict"] == "DESIGN_REGRESSION"
    assert result["summary"]["blocking_regressions"] == 1
    assert result["core_write_allowed"] is False


def test_provisional_target_cannot_block_design_verdict():
    registry = {"targets": {"fps": {"type": "max", "max": 33.34, "severity": "high", "provisional": True}}}
    result = evaluate_design_targets(current={"fps": 50}, baseline={"fps": 40}, registry=registry)
    assert result["summary"]["blocking_regressions"] == 0
    assert result["core_write_allowed"] is False
