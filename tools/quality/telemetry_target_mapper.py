#!/usr/bin/env python3
"""Map raw LITD telemetry reports onto canonical design-target metric names.

The mapper is deliberately explicit: only known, semantically equivalent fields are
mapped. Missing or ambiguous metrics remain absent and are therefore evaluated as
INCONCLUSIVE instead of being guessed.
"""
from __future__ import annotations

from typing import Any


DIRECT_PATHS: dict[str, tuple[str, ...]] = {
    "outcomes.retreat_rate": ("outcomes", "retreat_rate"),
    "outcomes.wipe_rate": ("outcomes", "wipe_rate"),
    "combat.normal_rounds": ("combat_rounds", "combat"),
    "combat.elite_rounds": ("combat_rounds", "elite"),
    "combat.boss_rounds": ("combat_rounds", "boss"),
    "loot.legendary_rate": ("loot_rarity", "legendary", "share"),
    "expedition.visited_rooms": ("expedition", "average_rooms_cleared"),
}

# Balance-matrix v3 emits campaign encounter rows under monte_carlo.encounters.
CAMPAIGN_KEYS: dict[str, str] = {
    "campaign.normal_rounds": "campaign:normal",
    "campaign.miniboss_rounds": "campaign:miniboss",
    "campaign.boss_rounds": "campaign:boss",
}


def _get_path(payload: dict[str, Any], path: tuple[str, ...]) -> Any:
    value: Any = payload
    for key in path:
        if not isinstance(value, dict) or key not in value:
            return None
        value = value[key]
    return value


def _numeric(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _spread(rows: Any, field: str) -> float | None:
    if not isinstance(rows, dict):
        return None
    values: list[float] = []
    for row in rows.values():
        if not isinstance(row, dict):
            continue
        value = _numeric(row.get(field))
        if value is not None:
            values.append(value)
    if len(values) < 2:
        return None
    return max(values) - min(values)


def map_report_to_canonical_metrics(payload: dict[str, Any]) -> dict[str, float]:
    if not isinstance(payload, dict):
        raise ValueError("telemetry_payload_must_be_object")

    mapped: dict[str, float] = {}
    for canonical, path in DIRECT_PATHS.items():
        value = _numeric(_get_path(payload, path))
        if value is not None:
            mapped[canonical] = value

    win_spread = _spread(payload.get("classes"), "win_rate")
    if win_spread is not None:
        mapped["balance.class_win_rate_spread"] = win_spread
    survival_spread = _spread(payload.get("classes"), "survival_rate")
    if survival_spread is not None:
        mapped["balance.class_survival_rate_spread"] = survival_spread

    encounters = _get_path(payload, ("monte_carlo", "encounters"))
    if isinstance(encounters, dict):
        for canonical, source_key in CAMPAIGN_KEYS.items():
            row = encounters.get(source_key)
            if isinstance(row, dict):
                value = _numeric(row.get("average_rounds"))
                if value is not None:
                    mapped[canonical] = value

    # Do not infer duration, generated-room count, branch count, extraction windows,
    # events, discoveries or meaningful loot unless the telemetry explicitly emits
    # semantically matching fields.
    return mapped


def mapping_coverage(mapped: dict[str, float], target_registry: dict[str, Any]) -> dict[str, Any]:
    targets = target_registry.get("targets", {})
    target_keys = set(targets) if isinstance(targets, dict) else set()
    mapped_keys = set(mapped)
    return {
        "mapped_target_count": len(mapped_keys & target_keys),
        "total_target_count": len(target_keys),
        "unmapped_targets": sorted(target_keys - mapped_keys),
        "unknown_mapped_metrics": sorted(mapped_keys - target_keys),
    }
