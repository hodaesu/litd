import pytest

from tools.quality.global_governance_recovery_gate import evaluate


def report():
    adversarial = [
        "source_compromise", "ledger_tamper", "replay", "hash_substitution",
        "stale_sha", "target_change", "wrong_route", "bypass_attempt",
    ]
    return {
        "kind": "GLOBAL_GOVERNANCE_COMPROMISE_RECOVERY",
        "incident_id": "GOV-INC-001",
        "severity": "CRITICAL",
        "detected_at": "2026-09-12T10:00:00Z",
        "containment_started_at": "2026-09-12T10:05:00Z",
        "recovery_verified_at": "2026-09-12T12:00:00Z",
        "source_commit_sha": "a" * 40,
        "trusted_baseline_commit_sha": "b" * 40,
        "compromised_components": ["global-runner", "global-token"],
        "affected_projects": ["LITD", "COMPANY"],
        "global_automation_frozen": True,
        "all_mutation_credentials_revoked": True,
        "replacement_credentials_isolated": True,
        "credential_rotation_evidence_refs": ["vault:rotation-1", "github:audit-1"],
        "ledger_recovery": {
            "trusted_checkpoint_hash": "c" * 64,
            "restored_ledger_hash": "d" * 64,
            "chain_verified": True,
            "replay_scan_passed": True,
        },
        "adversarial_tests": [
            {"test_id": name, "status": "PASS", "artifact_hash": "e" * 64}
            for name in adversarial
        ],
        "local_guardian_results": [
            {
                "project_id": project,
                "decision": "GREEN",
                "integrity_verified": True,
                "cross_project_isolation_verified": True,
                "recovery_test_run_id": index,
                "evidence_refs": [f"artifact:{project.lower()}-recovery"],
            }
            for index, project in enumerate(["LITD", "COMPANY"], start=1)
        ],
        "independent_reviewers": ["security-reviewer", "project-owner"],
    }


def test_complete_recovery_only_allows_separate_human_decision():
    result = evaluate(report())
    assert result["status"] == "READY_FOR_SEPARATE_HUMAN_RESUME_DECISION"
    assert result["blockers"] == []
    assert result["human_resume_decision_required"] is True
    assert result["automatic_resume_allowed"] is False
    assert result["automatic_credential_restore_allowed"] is False
    assert result["automatic_merge_allowed"] is False
    assert result["automatic_core_write_allowed"] is False
    assert result["automatic_cross_project_propagation_allowed"] is False


@pytest.mark.parametrize(
    ("field", "blocker"),
    [
        ("global_automation_frozen", "global_automation_not_frozen"),
        ("all_mutation_credentials_revoked", "mutation_credentials_not_revoked"),
        ("replacement_credentials_isolated", "replacement_credentials_not_isolated"),
    ],
)
def test_incomplete_containment_blocks(field, blocker):
    row = report()
    row[field] = False
    result = evaluate(row)
    assert result["status"] == "RECOVERY_BLOCKED"
    assert blocker in result["blockers"]


def test_tampered_or_unverified_ledger_blocks():
    row = report()
    row["ledger_recovery"]["chain_verified"] = False
    row["ledger_recovery"]["replay_scan_passed"] = False
    result = evaluate(row)
    assert "restored_ledger_chain_not_verified" in result["blockers"]
    assert "ledger_replay_scan_not_passed" in result["blockers"]


def test_failed_adversarial_case_blocks():
    row = report()
    row["adversarial_tests"][3]["status"] = "FAIL"
    result = evaluate(row)
    assert "adversarial_recovery_tests_failed" in result["blockers"]


def test_missing_adversarial_case_fails_closed():
    row = report()
    row["adversarial_tests"].pop()
    with pytest.raises(ValueError, match="missing adversarial tests"):
        evaluate(row)


def test_every_project_requires_an_independent_local_guardian():
    row = report()
    row["local_guardian_results"].pop()
    with pytest.raises(ValueError, match="every affected project"):
        evaluate(row)


def test_local_project_can_refuse_global_recovery():
    row = report()
    row["local_guardian_results"][0]["decision"] = "ORANGE"
    result = evaluate(row)
    assert "local_guardian_not_green:LITD" in result["blockers"]
    assert result["status"] == "RECOVERY_BLOCKED"


def test_cross_project_isolation_failure_blocks():
    row = report()
    row["local_guardian_results"][1]["cross_project_isolation_verified"] = False
    result = evaluate(row)
    assert "cross_project_isolation_not_verified:COMPANY" in result["blockers"]


def test_two_distinct_reviewers_are_required():
    row = report()
    row["independent_reviewers"] = ["security-reviewer"]
    with pytest.raises(ValueError, match="two independent reviewers"):
        evaluate(row)


def test_chronology_and_sha_are_strict():
    row = report()
    row["containment_started_at"] = "2026-09-12T09:00:00Z"
    with pytest.raises(ValueError, match="chronological"):
        evaluate(row)
    row = report()
    row["source_commit_sha"] = "not-a-sha"
    with pytest.raises(ValueError, match="40 lowercase hex"):
        evaluate(row)
