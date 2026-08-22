from __future__ import annotations

import json
from pathlib import Path

from tools.qa.roguelike_telemetry_sim import simulate, write_report


ROOT = Path(__file__).resolve().parents[2]


def test_telemetry_is_deterministic_for_same_seed() -> None:
    first = simulate(ROOT, runs=120, seed=424242).payload
    second = simulate(ROOT, runs=120, seed=424242).payload
    assert first["outcomes"] == second["outcomes"]
    assert first["combat_rounds"] == second["combat_rounds"]
    assert first["loot_rarity"] == second["loot_rarity"]


def test_telemetry_exposes_requested_balance_dimensions() -> None:
    payload = simulate(ROOT, runs=150, seed=12345).payload
    assert payload["runs"] == 150
    assert payload["levels"]
    assert payload["classes"]
    assert payload["skill_usage"]
    assert payload["loot_rarity"]
    assert payload["combat_rounds"]
    assert "average_light_remaining" in payload["expedition"]
    assert "average_captures" in payload["expedition"]
    assert "average_gold_found" in payload["expedition"]
    assert "average_essence_found" in payload["expedition"]


def test_telemetry_surfaces_light_runtime_contract() -> None:
    payload = simulate(ROOT, runs=30, seed=77).payload
    contract = payload["runtime_contract"]
    assert contract["configured_light_decay_interval"] >= 1
    assert contract["effective_light_decay_interval"] >= 1
    assert isinstance(contract["runtime_implements_room_decay_interval"], bool)


def test_loot_distribution_is_normalized() -> None:
    payload = simulate(ROOT, runs=250, seed=9001).payload
    share = sum(float(row["share"]) for row in payload["loot_rarity"].values())
    assert abs(share - 1.0) < 0.01


def test_reports_are_written(tmp_path: Path) -> None:
    result = simulate(ROOT, runs=40, seed=555)
    report = tmp_path / "telemetry.json"
    csv_path = tmp_path / "telemetry.csv"
    write_report(result, report, csv_path)
    parsed = json.loads(report.read_text(encoding="utf-8"))
    assert parsed["runs"] == 40
    assert csv_path.read_text(encoding="utf-8").startswith("section,key,metric,value")
