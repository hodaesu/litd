#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Any

from tools.qa import balance_matrix_sim_v2 as v2

ROOT = v2.ROOT
BRIDGE_PATH = v2.BRIDGE_PATH


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
        "normal_enemy_ids": list(v2.NORMAL_ENEMY_IDS),
        "minibosses": minibosses,
        "bosses": bosses,
    }


def simulate_matrix(root: Path = ROOT, **kwargs: Any):
    original = v2.extract_runtime_campaign_profiles
    v2.extract_runtime_campaign_profiles = extract_runtime_campaign_profiles
    try:
        result = v2.simulate_matrix(root, **kwargs)
    finally:
        v2.extract_runtime_campaign_profiles = original
    result.payload["model_version"] = 5
    result.payload["contracts"]["campaign_profile_parser"] = "exact_runtime_blocks"
    return result


def main() -> int:
    original_extract = v2.extract_runtime_campaign_profiles
    original_simulate = v2.simulate_matrix
    v2.extract_runtime_campaign_profiles = extract_runtime_campaign_profiles

    def _patched_simulate(root: Path = ROOT, **kwargs: Any):
        result = original_simulate(root, **kwargs)
        result.payload["model_version"] = 5
        result.payload["contracts"]["campaign_profile_parser"] = "exact_runtime_blocks"
        return result

    v2.simulate_matrix = _patched_simulate
    try:
        return v2.main()
    finally:
        v2.extract_runtime_campaign_profiles = original_extract
        v2.simulate_matrix = original_simulate


if __name__ == "__main__":
    raise SystemExit(main())
