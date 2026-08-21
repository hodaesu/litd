#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Any

from tools.qa import balance_matrix_sim_v2 as v2

ROOT = v2.ROOT
BRIDGE_PATH = v2.BRIDGE_PATH
NORMAL_ENEMY_IDS = (1, 8)


def extract_runtime_campaign_profiles(root: Path = ROOT) -> dict[str, Any]:
    text = (root / BRIDGE_PATH).read_text(encoding="utf-8")
    miniboss_marker = 'if encounter_type == "miniboss" and not miniboss_data.is_empty():'
    boss_marker = '\n        if encounter_type == "boss":'
    scaling_marker = "level_scaling_policy.apply_campaign_scaling"

    miniboss_start = text.index(miniboss_marker)
    boss_start = text.index(boss_marker, miniboss_start + len(miniboss_marker))
    scaling_start = text.index(scaling_marker, boss_start + len(boss_marker))

    minibosses = v2._extract_setup_profiles(text[miniboss_start:boss_start])
    bosses = v2._extract_setup_profiles(text[boss_start:scaling_start])
    return {
        "source": str(BRIDGE_PATH),
        "normal_enemy_ids": list(NORMAL_ENEMY_IDS),
        "minibosses": minibosses,
        "bosses": bosses,
    }


def _apply_campaign_duration_guardrails(result: v2.base.MatrixResult, root: Path) -> None:
    config = v2.base._load_json(root / "data/roguelike/balance_matrix.json")
    targets = config.get("targets", {})
    encounters = result.payload.get("monte_carlo", {}).get("encounters", {})

    rounds: dict[str, float] = {}
    for encounter_type in ("normal", "miniboss", "boss"):
        row = encounters.get(f"campaign:{encounter_type}", {})
        if row:
            rounds[encounter_type] = float(row.get("average_rounds", 0.0))

    result.payload["campaign_duration_guardrails"] = {
        "average_rounds": {key: round(value, 3) for key, value in rounds.items()},
        "target_windows": {
            "normal": targets.get("campaign_normal_rounds", [2.0, 4.4]),
            "miniboss": targets.get("campaign_miniboss_rounds", [4.0, 5.8]),
            "boss": targets.get("campaign_boss_rounds", [6.0, 10.0]),
        },
        "minimum_gaps": {
            "miniboss_minus_normal": float(targets.get("campaign_miniboss_normal_round_gap_min", 0.45)),
            "boss_minus_miniboss": float(targets.get("campaign_boss_miniboss_round_gap_min", 1.25)),
        },
    }

    if len(rounds) != 3:
        result.alerts.append({
            "severity": "high",
            "code": "campaign_duration_coverage",
            "detail": f"expected normal/miniboss/boss, got {sorted(rounds)}",
        })
        result.payload["alerts"] = result.alerts
        return

    windows = {
        "normal": [float(value) for value in targets.get("campaign_normal_rounds", [2.0, 4.4])],
        "miniboss": [float(value) for value in targets.get("campaign_miniboss_rounds", [4.0, 5.8])],
        "boss": [float(value) for value in targets.get("campaign_boss_rounds", [6.0, 10.0])],
    }
    for encounter_type, window in windows.items():
        value = rounds[encounter_type]
        if value < window[0] or value > window[1]:
            result.alerts.append({
                "severity": "high",
                "code": f"campaign_{encounter_type}_round_window",
                "detail": f"{value:.3f} outside [{window[0]:.2f},{window[1]:.2f}]",
            })

    miniboss_gap = rounds["miniboss"] - rounds["normal"]
    miniboss_gap_min = float(targets.get("campaign_miniboss_normal_round_gap_min", 0.45))
    if miniboss_gap < miniboss_gap_min:
        result.alerts.append({
            "severity": "high",
            "code": "campaign_miniboss_not_distinct_from_normal",
            "detail": f"gap={miniboss_gap:.3f} < {miniboss_gap_min:.2f}",
        })

    boss_gap = rounds["boss"] - rounds["miniboss"]
    boss_gap_min = float(targets.get("campaign_boss_miniboss_round_gap_min", 1.25))
    if boss_gap < boss_gap_min:
        result.alerts.append({
            "severity": "high",
            "code": "campaign_boss_not_distinct_from_miniboss",
            "detail": f"gap={boss_gap:.3f} < {boss_gap_min:.2f}",
        })

    result.payload["alerts"] = result.alerts


def _decorate_result(result: v2.base.MatrixResult, root: Path) -> v2.base.MatrixResult:
    result.payload["model_version"] = 6
    result.payload["contracts"]["campaign_profile_parser"] = "exact_runtime_blocks"
    result.payload["contracts"]["campaign_normal_enemy_ids"] = list(NORMAL_ENEMY_IDS)
    result.payload["contracts"]["campaign_duration_hierarchy"] = "normal < miniboss < boss"
    _apply_campaign_duration_guardrails(result, root)
    return result


def simulate_matrix(root: Path = ROOT, **kwargs: Any):
    original_extract = v2.extract_runtime_campaign_profiles
    original_normal_ids = list(v2.NORMAL_ENEMY_IDS)
    v2.extract_runtime_campaign_profiles = extract_runtime_campaign_profiles
    v2.NORMAL_ENEMY_IDS = list(NORMAL_ENEMY_IDS)
    try:
        result = v2.simulate_matrix(root, **kwargs)
    finally:
        v2.extract_runtime_campaign_profiles = original_extract
        v2.NORMAL_ENEMY_IDS = original_normal_ids
    return _decorate_result(result, root)


def main() -> int:
    original_extract = v2.extract_runtime_campaign_profiles
    original_simulate = v2.simulate_matrix
    original_normal_ids = list(v2.NORMAL_ENEMY_IDS)
    v2.extract_runtime_campaign_profiles = extract_runtime_campaign_profiles
    v2.NORMAL_ENEMY_IDS = list(NORMAL_ENEMY_IDS)

    def _patched_simulate(root: Path = ROOT, **kwargs: Any):
        result = original_simulate(root, **kwargs)
        return _decorate_result(result, root)

    v2.simulate_matrix = _patched_simulate
    try:
        return v2.main()
    finally:
        v2.extract_runtime_campaign_profiles = original_extract
        v2.simulate_matrix = original_simulate
        v2.NORMAL_ENEMY_IDS = original_normal_ids


if __name__ == "__main__":
    raise SystemExit(main())
