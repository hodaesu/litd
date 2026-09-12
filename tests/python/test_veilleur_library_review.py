import pytest

from tools.quality.veilleur_library_review import build_review_batch


def triage(route="LITD_LIBRARY", canonical_hash="a" * 64):
    return {
        "kind": "LITD_VEILLEUR_TRIAGE_BATCH",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "items": [
            {
                "project_id": "LITD",
                "target_route": "LITD_LIBRARY",
                "evidence_id": "e1",
                "canonical_hash": canonical_hash,
                "route": route,
                "route_confidence": 0.9,
                "cross_reference": False,
                "library_candidate": True,
                "impact_analysis": {
                    "scopes": ["engine"],
                    "requires_review": route == "LITD_LIBRARY",
                },
            }
        ],
        "core_write_allowed": False,
        "automatic_library_write_allowed": False,
        "automatic_core_change_candidate_allowed": False,
    }


def test_unknown_candidate_requires_contradiction_and_obsolescence_review():
    report = build_review_batch(triage())
    item = report["items"][0]
    assert report["project_id"] == "LITD"
    assert report["target_route"] == "LITD_LIBRARY"
    assert item["project_id"] == "LITD"
    assert item["target_route"] == "LITD_LIBRARY"
    assert item["contradiction"]["status"] == "REVIEW_REQUIRED"
    assert item["obsolescence"]["status"] == "REVIEW_REQUIRED"
    assert item["impact"]["requires_core_review"] is True
    assert report["automatic_core_change_candidate_allowed"] is False


def test_exact_canonical_hash_does_not_invent_contradiction():
    report = build_review_batch(triage(), [{"record_id": "r1", "canonical_hash": "a" * 64}])
    item = report["items"][0]
    assert item["contradiction"]["status"] == "EXACT_CANONICAL_MATCH"
    assert item["obsolescence"]["status"] == "NO_CHANGE"
    assert item["contradiction"]["canonical_record_id"] == "r1"


def test_cross_project_triage_batch_fails_closed():
    data = triage()
    data["project_id"] = "COMPANY"
    data["target_route"] = "COMPANY_LIBRARY"
    with pytest.raises(ValueError, match="project scope mismatch"):
        build_review_batch(data)


def test_cross_project_item_fails_closed():
    data = triage()
    data["items"][0]["project_id"] = "COMPANY"
    data["items"][0]["target_route"] = "COMPANY_LIBRARY"
    with pytest.raises(ValueError, match="item project/route scope mismatch"):
        build_review_batch(data)


def test_wrong_route_scope_fails_closed():
    data = triage()
    data["target_route"] = "GENERAL_LIBRARY"
    with pytest.raises(ValueError, match="route scope mismatch"):
        build_review_batch(data)


def test_authority_escalation_fails_closed():
    data = triage()
    data["core_write_allowed"] = True
    with pytest.raises(ValueError, match="authority violation"):
        build_review_batch(data)
