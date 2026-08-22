from __future__ import annotations

import json
from pathlib import Path

from tools.qa.balance_matrix_sim import representative_compositions
from tools.qa.balance_matrix_sim_v2 import extract_runtime_campaign_profiles, simulate_matrix


ROOT = Path(__file__).resolve().parents[2]


def _load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_runtime_profiles_cover_all_campaign_boss_chapters() -> None:
    profiles = extract_runtime_campaign_profiles(ROOT)
    boss_chapters = sorted({int(row["chapter_number"]) for row in profiles["bosses"]})
    assert boss_chapters == list(range(1, 11))
    assert profiles["normal_enemy_ids"] == [1, 8, 1, 8]


def test_runtime_profiles_use_live_boss_stats() -> None:
    profiles = extract_runtime_campaign_profiles(ROOT)
    by_id = {row["encounter_id"]: row for row in profiles["bosses"]}
    assert by_id["c01_boss_ash_witness"]["hp"] == 110
    assert by_id["c02_marker_warden"]["hp"] == 128
    assert by_id["c10_boss_final"]["hp"] == 320
    assert by_id["c10_boss_final"]["damage"] == [14, 22]


def test_runtime_aligned_matrix_reports_live_profile_source() -> None:
    classes = _load("data/classes.json")
    heroes = _load("data/heroes.json")
    compositions = representative_compositions(classes, heroes, 8)
    result = simulate_matrix(
        ROOT,
        levels=[3, 50],
        monte_carlo_compositions=compositions,
        monte_carlo_cycles=[0, 4],
        samples_per_cell=1,
        seed=260821,
    )
    assert result.payload["model_version"] == 6
    assert result.payload["contracts"]["campaign_runtime_profiles_live"] is True
    assert result.payload["contracts"]["campaign_normal_enemy_ids"] == [1, 8, 1, 8]
    assert result.payload["contracts"]["campaign_member_scaling"]["normal"] == {"hp": 0.46, "damage": 0.55}
    assert result.payload["coverage"]["campaign_runtime_boss_chapters"] == list(range(1, 11))
    assert result.payload["coverage"]["campaign_runtime_boss_profile_count"] >= 10
