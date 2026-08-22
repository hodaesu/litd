from __future__ import annotations

from pathlib import Path

from tools.qa.roguelike_telemetry_sim_v2 import ROOM_ENCOUNTER_IDS, simulate


ROOT = Path(__file__).resolve().parents[2]


def test_v2_uses_live_main_v25_encounter_budget() -> None:
    assert ROOM_ENCOUNTER_IDS["combat"] == [1, 8]
    assert ROOM_ENCOUNTER_IDS["elite"] == [10, 8]
    assert ROOM_ENCOUNTER_IDS["ambush"] == [8, 8, 1]
    assert ROOM_ENCOUNTER_IDS["creature"] == [10]
    assert ROOM_ENCOUNTER_IDS["boss"] == [38]


def test_v2_detects_effective_light_interval_through_ui_compensation() -> None:
    payload = simulate(ROOT, runs=60, seed=260821).payload
    contract = payload["runtime_contract"]
    assert contract["configured_light_decay_interval"] == 2
    assert contract["effective_light_decay_interval"] == 2
    assert contract["runtime_implements_room_decay_interval"] is True


def test_v2_reports_runtime_aligned_model_metadata() -> None:
    payload = simulate(ROOT, runs=60, seed=821).payload
    assert payload["model_version"] == 2
    assert payload["encounter_source"] == "scripts/ui/main_v25.gd"
    assert payload["encounter_groups"]["boss"] == [38]
