from tools.qa.legendary_seven_post_campaign_audit import run


def test_legendary_seven_post_campaign_audit_passes():
    report = run()
    assert report["ok"], report["errors"]
    assert report["hero_count"] == 7
