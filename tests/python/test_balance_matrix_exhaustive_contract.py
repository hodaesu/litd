from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_exhaustive_matrix_covers_every_four_class_party() -> None:
    config = json.loads((ROOT / "data/roguelike/balance_matrix.json").read_text(encoding="utf-8"))
    classes = json.loads((ROOT / "data/classes.json").read_text(encoding="utf-8"))
    exhaustive = config["exhaustive"]

    assert len(classes) == 10
    assert exhaustive["monte_carlo_compositions"] == 210
    assert exhaustive["minimum_monte_carlo_compositions"] == 210
    assert exhaustive["monte_carlo_cycles"] == [0, 1, 2, 3, 4]
    assert exhaustive["scope"] == "all_four_class_combinations"
