#!/usr/bin/env python3
"""Bot v21: deterministic long-haul campaign stress model.

Runs hundreds of expeditions with repeated wins/losses, deaths, recruitment, purchases,
extractions and recovery. This complements (not replaces) the real Godot campaign bots.
"""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Any

RULES = Path("data/economy/sanctuary_economy_rules.json")
OUT = Path("reports/player-bot-v21-longhaul-campaign.json")
DEFAULT_SEEDS = [2101, 2202, 2303, 2404, 2505]


def load_rules() -> dict[str, Any]:
    return json.loads(RULES.read_text(encoding="utf-8"))


def clamp(value: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, value))


def run_campaign(seed: int, expeditions: int, rules: dict[str, Any]) -> dict[str, Any]:
    rng = random.Random(seed)
    market = rules["market"]
    recruit = rules["hero_recruitment"]
    gold = 180
    essence = 0
    roster = 4
    level = 1
    deaths = 0
    recruits = 0
    purchases = 0
    bankrupt_turns = 0
    extraction_streak = 0
    max_extraction_streak = 0
    lowest_gold = gold
    victories = 0
    defeats = 0
    history: list[dict[str, Any]] = []

    common_price = int(market["rarity_buy_price"]["common"])
    sell_ratio = float(market["sell_ratio"])
    base_cost = int(recruit["base_cost"])
    level_cost = int(recruit["level_cost"])
    max_cost = int(recruit["max_cost"])

    for expedition in range(1, expeditions + 1):
        # Difficulty rises with level, while adaptation/equipment keeps the win chance bounded.
        win_chance = max(0.38, min(0.78, 0.64 - level * 0.003 + purchases * 0.002))
        victory = rng.random() < win_chance
        extracted = victory or rng.random() < 0.58
        death = rng.random() < (0.06 if victory else 0.24)

        if victory:
            victories += 1
            reward = 34 + level * 3 + rng.randint(0, 34)
            gold += reward
            essence += 1 + (1 if rng.random() < 0.25 else 0)
            level = min(50, level + (1 if expedition % 3 == 0 else 0))
        else:
            defeats += 1
            loss = 6 + rng.randint(0, 20)
            gold = max(0, gold - loss)

        if extracted:
            extraction_streak += 1
            max_extraction_streak = max(max_extraction_streak, extraction_streak)
        else:
            extraction_streak = 0

        if death:
            deaths += 1
            roster = max(0, roster - 1)
            recruit_cost = min(max_cost, base_cost + max(0, level - int(recruit["catchup_level_lag"])) * level_cost)
            if gold >= recruit_cost:
                gold -= recruit_cost
                roster += 1
                recruits += 1

        # Strategic shopping: only spend when a reserve remains after the purchase.
        reserve = 45 + level * 2
        if gold >= common_price + reserve and rng.random() < 0.45:
            gold -= common_price
            purchases += 1
        elif gold < reserve and purchases > 0 and rng.random() < 0.25:
            resale = max(1, int(common_price * sell_ratio))
            gold += resale

        if gold < 20:
            bankrupt_turns += 1
        lowest_gold = min(lowest_gold, gold)
        if expedition % 25 == 0 or death or roster == 0:
            history.append({
                "expedition": expedition,
                "gold": gold,
                "essence": essence,
                "roster": roster,
                "level": level,
                "deaths": deaths,
                "recruits": recruits,
                "purchases": purchases,
            })
        if roster == 0:
            break

    completed = history[-1]["expedition"] if history else 0
    if completed < expeditions and roster > 0:
        completed = expeditions
    return {
        "seed": seed,
        "target_expeditions": expeditions,
        "completed_expeditions": completed,
        "gold": gold,
        "lowest_gold": lowest_gold,
        "essence": essence,
        "roster": roster,
        "level": level,
        "victories": victories,
        "defeats": defeats,
        "deaths": deaths,
        "recruits": recruits,
        "purchases": purchases,
        "bankrupt_turns": bankrupt_turns,
        "max_extraction_streak": max_extraction_streak,
        "history": history,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expeditions", type=int, default=200)
    args = parser.parse_args()
    expeditions = clamp(args.expeditions, 50, 1000)
    rules = load_rules()
    campaigns = [run_campaign(seed, expeditions, rules) for seed in DEFAULT_SEEDS]
    findings: list[dict[str, Any]] = []
    for campaign in campaigns:
        if campaign["roster"] == 0:
            findings.append({"seed": campaign["seed"], "code": "roster_collapse", "severity": "high", "expedition": campaign["completed_expeditions"]})
        if campaign["bankrupt_turns"] > expeditions * 0.30:
            findings.append({"seed": campaign["seed"], "code": "persistent_poverty", "severity": "high", "turns": campaign["bankrupt_turns"]})
        if campaign["recruits"] == 0 and campaign["deaths"] >= 3:
            findings.append({"seed": campaign["seed"], "code": "recruitment_recovery_failure", "severity": "high", "deaths": campaign["deaths"]})
    status = "failed" if any(f["severity"] == "high" for f in findings) else "passed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "bot": "v21",
        "status": status,
        "method": "deterministic long-haul campaign stress model",
        "seeds": DEFAULT_SEEDS,
        "campaigns": campaigns,
        "findings": findings,
        "note": "Model-level stress test; production-runtime fidelity remains covered by v5/v6/v19.",
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"PLAYER_BOT_V21_{status.upper()} campaigns={len(campaigns)} findings={len(findings)}")
    return 1 if status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
