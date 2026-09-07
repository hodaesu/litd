from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "veilleurs" / "v06"


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


@dataclass
class Unit:
    entity_id: str
    team: str
    role: str
    hp: int
    max_hp: int
    for_stat: int
    pre: int
    mob: int
    res: int
    armor: int
    weapon: int
    guard: int = 0
    hit_penalty: int = 0
    trauma: int = 0
    statuses: dict[str, int] = field(default_factory=dict)

    @property
    def alive(self) -> bool:
        return self.hp > 0

    @property
    def hp_ratio(self) -> float:
        return self.hp / max(1, self.max_hp)


def hit_chance(attacker: Unit, defender: Unit, base: int = 74, bonus: int = 0) -> int:
    chance = base + (attacker.pre - defender.mob) * 0.45 + bonus - attacker.hit_penalty
    if defender.statuses.get("EXPOSED", 0) > 0:
        chance += 8
    return max(10, min(97, round(chance)))


def damage(attacker: Unit, defender: Unit, multiplier: float = 1.0) -> int:
    attack_power = attacker.weapon * multiplier * (0.70 + attacker.for_stat / 200.0)
    armor = defender.armor + defender.guard
    reduction = armor / (armor + 100.0)
    return max(1, round(attack_power * (1.0 - reduction)))


def make_units() -> tuple[list[Unit], list[Unit]]:
    watchers = load("watchers.json")["watchers"]
    enemies_by_id = {e["entity_id"]: e for e in load("enemies_24_definitions.json")["enemies"]}
    enemy_ids = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]
    party: list[Unit] = []
    watcher_roles = {
        "ENT_WATCHER_SAHEN": "frontline",
        "ENT_WATCHER_MIRA": "precision",
        "ENT_WATCHER_NAREM": "guardian",
        "ENT_WATCHER_YSRA": "observer",
    }
    for w in watchers:
        s = w["stats"]
        party.append(Unit(w["entity_id"], "watcher", watcher_roles[w["entity_id"]], 80 + s["VIG"], 80 + s["VIG"], s["FOR"], s["PRE"], s["MOB"], s["RES"], 30, 30))
    foes: list[Unit] = []
    for eid in enemy_ids:
        e = enemies_by_id[eid]
        s = e["stats"]
        foes.append(Unit(eid, "enemy", e["combat_role"], 80 + s["VIG"], 80 + s["VIG"], s["FOR"], s["PRE"], s["MOB"], s["RES"], 20, 27))
    return party, foes


def tick(units: list[Unit]) -> None:
    for unit in units:
        unit.guard = 0
        unit.hit_penalty = max(0, unit.hit_penalty - 3)
        for status in list(unit.statuses):
            unit.statuses[status] -= 1
            if unit.statuses[status] <= 0:
                del unit.statuses[status]


def watcher_action(actor: Unit, party: list[Unit], foes: list[Unit], rng: random.Random, round_no: int) -> int:
    living_foes = [u for u in foes if u.alive]
    living_party = [u for u in party if u.alive]
    if not living_foes:
        return 0
    weakest_ally = min(living_party, key=lambda u: u.hp_ratio)
    weakest_enemy = min(living_foes, key=lambda u: (u.hp_ratio, u.mob))

    if actor.role == "guardian" and weakest_ally.hp_ratio < 0.55:
        healed = min(14, weakest_ally.max_hp - weakest_ally.hp)
        weakest_ally.hp += healed
        weakest_ally.guard = max(weakest_ally.guard, 10)
        return 0
    if actor.role == "frontline" and round_no % 3 == 0:
        actor.guard = 18
        weakest_ally.guard = max(weakest_ally.guard, 8)
        return 0
    if actor.role == "observer" and round_no % 2 == 1:
        target = max(living_foes, key=lambda u: (u.pre, u.res))
        target.hit_penalty = max(target.hit_penalty, 8)
        target.statuses["EXPOSED"] = max(target.statuses.get("EXPOSED", 0), 2)
        return 0

    target = weakest_enemy
    multiplier = {"frontline": 1.05, "precision": 1.08, "guardian": 0.78, "observer": 0.72}[actor.role]
    bonus = 10 if actor.role == "precision" else 2
    if rng.randint(1, 100) <= hit_chance(actor, target, bonus=bonus):
        dealt = damage(actor, target, multiplier)
        target.hp = max(0, target.hp - dealt)
        target.trauma += round(dealt * (1.15 if actor.role == "frontline" else 0.85))
        if actor.role == "frontline":
            target.statuses["STAGGER"] = 1
        return dealt
    return 0


def enemy_action(actor: Unit, party: list[Unit], foes: list[Unit], rng: random.Random) -> int:
    living_party = [u for u in party if u.alive]
    if not living_party:
        return 0
    if actor.role in {"anatomy", "execution", "hunter", "assault", "drain"}:
        target = min(living_party, key=lambda u: (u.hp_ratio - u.trauma / 1000.0, u.guard))
    else:
        target = min(living_party, key=lambda u: (u.hp_ratio, u.mob))
    bonus = 7 if actor.role == "anatomy" else 2
    if rng.randint(1, 100) <= hit_chance(actor, target, base=72, bonus=bonus):
        multiplier = 1.12 if actor.role in {"anatomy", "execution"} else 1.0
        dealt = damage(actor, target, multiplier)
        target.hp = max(0, target.hp - dealt)
        target.guard = 0
        target.trauma += round(dealt * (1.05 if actor.role == "anatomy" else 0.8))
        if target.trauma >= 55:
            target.hit_penalty = max(target.hit_penalty, 6)
        return dealt
    return 0


def simulate(seed: int) -> dict:
    rng = random.Random(seed)
    party, foes = make_units()
    rounds = 0
    damage_taken = 0
    while any(u.alive for u in party) and any(u.alive for u in foes) and rounds < 30:
        rounds += 1
        order = sorted([u for u in party + foes if u.alive], key=lambda u: (u.pre + u.mob, rng.random()), reverse=True)
        for actor in order:
            if not actor.alive:
                continue
            if actor.team == "watcher":
                watcher_action(actor, party, foes, rng, rounds)
            else:
                damage_taken += enemy_action(actor, party, foes, rng)
            if not any(u.alive for u in party) or not any(u.alive for u in foes):
                break
        tick(party + foes)
    win = any(u.alive for u in party) and not any(u.alive for u in foes)
    return {
        "win": win,
        "rounds": rounds,
        "watchers_alive": sum(u.alive for u in party),
        "damage_taken": damage_taken,
        "party_remaining_hp": sum(u.hp for u in party),
        "severe_trauma_watchers": sum(u.trauma >= 55 for u in party),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=2000)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    runs = max(100, args.runs if not args.check else min(args.runs, 500))
    rows = [simulate(i + 16061) for i in range(runs)]
    win_rate = 100.0 * sum(r["win"] for r in rows) / runs
    avg_rounds = sum(r["rounds"] for r in rows) / runs
    avg_alive = sum(r["watchers_alive"] for r in rows) / runs
    avg_damage = sum(r["damage_taken"] for r in rows) / runs
    trauma_rate = 100.0 * sum(r["severe_trauma_watchers"] for r in rows) / (runs * 4)
    report = {
        "runs": runs,
        "encounter": ["Goule affamée", "Écorcheuse", "Fouisseuse"],
        "watcher_win_rate_percent": round(win_rate, 1),
        "target_win_band_percent": [65.0, 92.0],
        "average_rounds": round(avg_rounds, 2),
        "average_watchers_alive": round(avg_alive, 2),
        "average_damage_taken": round(avg_damage, 2),
        "severe_trauma_incidence_percent": round(trauma_rate, 1),
        "interpretation": "Pre-playtest tactical model: guard, heal, observation, focus-fire and trauma are represented. Human tactile playtest remains authoritative.",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.check:
        healthy = 65.0 <= win_rate <= 92.0 and 4.0 <= avg_rounds <= 14.0 and 1.4 <= avg_alive <= 3.8
        if not healthy:
            print("VEILLEURS_V061_BALANCE_OUT_OF_TARGET")
            return 1
    print("VEILLEURS_V061_BALANCE_SIM_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
