import pytest

from tools.quality.veilleur_review_resolution import _hash, resolve_candidate


def candidate(route="LITD_LIBRARY", cross_reference=False):
    payload = {
        "kind": "LITD_LIBRARY_REVIEW_CANDIDATE",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "evidence_id": "e1",
        "route": route,
        "cross_reference": cross_reference,
        "core_write_allowed": False,
        "automatic_library_write_allowed": False,
    }
    payload["candidate_hash"] = _hash(payload)
    return payload


def resolution(decision="PROPOSE_LITD_CHANGE_CANDIDATE", item=None):
    item = item or candidate()
    return {
        "candidate_hash": item["candidate_hash"],
        "decision": decision,
        "rationale": "Evidence and impact review justify this governed decision.",
        "decided_by": "guardian-review",
        "decided_at": "2026-09-12T08:00:00+02:00",
        "evidence_refs": ["evidence:e1"],
    }


def test_litd_change_candidate_requires_guardian_and_never_writes_core():
    item = candidate()
    receipt = resolve_candidate(item, resolution(item=item))
    assert receipt["project_id"] == "LITD"
    assert receipt["target_route"] == "LITD_LIBRARY"
    assert receipt["outcome"] == "LITD_CHANGE_CANDIDATE_APPROVED_PENDING_GUARDIAN"
    assert receipt["requires_guardian_review"] is True
    assert receipt["core_write_allowed"] is False
    assert receipt["library_write_allowed"] is False


def test_general_knowledge_cannot_propose_litd_change_candidate():
    item = candidate("GENERAL_LIBRARY")
    data = resolution(item=item)
    with pytest.raises(ValueError, match="LITD_LIBRARY"):
        resolve_candidate(item, data)


def test_cross_project_candidate_with_valid_hash_fails_closed():
    item = candidate()
    item["project_id"] = "COMPANY"
    item["target_route"] = "COMPANY_LIBRARY"
    item["candidate_hash"] = _hash({k: v for k, v in item.items() if k != "candidate_hash"})
    data = resolution(item=item)
    with pytest.raises(ValueError, match="project scope mismatch"):
        resolve_candidate(item, data)


def test_wrong_target_route_with_valid_hash_fails_closed():
    item = candidate()
    item["target_route"] = "GENERAL_LIBRARY"
    item["candidate_hash"] = _hash({k: v for k, v in item.items() if k != "candidate_hash"})
    data = resolution(item=item)
    with pytest.raises(ValueError, match="route scope mismatch"):
        resolve_candidate(item, data)


def test_candidate_hash_mismatch_fails_closed():
    item = candidate()
    data = resolution(item=item)
    data["candidate_hash"] = "b" * 64
    with pytest.raises(ValueError, match="hash mismatch"):
        resolve_candidate(item, data)


def test_cross_reference_requires_explicit_candidate_signal():
    item = candidate()
    with pytest.raises(ValueError, match="cross_reference"):
        resolve_candidate(item, resolution("LINK_AS_CROSS_REFERENCE", item))
    item = candidate(cross_reference=True)
    data = resolution("LINK_AS_CROSS_REFERENCE", item)
    receipt = resolve_candidate(item, data)
    assert receipt["outcome"] == "CROSS_REFERENCE_APPROVED_PENDING_APPLICATION"


def test_supersession_requires_explicit_target_and_never_auto_obsoletes():
    item = candidate()
    data = resolution("PROPOSE_SUPERSESSION", item)
    with pytest.raises(ValueError, match="supersedes_record_id"):
        resolve_candidate(item, data)
    data["supersedes_record_id"] = "record-old"
    receipt = resolve_candidate(item, data)
    assert receipt["automatic_obsolescence_allowed"] is False
    assert receipt["supersedes_record_id"] == "record-old"


def test_naive_timestamp_is_rejected():
    item = candidate()
    data = resolution(item=item)
    data["decided_at"] = "2026-09-12T08:00:00"
    with pytest.raises(ValueError, match="timezone-aware"):
        resolve_candidate(item, data)


def test_candidate_authority_escalation_is_rejected():
    bad = candidate()
    bad["core_write_allowed"] = True
    bad["candidate_hash"] = _hash({k: v for k, v in bad.items() if k != "candidate_hash"})
    with pytest.raises(ValueError, match="Core authority"):
        resolve_candidate(bad, resolution(item=bad))


def test_tampered_candidate_with_stale_hash_fails_closed():
    bad = candidate()
    data = resolution(item=bad)
    bad["project_id"] = "COMPANY"
    with pytest.raises(ValueError, match="integrity mismatch"):
        resolve_candidate(bad, data)
