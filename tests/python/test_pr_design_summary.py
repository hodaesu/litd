from tools.quality.pr_design_summary import MARKER, build_pr_summary


def _comparison(*, verdict="IN_TARGET", severity="high", provisional=False, baseline=6.0, current=6.0):
    blocking = int(verdict == "FARTHER_FROM_TARGET" and severity == "high" and not provisional)
    farther = int(verdict == "FARTHER_FROM_TARGET")
    closer = int(verdict == "CLOSER_TO_TARGET")
    in_target = int(verdict == "IN_TARGET")
    return {
        "status": "BASELINE_COMPARISON_COMPLETE",
        "current_run_id": "200",
        "baseline_run_id": "100",
        "summary": {
            "closer_to_target": closer,
            "farther_from_target": farther,
            "in_target": in_target,
            "blocking_regressions": blocking,
        },
        "reports": [{
            "report": "roguelike-telemetry.json",
            "design_target_evaluation": {
                "evaluations": [{
                    "metric": "combat.boss_rounds",
                    "baseline": baseline,
                    "current": current,
                    "verdict": verdict,
                    "severity": severity,
                    "provisional": provisional,
                    "target": {"type": "window", "min": 5.5, "max": 10.5},
                }]
            },
        }],
    }


def test_blocking_regression_is_explicit_and_traceable():
    body = build_pr_summary([_comparison(verdict="FARTHER_FROM_TARGET", baseline=8.0, current=11.0)])
    assert MARKER in body
    assert "Gate bloquant :** OUI" in body
    assert "⛔ FARTHER_FROM_TARGET" in body
    assert "combat.boss_rounds" in body
    assert "100" in body and "200" in body
    assert "+3" in body


def test_nonblocking_regression_does_not_claim_block():
    body = build_pr_summary([_comparison(verdict="FARTHER_FROM_TARGET", severity="medium", baseline=6.0, current=7.0)])
    assert "Gate bloquant :** NON" in body
    assert "⚠️ FARTHER_FROM_TARGET" in body


def test_in_target_summary_is_positive_without_claiming_improvement():
    body = build_pr_summary([_comparison(verdict="IN_TARGET", baseline=6.0, current=6.0)])
    assert "restent dans les cibles" in body
    assert "✓ IN_TARGET" in body
    assert "Gate bloquant :** NON" in body


def test_no_compatible_baseline_is_informational():
    body = build_pr_summary([{
        "status": "NO_COMPATIBLE_BASELINE",
        "current_run_id": "300",
        "baseline_run_id": None,
        "summary": {"closer_to_target": 0, "farther_from_target": 0, "in_target": 0, "blocking_regressions": 0},
        "reports": [],
    }])
    assert "Aucune baseline compatible" in body
    assert "Gate bloquant :** NON" in body


def test_comment_reminds_that_ci_is_authority():
    body = build_pr_summary([_comparison()])
    assert "source d'autorité reste le gate CI" in body
