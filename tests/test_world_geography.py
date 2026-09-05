from tools.qa.world_geography_audit import audit_world_geography


def test_world_geography_contract():
    report = audit_world_geography()
    assert report["ok"], "\n".join(report["errors"])
    assert report["summary"]["cities"] == 6
    assert report["summary"]["war_battle_locations"] == 8
    assert report["summary"]["map_layers"] == 6
