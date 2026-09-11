from tools.quality.goalpost_review_candidate import build_goalpost_review_candidate


def report(verdict="GOALPOST_DRIFT_REVIEW_REQUIRED"):
    return {
        "kind": "LITD_GOALPOST_DRIFT_REPORT",
        "status": "REVIEW_REQUIRED" if verdict == "GOALPOST_DRIFT_REVIEW_REQUIRED" else "OK",
        "report_hash": "a" * 64,
        "measurement_source": "compatibility_safe_history",
        "signals": [{
            "target_id": "combat.boss_rounds",
            "verdict": verdict,
            "target_relaxation_ratio": 0.142857,
            "measurement_count": 4,
            "first_measurement": 11.5,
            "latest_measurement": 11.5,
            "measurement_improved_against_original_target": False,
            "comparison_identity": {
                "metric_family": "litd_balance_telemetry",
                "model_version": 2,
                "scenario": "first_veil_crypts",
                "seed_policy": "fixed",
                "seed_value": "20260821",
            },
        }],
    }


def test_goalpost_signal_creates_review_candidate():
    result = build_goalpost_review_candidate(report())
    assert result["status"] == "REQUIRES_DECISION"
    assert result["requires_human_or_governed_decision"] is True
    assert result["causes"][0]["target_id"] == "combat.boss_rounds"
    assert result["evidence"][0]["goalpost_report_hash"] == "a" * 64


def test_no_signal_requires_no_decision():
    result = build_goalpost_review_candidate(report("NO_GOALPOST_SIGNAL"))
    assert result["status"] == "NO_DECISION_REQUIRED"
    assert result["causes"] == []


def test_inconclusive_signal_is_not_promoted_to_decision():
    result = build_goalpost_review_candidate(report("INCONCLUSIVE"))
    assert result["status"] == "NO_DECISION_REQUIRED"


def test_candidate_never_writes_core_or_changes_targets_automatically():
    result = build_goalpost_review_candidate(report())
    assert result["core_write_allowed"] is False
    assert result["automatic_target_change_allowed"] is False


def test_allowed_decisions_require_governed_follow_up():
    result = build_goalpost_review_candidate(report())
    assert "APPLY_CORE_CHANGE" not in result["allowed_decisions"]
    assert "PROPOSE_TARGET_REVISION" in result["allowed_decisions"]
    assert "REQUEST_IMPLEMENTATION_FIX" in result["allowed_decisions"]


def test_candidate_hash_is_deterministic():
    first = build_goalpost_review_candidate(report())
    second = build_goalpost_review_candidate(report())
    assert first["candidate_hash"] == second["candidate_hash"]
