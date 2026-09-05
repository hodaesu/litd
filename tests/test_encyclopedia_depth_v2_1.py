from tools.qa.encyclopedia_depth_v2_1_audit import run


def test_depth_v2_1_audit_passes():
    report = run()
    assert report["ok"], report["errors"]


def test_depth_v2_1_counts_are_locked():
    report = run()
    assert report["counts"] == {
        "concorde_cities": 6,
        "city_districts": 36,
        "existing_npcs_linked_to_districts": 48,
        "late_foreign_polities": 4,
        "late_foreign_major_cities": 16,
        "late_foreign_microhistory_events": 16,
        "satellite_settlements": 18,
        "trades": 24,
        "everyday_objects": 30,
        "quest_bridges": 18,
    }
