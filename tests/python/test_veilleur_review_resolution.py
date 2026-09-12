import pytest

from tools.quality.veilleur_review_resolution import _hash, resolve_candidate


def candidate(route="LITD_LIBRARY", cross_reference=False):
    payload = {
        "kind": "LITD_LIBRARY_REVIEW_CANDIDATE",
        "evidence_id": "e1",
        "route": route,
        "cross_reference": cross_reference,
        "core_write_allowed": False,
        "automatic_library_write_allowed": False,
    }
    payload["candidate_hash"] = _hash(payload)
    return payload


def resolution(decision="PROPOSE_LITD_CHANGE_CANDIDATE", source=None):
    reviewed_candidate = source if source is not None else candidate()
    return {
        "candidate_hash": reviewed_candidate["candidate_hash"],
        "decision": decision,
        "rationale": "Evidence and impact review justify this governed decision.",
        "decided_by": "guardian-review",
        "decided_at": "2026-09-12T08:00:00+02:00",
        "evidence_refs": ["evidence:e1"],
    }


def test_litd_change_candidate_requires_guardian_and_never_writes_core():
    reviewed_candidate = candidate()
    receipt = resolve_candidate(reviewed_candidate, resolution(source=reviewed_candidate))
    assert receipt["outcome"] == "LITD_CHANGE_CANDIDATE_APPROVED_PENDING_GUARDIAN"
    assert receipt["requires_guardian_review"] is True
    assert receipt["core_write_allowed"] is False
    assert receipt["library_write_allowed"] is False


def test_general_knowledge_cannot_propose_litd_change_candidate():
    reviewed_candidate = candidate("GENERAL_LIBRARY")
    with pytest.raises(ValueError, match="LITD_LIBRARY"):
        resolve_candidate(reviewed_candidate, resolution(source=reviewed_candidate))


def test_candidate_hash_mismatch_fails_closed():
    data = resolution()
    data["candidate_hash"] = "b" * 64
    with pytest.raises(ValueError, match="hash mismatch"):
        resolve_candidate(candidate(), data)


def test_cross_reference_requires_explicit_candidate_signal():
    reviewed_candidate = candidate()
    with pytest.raises(ValueError, match="cross_reference"):
        resolve_candidate(
            reviewed_candidate,
            resolution("LINK_AS_CROSS_REFERENCE", reviewed_candidate),
        )
    reviewed_candidate = candidate(cross_reference=True)
    receipt = resolve_candidate(
        reviewed_candidate,
        resolution("LINK_AS_CROSS_REFERENCE", reviewed_candidate),
    )
    assert receipt["outcome"] == "CROSS_REFERENCE_APPROVED_PENDING_APPLICATION"


def test_supersession_requires_explicit_target_and_never_auto_obsoletes():
    reviewed_candidate = candidate()
    data = resolution("PROPOSE_SUPERSESSION", reviewed_candidate)
    with pytest.raises(ValueError, match="supersedes_record_id"):
        resolve_candidate(reviewed_candidate, data)
    data["supersedes_record_id"] = "record-old"
    receipt = resolve_candidate(reviewed_candidate, data)
    assert receipt["automatic_obsolescence_allowed"] is False
    assert receipt["supersedes_record_id"] == "record-old"


def test_naive_timestamp_is_rejected():
    data = resolution()
    data["decided_at"] = "2026-09-12T08:00:00"
    with pytest.raises(ValueError, match="timezone-aware"):
        resolve_candidate(candidate(), data)


def test_candidate_authority_escalation_is_rejected():
    bad = candidate()
    bad["core_write_allowed"] = True
    bad["candidate_hash"] = _hash({k: v for k, v in bad.items() if k != "candidate_hash"})
    with pytest.raises(ValueError, match="Core authority"):
        resolve_candidate(bad, resolution(source=bad))


def test_tampered_candidate_with_stale_hash_fails_closed():
    bad = candidate()
    bad["route"] = "GENERAL_LIBRARY"
    with pytest.raises(ValueError, match="integrity mismatch"):
        resolve_candidate(bad, resolution())
