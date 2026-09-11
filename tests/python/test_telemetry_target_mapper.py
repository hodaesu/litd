from tools.quality.telemetry_target_mapper import map_report_to_canonical_metrics, mapping_coverage


def test_maps_known_roguelike_metrics_without_guessing():
    payload = {
        "outcomes": {"retreat_rate": 0.42, "wipe_rate": 0.11},
        "expedition": {"average_rooms_cleared": 14.2},
        "combat_rounds": {"combat": 3.1, "elite": 4.9, "boss": 7.8},
        "loot_rarity": {"legendary": {"share": 0.012}},
        "classes": {
            "a": {"win_rate": 0.55, "survival_rate": 0.80},
            "b": {"win_rate": 0.61, "survival_rate": 0.74},
        },
    }
    mapped = map_report_to_canonical_metrics(payload)
    assert mapped["outcomes.retreat_rate"] == 0.42
    assert mapped["outcomes.wipe_rate"] == 0.11
    assert mapped["expedition.visited_rooms"] == 14.2
    assert mapped["combat.normal_rounds"] == 3.1
    assert mapped["combat.elite_rounds"] == 4.9
    assert mapped["combat.boss_rounds"] == 7.8
    assert mapped["loot.legendary_rate"] == 0.012
    assert round(mapped["balance.class_win_rate_spread"], 6) == 0.06
    assert round(mapped["balance.class_survival_rate_spread"], 6) == 0.06
    assert "expedition.duration_minutes" not in mapped
    assert "expedition.generated_rooms" not in mapped


def test_maps_campaign_rounds_from_balance_matrix_shape():
    payload = {
        "monte_carlo": {
            "encounters": {
                "campaign:normal": {"average_rounds": 3.0},
                "campaign:miniboss": {"average_rounds": 5.0},
                "campaign:boss": {"average_rounds": 8.0},
            }
        }
    }
    mapped = map_report_to_canonical_metrics(payload)
    assert mapped == {
        "campaign.normal_rounds": 3.0,
        "campaign.miniboss_rounds": 5.0,
        "campaign.boss_rounds": 8.0,
    }


def test_single_class_does_not_fabricate_spread():
    mapped = map_report_to_canonical_metrics({"classes": {"only": {"win_rate": 0.5, "survival_rate": 0.8}}})
    assert "balance.class_win_rate_spread" not in mapped
    assert "balance.class_survival_rate_spread" not in mapped


def test_booleans_are_not_numeric_metrics():
    mapped = map_report_to_canonical_metrics({"outcomes": {"retreat_rate": True, "wipe_rate": False}})
    assert "outcomes.retreat_rate" not in mapped
    assert "outcomes.wipe_rate" not in mapped


def test_mapping_coverage_reports_missing_targets_explicitly():
    registry = {"targets": {"outcomes.retreat_rate": {}, "expedition.duration_minutes": {}}}
    coverage = mapping_coverage({"outcomes.retreat_rate": 0.5}, registry)
    assert coverage["mapped_target_count"] == 1
    assert coverage["total_target_count"] == 2
    assert coverage["unmapped_targets"] == ["expedition.duration_minutes"]
