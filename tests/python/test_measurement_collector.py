import json
import tempfile
from pathlib import Path

from tools.quality.measurement_collector import build_measurement_candidate, collect_report


def github_env():
    return {
        "GITHUB_REPOSITORY": "hodaesu/litd",
        "GITHUB_SHA": "b" * 40,
        "GITHUB_RUN_ID": "999",
        "GITHUB_RUN_ATTEMPT": "1",
        "GITHUB_WORKFLOW": "Balance Telemetry",
        "GITHUB_JOB": "roguelike-telemetry",
    }


def test_collects_numeric_game_metrics_alerts_and_canonical_diagnostics():
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "telemetry.json"
        path.write_text(json.dumps({
            "outcomes": {"retreat_rate": 0.42, "wipe_rate": 0.11, "success_rate": 0.67},
            "expedition": {"average_rooms_cleared": 14.2, "average_duration": 39.5},
            "combat_rounds": {"combat": 3.0, "elite": 5.0, "boss": 8.0},
            "loot_rarity": {"legendary": {"share": 0.01}},
            "classes": {
                "a": {"win_rate": 0.55, "survival_rate": 0.80},
                "b": {"win_rate": 0.61, "survival_rate": 0.74},
            },
            "alerts": [{"severity": "medium", "code": "example"}],
            "seed": 12345,
        }), encoding="utf-8")
        result = collect_report(path)
        assert result["metrics"]["outcomes.retreat_rate"] == 0.42
        assert result["metrics"]["expedition.average_duration"] == 39.5
        assert "seed" not in result["metrics"]
        assert result["alerts"]["medium"] == 1
        assert len(result["report_sha256"]) == 64
        assert result["canonical_metrics"]["outcomes.retreat_rate"] == 0.42
        assert result["canonical_metrics"]["expedition.visited_rooms"] == 14.2
        assert result["canonical_metrics"]["combat.boss_rounds"] == 8.0
        assert result["design_target_evaluation"]["overall_verdict"] == "ALIGNED_OR_IMPROVING"
        assert result["mapping_coverage"]["mapped_target_count"] >= 8
        # average_duration is intentionally not guessed into duration_minutes.
        assert "expedition.duration_minutes" not in result["canonical_metrics"]


def test_candidate_is_linked_to_real_github_execution():
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "balance.json"
        path.write_text(json.dumps({"average_rounds": 4.2, "alerts": []}), encoding="utf-8")
        candidate = build_measurement_candidate([path], env=github_env())
        assert candidate["kind"] == "MEASUREMENT_CANDIDATE"
        assert candidate["commit_sha"] == "b" * 40
        assert candidate["run_id"] == "999"
        assert candidate["summary"]["eligible_for_promotion"] is True
        assert candidate["summary"]["canonical_metric_count"] == 0
        assert candidate["promotion_rule"] == "requires_matching_CORE_DECISION_COMMIT_TEST_chain"
        assert len(candidate["candidate_hash"]) == 64


def test_high_alert_blocks_automatic_promotion_eligibility():
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "balance.json"
        path.write_text(json.dumps({
            "average_rounds": 11.0,
            "alerts": [{"severity": "high", "code": "boss_round_window"}],
        }), encoding="utf-8")
        candidate = build_measurement_candidate([path], env=github_env())
        assert candidate["summary"]["high_alerts"] == 1
        assert candidate["summary"]["eligible_for_promotion"] is False


def test_missing_github_identity_is_rejected():
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "balance.json"
        path.write_text(json.dumps({"average_rounds": 4.0}), encoding="utf-8")
        try:
            build_measurement_candidate([path], env={})
        except ValueError as exc:
            assert "missing_github_environment" in str(exc)
        else:
            raise AssertionError("measurement must be tied to a real GitHub execution")
