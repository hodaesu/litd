from __future__ import annotations

import json
from pathlib import Path

from tools.qa import balance_matrix_sim_v2 as v2
from tools.qa.balance_matrix_sim_v3 import (
    NORMAL_ENEMY_IDS,
    _apply_campaign_duration_guardrails,
    extract_runtime_campaign_profiles,
)


ROOT = Path(__file__).resolve().parents[2]


def test_exact_runtime_blocks_keep_minibosses_and_bosses_separate() -> None:
    profiles = extract_runtime_campaign_profiles(ROOT)
    miniboss_ids = {row["encounter_id"] for row in profiles["minibosses"]}
    boss_ids = {row["encounter_id"] for row in profiles["bosses"]}

    assert len(miniboss_ids) == 8
    assert len(boss_ids) == 11
    assert miniboss_ids.isdisjoint(boss_ids)
    assert "c02_broken_curator" in miniboss_ids
    assert "c10_unpaid_cost" in miniboss_ids
    assert "c02_marker_warden" in boss_ids
    assert "c10_boss_final" in boss_ids


def test_exact_runtime_boss_profiles_cover_chapters_one_through_ten() -> None:
    profiles = extract_runtime_campaign_profiles(ROOT)
    chapters = sorted({int(row["chapter_number"]) for row in profiles["bosses"]})
    assert chapters == list(range(1, 11))


def test_campaign_normal_pack_and_miniboss_tuning_match_runtime() -> None:
    bridge = (ROOT / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    rules = json.loads((ROOT / "data/roguelike/roguelike_rules.json").read_text(encoding="utf-8"))
    matrix = json.loads((ROOT / "data/roguelike/balance_matrix.json").read_text(encoding="utf-8"))

    assert NORMAL_ENEMY_IDS == (1, 8)
    assert "var ids: Array[int] = [1,8]" in bridge
    assert matrix["campaign"]["normal_enemy_ids"] == [1, 8]
    assert rules["combat_balance"]["campaign_miniboss_hp_multiplier"] == 1.65


def test_campaign_duration_guardrails_accept_clear_three_step_hierarchy() -> None:
    result = v2.base.MatrixResult(
        payload={
            "monte_carlo": {
                "encounters": {
                    "campaign:normal": {"average_rounds": 4.0},
                    "campaign:miniboss": {"average_rounds": 4.8},
                    "campaign:boss": {"average_rounds": 7.3},
                }
            }
        },
        alerts=[],
    )

    _apply_campaign_duration_guardrails(result, ROOT)

    assert result.alerts == []
    assert result.payload["campaign_duration_guardrails"]["average_rounds"] == {
        "normal": 4.0,
        "miniboss": 4.8,
        "boss": 7.3,
    }


def test_campaign_duration_guardrails_reject_inverted_rhythm() -> None:
    result = v2.base.MatrixResult(
        payload={
            "monte_carlo": {
                "encounters": {
                    "campaign:normal": {"average_rounds": 6.6},
                    "campaign:miniboss": {"average_rounds": 3.5},
                    "campaign:boss": {"average_rounds": 7.2},
                }
            }
        },
        alerts=[],
    )

    _apply_campaign_duration_guardrails(result, ROOT)
    codes = {row["code"] for row in result.alerts}

    assert "campaign_normal_round_window" in codes
    assert "campaign_miniboss_round_window" in codes
    assert "campaign_miniboss_not_distinct_from_normal" in codes
