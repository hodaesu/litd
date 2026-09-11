from tools.quality.design_regression_gate import blocking_regressions, evaluate_gate


def comparison(*rows):
    return {
        "current_run_id": "200",
        "baseline_run_id": "100",
        "comparison_hash": "a" * 64,
        "design_target_evaluation": {"evaluations": list(rows)},
    }


def row(verdict="IN_TARGET", severity="high", provisional=False, metric="combat.boss_rounds"):
    return {
        "metric": metric,
        "verdict": verdict,
        "severity": severity,
        "provisional": provisional,
        "current": 12.0,
        "baseline": 8.0,
    }


def test_high_non_provisional_farther_blocks():
    result = evaluate_gate([comparison(row(verdict="FARTHER_FROM_TARGET"))])
    assert result["blocked"] is True
    assert result["failure_count"] == 1


def test_medium_regression_does_not_block():
    result = evaluate_gate([comparison(row(verdict="FARTHER_FROM_TARGET", severity="medium"))])
    assert result["blocked"] is False


def test_provisional_high_regression_does_not_block():
    result = evaluate_gate([comparison(row(verdict="FARTHER_FROM_TARGET", provisional=True))])
    assert result["blocked"] is False


def test_in_target_does_not_block():
    result = evaluate_gate([comparison(row(verdict="IN_TARGET"))])
    assert result["blocked"] is False


def test_inconclusive_comparison_does_not_invent_failure():
    result = evaluate_gate([{"design_target_evaluation": {"evaluations": []}}])
    assert result["blocked"] is False


def test_gate_never_writes_core():
    result = evaluate_gate([comparison(row())])
    assert result["core_write_allowed"] is False
