#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from tools.qa import combat_economy_sim as legacy
from tools.qa.combat_turn_audit import run as run_turn_audit

ROOT = Path(__file__).resolve().parents[2]


def expected_hero_heavy_damage_v2(base_range: list[int], bonuses: dict[str, int]) -> float:
    base = (float(base_range[0]) + float(base_range[1])) / 2.0
    base += float(bonuses.get("damage_bonus", 0))
    damage = base * 1.35
    damage *= 1.0 + float(bonuses.get("precision", 0)) / 100.0
    damage *= 1.0 + float(bonuses.get("damage_percent", 0)) / 100.0
    damage *= 1.0 + 0.5 * float(bonuses.get("critical_chance", 0)) / 100.0
    return damage


def run(root: Path = ROOT):
    original = legacy.expected_hero_heavy_damage
    legacy.expected_hero_heavy_damage = expected_hero_heavy_damage_v2
    try:
        simulation = legacy.run(root)
    finally:
        legacy.expected_hero_heavy_damage = original

    obsolete_warning_names = {
        "Prototype de tour : seul le premier héros vivant agit",
        "Talents offensifs/défensifs potentiellement inertes dans le combat principal",
    }
    simulation.warnings = [
        item for item in simulation.warnings
        if item.get("name") not in obsolete_warning_names
    ]

    turn_report = run_turn_audit(root)
    simulation.report["combat_v2"] = turn_report
    for item in turn_report["checks"]:
        simulation.check("Combat v2 — %s" % item["name"], bool(item["ok"]), str(item.get("detail", "")))

    simulation.report["hero_skill_stat_usage"] = {
        "produced_stats": turn_report["produced_stats"],
        "consumed_by_effective_combat": turn_report["consumed_stats"],
        "missing_stats": turn_report["missing_stats"],
    }
    return simulation


def main() -> int:
    simulation = run(ROOT)
    path = legacy.write_report(ROOT, simulation)
    for check in simulation.checks:
        print(("PASS" if check["ok"] else "FAIL"), "-", check["name"], check["detail"])
    for warning in simulation.warnings:
        print("WARN -", warning["name"], warning["detail"])
    print(f"RESULT: {len(simulation.errors)} error(s), {len(simulation.warnings)} warning(s) — {path}")
    return 1 if simulation.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
