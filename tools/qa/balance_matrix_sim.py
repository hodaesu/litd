#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import gzip
import itertools
import json
import math
import random
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable

from tools.qa import roguelike_telemetry_sim as legacy
from tools.qa import roguelike_telemetry_sim_v2 as runtime_model

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class Aggregate:
    samples: int = 0
    wins: int = 0
    deaths: int = 0
    rounds: float = 0.0

    def add(self, *, samples: int, wins: int, deaths: int, rounds: float) -> None:
        self.samples += samples
        self.wins += wins
        self.deaths += deaths
        self.rounds += rounds * samples

    def row(self) -> dict[str, Any]:
        count = max(1, self.samples)
        return {
            "samples": self.samples,
            "win_rate": round(self.wins / count, 4),
            "average_rounds": round(self.rounds / count, 3),
            "deaths_per_battle": round(self.deaths / count, 4),
        }


@dataclass
class MatrixResult:
    payload: dict[str, Any]
    alerts: list[dict[str, Any]]


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _class_map(classes: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(row["id"]): row for row in classes}


def all_compositions(classes: list[dict[str, Any]]) -> list[tuple[str, ...]]:
    ids = sorted(str(row["id"]) for row in classes)
    if len(ids) < 4:
        return []
    return list(itertools.combinations(ids, 4))


def canonical_composition(heroes: list[dict[str, Any]]) -> tuple[str, ...]:
    ids = [str(row.get("class_id", "")) for row in heroes[:4] if str(row.get("class_id", ""))]
    return tuple(sorted(dict.fromkeys(ids)))


def representative_compositions(
    classes: list[dict[str, Any]],
    heroes: list[dict[str, Any]],
    count: int,
) -> list[tuple[str, ...]]:
    combos = all_compositions(classes)
    if not combos:
        return []
    count = max(1, min(count, len(combos)))
    selected: list[tuple[str, ...]] = []
    canonical = canonical_composition(heroes)
    if len(canonical) == 4 and canonical in combos:
        selected.append(canonical)
    if count == 1:
        return selected or [combos[0]]
    for index in range(count):
        position = int(round(index * (len(combos) - 1) / max(1, count - 1)))
        combo = combos[position]
        if combo not in selected:
            selected.append(combo)
    cursor = 0
    while len(selected) < count and cursor < len(combos):
        if combos[cursor] not in selected:
            selected.append(combos[cursor])
        cursor += 1
    return selected[:count]


def _build_party(
    level: int,
    composition: tuple[str, ...],
    classes: list[dict[str, Any]],
) -> list[legacy.Hero]:
    cmap = _class_map(classes)
    party: list[legacy.Hero] = []
    hp_scale = 1.0 + max(0, level - 3) * 0.018
    damage_scale = 1.0 + max(0, level - 3) * 0.035
    for class_id in composition:
        row = cmap[class_id]
        hp = float(row["hp"]) * hp_scale
        party.append(
            legacy.Hero(
                class_id=class_id,
                hp=hp,
                max_hp=hp,
                damage_min=float(row["damage"][0]) * damage_scale,
                damage_max=float(row["damage"][1]) * damage_scale,
                level=level,
            )
        )
    return party


def _ngplus_multipliers(cycle: int, ngplus: dict[str, Any]) -> tuple[float, float, float]:
    curve = ngplus.get("difficulty_per_cycle", {})
    hp = 1.0 + cycle * float(curve.get("enemy_hp_pct", 18)) / 100.0
    damage = 1.0 + cycle * float(curve.get("enemy_damage_pct", 12)) / 100.0
    fear = 1.0 + cycle * float(curve.get("enemy_fear_pct", 8)) / 100.0
    return hp, damage, fear


def campaign_reference_level(chapter_number: int, encounter_type: str) -> int:
    if encounter_type in {"miniboss", "boss"}:
        return max(1, min(50, 3 + max(0, chapter_number - 1) * 5))
    return 3


def _campaign_pack(
    level: int,
    chapter_number: int,
    encounter_type: str,
    cycle: int,
    rules: dict[str, Any],
    matrix_config: dict[str, Any],
    enemies: list[dict[str, Any]],
    ngplus: dict[str, Any],
) -> list[dict[str, float]]:
    by_id = {int(row.get("id", -1)): row for row in enemies}
    campaign_cfg = matrix_config.get("campaign", {})
    ids = [int(value) for value in campaign_cfg.get(f"{encounter_type}_enemy_ids", [])]
    if not ids:
        ids = [1, 8] if encounter_type == "normal" else ([10] if encounter_type == "miniboss" else [38])

    reference = campaign_reference_level(chapter_number, encounter_type)
    delta = level - reference
    hp_multiplier = _clamp(1.0 + delta * 0.045, 0.50, 2.75)
    damage_multiplier = _clamp(1.0 + delta * 0.03, 0.65, 2.00)
    fear_multiplier = _clamp(1.0 + delta * 0.018, 0.70, 1.65)

    combat_balance = rules.get("combat_balance", {})
    encounter_hp = 1.0
    encounter_damage = 1.0
    if encounter_type == "miniboss":
        encounter_hp = float(combat_balance.get("campaign_miniboss_hp_multiplier", 1.20))
        encounter_damage = float(combat_balance.get("campaign_miniboss_damage_multiplier", 1.0))
    elif encounter_type == "boss":
        encounter_hp = float(combat_balance.get("campaign_boss_hp_multiplier", 1.50))
        encounter_damage = float(combat_balance.get("campaign_boss_damage_multiplier", 1.05))

    cycle_hp, cycle_damage, cycle_fear = _ngplus_multipliers(cycle, ngplus)
    pack: list[dict[str, float]] = []
    for enemy_id in ids:
        template = by_id.get(enemy_id)
        if template is None:
            continue
        hp = float(template.get("hp", 48)) * hp_multiplier * encounter_hp * cycle_hp
        damage_values = [float(value) for value in template.get("damage", [6, 10])]
        damage = legacy._mean(damage_values) * damage_multiplier * encounter_damage * cycle_damage
        fear = float(template.get("fear", 4)) * fear_multiplier * cycle_fear
        pack.append({"hp": hp, "max_hp": hp, "damage": damage, "fear": fear})
    return pack


def dungeon_enemy_level(profile: dict[str, Any], depth: int, room_type: str) -> int:
    level = int(profile.get("enemy_base_level", 3))
    level += max(0, depth - 1) * int(profile.get("enemy_level_per_depth", 0))
    if room_type == "elite":
        level += int(profile.get("elite_bonus_levels", 0))
    elif room_type == "boss":
        level += int(profile.get("boss_bonus_levels", 0))
    return max(1, min(50, level))


def _dungeon_pack(
    rng: random.Random,
    room_type: str,
    depth: int,
    cycle: int,
    profile: dict[str, Any],
    enemies: list[dict[str, Any]],
    ngplus: dict[str, Any],
) -> list[dict[str, float]]:
    pack = runtime_model._enemy_pack_v2(rng, room_type, depth, 1.0, profile, enemies)
    cycle_hp, cycle_damage, cycle_fear = _ngplus_multipliers(cycle, ngplus)
    for enemy in pack:
        enemy["hp"] *= cycle_hp
        enemy["max_hp"] *= cycle_hp
        enemy["damage"] *= cycle_damage
        enemy["fear"] *= cycle_fear
    return pack


def _combat_with_pack(
    rng: random.Random,
    party: list[legacy.Hero],
    enemies: list[dict[str, float]],
    rules: dict[str, Any],
) -> tuple[bool, int, int]:
    balance = rules.get("combat_balance", {})
    heal_map = balance.get("class_heal_base", {})
    stall_start = int(balance.get("stall_round_start", 5))
    heal_decay = float(balance.get("stall_healing_decay_per_round", 0.12))
    heal_floor = float(balance.get("stall_healing_efficiency_floor", 0.5))
    casualties_before = sum(1 for hero in party if not hero.alive)
    rounds = 0

    while rounds < 18 and any(hero.alive for hero in party) and any(enemy["hp"] > 0 for enemy in enemies):
        rounds += 1
        for hero in party:
            if not hero.alive or not any(enemy["hp"] > 0 for enemy in enemies):
                continue
            action = legacy._choose_action(rng, hero, party)
            hero.actions[action] += 1
            if action == "guard":
                hero.guard = max(hero.guard, 0.45)
                continue
            if action == "heal":
                targets = [candidate for candidate in party if candidate.alive and candidate.hp < candidate.max_hp]
                if targets:
                    target = min(targets, key=lambda candidate: candidate.hp / max(1.0, candidate.max_hp))
                    base = float(heal_map.get(hero.class_id, heal_map.get("default", 6)))
                    efficiency = 1.0
                    if rounds > stall_start:
                        efficiency = max(heal_floor, 1.0 - (rounds - stall_start) * heal_decay)
                    amount = min(target.max_hp - target.hp, base * efficiency * rng.uniform(0.9, 1.1))
                    target.hp += amount
                    hero.healing_done += amount
                    continue
                hero.actions["heal"] -= 1
                hero.actions["strike"] += 1
                action = "strike"

            target = rng.choice([enemy for enemy in enemies if enemy["hp"] > 0])
            base_damage = rng.uniform(hero.damage_min, hero.damage_max)
            if action == "heavy":
                damage = base_damage * 1.35 if rng.random() < 0.84 else 0.0
            elif action == "technique":
                damage = base_damage * 1.08 if rng.random() < 0.92 else 0.0
            else:
                damage = base_damage if rng.random() < 0.95 else 0.0
            if rng.random() < 0.08:
                damage *= 1.5
            target["hp"] -= damage
            hero.damage_done += max(0.0, damage)

        if not any(enemy["hp"] > 0 for enemy in enemies):
            break

        for enemy in enemies:
            if enemy["hp"] <= 0:
                continue
            alive = [hero for hero in party if hero.alive]
            if not alive:
                break
            target = rng.choice(alive)
            damage = enemy["damage"] * rng.uniform(0.82, 1.18)
            if target.guard > 0:
                damage *= 1.0 - target.guard
                target.guard = 0.0
            target.hp -= damage
            if target.hp <= 0:
                target.hp = 0.0
                target.alive = False

    won = any(hero.alive for hero in party) and not any(enemy["hp"] > 0 for enemy in enemies)
    casualties_after = sum(1 for hero in party if not hero.alive)
    return won, rounds, casualties_after - casualties_before


def _party_power_index(
    level: int,
    composition: tuple[str, ...],
    classes: list[dict[str, Any]],
    rules: dict[str, Any],
) -> float:
    cmap = _class_map(classes)
    heal_map = rules.get("combat_balance", {}).get("class_heal_base", {})
    hp_scale = 1.0 + max(0, level - 3) * 0.018
    damage_scale = 1.0 + max(0, level - 3) * 0.035
    offense = 0.0
    sustain = 0.0
    total_hp = 0.0
    for class_id in composition:
        row = cmap[class_id]
        weights = legacy._class_action_weights(class_id)
        avg_damage = legacy._mean([float(value) for value in row["damage"]]) * damage_scale
        expected_attack = (
            weights.get("strike", 0.0) * 0.95
            + weights.get("heavy", 0.0) * 0.84 * 1.35
            + weights.get("technique", 0.0) * 0.92 * 1.08
        )
        offense += avg_damage * expected_attack * 1.04
        sustain += weights.get("heal", 0.0) * float(heal_map.get(class_id, heal_map.get("default", 6)))
        hp = float(row["hp"]) * hp_scale
        total_hp += hp * (1.0 + weights.get("guard", 0.0) * 0.45)
    return offense + sustain * 0.40 + total_hp * 0.018


def _enemy_pressure_index(pack: list[dict[str, float]]) -> float:
    if not pack:
        return 0.0
    total_hp = sum(float(enemy["max_hp"]) for enemy in pack)
    total_damage = sum(float(enemy["damage"]) for enemy in pack)
    total_fear = sum(float(enemy.get("fear", 0.0)) for enemy in pack)
    return total_hp * 0.055 + total_damage * 1.20 + total_fear * 0.20


def _depth_for(label: str, max_depth: int) -> int:
    if label == "first":
        return 1
    if label == "last":
        return max_depth
    return max(1, int(math.ceil(max_depth / 2.0)))


def _add_aggregate(bucket: dict[Any, Aggregate], key: Any, row: dict[str, Any]) -> None:
    bucket[key].add(
        samples=int(row["samples"]),
        wins=int(row["wins"]),
        deaths=int(row["deaths"]),
        rounds=float(row["average_rounds"]),
    )


def _row_from_samples(
    *,
    scope: str,
    level: int,
    cycle: int,
    composition: tuple[str, ...],
    label: str,
    samples: int,
    wins: int,
    deaths: int,
    total_rounds: int,
    extra: dict[str, Any],
) -> dict[str, Any]:
    return {
        "scope": scope,
        "label": label,
        "level": level,
        "cycle": cycle,
        "composition": "+".join(composition),
        "samples": samples,
        "wins": wins,
        "win_rate": round(wins / max(1, samples), 4),
        "deaths": deaths,
        "deaths_per_battle": round(deaths / max(1, samples), 4),
        "average_rounds": round(total_rounds / max(1, samples), 3),
        **extra,
    }


def _mc_cell(
    rng: random.Random,
    *,
    scope: str,
    level: int,
    cycle: int,
    composition: tuple[str, ...],
    classes: list[dict[str, Any]],
    rules: dict[str, Any],
    samples: int,
    label: str,
    pack_factory: Callable[[random.Random], list[dict[str, float]]],
    extra: dict[str, Any],
) -> dict[str, Any]:
    wins = 0
    deaths = 0
    rounds = 0
    for _ in range(samples):
        party = _build_party(level, composition, classes)
        pack = pack_factory(rng)
        won, battle_rounds, battle_deaths = _combat_with_pack(rng, party, pack, rules)
        wins += int(won)
        deaths += battle_deaths
        rounds += battle_rounds
    return _row_from_samples(
        scope=scope,
        level=level,
        cycle=cycle,
        composition=composition,
        label=label,
        samples=samples,
        wins=wins,
        deaths=deaths,
        total_rounds=rounds,
        extra=extra,
    )


def simulate_matrix(
    root: Path = ROOT,
    *,
    mode: str = "quick",
    seed: int | None = None,
    levels: Iterable[int] | None = None,
    monte_carlo_compositions: list[tuple[str, ...]] | None = None,
    monte_carlo_cycles: list[int] | None = None,
    samples_per_cell: int | None = None,
    raw_sink: Callable[[dict[str, Any]], None] | None = None,
) -> MatrixResult:
    rules = _load_json(root / "data/roguelike/roguelike_rules.json")
    config = _load_json(root / "data/roguelike/balance_matrix.json")
    classes = _load_json(root / "data/classes.json")
    heroes = _load_json(root / "data/heroes.json")
    enemies = _load_json(root / "data/enemies.json")
    campaign = _load_json(root / "data/world/main_campaign.json")
    ngplus = _load_json(root / "data/world/new_game_plus.json")

    if mode not in {"quick", "exhaustive"}:
        raise ValueError(f"unsupported mode: {mode}")

    mode_cfg = config.get(mode, {})
    seed = int(seed if seed is not None else config.get("seed", 20260821))
    rng = random.Random(seed)
    selected_levels = sorted({max(1, min(50, int(value))) for value in (levels or range(1, 51))})
    all_combos = all_compositions(classes)

    if monte_carlo_compositions is None:
        requested = int(mode_cfg.get("monte_carlo_compositions", 10 if mode == "quick" else 32))
        monte_carlo_compositions = representative_compositions(classes, heroes, requested)
    if monte_carlo_cycles is None:
        monte_carlo_cycles = [int(value) for value in mode_cfg.get("monte_carlo_cycles", [0, 1, 4])]
    if samples_per_cell is None:
        samples_per_cell = max(1, int(mode_cfg.get("samples_per_cell", 1)))

    analytical_cycles = [int(value) for value in config.get("analytical_cycles", [0, 1, 2, 3, 4])]
    chapters = sorted(campaign.get("chapters", []), key=lambda row: int(row.get("number", 0)))
    dungeons = rules.get("dungeons", {})
    max_depth = int(rules.get("depth", {}).get("max", 5))
    dungeon_encounters = config.get("dungeon", {}).get(
        "encounters",
        [
            {"type": "combat", "depth": "first"},
            {"type": "elite", "depth": "middle"},
            {"type": "boss", "depth": "last"},
        ],
    )
    campaign_encounters = [str(value) for value in config.get("campaign", {}).get("encounter_types", ["normal", "miniboss", "boss"])]

    analytical_scenarios = 0
    analytical_campaign = defaultdict(lambda: {"count": 0, "sum": 0.0, "min": float("inf"), "max": 0.0})
    analytical_dungeon = defaultdict(lambda: {"count": 0, "sum": 0.0, "min": float("inf"), "max": 0.0})
    power_by_level = defaultdict(list)

    for level in selected_levels:
        for composition in all_combos:
            party_power = _party_power_index(level, composition, classes, rules)
            power_by_level[level].append(party_power)
            for cycle in analytical_cycles:
                for chapter in chapters:
                    chapter_number = int(chapter.get("number", 1))
                    for encounter_type in campaign_encounters:
                        pack = _campaign_pack(level, chapter_number, encounter_type, cycle, rules, config, enemies, ngplus)
                        pressure = _enemy_pressure_index(pack) / max(0.01, party_power)
                        bucket = analytical_campaign[(level, cycle)]
                        bucket["count"] += 1
                        bucket["sum"] += pressure
                        bucket["min"] = min(bucket["min"], pressure)
                        bucket["max"] = max(bucket["max"], pressure)
                        analytical_scenarios += 1
                for dungeon_id, profile_value in dungeons.items():
                    profile = dict(profile_value)
                    required = int(profile.get("required_level", 1))
                    if level < required:
                        continue
                    for encounter in dungeon_encounters:
                        room_type = str(encounter.get("type", "combat"))
                        depth = _depth_for(str(encounter.get("depth", "first")), max_depth)
                        pack = _dungeon_pack(rng, room_type, depth, cycle, profile, enemies, ngplus)
                        pressure = _enemy_pressure_index(pack) / max(0.01, party_power)
                        bucket = analytical_dungeon[(str(dungeon_id), level, cycle)]
                        bucket["count"] += 1
                        bucket["sum"] += pressure
                        bucket["min"] = min(bucket["min"], pressure)
                        bucket["max"] = max(bucket["max"], pressure)
                        analytical_scenarios += 1

    campaign_by_level: dict[Any, Aggregate] = defaultdict(Aggregate)
    campaign_by_cycle: dict[Any, Aggregate] = defaultdict(Aggregate)
    campaign_by_chapter: dict[Any, Aggregate] = defaultdict(Aggregate)
    campaign_by_composition: dict[Any, Aggregate] = defaultdict(Aggregate)
    campaign_level_cycle: dict[Any, Aggregate] = defaultdict(Aggregate)
    dungeon_by_level: dict[Any, Aggregate] = defaultdict(Aggregate)
    dungeon_by_cycle: dict[Any, Aggregate] = defaultdict(Aggregate)
    dungeon_by_id: dict[Any, Aggregate] = defaultdict(Aggregate)
    dungeon_by_composition: dict[Any, Aggregate] = defaultdict(Aggregate)
    dungeon_id_level_cycle: dict[Any, Aggregate] = defaultdict(Aggregate)
    encounter_aggregates: dict[Any, Aggregate] = defaultdict(Aggregate)
    slowest_cells: list[dict[str, Any]] = []
    hardest_cells: list[dict[str, Any]] = []
    mc_cells = 0
    mc_battles = 0

    def emit(row: dict[str, Any]) -> None:
        nonlocal mc_cells, mc_battles, slowest_cells, hardest_cells
        mc_cells += 1
        mc_battles += int(row["samples"])
        if raw_sink is not None:
            raw_sink(row)
        slowest_cells.append(row)
        slowest_cells = sorted(slowest_cells, key=lambda item: float(item["average_rounds"]), reverse=True)[:12]
        hardest_cells.append(row)
        hardest_cells = sorted(
            hardest_cells,
            key=lambda item: (float(item["win_rate"]), -float(item["average_rounds"])),
        )[:12]

        scope = str(row["scope"])
        if scope == "campaign":
            _add_aggregate(campaign_by_level, int(row["level"]), row)
            _add_aggregate(campaign_by_cycle, int(row["cycle"]), row)
            _add_aggregate(campaign_by_chapter, str(row["chapter_id"]), row)
            _add_aggregate(campaign_by_composition, str(row["composition"]), row)
            _add_aggregate(campaign_level_cycle, (int(row["level"]), int(row["cycle"])), row)
        else:
            _add_aggregate(dungeon_by_level, int(row["level"]), row)
            _add_aggregate(dungeon_by_cycle, int(row["cycle"]), row)
            _add_aggregate(dungeon_by_id, str(row["dungeon_id"]), row)
            _add_aggregate(dungeon_by_composition, str(row["composition"]), row)
            _add_aggregate(
                dungeon_id_level_cycle,
                (str(row["dungeon_id"]), int(row["level"]), int(row["cycle"])),
                row,
            )
        _add_aggregate(encounter_aggregates, f"{scope}:{row['encounter_type']}", row)

    for composition in monte_carlo_compositions:
        for level in selected_levels:
            for cycle in monte_carlo_cycles:
                for chapter in chapters:
                    chapter_number = int(chapter.get("number", 1))
                    chapter_id = str(chapter.get("id", f"chapter_{chapter_number:02d}"))
                    for encounter_type in campaign_encounters:
                        row = _mc_cell(
                            rng,
                            scope="campaign",
                            level=level,
                            cycle=cycle,
                            composition=composition,
                            classes=classes,
                            rules=rules,
                            samples=samples_per_cell,
                            label=f"{chapter_id}:{encounter_type}",
                            pack_factory=lambda local_rng, l=level, cn=chapter_number, et=encounter_type, c=cycle: _campaign_pack(
                                l, cn, et, c, rules, config, enemies, ngplus
                            ),
                            extra={
                                "chapter_id": chapter_id,
                                "chapter_number": chapter_number,
                                "dungeon_id": "",
                                "required_level": "",
                                "depth": "",
                                "fixed_enemy_level": "",
                                "encounter_type": encounter_type,
                            },
                        )
                        emit(row)

                for dungeon_id, profile_value in sorted(dungeons.items()):
                    profile = dict(profile_value)
                    required = int(profile.get("required_level", 1))
                    if level < required:
                        continue
                    for encounter in dungeon_encounters:
                        room_type = str(encounter.get("type", "combat"))
                        depth = _depth_for(str(encounter.get("depth", "first")), max_depth)
                        fixed_level = dungeon_enemy_level(profile, depth, room_type)
                        row = _mc_cell(
                            rng,
                            scope="dungeon",
                            level=level,
                            cycle=cycle,
                            composition=composition,
                            classes=classes,
                            rules=rules,
                            samples=samples_per_cell,
                            label=f"{dungeon_id}:d{depth}:{room_type}",
                            pack_factory=lambda local_rng, rt=room_type, d=depth, c=cycle, p=profile: _dungeon_pack(
                                local_rng, rt, d, c, p, enemies, ngplus
                            ),
                            extra={
                                "chapter_id": "",
                                "chapter_number": "",
                                "dungeon_id": str(dungeon_id),
                                "required_level": required,
                                "depth": depth,
                                "fixed_enemy_level": fixed_level,
                                "encounter_type": room_type,
                            },
                        )
                        emit(row)

    def aggregate_rows(source: dict[Any, Aggregate]) -> dict[str, Any]:
        return {str(key): value.row() for key, value in sorted(source.items(), key=lambda item: str(item[0]))}

    analytical_campaign_rows = {}
    for (level, cycle), stats in sorted(analytical_campaign.items()):
        count = max(1, int(stats["count"]))
        analytical_campaign_rows[f"L{level}:C{cycle}"] = {
            "scenarios": int(stats["count"]),
            "average_pressure": round(float(stats["sum"]) / count, 4),
            "min_pressure": round(float(stats["min"]), 4),
            "max_pressure": round(float(stats["max"]), 4),
        }

    analytical_dungeon_rows = {}
    for (dungeon_id, level, cycle), stats in sorted(analytical_dungeon.items()):
        count = max(1, int(stats["count"]))
        analytical_dungeon_rows[f"{dungeon_id}:L{level}:C{cycle}"] = {
            "scenarios": int(stats["count"]),
            "average_pressure": round(float(stats["sum"]) / count, 4),
            "min_pressure": round(float(stats["min"]), 4),
            "max_pressure": round(float(stats["max"]), 4),
        }

    composition_power_spread = {}
    for level, values in sorted(power_by_level.items()):
        if not values:
            continue
        composition_power_spread[str(level)] = {
            "min": round(min(values), 3),
            "max": round(max(values), 3),
            "spread_pct": round((max(values) - min(values)) / max(0.01, legacy._mean(values)), 4),
        }

    dungeon_gates = {}
    for dungeon_id, profile_value in sorted(dungeons.items()):
        required = int(profile_value.get("required_level", 1))
        dungeon_gates[str(dungeon_id)] = {
            "required_level": required,
            "blocked_levels": list(range(1, required)),
            "eligible_levels": list(range(required, 51)),
        }

    payload: dict[str, Any] = {
        "schema_version": 1,
        "model_version": 3,
        "mode": mode,
        "seed": seed,
        "coverage": {
            "levels": selected_levels,
            "level_count": len(selected_levels),
            "class_count": len(classes),
            "analytical_composition_count": len(all_combos),
            "expected_all_compositions": math.comb(len(classes), 4) if len(classes) >= 4 else 0,
            "analytical_cycles": analytical_cycles,
            "campaign_chapter_count": len(chapters),
            "campaign_chapter_ids": [str(row.get("id", "")) for row in chapters],
            "dungeon_count": len(dungeons),
            "dungeon_ids": sorted(str(value) for value in dungeons),
            "future_dungeon_autodiscovery": True,
            "analytical_scenarios": analytical_scenarios,
            "monte_carlo_composition_count": len(monte_carlo_compositions),
            "monte_carlo_compositions": ["+".join(value) for value in monte_carlo_compositions],
            "monte_carlo_cycles": monte_carlo_cycles,
            "monte_carlo_cells": mc_cells,
            "monte_carlo_battles": mc_battles,
            "samples_per_cell": samples_per_cell,
        },
        "contracts": {
            "max_character_level": 50,
            "campaign_scales_to_party_level": True,
            "dungeons_never_scale_to_party_level": True,
            "dungeons_have_required_levels": True,
            "ngplus_enemy_scaling_source": "data/world/new_game_plus.json",
            "campaign_scaling_source": "scripts/core/level_scaling_policy.gd",
            "dungeon_scaling_source": "data/roguelike/roguelike_rules.json",
            "runtime_encounter_source": "scripts/ui/main_v25.gd",
        },
        "analytical": {
            "campaign_pressure_by_level_cycle": analytical_campaign_rows,
            "dungeon_pressure_by_id_level_cycle": analytical_dungeon_rows,
            "composition_power_spread_by_level": composition_power_spread,
            "dungeon_gates": dungeon_gates,
            "ngplus_multipliers": {
                str(cycle): {
                    "hp": round(_ngplus_multipliers(cycle, ngplus)[0], 3),
                    "damage": round(_ngplus_multipliers(cycle, ngplus)[1], 3),
                    "fear": round(_ngplus_multipliers(cycle, ngplus)[2], 3),
                }
                for cycle in analytical_cycles
            },
            "campaign_reference_levels": {
                str(chapter.get("id", "")): {
                    encounter: campaign_reference_level(int(chapter.get("number", 1)), encounter)
                    for encounter in campaign_encounters
                }
                for chapter in chapters
            },
        },
        "monte_carlo": {
            "campaign_by_level": aggregate_rows(campaign_by_level),
            "campaign_by_cycle": aggregate_rows(campaign_by_cycle),
            "campaign_by_chapter": aggregate_rows(campaign_by_chapter),
            "campaign_by_composition": aggregate_rows(campaign_by_composition),
            "dungeon_by_level": aggregate_rows(dungeon_by_level),
            "dungeon_by_cycle": aggregate_rows(dungeon_by_cycle),
            "dungeon_by_id": aggregate_rows(dungeon_by_id),
            "dungeon_by_composition": aggregate_rows(dungeon_by_composition),
            "encounters": aggregate_rows(encounter_aggregates),
        },
        "hardest_cells": hardest_cells,
        "slowest_cells": slowest_cells,
    }

    alerts: list[dict[str, Any]] = []
    if selected_levels != list(range(1, 51)):
        alerts.append({
            "severity": "high",
            "code": "level_coverage",
            "detail": f"expected 1..50, got {selected_levels[:3]}...{selected_levels[-3:] if selected_levels else []}",
        })
    expected_combos = payload["coverage"]["expected_all_compositions"]
    if len(all_combos) != expected_combos or expected_combos <= 0:
        alerts.append({
            "severity": "high",
            "code": "composition_coverage",
            "detail": f"{len(all_combos)}/{expected_combos}",
        })
    if len(chapters) != 10:
        alerts.append({
            "severity": "high",
            "code": "campaign_chapter_coverage",
            "detail": f"expected 10, got {len(chapters)}",
        })
    if not dungeons:
        alerts.append({"severity": "high", "code": "dungeon_coverage", "detail": "no dungeon profiles"})
    if any(int(row.get("required_level", 1)) < 1 for row in dungeons.values()):
        alerts.append({"severity": "high", "code": "dungeon_required_level", "detail": "required_level < 1"})
    if len(monte_carlo_compositions) < int(mode_cfg.get("minimum_monte_carlo_compositions", 8)):
        alerts.append({
            "severity": "high",
            "code": "monte_carlo_composition_sample",
            "detail": str(len(monte_carlo_compositions)),
        })

    targets = config.get("targets", {})
    cycle_zero_levels = [
        campaign_level_cycle[(level, 0)].row()["win_rate"]
        for level in selected_levels
        if (level, 0) in campaign_level_cycle
    ]
    if cycle_zero_levels:
        spread = max(cycle_zero_levels) - min(cycle_zero_levels)
        if spread > float(targets.get("campaign_level_win_rate_spread_max", 0.30)):
            alerts.append({
                "severity": "medium",
                "code": "campaign_level_win_rate_spread",
                "detail": f"{spread:.3f}",
            })

    comp_rows = [row.row() for row in campaign_by_composition.values() if row.samples > 0]
    if comp_rows:
        win_rates = [float(row["win_rate"]) for row in comp_rows]
        spread = max(win_rates) - min(win_rates)
        if spread > float(targets.get("composition_win_rate_spread_max", 0.20)):
            alerts.append({
                "severity": "medium",
                "code": "composition_win_rate_spread",
                "detail": f"{spread:.3f}",
            })

    cycle_rows = {int(key): value.row() for key, value in campaign_by_cycle.items()}
    ordered_cycles = sorted(cycle_rows)
    for previous, current in zip(ordered_cycles, ordered_cycles[1:]):
        previous_win = float(cycle_rows[previous]["win_rate"])
        current_win = float(cycle_rows[current]["win_rate"])
        if current_win > previous_win + float(targets.get("ngplus_allowed_win_rate_noise", 0.04)):
            alerts.append({
                "severity": "medium",
                "code": "ngplus_non_monotonic",
                "detail": f"cycle {previous}={previous_win:.3f}, cycle {current}={current_win:.3f}",
            })

    for dungeon_id, profile_value in dungeons.items():
        required = int(profile_value.get("required_level", 1))
        if (str(dungeon_id), required, 0) in dungeon_id_level_cycle:
            row = dungeon_id_level_cycle[(str(dungeon_id), required, 0)].row()
            low, high = [float(value) for value in targets.get("dungeon_required_level_win_rate", [0.20, 0.80])]
            win_rate = float(row["win_rate"])
            if win_rate < low or win_rate > high:
                alerts.append({
                    "severity": "medium",
                    "code": "dungeon_required_level_win_rate",
                    "detail": f"{dungeon_id}={win_rate:.3f} outside [{low:.2f},{high:.2f}]",
                })
        if (str(dungeon_id), 50, 0) in dungeon_id_level_cycle:
            row = dungeon_id_level_cycle[(str(dungeon_id), 50, 0)].row()
            minimum = float(targets.get("dungeon_level50_win_rate_min", 0.70))
            if float(row["win_rate"]) < minimum:
                alerts.append({
                    "severity": "medium",
                    "code": "dungeon_overlevel_advantage",
                    "detail": f"{dungeon_id} L50={float(row['win_rate']):.3f} < {minimum:.2f}",
                })

    payload["alerts"] = alerts
    return MatrixResult(payload=payload, alerts=alerts)


RAW_FIELDS = [
    "scope",
    "label",
    "level",
    "cycle",
    "composition",
    "samples",
    "wins",
    "win_rate",
    "deaths",
    "deaths_per_battle",
    "average_rounds",
    "chapter_id",
    "chapter_number",
    "dungeon_id",
    "required_level",
    "depth",
    "fixed_enemy_level",
    "encounter_type",
]


def write_summary_csv(result: MatrixResult, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["section", "key", "samples", "win_rate", "average_rounds", "deaths_per_battle"])
        for section in (
            "campaign_by_level",
            "campaign_by_cycle",
            "campaign_by_chapter",
            "campaign_by_composition",
            "dungeon_by_level",
            "dungeon_by_cycle",
            "dungeon_by_id",
            "dungeon_by_composition",
            "encounters",
        ):
            for key, row in result.payload["monte_carlo"].get(section, {}).items():
                writer.writerow([
                    section,
                    key,
                    row["samples"],
                    row["win_rate"],
                    row["average_rounds"],
                    row["deaths_per_battle"],
                ])


def main() -> int:
    parser = argparse.ArgumentParser(description="Full LITD balance matrix: levels, parties, campaign, dungeons and NG+")
    parser.add_argument("--mode", choices=["quick", "exhaustive"], default="quick")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--samples-per-cell", type=int, default=None)
    parser.add_argument("--report", type=Path, default=ROOT / "reports/balance-matrix.json")
    parser.add_argument("--csv", type=Path, default=ROOT / "reports/balance-matrix.csv")
    parser.add_argument("--raw-csv-gz", type=Path, default=ROOT / "reports/balance-matrix-cells.csv.gz")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    args.raw_csv_gz.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(args.raw_csv_gz, "wt", encoding="utf-8", newline="") as raw_handle:
        raw_writer = csv.DictWriter(raw_handle, fieldnames=RAW_FIELDS, extrasaction="ignore")
        raw_writer.writeheader()
        result = simulate_matrix(
            ROOT,
            mode=args.mode,
            seed=args.seed,
            samples_per_cell=args.samples_per_cell,
            raw_sink=raw_writer.writerow,
        )

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result.payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_summary_csv(result, args.csv)

    coverage = result.payload["coverage"]
    print(
        "BALANCE_MATRIX",
        f"mode={args.mode}",
        f"levels={coverage['level_count']}",
        f"all_compositions={coverage['analytical_composition_count']}",
        f"chapters={coverage['campaign_chapter_count']}",
        f"dungeons={coverage['dungeon_count']}",
        f"mc_battles={coverage['monte_carlo_battles']}",
    )
    print("CYCLES", json.dumps(coverage["analytical_cycles"]))
    print("DUNGEONS", json.dumps(coverage["dungeon_ids"], ensure_ascii=False))
    for alert in result.alerts:
        print(f"ALERT {alert['severity'].upper()} {alert['code']}: {alert['detail']}")
    print(f"REPORT {args.report}")
    if args.strict and any(alert["severity"] == "high" for alert in result.alerts):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
