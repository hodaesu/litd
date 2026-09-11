from tools.quality.design_decision_candidate import build_decision_candidate


def comparison(verdict="FARTHER_FROM_TARGET", severity="high", provisional=False):
    return {
        "comparison_hash": "c" * 64,
        "current_candidate_hash": "n" * 64,
        "baseline_candidate_hash": "b" * 64,
        "current_run_id": "200",
        "baseline_run_id": "100",
        "reports": [{
            "report": "roguelike-telemetry.json",
            "design_target_evaluation": {
                "evaluations": [{
                    "metric": "combat.boss_rounds",
                    "baseline": 8.4,
                    "current": 11.1,
                    "target": {"type": "window", "min": 5.5, "max": 10.5},
                    "verdict": verdict,
                    "severity": severity,
                    "provisional": provisional,
                }]
            },
        }],
    }


def test_blocking_regression_creates_review_candidate():
    result = build_decision_candidate([comparison()])
    assert result["status"] == "REQUIRES_DECISION"
    assert result["requires_human_or_governed_decision"] is True
    assert result["causes"][0]["metric"] == "combat.boss_rounds"
    assert result["evidence"][0]["baseline_run_id"] == "100"


def test_candidate_never_writes_core():
    result = build_decision_candidate([comparison()])
    assert result["core_write_allowed"] is False


def test_nonblocking_regression_does_not_create_decision():
    result = build_decision_candidate([comparison(severity="medium")])
    assert result["status"] == "NO_DECISION_REQUIRED"
    assert result["causes"] == []


def test_provisional_high_target_does_not_create_decision():
    result = build_decision_candidate([comparison(provisional=True)])
    assert result["status"] == "NO_DECISION_REQUIRED"


def test_in_target_does_not_create_decision():
    result = build_decision_candidate([comparison(verdict="IN_TARGET")])
    assert result["status"] == "NO_DECISION_REQUIRED"


def test_allowed_decisions_do_not_include_automatic_core_mutation():
    result = build_decision_candidate([comparison()])
    assert "APPLY_CORE_CHANGE" not in result["allowed_decisions"]
    assert "PROPOSE_TARGET_REVISION" in result["allowed_decisions"]
