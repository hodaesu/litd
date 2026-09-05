from tools.qa.encyclopedia_completion_audit import audit_encyclopedia


def test_encyclopedia_v1_is_complete() -> None:
    report = audit_encyclopedia()
    assert report["ok"], report["errors"]
    assert report["summary"]["language_families"] >= 5
    assert report["summary"]["regional_languages"] >= 12
    assert report["summary"]["religious_traditions"] >= 6
    assert report["summary"]["martial_lineages"] == 18
    assert report["summary"]["cities"] == 6
    assert report["summary"]["bestiary_entries"] >= 14
    assert report["summary"]["legendary_biographies"] == 7
    assert report["summary"]["requested_domains"] >= 18
