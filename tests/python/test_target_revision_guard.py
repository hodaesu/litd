from tools.quality.target_revision_guard import evaluate_revision_change, validate_target_revision_proposal


def proposal(**overrides):
    payload = {
        "kind": "LITD_TARGET_REVISION_PROPOSAL",
        "decision": "PROPOSE_TARGET_REVISION",
        "target_ids": ["combat.boss_rounds"],
        "old_values": {"min": 5.5, "max": 10.5},
        "new_values": {"min": 6.0, "max": 11.0},
        "rationale": "Repeated telemetry and playtest evidence indicate the previous boss-round window no longer represents the validated pacing intent.",
        "evidence_refs": ["artifact:measurement-comparison-123"],
        "candidate_hash": "a" * 64,
        "core_write_allowed": False,
    }
    payload.update(overrides)
    return payload


def test_implementation_only_passes_without_proposal():
    result = evaluate_revision_change(["scripts/combat.gd"], [])
    assert result["status"] == "PASS"


def test_target_change_requires_proposal():
    result = evaluate_revision_change(["docs/knowledge/design-targets.json"], [])
    assert result["status"] == "BLOCK"
    assert "target_revision_proposal_required" in result["reasons"]


def test_target_and_implementation_cannot_share_pr():
    result = evaluate_revision_change(
        [
            "docs/knowledge/design-targets.json",
            "scripts/combat.gd",
            "docs/knowledge/decisions/target-revisions/boss.json",
        ],
        [proposal()],
    )
    assert result["status"] == "BLOCK"
    assert "target_and_implementation_must_be_separate_prs" in result["reasons"]


def test_governance_only_target_revision_passes_with_valid_proposal():
    result = evaluate_revision_change(
        [
            "docs/knowledge/design-targets.json",
            "docs/knowledge/decisions/target-revisions/boss.json",
        ],
        [proposal()],
    )
    assert result["status"] == "PASS"
    assert result["core_write_allowed"] is False


def test_proposal_cannot_authorize_core_write():
    errors = validate_target_revision_proposal(proposal(core_write_allowed=True))
    assert "direct_core_write_forbidden" in errors


def test_proposal_must_contain_evidence_and_real_change():
    errors = validate_target_revision_proposal(proposal(evidence_refs=[], new_values={"min": 5.5, "max": 10.5}))
    assert "evidence_refs_required" in errors
    assert "no_effective_revision" in errors


def test_apply_core_change_is_rejected():
    errors = validate_target_revision_proposal(proposal(decision="APPLY_CORE_CHANGE"))
    assert "invalid_decision" in errors
