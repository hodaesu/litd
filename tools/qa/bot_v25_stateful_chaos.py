#!/usr/bin/env python3
"""Bot v25: deterministic stateful chaos monkey.

Generates long semi-random action sequences across combat/loot/extraction/market/recruit/save-load
and checks invariants after every transition. Failures preserve seed + step + action for replay.
"""
from __future__ import annotations

import json
import random
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from typing import Any

RULES = Path("data/economy/sanctuary_economy_rules.json")
OUT = Path("reports/player-bot-v25-stateful-chaos.json")
SEEDS = [2501, 2502, 2503, 2504, 2505]
STEPS_PER_SEED = 2500


@dataclass
class State:
    gold: int = 180
    essence: int = 0
    roster: int = 4
    inventory: int = 0
    in_expedition: bool = False
    battle_active: bool = False
    hp_pool: int = 400
    level: int = 1
    save_slot: int = 0


def load_rules() -> dict[str, Any]:
    return json.loads(RULES.read_text(encoding="utf-8"))


def assert_invariants(state: State) -> list[str]:
    errors = []
    if state.gold < 0:
        errors.append("negative_gold")
    if state.essence < 0:
        errors.append("negative_essence")
    if state.roster < 0 or state.roster > 12:
        errors.append("invalid_roster")
    if state.inventory < 0 or state.inventory > 999:
        errors.append("invalid_inventory")
    if state.hp_pool < 0:
        errors.append("negative_hp_pool")
    if not 1 <= state.level <= 50:
        errors.append("level_out_of_bounds")
    if state.battle_active and not state.in_expedition:
        errors.append("battle_without_expedition")
    if state.in_expedition and state.roster == 0:
        errors.append("expedition_without_roster")
    return errors


def valid_actions(state: State) -> list[str]:
    actions = ["save", "load"]
    if not state.in_expedition and state.roster > 0:
        actions += ["enter_expedition", "buy", "sell", "recruit"]
    if state.in_expedition:
        actions += ["loot", "extract", "start_combat"]
    if state.battle_active:
        actions += ["attack", "flee"]
    return actions


def main() -> int:
    rules = load_rules()
    common_price = int(rules["market"]["rarity_buy_price"]["common"])
    sell_price = max(1, int(common_price * float(rules["market"]["sell_ratio"])))
    recruit = rules["hero_recruitment"]
    failures: list[dict[str, Any]] = []
    traces: list[dict[str, Any]] = []
    total_steps = 0

    for seed in SEEDS:
        rng = random.Random(seed)
        state = State()
        saved = replace(state)
        action_counts: dict[str, int] = {}
        for step in range(STEPS_PER_SEED):
            actions = valid_actions(state)
            action = rng.choice(actions)
            action_counts[action] = action_counts.get(action, 0) + 1
            before = replace(state)

            if action == "save":
                saved = replace(state)
                state.save_slot += 1
                # save_slot is diagnostic metadata, not persisted gameplay state
                saved.save_slot = state.save_slot
            elif action == "load":
                state = replace(saved)
            elif action == "enter_expedition":
                state.in_expedition = True
                state.battle_active = False
            elif action == "start_combat":
                state.battle_active = True
            elif action == "attack":
                damage = rng.randint(0, 35)
                state.hp_pool = max(0, state.hp_pool - damage)
                if rng.random() < 0.38:
                    state.battle_active = False
                    state.gold += rng.randint(8, 32)
                    state.essence += 1 if rng.random() < 0.2 else 0
                elif rng.random() < 0.05 and state.roster > 0:
                    state.roster -= 1
                    state.hp_pool = max(0, state.hp_pool - 40)
                    if state.roster == 0:
                        state.battle_active = False
                        state.in_expedition = False
            elif action == "flee":
                state.battle_active = False
                state.in_expedition = False
                state.gold = max(0, state.gold - rng.randint(0, 12))
            elif action == "loot":
                state.inventory += 1
                state.gold += rng.randint(0, 18)
            elif action == "extract":
                state.battle_active = False
                state.in_expedition = False
                state.gold += state.inventory * rng.randint(2, 8)
                state.inventory = 0
                if rng.random() < 0.35:
                    state.level = min(50, state.level + 1)
            elif action == "buy":
                if state.gold >= common_price:
                    state.gold -= common_price
                    state.inventory += 1
            elif action == "sell":
                if state.inventory > 0:
                    state.inventory -= 1
                    state.gold += sell_price
            elif action == "recruit":
                level_cost = min(int(recruit["max_cost"]), int(recruit["base_cost"]) + max(0, state.level - int(recruit["catchup_level_lag"])) * int(recruit["level_cost"]))
                if state.roster < 4 and state.gold >= level_cost:
                    state.gold -= level_cost
                    state.roster += 1
                    state.hp_pool += 100

            total_steps += 1
            errors = assert_invariants(state)
            if errors:
                failures.append({
                    "seed": seed,
                    "step": step,
                    "action": action,
                    "errors": errors,
                    "before": asdict(before),
                    "after": asdict(state),
                    "replay_key": f"{seed}:{step}:{action}",
                })
                break

        traces.append({"seed": seed, "steps": step + 1, "action_counts": action_counts, "final_state": asdict(state)})

    status = "failed" if failures else "passed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "bot": "v25",
        "status": status,
        "method": "deterministic state-machine chaos sequences with per-transition invariants",
        "seeds": SEEDS,
        "steps_per_seed": STEPS_PER_SEED,
        "total_steps": total_steps,
        "failures": failures,
        "traces": traces,
        "invariants": [
            "resources_non_negative",
            "roster_bounds",
            "inventory_bounds",
            "level_1_to_50",
            "battle_requires_expedition",
            "expedition_requires_roster",
        ],
        "note": "Model-level chaos coverage; production Godot action adapters can replace transitions incrementally.",
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"PLAYER_BOT_V25_{status.upper()} steps={total_steps} failures={len(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
