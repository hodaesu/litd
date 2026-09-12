from tools.quality.veilleur_library_review import build_review_batch


def triage(route="LITD_LIBRARY", canonical_hash="a"*64):
    return {
        "kind":"LITD_VEILLEUR_TRIAGE_BATCH",
        "items":[{
            "evidence_id":"e1","canonical_hash":canonical_hash,"route":route,
            "route_confidence":0.9,"cross_reference":False,"library_candidate":True,
            "impact_analysis":{"scopes":["engine"],"requires_review":route=="LITD_LIBRARY"}
        }],
        "core_write_allowed":False,"automatic_library_write_allowed":False,
        "automatic_core_change_candidate_allowed":False,
    }


def test_unknown_candidate_requires_contradiction_and_obsolescence_review():
    report=build_review_batch(triage())
    item=report["items"][0]
    assert item["contradiction"]["status"]=="REVIEW_REQUIRED"
    assert item["obsolescence"]["status"]=="REVIEW_REQUIRED"
    assert item["impact"]["requires_core_review"] is True
    assert report["automatic_core_change_candidate_allowed"] is False


def test_exact_canonical_hash_does_not_invent_contradiction():
    report=build_review_batch(triage(),[{"record_id":"r1","canonical_hash":"a"*64}])
    item=report["items"][0]
    assert item["contradiction"]["status"]=="EXACT_CANONICAL_MATCH"
    assert item["obsolescence"]["status"]=="NO_CHANGE"
    assert item["contradiction"]["canonical_record_id"]=="r1"


def test_authority_escalation_fails_closed():
    data=triage(); data["core_write_allowed"]=True
    try:
        build_review_batch(data)
        assert False
    except ValueError as exc:
        assert "authority violation" in str(exc)
