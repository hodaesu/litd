from __future__ import annotations

import json
from pathlib import Path

from tools.qa.balance_matrix_sim import (
    all_compositions,
    campaign_reference_level,
    dungeon_enemy_level,
    representative_compositions,
    simulate_matrix,
)


ROOT = Path(__file__).resolve().parents[2]


def _load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_all_ten_classes_produce_210_four_person_compositions() -> None:
    classes = _load("data/classes.json")
    combos = all_compositions(classes)
    assert len(classes) == 10
    assert len(combos) == 210
    assert len(set(combos)) == 210
    assert all(len(combo) == 4 for combo in combos)


def test_campaign_reference_curve_matches_runtime_policy() -> None:
    assert campaign_reference_level(1, "normal") == 3
    assert campaign_reference_level(1, "boss") == 3
    assert campaign_reference_level(2, "boss") == 8
    assert campaign_reference_level(10, "boss") == 48
    assert campaign_reference_level(10, "miniboss") == 48


def test_dungeon_enemy_level_is_fixed_by_profile_not_party() -> None:
    rules = _load("data/roguelike/roguelike_rules.json")
    profile = rules["dungeons"]["first_veil_crypts"]
    assert dungeon_enemy_level(profile, 1, "combat") == 4
    assert dungeon_enemy_level(profile, 1, "elite") == 6
    assert dungeon_enemy_level(profile, 5, "combat") == 12
    assert dungeon_enemy_level(profile, 5, "boss") == 16


def test_representative_sampler_is_deterministic_and_keeps_canonical_party() -> None:
    classes = _load("data/classes.json")
    heroes = _load("data/heroes.json")
    first = representative_compositions(classes, heroes, 10)
    second = representative_compositions(classes, heroes, 10)
    canonical = tuple(sorted(str(row["class_id"]) for row in heroes[:4]))
    assert first == second
    assert len(first) == 10
    assert canonical in first


def test_matrix_sees_levels_campaign_dungeon_compositions_and_ngplus() -> None:
    classes = _load("data/classes.json")
    heroes = _load("data/heroes.json")
    sample_compositions = representative_compositions(classes, heroes, 8)
    result = simulate_matrix(
        ROOT,
        levels=[1, 3, 50],
        monte_carlo_compositions=sample_compositions,
        monte_carlo_cycles=[0, 4],
        samples_per_cell=1,
        seed=260821,
    )
    coverage = result.payload["coverage"]
    assert coverage["analytical_composition_count"] == 210
    assert coverage["expected_all_compositions"] == 210
    assert coverage["campaign_chapter_count"] == 10
    assert "first_veil_crypts" in coverage["dungeon_ids"]
    assert coverage["future_dungeon_autodiscovery"] is True
    assert coverage["monte_carlo_composition_count"] == 8
    assert set(result.payload["monte_carlo"]["campaign_by_level"]) == {"1", "3", "50"}
    assert "3" in result.payload["monte_carlo"]["dungeon_by_level"]
    assert "1" not in result.payload["monte_carlo"]["dungeon_by_level"]
    assert result.payload["analytical"]["ngplus_multipliers"]["4"]["hp"] == 1.72
    assert result.payload["contracts"]["campaign_scales_to_party_level"] is True
    assert result.payload["contracts"]["dungeons_never_scale_to_party_level"] is True
