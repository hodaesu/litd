#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Any

from tools.qa import roguelike_telemetry_sim as legacy

ROOT = Path(__file__).resolve().parents[2]
UI_PATH = ROOT / "scripts/ui/main_v25.gd"
ROOM_ENCOUNTER_IDS: dict[str, list[int]] = {
    "combat": [1, 8],
    "elite": [10, 8],
    "ambush": [8, 8, 1],
    "creature": [10],
    "boss": [38],
}


def _runtime_light_interval_v2(rules: dict[str, Any]) -> tuple[int, bool]:
    configured = max(1, int(rules.get("light", {}).get("room_decay_interval", 1)))
    sources: list[str] = []
    for path in (legacy.RUNTIME_PATH, UI_PATH):
        if path.exists():
            sources.append(path.read_text(encoding="utf-8"))
    implemented = any("room_decay_interval" in source for source in sources)
    return (configured if implemented else 1), implemented


def _enemy_pack_v2(
    rng: random.Random,
    room_type: str,
    depth: int,
    danger: float,
    dungeon: dict[str, Any],
    enemy_templates: list[dict[str, Any]],
) -> list[dict[str, float]]:
    by_id = {int(row.get("id", -1)): row for row in enemy_templates}
    ids = ROOM_ENCOUNTER_IDS.get(room_type, ROOM_ENCOUNTER_IDS["combat"])

    level = int(dungeon.get("enemy_base_level", 4)) + (depth - 1) * int(dungeon.get("enemy_level_per_depth", 2))
    if room_type == "elite":
        level += int(dungeon.get("elite_bonus_levels", 2))
    elif room_type == "boss":
        level += int(dungeon.get("boss_bonus_levels", 4))

    delta = level - int(dungeon.get("template_reference_level", 3))
    hp_level = max(0.25, 1.0 + delta * float(dungeon.get("hp_per_level", 0.06)))
    damage_level = max(0.25, 1.0 + delta * float(dungeon.get("damage_per_level", 0.04)))
    danger_hp = 1.0 + max(0.0, danger - 1.0) * 0.25
    danger_damage = 1.0 + max(0.0, danger - 1.0) * 0.75

    room_hp = 1.0
    room_damage = 1.0
    if room_type == "elite":
        room_hp = float(dungeon.get("elite_hp_multiplier", 1.20))
        room_damage = float(dungeon.get("elite_damage_multiplier", 1.0))
    elif room_type == "boss":
        room_hp = float(dungeon.get("boss_hp_multiplier", 1.55))
        room_damage = float(dungeon.get("boss_damage_multiplier", 1.05))

    pack: list[dict[str, float]] = []
    for enemy_id in ids:
        template = by_id.get(enemy_id)
        if template is None:
            continue
        hp = float(template.get("hp", 48)) * hp_level * danger_hp * room_hp
        damage_values = [float(value) for value in template.get("damage", [6, 10])]
        damage = legacy._mean(damage_values) * damage_level * danger_damage * room_damage
        pack.append({
            "hp": hp,
            "max_hp": hp,
            "damage": damage,
            "fear": float(template.get("fear", 4)),
        })
    return pack


def simulate(root: Path = ROOT, runs: int | None = None, seed: int | None = None) -> legacy.SimResult:
    original_interval = legacy._runtime_light_interval
    original_pack = legacy._enemy_pack
    legacy._runtime_light_interval = _runtime_light_interval_v2
    legacy._enemy_pack = _enemy_pack_v2
    try:
        result = legacy.simulate(root, runs=runs, seed=seed)
    finally:
        legacy._runtime_light_interval = original_interval
        legacy._enemy_pack = original_pack

    result.payload["model_version"] = 2
    result.payload["encounter_source"] = "scripts/ui/main_v25.gd"
    result.payload["encounter_groups"] = ROOM_ENCOUNTER_IDS
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Runtime-aligned Monte Carlo telemetry for LITD")
    parser.add_argument("--runs", type=int, default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--report", type=Path, default=ROOT / "reports/roguelike-telemetry.json")
    parser.add_argument("--csv", type=Path, default=ROOT / "reports/roguelike-telemetry.csv")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    result = simulate(ROOT, runs=args.runs, seed=args.seed)
    legacy.write_report(result, args.report, args.csv)
    print(f"TELEMETRY_V2 runs={result.payload['runs']} seed={result.payload['seed']} dungeon={result.payload['dungeon_id']}")
    print("OUTCOMES", json.dumps(result.payload["outcomes"], ensure_ascii=False, sort_keys=True))
    print("ROUNDS", json.dumps(result.payload["combat_rounds"], ensure_ascii=False, sort_keys=True))
    print("EXPEDITION", json.dumps(result.payload["expedition"], ensure_ascii=False, sort_keys=True))
    print("LEVELS", json.dumps(result.payload["levels"], ensure_ascii=False, sort_keys=True))
    print("CLASSES", json.dumps(result.payload["classes"], ensure_ascii=False, sort_keys=True))
    print("SKILLS", json.dumps(result.payload["skill_usage"], ensure_ascii=False, sort_keys=True))
    print("LOOT", json.dumps(result.payload["loot_rarity"], ensure_ascii=False, sort_keys=True))
    for alert in result.alerts:
        print(f"ALERT {alert['severity'].upper()} {alert['code']}: {alert['detail']}")
    print(f"REPORT {args.report}")
    if args.strict and any(alert["severity"] == "high" for alert in result.alerts):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
