from __future__ import annotations
import argparse
import csv
import json
import random
import statistics
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
MODEL_VERSION = "0.3-synthetic"
SCENARIO_ID = "SIM_001"
ROOT = Path(__file__).resolve().parents[2]
TARGETS_PATH = ROOT / "data" / "veilleurs" / "balance_lab_v03_targets.json"
DEFAULT_TARGETS = {
    "hero_win_rate": [0.80, 0.90],
    "average_rounds": [3.0, 5.0],
    "hit_rate": [0.70, 0.92],
    "hero_death_rate_per_slot": [0.0, 0.035],
    "mutilations_per_combat": [0.0, 0.03],
}
@dataclass
class Actor:
    id: str
    side: str
    role: str
    max_hp: float
    hp: float
    accuracy: float
    speed: float
    armor: float
    power: float
    crit: float
    rank: int
    bleed: int = 0
    fear: float = 0.0
    alive: bool = True
    dying: bool = False
    incapacitated: bool = False
    guarded_by: str | None = None
    guard_charges: int = 0
    injuries: list[str] = field(default_factory=list)
    def active(self) -> bool:
        return self.alive and not self.dying and not self.incapacitated
@dataclass
class RunMetrics:
    seed: int
    winner: str
    rounds: int
    attacks: int = 0
    hits: int = 0
    crits: int = 0
    hero_damage: float = 0.0
    enemy_damage: float = 0.0
    hero_deaths: int = 0
    hero_dying: int = 0
    stabilizations: int = 0
    guards: int = 0
    guarded_hits: int = 0
    guard_damage_prevented: float = 0.0
    displacements: int = 0
    bleed_ticks: int = 0
    fear_delta: float = 0.0
    injuries: Counter = field(default_factory=Counter)
    action_usage: Counter = field(default_factory=Counter)
    role_value: Counter = field(default_factory=Counter)
def _heroes() -> list[Actor]:
    return [
        Actor("vanguard", "heroes", "vanguard", 120, 120, .78, 8, .25, 34, .04, 1),
        Actor("blade", "heroes", "blade", 95, 95, .86, 12, .12, 36, .10, 2),
        Actor("scout", "heroes", "scout", 85, 85, .90, 14, .08, 30, .08, 3),
        Actor("support", "heroes", "support", 100, 100, .82, 10, .15, 18, .05, 4),
    ]
def _enemies() -> list[Actor]:
    return [
        Actor("ghoul_a", "enemies", "ghoul", 74, 74, .77, 12, .03, 29, .04, 1),
        Actor("ghoul_b", "enemies", "ghoul", 74, 74, .77, 12, .03, 29, .04, 2),
        Actor("disruptor", "enemies", "disruptor", 88, 88, .84, 14, .05, 24, .05, 3),
    ]
def _alive(team: list[Actor]) -> list[Actor]:
    return [a for a in team if a.alive]
def _active(team: list[Actor]) -> list[Actor]:
    return [a for a in team if a.active()]
def _injury(rng: random.Random, damage: float, target: Actor, metrics: RunMetrics, bonus: float = 0.0) -> None:
    ratio = damage / max(20.0, target.max_hp * .30)
    roll = rng.random() + bonus
    severity = None
    if ratio > 1.18 and roll > .97:
        severity = "critical"
    elif ratio > .78 and roll > .86:
        severity = "severe"
    elif ratio > .52 and roll > .70:
        severity = "moderate"
    elif ratio > .30 and roll > .50:
        severity = "light"
    if severity:
        target.injuries.append(severity)
        metrics.injuries[severity] += 1
        if severity == "critical" and rng.random() < .015:
            metrics.injuries["mutilation"] += 1
        if severity in {"moderate", "severe", "critical"} and rng.random() < .42:
            target.bleed = min(3, target.bleed + (2 if severity == "critical" else 1))
def _apply_damage(rng: random.Random, attacker: Actor, target: Actor, base: float, metrics: RunMetrics,
                  accuracy_bonus: float = 0.0, armor_pierce: float = 0.0, injury_bonus: float = 0.0,
                  bleed_bonus: int = 0) -> bool:
    metrics.attacks += 1
    hit_chance = max(.20, min(.98, attacker.accuracy + accuracy_bonus))
    if rng.random() >= hit_chance:
        return False
    metrics.hits += 1
    crit = rng.random() < attacker.crit
    if crit:
        metrics.crits += 1
    raw = base * rng.uniform(.88, 1.12) * (1.25 if crit else 1.0)
    effective_armor = max(0.0, target.armor - armor_pierce)
    damage = raw * (1.0 - effective_armor)
    if target.guarded_by and target.guard_charges > 0:
        prevention = damage * .42
        damage -= prevention
        metrics.guarded_hits += 1
        metrics.guard_damage_prevented += prevention
        target.guard_charges -= 1
    target.hp -= damage
    if attacker.side == "heroes":
        metrics.hero_damage += damage
    else:
        metrics.enemy_damage += damage
    _injury(rng, damage, target, metrics, injury_bonus + (.08 if crit else 0.0))
    if bleed_bonus and rng.random() < .55:
        target.bleed = min(3, target.bleed + bleed_bonus)
    if target.hp <= 0 and target.alive:
        if target.side == "heroes" and not target.dying and rng.random() < .95:
            target.hp = 0
            target.dying = True
            metrics.hero_dying += 1
        else:
            target.alive = False
            target.dying = False
            if target.side == "heroes":
                metrics.hero_deaths += 1
    return True
def _bleed_phase(actor: Actor, metrics: RunMetrics) -> None:
    if not actor.alive or actor.bleed <= 0:
        return
    loss = actor.max_hp * {1: .025, 2: .05, 3: .085}.get(actor.bleed, .10)
    actor.hp -= loss
    metrics.bleed_ticks += 1
    if actor.hp <= 0:
        if actor.side == "heroes" and not actor.dying:
            actor.hp = 0
            actor.dying = True
            metrics.hero_dying += 1
        elif actor.side == "enemies":
            actor.alive = False
def _hero_turn(rng: random.Random, actor: Actor, heroes: list[Actor], enemies: list[Actor], metrics: RunMetrics) -> None:
    living_enemies = _alive(enemies)
    if not living_enemies:
        return
    metrics.action_usage[f"hero:{actor.role}"] += 1
    if actor.role == "support":
        dying = [h for h in heroes if h.alive and h.dying]
        if dying:
            target = min(dying, key=lambda h: h.max_hp)
            target.dying = False
            target.incapacitated = True
            target.hp = max(1.0, target.max_hp * .05)
            target.bleed = max(0, target.bleed - 2)
            metrics.stabilizations += 1
            metrics.role_value["support_stabilizations"] += 1
            metrics.action_usage["support:stabilize"] += 1
            return
        bleeding = [h for h in heroes if h.alive and h.bleed >= 2]
        if bleeding:
            target = max(bleeding, key=lambda h: h.bleed)
            reduced = min(2, target.bleed)
            target.bleed -= reduced
            metrics.role_value["support_bleed_reduced"] += reduced
            metrics.action_usage["support:compression"] += 1
            return
        target = max(living_enemies, key=lambda e: e.armor)
        _apply_damage(rng, actor, target, 16, metrics, accuracy_bonus=.04, armor_pierce=.10)
        metrics.action_usage["support:identify_weakness"] += 1
        return
    if actor.role == "vanguard":
        for ally in heroes:
            if ally.guarded_by == actor.id:
                ally.guarded_by = None
                ally.guard_charges = 0
        candidates = [h for h in heroes if h.alive and h.id != actor.id]
        at_risk = [h for h in candidates if h.bleed > 0 or h.injuries or h.rank <= 2]
        if at_risk or rng.random() < .45:
            target = max(candidates, key=lambda h: (h.bleed, len(h.injuries), 1.0 - h.hp / h.max_hp, h.role in {"support", "scout"} and h.rank <= 2))
            target.guarded_by = actor.id
            target.guard_charges = 1
            metrics.guards += 1
            metrics.role_value["vanguard_guards"] += 1
            metrics.action_usage["vanguard:rempart"] += 1
            return
        target = min(living_enemies, key=lambda e: e.hp)
        _apply_damage(rng, actor, target, 27, metrics, accuracy_bonus=-.02, injury_bonus=.06)
        metrics.action_usage["vanguard:fracas"] += 1
        return
    if actor.role == "blade":
        target = max(living_enemies, key=lambda e: (e.role == "disruptor", -e.hp/e.max_hp))
        if target.armor >= .20:
            _apply_damage(rng, actor, target, 28, metrics, accuracy_bonus=.06, armor_pierce=.20, injury_bonus=.08)
            metrics.action_usage["blade:estoc"] += 1
        else:
            _apply_damage(rng, actor, target, 30, metrics, accuracy_bonus=-.02, injury_bonus=.18, bleed_bonus=1)
            metrics.action_usage["blade:precision_cut"] += 1
        metrics.role_value["blade_targeted_attacks"] += 1
        return
    if actor.role == "scout":
        target = min(living_enemies, key=lambda e: e.hp)
        _apply_damage(rng, actor, target, 27, metrics, accuracy_bonus=.08, armor_pierce=.05, injury_bonus=.05)
        metrics.action_usage["scout:aimed_shot"] += 1
        if target.alive and rng.random() < .16:
            old = target.rank
            target.rank = max(1, target.rank - 1)
            if target.rank != old:
                metrics.displacements += 1
                metrics.role_value["scout_displacements"] += 1
        return
def _enemy_turn(rng: random.Random, actor: Actor, heroes: list[Actor], enemies: list[Actor], metrics: RunMetrics) -> None:
    targets = [h for h in heroes if h.alive and not h.dying]
    if not targets:
        return
    metrics.action_usage[f"enemy:{actor.role}"] += 1
    if actor.role == "ghoul":
        def ghoul_priority(h: Actor) -> tuple[int, int, float]:
            return (h.bleed, len(h.injuries), -(h.hp/h.max_hp))
        target = max(targets, key=ghoul_priority)
        acc_bonus = .08 if target.bleed > 0 else 0.0
        bleed_bonus = 1 if target.bleed > 0 else 0
        _apply_damage(rng, actor, target, 31, metrics, accuracy_bonus=acc_bonus, injury_bonus=.08, bleed_bonus=bleed_bonus)
        metrics.action_usage["ghoul:bite" if target.bleed else "ghoul:claws"] += 1
        return
    backliners = [h for h in targets if h.role in {"support", "scout"} and h.rank >= 3]
    if backliners and rng.random() < .58:
        target = max(backliners, key=lambda h: h.rank)
        old = target.rank
        target.rank = max(1, target.rank - 1)
        if target.rank != old:
            metrics.displacements += 1
            metrics.role_value["enemy_formation_damage"] += 1
        target.fear = min(100.0, target.fear + 6)
        metrics.fear_delta += 6
        metrics.action_usage["disruptor:traction"] += 1
        return
    target = min(targets, key=lambda h: h.hp/h.max_hp)
    _apply_damage(rng, actor, target, 25, metrics, accuracy_bonus=.05, injury_bonus=.02)
    metrics.action_usage["disruptor:projection"] += 1
    if target.alive and rng.random() < .35:
        old = target.rank
        target.rank = min(4, target.rank + 1)
        if target.rank != old:
            metrics.displacements += 1
            metrics.role_value["enemy_formation_damage"] += 1
def simulate_one(seed: int, max_rounds: int = 12) -> RunMetrics:
    rng = random.Random(seed)
    heroes = _heroes()
    enemies = _enemies()
    metrics = RunMetrics(seed=seed, winner="draw", rounds=0)
    for round_no in range(1, max_rounds + 1):
        metrics.rounds = round_no
        order = sorted(
            [a for a in heroes + enemies if a.alive],
            key=lambda a: a.speed + rng.uniform(-2.0, 2.0),
            reverse=True,
        )
        for actor in order:
            if not actor.alive:
                continue
            _bleed_phase(actor, metrics)
            if not actor.alive:
                continue
            if actor.dying:
                if rng.random() < .20 + .06 * actor.bleed:
                    actor.alive = False
                    actor.dying = False
                    if actor.side == "heroes":
                        metrics.hero_deaths += 1
                continue
            if actor.incapacitated:
                continue
            if actor.side == "heroes":
                _hero_turn(rng, actor, heroes, enemies, metrics)
            else:
                _enemy_turn(rng, actor, heroes, enemies, metrics)
            if not _alive(enemies):
                metrics.winner = "heroes"
                return metrics
            if not _active(heroes) and not any(h.alive and h.dying for h in heroes):
                metrics.winner = "enemies"
                return metrics
        living_heroes = [h for h in heroes if h.alive]
        if living_heroes and _alive(enemies):
            effective = [max(0.0, h.hp) / h.max_hp for h in living_heroes if not h.dying and not h.incapacitated]
            avg_ratio = statistics.fmean(effective) if effective else 0.0
            degraded = sum(1 for h in heroes if (not h.alive) or h.dying or h.incapacitated)
            retreat_pressure = 0.0
            if avg_ratio < .58:
                retreat_pressure += (.58 - avg_ratio) * 2.0
            retreat_pressure += degraded * .16
            retreat_pressure += max(0, sum(h.bleed for h in living_heroes) - 2) * .035
            if retreat_pressure > 0 and rng.random() < min(.78, retreat_pressure):
                metrics.winner = "retreat"
                return metrics
        if any(e.alive and e.role == "disruptor" for e in enemies):
            for h in heroes:
                if h.alive:
                    h.fear = min(100.0, h.fear + 1.5)
                    metrics.fear_delta += 1.5
    if not _alive(enemies):
        metrics.winner = "heroes"
    elif not _active(heroes):
        metrics.winner = "enemies"
    return metrics
def _summary(values: list[float]) -> dict[str, float]:
    if not values:
        return {k: 0.0 for k in ("mean", "median", "p10", "p90", "min", "max")}
    ordered = sorted(values)
    def pct(f: float) -> float:
        idx = int(round((len(ordered) - 1) * f))
        return float(ordered[idx])
    return {
        "mean": round(statistics.fmean(values), 4),
        "median": round(float(statistics.median(values)), 4),
        "p10": round(pct(.10), 4),
        "p90": round(pct(.90), 4),
        "min": round(float(min(values)), 4),
        "max": round(float(max(values)), 4),
    }
def _load_targets() -> dict[str, list[float]]:
    if TARGETS_PATH.exists():
        raw = json.loads(TARGETS_PATH.read_text(encoding="utf-8"))
        return {**DEFAULT_TARGETS, **raw.get("targets", {})}
    return dict(DEFAULT_TARGETS)
def build_report(runs: int = 10000, seed: int = 31003) -> tuple[dict[str, Any], list[RunMetrics]]:
    rows = [simulate_one(seed + i * 7919) for i in range(runs)]
    win_counts = Counter(r.winner for r in rows)
    injuries = Counter()
    actions = Counter()
    role_value = Counter()
    for row in rows:
        injuries.update(row.injuries)
        actions.update(row.action_usage)
        role_value.update(row.role_value)
    win_rate = win_counts["heroes"] / runs
    death_rate = sum(r.hero_deaths for r in rows) / (runs * 4)
    hit_rate = sum(r.hits for r in rows) / max(1, sum(r.attacks for r in rows))
    targets = _load_targets()
    alerts: list[dict[str, str]] = []
    def check(code: str, value: float, severity: str = "medium") -> None:
        low, high = [float(x) for x in targets[code]]
        if not low <= value <= high:
            alerts.append({"severity": severity, "code": code, "detail": f"{value:.4f} outside [{low:.4f},{high:.4f}]"})
    check("hero_win_rate", win_rate, "high")
    check("average_rounds", statistics.fmean([r.rounds for r in rows]), "high")
    check("hit_rate", hit_rate, "medium")
    check("hero_death_rate_per_slot", death_rate, "high")
    mutilation_rate = injuries["mutilation"] / runs
    check("mutilations_per_combat", mutilation_rate, "high")
    report: dict[str, Any] = {
        "system": "litd_balance_lab",
        "model_version": MODEL_VERSION,
        "scenario": SCENARIO_ID,
        "model_status": "synthetic_pre_godot_contract_model",
        "human_playtest_still_required": True,
        "runs": runs,
        "seed": seed,
        "determinism_contract": "same_state_plus_actions_plus_seed_equals_same_result",
        "targets": targets,
        "outcomes": {
            "heroes": win_counts["heroes"],
            "enemies": win_counts["enemies"],
            "draw": win_counts["draw"],
            "retreat": win_counts["retreat"],
            "hero_win_rate": round(win_rate, 5),
            "hero_death_rate_per_slot": round(death_rate, 5),
        },
        "rounds": _summary([float(r.rounds) for r in rows]),
        "combat": {
            "attacks_per_run": _summary([float(r.attacks) for r in rows]),
            "hit_rate": round(hit_rate, 5),
            "crits_per_run": _summary([float(r.crits) for r in rows]),
            "hero_damage_per_run": _summary([r.hero_damage for r in rows]),
            "enemy_damage_per_run": _summary([r.enemy_damage for r in rows]),
        },
        "body": {
            "injuries_total": dict(sorted(injuries.items())),
            "injuries_per_run": {k: round(v / runs, 5) for k, v in sorted(injuries.items())},
            "bleed_ticks_per_run": round(sum(r.bleed_ticks for r in rows) / runs, 5),
        },
        "roles": {
            "guards_per_run": round(sum(r.guards for r in rows) / runs, 5),
            "guarded_hits_per_run": round(sum(r.guarded_hits for r in rows) / runs, 5),
            "guard_damage_prevented_per_run": round(sum(r.guard_damage_prevented for r in rows) / runs, 5),
            "stabilizations_per_run": round(sum(r.stabilizations for r in rows) / runs, 5),
            "displacements_per_run": round(sum(r.displacements for r in rows) / runs, 5),
            "fear_delta_per_run": round(sum(r.fear_delta for r in rows) / runs, 5),
            "role_value_totals": dict(sorted(role_value.items())),
        },
        "action_usage": dict(sorted(actions.items())),
        "alerts": alerts,
        "ok": not any(a["severity"] == "high" for a in alerts),
    }
    return report, rows
def _write_csv(rows: list[RunMetrics], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "seed", "winner", "rounds", "attacks", "hits", "crits", "hero_damage", "enemy_damage",
        "hero_deaths", "hero_dying", "stabilizations", "guards", "guarded_hits",
        "guard_damage_prevented", "displacements", "bleed_ticks", "fear_delta",
        "injury_light", "injury_moderate", "injury_severe", "injury_critical", "mutilation",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for r in rows:
            writer.writerow({
                "seed": r.seed, "winner": r.winner, "rounds": r.rounds, "attacks": r.attacks,
                "hits": r.hits, "crits": r.crits, "hero_damage": round(r.hero_damage, 4),
                "enemy_damage": round(r.enemy_damage, 4), "hero_deaths": r.hero_deaths,
                "hero_dying": r.hero_dying, "stabilizations": r.stabilizations, "guards": r.guards,
                "guarded_hits": r.guarded_hits, "guard_damage_prevented": round(r.guard_damage_prevented, 4),
                "displacements": r.displacements, "bleed_ticks": r.bleed_ticks,
                "fear_delta": round(r.fear_delta, 4), "injury_light": r.injuries["light"],
                "injury_moderate": r.injuries["moderate"], "injury_severe": r.injuries["severe"],
                "injury_critical": r.injuries["critical"], "mutilation": r.injuries["mutilation"],
            })
def _write_markdown(report: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = [
        "# LITD BalanceLab v0.3 — SIM_001", "",
        f"- Runs: **{report['runs']}**", f"- Seed: **{report['seed']}**",
        f"- Hero win rate: **{report['outcomes']['hero_win_rate']:.2%}**",
        f"- Average rounds: **{report['rounds']['mean']:.2f}**",
        f"- Hit rate: **{report['combat']['hit_rate']:.2%}**",
        f"- Hero death rate / slot: **{report['outcomes']['hero_death_rate_per_slot']:.2%}**",
        "", "## Alerts", "",
    ]
    if report["alerts"]:
        for a in report["alerts"]:
            out.append(f"- **{a['severity'].upper()}** `{a['code']}` — {a['detail']}")
    else:
        out.append("- None")
    out += ["", "> Synthetic pre-Godot contract model. Human playtest and runtime validation remain required.", ""]
    path.write_text("\n".join(out), encoding="utf-8")
def main() -> int:
    parser = argparse.ArgumentParser(description="LITD BalanceLab v0.3 synthetic SIM_001 runner")
    parser.add_argument("--runs", type=int, default=10000)
    parser.add_argument("--seed", type=int, default=31003)
    parser.add_argument("--report", type=Path, default=Path("reports/balance-lab-v03.json"))
    parser.add_argument("--csv", type=Path, default=Path("reports/balance-lab-v03-runs.csv"))
    parser.add_argument("--markdown", type=Path, default=Path("reports/balance-lab-v03.md"))
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    runs = max(100, args.runs)
    report, rows = build_report(runs, args.seed)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _write_csv(rows, args.csv)
    _write_markdown(report, args.markdown)
    print(f"BALANCE_LAB_V03 scenario={SCENARIO_ID} runs={runs} seed={args.seed}")
    print("OUTCOMES", json.dumps(report["outcomes"], sort_keys=True))
    print("ROUNDS", json.dumps(report["rounds"], sort_keys=True))
    for alert in report["alerts"]:
        print(f"ALERT {alert['severity'].upper()} {alert['code']}: {alert['detail']}")
    print(f"REPORT {args.report}")
    return 1 if args.strict and not report["ok"] else 0
if __name__ == "__main__":
    raise SystemExit(main())
