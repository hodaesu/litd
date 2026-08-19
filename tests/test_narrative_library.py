from tools.qa.narrative_library_audit import run


def test_narrative_library_audit_has_no_errors():
    payload = run()
    failures = [item for item in payload["checks"] if not item["ok"]]
    assert not failures, failures


def test_sidequests_mix_multiple_narrative_families():
    payload = run()
    family_checks = [
        item for item in payload["checks"]
        if "trois familles narratives distinctes" in item["name"]
    ]
    assert family_checks
    assert all(item["ok"] for item in family_checks)
