from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "veilleurs" / "v06"


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


@dataclass
class Unit:
    entity_id: str
    team: str
    hp: int
    max_hp: int
    for_stat: int
    pre: int
    mob: int
    armor: int
    weapon: int

    @property
    def alive(self) -> bool:
        return self.hp > 0


def hit_chance(attacker: Unit, defender: Unit, base: int = 75) -> int:
    return max(10, min(97, round(base + (attacker.pre - defender.mob) * 0.45)))


def damage(attacker: Unit, defender: Unit, multiplier: float = 1.0) -> int:
    attack_power = attacker.weapon * multiplier * (0.70 + attacker.for_stat / 200.0)
    reduction = defender.armor / (defender.armor + 100.0)
    return max(1, round(attack_power * (1.0 - reduction)))


def make_units() -> tuple[list[Unit], list[Unit]]:
    watchers = load("watchers.json")["watchers"]
    enemies_by_id = {e["entity_id"]: e for e in load("enemies_24_definitions.json")["enemies"]}
    enemy_ids = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]
    party = []
    for w in watchers:
        s = w["stats"]
        party.append(Unit(w["entity_id"], "watcher", 80 + s["VIG"], 80 + s["VIG"], s["FOR"], s["PRE"], s["MOB"], 30, 30))
    foes = []
    for eid in enemy_ids:
        e = enemies_by_id[eid]
        s = e["stats"]
        foes.append(Unit(eid, "enemy", 80 + s["VIG"], 80 + s["VIG"], s["FOR"], s["PRE"], s["MOB"], 20, 24))
    return party, foes


def simulate(seed: int) -> dict:
    rng = random.Random(seed)
    party, foes = make_units()
    rounds = 0
    damage_taken = 0
    while any(u.alive for u in party) and any(u.alive for u in foes) and rounds < 40:
        rounds += 1
        order = sorted([u for u in party + foes if u.alive], key=lambda u: (u.pre + u.mob, rng.random()), reverse=True)
        for actor in order:
            if not actor.alive:
                continue
            targets = foes if actor.team == "watcher" else party
            living = [u for u in targets if u.alive]
            if not living:
                break
            target = min(living, key=lambda u: (u.hp, u.mob))
            chance = hit_chance(actor, target)
            if rng.randint(1, 100) <= chance:
                dealt = damage(actor, target)
                target.hp = max(0, target.hp - dealt)
                if actor.team == "enemy":
                    damage_taken += dealt
    win = any(u.alive for u in party) and not any(u.alive for u in foes)
    return {
        "win": win,
        "rounds": rounds,
        "watchers_alive": sum(u.alive for u in party),
        "enemies_alive": sum(u.alive for u in foes),
        "damage_taken": damage_taken,
        "party_remaining_hp": sum(u.hp for u in party),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=1000)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    runs = max(20, args.runs if not args.check else min(args.runs, 250))
    rows = [simulate(i + 6000) for i in range(runs)]
    win_rate = 100.0 * sum(r["win"] for r in rows) / runs
    avg_rounds = sum(r["rounds"] for r in rows) / runs
    avg_alive = sum(r["watchers_alive"] for r in rows) / runs
    avg_damage = sum(r["damage_taken"] for r in rows) / runs
    report = {
        "runs": runs,
        "first_encounter": ["Goule affamée", "Écorcheuse", "Fouisseuse"],
        "watcher_win_rate_percent": round(win_rate, 1),
        "average_rounds": round(avg_rounds, 2),
        "average_watchers_alive": round(avg_alive, 2),
        "average_damage_taken": round(avg_damage, 2),
        "interpretation": "Baseline-only telemetry. Authored skills, body trauma and terrain should be layered after the first Godot playtest.",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not (0.0 <= win_rate <= 100.0 and 1.0 <= avg_rounds <= 40.0 and 0.0 <= avg_alive <= 4.0):
        return 1
    print("VEILLEURS_V06_BALANCE_SIM_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
