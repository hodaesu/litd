#!/usr/bin/env python3
from __future__ import annotations

import json
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


def _load_rules(root: Path) -> dict:
    return json.loads((root / "data/roguelike/roguelike_rules.json").read_text(encoding="utf-8"))


def _apply_roguelike_balance_checks(root: Path, simulation) -> None:
    rules = _load_rules(root)
    balance = rules.get("combat_balance", {})
    light = rules.get("light", {})
    depth = rules.get("depth", {})

    # Le simulateur historique lisait les PV écrits dans le bridge mais ignorait
    # la politique runtime qui renforce mini-boss et boss. On expose désormais les
    # deux valeurs pour éviter les faux positifs de boss "trop courts".
    simulation.warnings = [
        item for item in simulation.warnings
        if item.get("name") != "Boss potentiellement trop courts sans leurs résistances/puzzles"
    ]
    boss_rows = simulation.report.get("scripted_bosses", [])
    balanced_too_short: list[str] = []
    for row in boss_rows:
        rank = str(row.get("rank", ""))
        multiplier = 1.0
        if rank in {"miniboss", "deep_miniboss"}:
            multiplier = float(balance.get("campaign_miniboss_hp_multiplier", 1.0))
        elif rank in {"boss", "deep_boss"}:
            multiplier = float(balance.get("campaign_boss_hp_multiplier", 1.0))
        row["runtime_hp_multiplier"] = round(multiplier, 3)
        row["runtime_balanced_hp"] = int(round(float(row.get("hp", 0)) * multiplier))
        row["runtime_raw_rounds_to_zero_hp"] = round(float(row.get("raw_rounds_to_zero_hp", 0.0)) * multiplier, 2)
        if rank in {"boss", "deep_boss"} and float(row["runtime_raw_rounds_to_zero_hp"]) < 1.75:
            balanced_too_short.append(str(row.get("encounter_id", "")))
    simulation.check(
        "Boss : plancher de durée brute avant mécaniques",
        not balanced_too_short,
        ", ".join(balanced_too_short),
    )

    max_light = max(1, int(light.get("max", 10)))
    start_rules = json.loads((root / "data/levels/ashlands_survival_rules.json").read_text(encoding="utf-8"))
    start_light = int(start_rules.get("expedition_inventory", {}).get("light", max_light))
    decay = max(1, int(light.get("room_decay", 1)))
    interval = max(1, int(light.get("room_decay_interval", 1)))
    runway_rooms = int(start_light / decay) * interval
    max_depth = max(1, int(depth.get("max", 5)))
    full_dark_danger = 1.0 + float(light.get("dark_danger_bonus", 0.0)) + float(max_depth - 1) * float(depth.get("danger_bonus_per_depth", 0.0))
    full_dark_loot = 1.0 + float(light.get("dark_loot_bonus", 0.0)) + float(max_depth - 1) * float(depth.get("loot_bonus_per_depth", 0.0))
    simulation.report["roguelike_balance"] = {
        "starting_light": start_light,
        "automatic_light_runway_rooms": runway_rooms,
        "full_dark_max_depth_danger": round(full_dark_danger, 3),
        "full_dark_max_depth_loot": round(full_dark_loot, 3),
        "base_legendary_weight": int(rules.get("loot_rarity_weights", {}).get("legendary", 0)),
        "stun_chain_resistance": int(balance.get("stun_chain_resistance", 0)),
        "boss_stun_chain_resistance": int(balance.get("boss_stun_chain_resistance", 0)),
        "stall_round_start": int(balance.get("stall_round_start", 0)),
    }
    simulation.check("Roguelike : Lumière utile sur une descente longue", runway_rooms >= 12, f"autonomie théorique={runway_rooms} salles")
    simulation.check("Roguelike : obscurité dangereuse sans doubler les PV/danger", 1.35 <= full_dark_danger <= 1.70, f"danger max={full_dark_danger:.2f}")
    simulation.check("Roguelike : pousser dans le noir récompense le risque", full_dark_loot > full_dark_danger, f"butin={full_dark_loot:.2f} danger={full_dark_danger:.2f}")
    simulation.check("Roguelike : légendaire réellement rare à la base", int(rules.get("loot_rarity_weights", {}).get("legendary", 0)) <= 1)

    ui = (root / "scripts/ui/main_v25.gd").read_text(encoding="utf-8")
    simulation.check("Combat : anti-stall de soin actif", "stall_healing_decay_per_round" in ui and "stall_healing_efficiency_floor" in ui)
    simulation.check("Combat : résistance aux chaînes de stun active", "stun_recovery_until_round" in ui and "boss_stun_chain_resistance" in ui)


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
    _apply_roguelike_balance_checks(root, simulation)
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
