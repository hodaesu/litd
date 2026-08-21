from __future__ import annotations

from pathlib import Path

from tools.qa.balance_matrix_sim_v3 import extract_runtime_campaign_profiles


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
