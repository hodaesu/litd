import pytest

from tools.quality.application_closure_contract import _hash, evaluate


def decision():
    payload = {
        "kind": "LITD_APPLICATION_DECISION_RECEIPT",
        "outcome": "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE",
        "merge_authorized": True,
        "merge_must_be_separate_action": True,
        "post_merge_measurement_required": True,
        "provenance_checkpoint_required": True,
        "source_candidate_hash": "b" * 64,
        "implementation_commit_sha": "c" * 40,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_application_allowed": False,
        "automatic_target_change_allowed": False,
    }
    payload["application_decision_hash"] = _hash(payload)
    return payload


def evidence():
    return {
        "application_decision_hash": decision()["application_decision_hash"],
        "repository": "hodaesu/litd",
        "merged_source_commit_sha": "c" * 40,
        "merged_commit_sha": "d" * 40,
        "merge_evidence_refs": ["pr:999", "merge:d"],
        "post_merge_assessment": "NO_BLOCKING_REGRESSION",
        "measurement_provenance_run_id": 123,
        "measurement_source_commit_sha": "d" * 40,
        "measurement_artifact_hashes": ["e" * 64],
        "checkpoint_source_commit_sha": "d" * 40,
        "checkpoint_source_run_id": 123,
        "checkpoint_hash": "f" * 64,
        "sigstore_bundle_hash": "1" * 64,
        "checkpoint_signature_verified": True,
        "checkpoint_transparency_log_verified": True,
        "checkpoint_workflow_identity": "https://github.com/hodaesu/litd/.github/workflows/provenance-checkpoint.yml@refs/heads/main",
        "checkpoint_oidc_issuer": "https://token.actions.githubusercontent.com",
        "checkpoint_evidence_refs": ["artifact:signed-checkpoint", "rekor:123"],
    }


def test_valid_chain_closes_only_after_measurement_and_signed_checkpoint():
    result = evaluate(decision(), evidence())
    assert result["status"] == "APPLIED_MEASURED_PROVENANCE_VERIFIED"
    assert result["blockers"] == []
    assert result["automatic_merge_allowed"] is False
    assert result["automatic_rollback_allowed"] is False
    assert result["core_write_allowed"] is False


def test_unauthorized_merged_source_blocks():
    row = evidence(); row["merged_source_commit_sha"] = "2" * 40
    result = evaluate(decision(), row)
    assert "merged_source_not_authorized_implementation" in result["blockers"]


def test_measurement_must_be_bound_to_merge_commit():
    row = evidence(); row["measurement_source_commit_sha"] = "3" * 40
    result = evaluate(decision(), row)
    assert "post_merge_measurement_not_bound_to_merge_commit" in result["blockers"]


def test_checkpoint_must_be_bound_to_merge_commit():
    row = evidence(); row["checkpoint_source_commit_sha"] = "4" * 40
    result = evaluate(decision(), row)
    assert "checkpoint_not_bound_to_merge_commit" in result["blockers"]


def test_checkpoint_must_reference_measurement_provenance_run():
    row = evidence(); row["checkpoint_source_run_id"] = 456
    result = evaluate(decision(), row)
    assert "checkpoint_not_bound_to_measurement_provenance_run" in result["blockers"]


def test_post_merge_regression_blocks_and_requires_rollback_review():
    row = evidence(); row["post_merge_assessment"] = "BLOCKING_REGRESSION"
    result = evaluate(decision(), row)
    assert "post_merge_measurement_not_acceptable" in result["blockers"]
    assert result["rollback_review_required"] is True


def test_signature_and_transparency_are_both_required():
    row = evidence(); row["checkpoint_signature_verified"] = False
    result = evaluate(decision(), row)
    assert "checkpoint_signature_not_verified" in result["blockers"]
    row = evidence(); row["checkpoint_transparency_log_verified"] = False
    result = evaluate(decision(), row)
    assert "checkpoint_transparency_log_not_verified" in result["blockers"]


def test_workflow_identity_and_oidc_issuer_are_pinned():
    row = evidence(); row["checkpoint_workflow_identity"] = "https://github.com/evil/repo/.github/workflows/provenance-checkpoint.yml@refs/heads/main"
    result = evaluate(decision(), row)
    assert "checkpoint_workflow_identity_mismatch" in result["blockers"]
    row = evidence(); row["checkpoint_oidc_issuer"] = "https://example.invalid"
    result = evaluate(decision(), row)
    assert "checkpoint_oidc_issuer_mismatch" in result["blockers"]


def test_authority_escalation_fails_closed():
    d = decision(); d["automatic_merge_allowed"] = True
    d["application_decision_hash"] = _hash({k: v for k, v in d.items() if k != "application_decision_hash"})
    with pytest.raises(ValueError, match="authority violation"):
        evaluate(d, evidence())


def test_tampered_application_decision_with_stale_hash_fails_closed():
    bad = decision()
    bad["implementation_commit_sha"] = "0" * 40
    with pytest.raises(ValueError, match="integrity mismatch"):
        evaluate(bad, evidence())
