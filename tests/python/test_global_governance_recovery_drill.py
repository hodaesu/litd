import json

import pytest

from tools.quality.run_global_governance_recovery_drill import TEST_IDS, run, verify_ledger, ledger


def test_tabletop_executes_all_attacks_and_retains_hashed_evidence(tmp_path):
    source_sha = "4eb811428feeeeae0c59e11355446bf555ba23d6"
    summary = run(source_sha, tmp_path)

    assert summary["classification"] == "TABLETOP_ONLY"
    assert summary["required_adversarial_tests"] == 8
    assert summary["passed_adversarial_tests"] == 8
    assert summary["gate_status"] == "READY_FOR_SEPARATE_HUMAN_RESUME_DECISION"
    assert summary["production_recovery_proven"] is False
    assert summary["real_credential_rotation_proven"] is False
    assert summary["authenticated_two_person_review_proven"] is False
    assert summary["issue_315_closable"] is False
    assert len(summary["measurement_hash"]) == 64

    report = json.loads((tmp_path / "recovery-report.json").read_text(encoding="utf-8"))
    assert {row["test_id"] for row in report["adversarial_tests"]} == set(TEST_IDS)
    assert all(row["status"] == "PASS" for row in report["adversarial_tests"])
    for row in report["adversarial_tests"]:
        assert len(row["artifact_hash"]) == 64
        assert (tmp_path / f"{row['test_id']}.json").is_file()


def test_drill_ledger_detects_tamper_and_replay():
    clean = ledger([
        {"receipt_id": "one", "project": "LITD", "route": "litd/core"},
        {"receipt_id": "two", "project": "COMPANY", "route": "company/core"},
    ])
    assert verify_ledger(clean) is True
    assert verify_ledger([clean[0], {**clean[1], "route": "litd/core"}]) is False
    assert verify_ledger(clean + [clean[-1]]) is False


def test_drill_refuses_unbound_source_sha(tmp_path):
    with pytest.raises(ValueError, match="40 lowercase hexadecimal"):
        run("main", tmp_path)
