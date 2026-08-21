#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import random
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
RUNTIME_PATH = ROOT / "scripts/core/roguelike_runtime.gd"

COMBAT_ROOMS = {"combat", "elite", "ambush", "creature", "boss"}
RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]


@dataclass
class Hero:
    class_id: str
    hp: float
    max_hp: float
    damage_min: float
    damage_max: float
    level: int
    guard: float = 0.0
    alive: bool = True
    damage_done: float = 0.0
    healing_done: float = 0.0
    actions: Counter[str] = field(default_factory=Counter)


@dataclass
class SimResult:
    payload: dict[str, Any]
    alerts: list[dict[str, Any]]


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _runtime_light_interval(rules: dict[str, Any]) -> tuple[int, bool]:
    configured = max(1, int(rules.get("light", {}).get("room_decay_interval", 1)))
    if not RUNTIME_PATH.exists():
        return configured, False
    source = RUNTIME_PATH.read_text(encoding="utf-8")
    implemented = "room_decay_interval" in source
    return (configured if implemented else 1), implemented


def _weighted_choice(rng: random.Random, weights: dict[str, int]) -> str:
    total = sum(max(0, int(v)) for v in weights.values())
    if total <= 0:
        return "combat"
    roll = rng.uniform(0.0, float(total))
    cursor = 0.0
    for key, value in weights.items():
        cursor += max(0, int(value))
        if roll <= cursor:
            return key
    return "combat"


def _pick_rarity(rng: random.Random, rules: dict[str, Any], loot_multiplier: float) -> str:
    weights = rules.get("loot_rarity_weights", {})
    adjusted: list[float] = []
    total = 0.0
    for index, rarity in enumerate(RARITIES):
        weight = float(weights.get(rarity, 0))
        if index >= 2:
            weight *= loot_multiplier
        adjusted.append(weight)
        total += weight
    if total <= 0:
        return "common"
    roll = rng.random() * total
    cursor = 0.0
    for rarity, weight in zip(RARITIES, adjusted):
        cursor += weight
        if roll <= cursor:
            return rarity
    return "common"


def _class_action_weights(class_id: str) -> dict[str, float]:
    if class_id == "vestal":
        return {"strike": 0.25, "heavy": 0.08, "heal": 0.46, "guard": 0.10, "technique": 0.11}
    if class_id == "surgeon":
        return {"strike": 0.31, "heavy": 0.10, "heal": 0.36, "guard": 0.10, "technique": 0.13}
    if class_id in {"occultist", "mystic"}:
        return {"strike": 0.35, "heavy": 0.24, "heal": 0.16, "guard": 0.07, "technique": 0.18}
    if class_id == "watcher":
        return {"strike": 0.34, "heavy": 0.15, "heal": 0.05, "guard": 0.32, "technique": 0.14}
    if class_id == "breaker":
        return {"strike": 0.31, "heavy": 0.43, "heal": 0.03, "guard": 0.10, "technique": 0.13}
    if class_id in {"ranger", "scout", "duelist"}:
        return {"strike": 0.41, "heavy": 0.33, "heal": 0.04, "guard": 0.08, "technique": 0.14}
    if class_id == "inquisitor":
        return {"strike": 0.36, "heavy": 0.26, "heal": 0.07, "guard": 0.12, "technique": 0.19}
    return {"strike": 0.48, "heavy": 0.24, "heal": 0.10, "guard": 0.12, "technique": 0.06}


def _choose_action(rng: random.Random, hero: Hero, party: list[Hero]) -> str:
    weights = _class_action_weights(hero.class_id)
    wounded = [h for h in party if h.alive and h.hp / max(1.0, h.max_hp) < 0.48]
    if wounded and weights.get("heal", 0.0) > 0.04:
        weights = dict(weights)
        weights["heal"] += 0.22
        weights["strike"] = max(0.05, weights["strike"] - 0.12)
        weights["heavy"] = max(0.03, weights["heavy"] - 0.06)
    if hero.hp / max(1.0, hero.max_hp) < 0.35:
        weights = dict(weights)
        weights["guard"] += 0.16
        weights["heavy"] = max(0.03, weights["heavy"] - 0.08)
    total = sum(weights.values())
    roll = rng.random() * total
    cursor = 0.0
    for action, weight in weights.items():
        cursor += weight
        if roll <= cursor:
            return action
    return "strike"


def _build_party(
    rng: random.Random,
    level: int,
    classes: list[dict[str, Any]],
    heroes: list[dict[str, Any]],
    canonical: bool,
) -> list[Hero]:
    class_map = {str(row["id"]): row for row in classes}
    selected: list[tuple[str, float]] = []
    if canonical:
        for row in heroes[:4]:
            selected.append((str(row["class_id"]), float(row.get("max_hp", class_map[str(row["class_id"])]["hp"]))))
    else:
        picks = rng.sample(classes, k=min(4, len(classes)))
        selected = [(str(row["id"]), float(row["hp"])) for row in picks]

    party: list[Hero] = []
    for class_id, hp_seed in selected:
        c = class_map[class_id]
        hp_scale = 1.0 + max(0, level - 3) * 0.018
        dmg_scale = 1.0 + max(0, level - 3) * 0.035
        party.append(
            Hero(
                class_id=class_id,
                hp=hp_seed * hp_scale,
                max_hp=hp_seed * hp_scale,
                damage_min=float(c["damage"][0]) * dmg_scale,
                damage_max=float(c["damage"][1]) * dmg_scale,
                level=level,
            )
        )
    return party


def _enemy_pack(
    rng: random.Random,
    room_type: str,
    depth: int,
    danger: float,
    dungeon: dict[str, Any],
    enemy_templates: list[dict[str, Any]],
) -> list[dict[str, float]]:
    normal_templates = [row for row in enemy_templates if not bool(row.get("boss", False))]
    if not normal_templates:
        normal_templates = [{"hp": 48, "damage": [6, 10], "fear": 4}]

    if room_type == "boss":
        count = 1
    elif room_type == "elite":
        count = 2
    elif room_type == "ambush":
        count = rng.randint(3, 4)
    elif room_type == "creature":
        count = 1
    else:
        count = rng.randint(2, 3)

    level = int(dungeon.get("enemy_base_level", 4)) + (depth - 1) * int(dungeon.get("enemy_level_per_depth", 2))
    if room_type == "elite":
        level += int(dungeon.get("elite_bonus_levels", 2))
    if room_type == "boss":
        level += int(dungeon.get("boss_bonus_levels", 4))
    delta = level - int(dungeon.get("template_reference_level", 3))
    hp_level = max(0.30, 1.0 + delta * float(dungeon.get("hp_per_level", 0.06)))
    dmg_level = max(0.40, 1.0 + delta * float(dungeon.get("damage_per_level", 0.04)))

    hp_risk = 1.0 + max(0.0, danger - 1.0) * 0.25
    dmg_risk = 1.0 + max(0.0, danger - 1.0) * 0.75
    if room_type == "elite":
        hp_level *= float(dungeon.get("elite_hp_multiplier", 1.2))
        dmg_level *= float(dungeon.get("elite_damage_multiplier", 1.0))
    elif room_type == "boss":
        hp_level *= float(dungeon.get("boss_hp_multiplier", 1.55)) * 2.7
        dmg_level *= float(dungeon.get("boss_damage_multiplier", 1.05))
    elif room_type == "ambush":
        dmg_level *= 1.08

    pack: list[dict[str, float]] = []
    for _ in range(count):
        template = rng.choice(normal_templates)
        hp = float(template.get("hp", 48)) * hp_level * hp_risk
        damage = _mean([float(v) for v in template.get("damage", [6, 10])]) * dmg_level * dmg_risk
        if room_type == "boss":
            damage *= 1.22
        pack.append({"hp": hp, "max_hp": hp, "damage": damage, "fear": float(template.get("fear", 4))})
    return pack


def _combat(
    rng: random.Random,
    party: list[Hero],
    room_type: str,
    depth: int,
    danger: float,
    dungeon: dict[str, Any],
    rules: dict[str, Any],
    enemy_templates: list[dict[str, Any]],
) -> tuple[bool, int, int]:
    enemies = _enemy_pack(rng, room_type, depth, danger, dungeon, enemy_templates)
    balance = rules.get("combat_balance", {})
    heal_map = balance.get("class_heal_base", {})
    stall_start = int(balance.get("stall_round_start", 5))
    heal_decay = float(balance.get("stall_healing_decay_per_round", 0.12))
    heal_floor = float(balance.get("stall_healing_efficiency_floor", 0.5))
    casualties_before = sum(1 for h in party if not h.alive)

    rounds = 0
    while rounds < 18 and any(h.alive for h in party) and any(e["hp"] > 0 for e in enemies):
        rounds += 1
        for hero in party:
            if not hero.alive or not any(e["hp"] > 0 for e in enemies):
                continue
            action = _choose_action(rng, hero, party)
            hero.actions[action] += 1
            if action == "guard":
                hero.guard = max(hero.guard, 0.45)
                continue
            if action == "heal":
                targets = [h for h in party if h.alive and h.hp < h.max_hp]
                if not targets:
                    action = "strike"
                    hero.actions["heal"] -= 1
                    hero.actions["strike"] += 1
                else:
                    target = min(targets, key=lambda h: h.hp / max(1.0, h.max_hp))
                    base = float(heal_map.get(hero.class_id, heal_map.get("default", 6)))
                    efficiency = 1.0
                    if rounds > stall_start:
                        efficiency = max(heal_floor, 1.0 - (rounds - stall_start) * heal_decay)
                    amount = min(target.max_hp - target.hp, base * efficiency * rng.uniform(0.9, 1.1))
                    target.hp += amount
                    hero.healing_done += amount
                    continue
            target = rng.choice([e for e in enemies if e["hp"] > 0])
            base_damage = rng.uniform(hero.damage_min, hero.damage_max)
            if action == "heavy":
                hit = rng.random() < 0.84
                damage = base_damage * 1.35 if hit else 0.0
            elif action == "technique":
                hit = rng.random() < 0.92
                damage = base_damage * 1.08 if hit else 0.0
            else:
                hit = rng.random() < 0.95
                damage = base_damage if hit else 0.0
            if rng.random() < 0.08:
                damage *= 1.5
            target["hp"] -= damage
            hero.damage_done += max(0.0, damage)

        if not any(e["hp"] > 0 for e in enemies):
            break

        for enemy in enemies:
            if enemy["hp"] <= 0:
                continue
            alive = [h for h in party if h.alive]
            if not alive:
                break
            target = rng.choice(alive)
            damage = enemy["damage"] * rng.uniform(0.82, 1.18)
            if target.guard > 0.0:
                damage *= 1.0 - target.guard
                target.guard = 0.0
            target.hp -= damage
            if target.hp <= 0:
                target.hp = 0.0
                target.alive = False

    won = any(h.alive for h in party) and not any(e["hp"] > 0 for e in enemies)
    casualties_after = sum(1 for h in party if not h.alive)
    return won, rounds, casualties_after - casualties_before


def _risk_profile(light: int, depth: int, rules: dict[str, Any]) -> tuple[float, float, float]:
    light_rules = rules.get("light", {})
    depth_rules = rules.get("depth", {})
    max_light = max(1, int(light_rules.get("max", 10)))
    darkness = 1.0 - max(0, min(max_light, light)) / max_light
    danger = 1.0 + darkness * float(light_rules.get("dark_danger_bonus", 0.45)) + (depth - 1) * float(depth_rules.get("danger_bonus_per_depth", 0.035))
    loot = 1.0 + darkness * float(light_rules.get("dark_loot_bonus", 0.70)) + (depth - 1) * float(depth_rules.get("loot_bonus_per_depth", 0.07))
    essence = 1.0 + darkness * float(light_rules.get("dark_essence_bonus", 0.55))
    return danger, loot, essence


def _generate_layout(rng: random.Random, rules: dict[str, Any]) -> list[tuple[int, str]]:
    depth_rules = rules.get("depth", {})
    depth_count = rng.randint(int(depth_rules.get("min", 3)), int(depth_rules.get("max", 5)))
    layout: list[tuple[int, str]] = []
    for depth in range(1, depth_count + 1):
        room_count = rng.randint(int(depth_rules.get("rooms_per_depth_min", 4)), int(depth_rules.get("rooms_per_depth_max", 6)))
        for index in range(room_count):
            room_type = _weighted_choice(rng, rules.get("room_weights", {}))
            if depth == 1 and index == 0:
                room_type = "start"
            elif depth == depth_count and index == room_count - 1:
                room_type = "boss"
            layout.append((depth, room_type))
    return layout


def _should_extract(rng: random.Random, party: list[Hero], depth: int, light: int, boss_room_seen: bool) -> bool:
    alive = [h for h in party if h.alive]
    if not alive or boss_room_seen:
        return False
    hp_ratio = sum(h.hp for h in alive) / max(1.0, sum(h.max_hp for h in alive))
    deaths = len(party) - len(alive)
    pressure = 0.0
    if deaths >= 2:
        pressure += 0.78
    elif deaths == 1:
        pressure += 0.28
    if hp_ratio < 0.30:
        pressure += 0.60
    elif hp_ratio < 0.45:
        pressure += 0.30
    if light <= 1 and depth >= 2:
        pressure += 0.25
    if depth >= 4:
        pressure += 0.05
    return rng.random() < min(0.92, pressure)


def simulate(root: Path = ROOT, runs: int | None = None, seed: int | None = None) -> SimResult:
    rules = _load_json(root / "data/roguelike/roguelike_rules.json")
    targets = _load_json(root / "data/roguelike/balance_targets.json")
    classes = _load_json(root / "data/classes.json")
    heroes = _load_json(root / "data/heroes.json")
    enemies = _load_json(root / "data/enemies.json")
    survival = _load_json(root / "data/levels/ashlands_survival_rules.json")
    dungeon_id = str(rules.get("default_dungeon_id", "first_veil_crypts"))
    dungeon = rules.get("dungeons", {}).get(dungeon_id, {})
    required_level = int(dungeon.get("required_level", 3))
    runs = int(runs if runs is not None else targets.get("default_runs", 12000))
    seed = int(seed if seed is not None else targets.get("seed", 20260821))
    rng = random.Random(seed)

    effective_light_interval, interval_implemented = _runtime_light_interval(rules)
    configured_interval = max(1, int(rules.get("light", {}).get("room_decay_interval", 1)))
    start_light = int(survival.get("expedition_inventory", {}).get("light", rules.get("light", {}).get("max", 10)))
    light_decay = max(1, int(rules.get("light", {}).get("room_decay", 1)))
    level_offsets = [int(v) for v in targets.get("party_level_offsets", [0, 2, 4, 6, 9])]
    level_bands = [required_level + offset for offset in level_offsets]
    canonical_share = float(targets.get("canonical_party_share", 0.5))

    outcome_counts = Counter()
    level_stats: dict[int, Counter[str]] = defaultdict(Counter)
    level_hp_remaining: dict[int, list[float]] = defaultdict(list)
    round_stats: dict[str, list[int]] = defaultdict(list)
    light_remaining: list[int] = []
    rooms_cleared: list[int] = []
    depths_reached: list[int] = []
    captures_per_run: list[int] = []
    gold_per_run: list[int] = []
    essence_per_run: list[int] = []
    rarity_counts = Counter()
    class_stats: dict[str, Counter[str]] = defaultdict(Counter)
    class_damage: dict[str, float] = defaultdict(float)
    class_healing: dict[str, float] = defaultdict(float)
    skill_usage = Counter()

    for run_index in range(runs):
        party_level = level_bands[run_index % len(level_bands)]
        canonical = rng.random() < canonical_share
        party = _build_party(rng, party_level, classes, heroes, canonical)
        for hero in party:
            class_stats[hero.class_id]["runs_present"] += 1

        layout = _generate_layout(rng, rules)
        light = start_light
        captures = 0
        gold = 0
        essence = 0
        cleared = 0
        deepest = 1
        outcome = "retreat"
        boss_seen = False

        for depth, room_type in layout:
            deepest = max(deepest, depth)
            cleared += 1
            if cleared % effective_light_interval == 0:
                light = max(0, light - light_decay)
            danger, loot_multiplier, essence_multiplier = _risk_profile(light, depth, rules)

            if room_type in COMBAT_ROOMS:
                won, combat_rounds, _ = _combat(rng, party, room_type, depth, danger, dungeon, rules, enemies)
                round_stats[room_type].append(combat_rounds)
                if not won:
                    outcome = "wipe"
                    break
                if room_type == "boss":
                    boss_seen = True
                    outcome = "victory"
                else:
                    if room_type == "creature" and captures < int(rules.get("capture_limit_per_zone", 2)) and rng.random() < 0.52:
                        if rng.random() < 0.62:
                            captures += 1
                    gold += int(round(rng.uniform(4, 10) * loot_multiplier))
                    essence += int(round(rng.uniform(0.6, 2.2) * essence_multiplier))

                loot_rolls = 0
                if room_type == "boss":
                    loot_rolls = 2
                elif room_type == "elite":
                    loot_rolls = 1
                elif room_type in {"combat", "ambush", "creature"} and rng.random() < 0.58:
                    loot_rolls = 1
                for _ in range(loot_rolls):
                    rarity_counts[_pick_rarity(rng, rules, loot_multiplier)] += 1
            elif room_type == "camp":
                for hero in party:
                    if hero.alive:
                        hero.hp = min(hero.max_hp, hero.hp + hero.max_hp * 0.15)
                light = min(int(rules.get("light", {}).get("max", 10)), light + 2)
            elif room_type == "treasure":
                for _ in range(2):
                    rarity_counts[_pick_rarity(rng, rules, loot_multiplier)] += 1
                gold += int(round(rng.uniform(9, 18) * loot_multiplier))
            elif room_type in {"ruins", "secret", "anomaly", "altar"}:
                if rng.random() < 0.55:
                    rarity_counts[_pick_rarity(rng, rules, loot_multiplier)] += 1
                essence += int(round(rng.uniform(1.0, 3.0) * essence_multiplier))
            elif room_type == "trap":
                alive = [h for h in party if h.alive]
                if alive:
                    target = rng.choice(alive)
                    target.hp -= target.max_hp * rng.uniform(0.05, 0.13) * danger
                    if target.hp <= 0:
                        target.hp = 0
                        target.alive = False

            if outcome == "victory":
                break
            if not any(h.alive for h in party):
                outcome = "wipe"
                break
            if _should_extract(rng, party, depth, light, boss_seen):
                outcome = "retreat"
                break

        alive = [h for h in party if h.alive]
        hp_ratio = sum(h.hp for h in alive) / max(1.0, sum(h.max_hp for h in alive)) if alive else 0.0
        deaths = len(party) - len(alive)
        outcome_counts[outcome] += 1
        level_stats[party_level][outcome] += 1
        level_stats[party_level]["runs"] += 1
        level_stats[party_level]["deaths"] += deaths
        level_hp_remaining[party_level].append(hp_ratio)
        light_remaining.append(light)
        rooms_cleared.append(cleared)
        depths_reached.append(deepest)
        captures_per_run.append(captures)
        gold_per_run.append(gold)
        essence_per_run.append(essence)

        for hero in party:
            cs = class_stats[hero.class_id]
            if outcome == "victory":
                cs["victory_runs"] += 1
            if hero.alive:
                cs["survived_runs"] += 1
            else:
                cs["deaths"] += 1
            class_damage[hero.class_id] += hero.damage_done
            class_healing[hero.class_id] += hero.healing_done
            skill_usage.update(hero.actions)

    class_rows: dict[str, Any] = {}
    for class_id, stats in sorted(class_stats.items()):
        present = max(1, stats["runs_present"])
        class_rows[class_id] = {
            "runs_present": stats["runs_present"],
            "win_rate": round(stats["victory_runs"] / present, 4),
            "survival_rate": round(stats["survived_runs"] / present, 4),
            "deaths": stats["deaths"],
            "damage_per_presence": round(class_damage[class_id] / present, 2),
            "healing_per_presence": round(class_healing[class_id] / present, 2),
        }

    level_rows: dict[str, Any] = {}
    for level in sorted(level_stats):
        stats = level_stats[level]
        count = max(1, stats["runs"])
        level_rows[str(level)] = {
            "runs": stats["runs"],
            "win_rate": round(stats["victory"] / count, 4),
            "retreat_rate": round(stats["retreat"] / count, 4),
            "wipe_rate": round(stats["wipe"] / count, 4),
            "deaths_per_run": round(stats["deaths"] / count, 4),
            "average_hp_remaining_pct": round(_mean(level_hp_remaining[level]) * 100.0, 2),
        }

    total_loot = sum(rarity_counts.values())
    total_actions = sum(skill_usage.values())
    payload = {
        "schema_version": 1,
        "seed": seed,
        "runs": runs,
        "dungeon_id": dungeon_id,
        "required_level": required_level,
        "runtime_contract": {
            "configured_light_decay_interval": configured_interval,
            "effective_light_decay_interval": effective_light_interval,
            "runtime_implements_room_decay_interval": interval_implemented,
        },
        "outcomes": {
            "victory_rate": round(outcome_counts["victory"] / runs, 4),
            "retreat_rate": round(outcome_counts["retreat"] / runs, 4),
            "wipe_rate": round(outcome_counts["wipe"] / runs, 4),
        },
        "expedition": {
            "average_rooms_cleared": round(_mean([float(v) for v in rooms_cleared]), 2),
            "average_deepest_depth": round(_mean([float(v) for v in depths_reached]), 2),
            "average_light_remaining": round(_mean([float(v) for v in light_remaining]), 2),
            "average_captures": round(_mean([float(v) for v in captures_per_run]), 3),
            "average_gold_found": round(_mean([float(v) for v in gold_per_run]), 2),
            "average_essence_found": round(_mean([float(v) for v in essence_per_run]), 2),
        },
        "combat_rounds": {key: round(_mean([float(v) for v in values]), 2) for key, values in sorted(round_stats.items())},
        "levels": level_rows,
        "classes": class_rows,
        "skill_usage": {
            key: {"count": value, "share": round(value / max(1, total_actions), 4)}
            for key, value in skill_usage.most_common()
        },
        "loot_rarity": {
            rarity: {"count": rarity_counts[rarity], "share": round(rarity_counts[rarity] / max(1, total_loot), 4)}
            for rarity in RARITIES
        },
    }

    alerts: list[dict[str, Any]] = []
    if configured_interval > 1 and not interval_implemented:
        alerts.append({"severity": "high", "code": "light_interval_runtime_mismatch", "detail": f"rules={configured_interval}, runtime=1"})

    req = level_rows.get(str(required_level), {})
    req_win = float(req.get("win_rate", 0.0))
    req_range = targets.get("required_level_win_rate", [0.45, 0.72])
    if req_win < float(req_range[0]) or req_win > float(req_range[1]):
        alerts.append({"severity": "medium", "code": "required_level_win_rate", "detail": f"{req_win:.3f} outside {req_range}"})
    if float(req.get("wipe_rate", 0.0)) > float(targets.get("required_level_wipe_rate_max", 0.25)):
        alerts.append({"severity": "high", "code": "required_level_wipe_rate", "detail": str(req.get("wipe_rate"))})

    target_keys = {"combat": "normal_rounds", "elite": "elite_rounds", "boss": "boss_rounds"}
    for room_type, target_key in target_keys.items():
        if room_type not in payload["combat_rounds"]:
            continue
        value = float(payload["combat_rounds"][room_type])
        low, high = [float(v) for v in targets.get(target_key, [0, 999])]
        if value < low or value > high:
            alerts.append({"severity": "medium", "code": f"{room_type}_rounds", "detail": f"{value:.2f} outside [{low:.2f}, {high:.2f}]"})

    eligible = [row for row in class_rows.values() if int(row["runs_present"]) >= int(targets.get("minimum_class_samples", 250))]
    if eligible:
        win_rates = [float(row["win_rate"]) for row in eligible]
        survival_rates = [float(row["survival_rate"]) for row in eligible]
        if max(win_rates) - min(win_rates) > float(targets.get("class_win_rate_spread_max", 0.18)):
            alerts.append({"severity": "medium", "code": "class_win_rate_spread", "detail": f"spread={max(win_rates)-min(win_rates):.3f}"})
        if max(survival_rates) - min(survival_rates) > float(targets.get("class_survival_rate_spread_max", 0.20)):
            alerts.append({"severity": "medium", "code": "class_survival_rate_spread", "detail": f"spread={max(survival_rates)-min(survival_rates):.3f}"})

    legendary_share = float(payload["loot_rarity"]["legendary"]["share"])
    if legendary_share > float(targets.get("legendary_loot_rate_max", 0.03)):
        alerts.append({"severity": "medium", "code": "legendary_loot_rate", "detail": f"{legendary_share:.3f}"})

    payload["alerts"] = alerts
    return SimResult(payload=payload, alerts=alerts)


def write_report(result: SimResult, report_path: Path, csv_path: Path | None = None) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(result.payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if csv_path is None:
        return
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["section", "key", "metric", "value"])
        for level, row in result.payload["levels"].items():
            for metric, value in row.items():
                writer.writerow(["level", level, metric, value])
        for class_id, row in result.payload["classes"].items():
            for metric, value in row.items():
                writer.writerow(["class", class_id, metric, value])
        for action, row in result.payload["skill_usage"].items():
            writer.writerow(["skill", action, "share", row["share"]])
        for rarity, row in result.payload["loot_rarity"].items():
            writer.writerow(["loot", rarity, "share", row["share"]])


def main() -> int:
    parser = argparse.ArgumentParser(description="Monte Carlo telemetry for LITD roguelike balance")
    parser.add_argument("--runs", type=int, default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--report", type=Path, default=ROOT / "reports/roguelike-telemetry.json")
    parser.add_argument("--csv", type=Path, default=ROOT / "reports/roguelike-telemetry.csv")
    parser.add_argument("--strict", action="store_true", help="Fail on high severity balance alerts")
    args = parser.parse_args()

    result = simulate(ROOT, runs=args.runs, seed=args.seed)
    write_report(result, args.report, args.csv)
    print(f"TELEMETRY runs={result.payload['runs']} seed={result.payload['seed']} dungeon={result.payload['dungeon_id']}")
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
    if args.strict and any(a["severity"] == "high" for a in result.alerts):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
