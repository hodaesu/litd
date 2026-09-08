import json
from pathlib import Path

from tools.playtest.triage_veilleurs_playtests import build_triage

SCENARIOS = [
    "first_session_onboarding",
    "combat_decision_readability",
    "anatomy_causality",
    "fear_madness_clarity",
    "exploration_route_clarity",
    "sanctuary_consequence_loop",
]


def _write_pack(root: Path, *, blocking_scenario: str | None = None) -> None:
    testers = [f"naive-{i:02d}" for i in range(1, 6)]
    (root / "PACK_MANIFEST.json").write_text(
        json.dumps(
            {
                "build_commit": "abc123",
                "validation_status": "NOT_RUN",
                "testers": testers,
            }
        ),
        encoding="utf-8",
    )
    for tester in testers:
        folder = root / tester
        folder.mkdir()
        lines = []
        for scenario in SCENARIOS:
            lines.append(
                json.dumps(
                    {
                        "tester_id": tester,
                        "build_commit": "abc123",
                        "platform": "windows",
                        "scenario_id": scenario,
                        "first_action": "observed",
                        "hesitation_count": 0,
                        "help_request_count": 0,
                        "coach_intervention_count": 0,
                        "misinput_count": 0,
                        "blocking_issue_count": 1 if scenario == blocking_scenario else 0,
                        "player_explanation": "explication spontanée",
                        "observer_notes": "notes",
                    },
                    ensure_ascii=False,
                )
            )
        (folder / "measurement_events.jsonl").write_text(
            "\n".join(lines) + "\n", encoding="utf-8"
        )


def test_clean_pack_is_only_ready_for_human_review(tmp_path: Path):
    _write_pack(tmp_path)
    triage = build_triage(tmp_path)

    assert triage["data_errors"] == []
    assert triage["automatic_human_gate_decision"] == "FORBIDDEN"
    assert triage["automatic_maturity_transition"] == "FORBIDDEN"
    assert triage["rules"]["registry_write_allowed"] is False
    assert all(item["priority"] == "P3" for item in triage["priority_queue"])
    assert all(item["dataset_complete_for_review"] for item in triage["priority_queue"])
    assert triage["systems"]["combat_core"]["transition_review"] == "HUMAN_REVIEW_REQUIRED"
    assert triage["systems"]["combat_core"]["current_stage"] == "technically_validated"


def test_blocking_observation_becomes_p0_without_auto_fail(tmp_path: Path):
    _write_pack(tmp_path, blocking_scenario="combat_decision_readability")
    triage = build_triage(tmp_path)
    combat = next(
        item
        for item in triage["priority_queue"]
        if item["scenario_id"] == "combat_decision_readability"
    )

    assert combat["priority"] == "P0"
    assert combat["automatic_gate_decision"] == "FORBIDDEN"
    assert any(fix["id"] == "target_feedback" for fix in combat["candidate_fixes"])
    assert all(fix["apply_before_evidence"] is False for fix in combat["candidate_fixes"])


def test_missing_measurements_block_dataset_review_without_maturity_change(tmp_path: Path):
    (tmp_path / "PACK_MANIFEST.json").write_text(
        json.dumps(
            {
                "build_commit": "abc123",
                "validation_status": "NOT_RUN",
                "testers": ["naive-01"],
            }
        ),
        encoding="utf-8",
    )
    folder = tmp_path / "naive-01"
    folder.mkdir()
    (folder / "measurement_events.jsonl").write_text("", encoding="utf-8")

    triage = build_triage(tmp_path)
    assert triage["automatic_maturity_transition"] == "FORBIDDEN"
    assert all(not item["dataset_complete_for_review"] for item in triage["priority_queue"])
    assert all(system["transition_review"] == "NOT_READY" for system in triage["systems"].values())
