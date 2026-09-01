#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
LEVEL_CHECKPOINTS = [1, 10, 20, 30, 40, 50]
CHAPTER_TARGET_LEVELS = {index: index * 5 for index in range(1, 11)}

HERO_OFFENSE_STATS = {
    "aurelien": ["damage_percent", "critical_chance", "max_madness", "damage_bonus", "madness_resistance"],
    "malvor": ["break_chance", "damage_bonus", "stun_chance", "execute_percent", "damage_percent"],
    "lysandra": ["precision", "critical_chance", "damage_bonus", "stun_chance", "damage_percent"],
    "darius": ["riposte_chance", "damage_bonus", "critical_chance", "stun_chance", "damage_percent"],
}
STAT_BASE_VALUES = {
    "damage_bonus": 2,
    "critical_chance": 3,
    "damage_percent": 5,
    "break_chance": 4,
    "bleed_chance": 4,
    "physical_resistance": 2,
    "fear_resistance": 3,
    "guard_power": 4,
    "max_hp": 5,
    "riposte_chance": 3,
    "madness_resistance": 3,
    "max_madness": 4,
    "stun_chance": 3,
    "execute_percent": 6,
    "healing_power": 5,
    "max_hope": 4,
    "party_heal": 2,
    "precision": 3,
}
HERO_OFFSETS = {"aurelien": 1, "malvor": 2, "lysandra": 3, "darius": 4}


def load_json(root: Path, relative: str) -> Any:
    return json.loads((root / relative).read_text(encoding="utf-8"))


def parse_int_array(text: str, name: str) -> list[int]:
    match = re.search(rf"const\s+{re.escape(name)}[^=]*=\s*\[([^\]]*)\]", text)
    if not match:
        return []
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))]


class Simulation:
    def __init__(self) -> None:
        self.checks: list[dict[str, Any]] = []
        self.warnings: list[dict[str, Any]] = []
        self.report: dict[str, Any] = {}

    def check(self, name: str, ok: bool, detail: str = "") -> None:
        self.checks.append({"name": name, "ok": bool(ok), "detail": detail})

    def warn(self, name: str, triggered: bool, detail: str = "") -> None:
        if triggered:
            self.warnings.append({"name": name, "detail": detail})

    @property
    def errors(self) -> list[dict[str, Any]]:
        return [item for item in self.checks if not item["ok"]]


def hero_points_at_level(level: int, starting_level: int = 3) -> int:
    if level <= starting_level:
        return 1
    return 1 + (level - starting_level)


def hero_offense_bonuses(hero_id: str, level: int, levels: list[int], costs: list[int]) -> dict[str, int]:
    points = hero_points_at_level(level)
    spent = 0
    stats: dict[str, int] = {}
    sequence = HERO_OFFENSE_STATS.get(hero_id, HERO_OFFENSE_STATS["darius"])
    hero_offset = HERO_OFFSETS.get(hero_id, 0)
    for index, (required_level, cost) in enumerate(zip(levels, costs)):
        if required_level > level or spent + cost > points:
            break
        stat = sequence[index % len(sequence)]
        value = STAT_BASE_VALUES.get(stat, 2) + (index // 4) + hero_offset
        stats[stat] = stats.get(stat, 0) + value
        spent += cost
    return stats


def expected_hero_heavy_damage(base_range: list[int], bonuses: dict[str, int]) -> float:
    base = (float(base_range[0]) + float(base_range[1])) / 2.0
    base += float(bonuses.get("damage_bonus", 0))
    damage = base * 1.35
    damage *= 1.0 + float(bonuses.get("precision", 0)) / 100.0
    damage *= 1.0 + 0.5 * float(bonuses.get("critical_chance", 0)) / 100.0
    return damage


def party_damage_curve(root: Path, sim: Simulation) -> dict[int, float]:
    heroes = load_json(root, "data/heroes.json")
    classes = {str(item["id"]): item for item in load_json(root, "data/classes.json")}
    skill_source = (root / "scripts/core/hero_skill_manager.gd").read_text(encoding="utf-8")
    levels = parse_int_array(skill_source, "LEVELS")
    costs = parse_int_array(skill_source, "COSTS")
    curve: dict[int, float] = {}
    detail: dict[str, Any] = {}
    for checkpoint in LEVEL_CHECKPOINTS:
        total = 0.0
        per_hero: dict[str, float] = {}
        for hero in heroes:
            hero_id = str(hero.get("id", ""))
            cls = classes[str(hero.get("class_id", ""))]
            bonuses = hero_offense_bonuses(hero_id, checkpoint, levels, costs)
            damage = expected_hero_heavy_damage(cls.get("damage", [1, 2]), bonuses)
            total += damage
            per_hero[hero_id] = round(damage, 2)
        curve[checkpoint] = total
        detail[str(checkpoint)] = {"party_heavy_expected": round(total, 2), "per_hero": per_hero}
    sim.report["hero_damage_curve"] = detail
    sim.check("Simulation héros : checkpoints calculés", set(curve) == set(LEVEL_CHECKPOINTS), str(sorted(curve)))
    return curve


def parse_scripted_enemies(root: Path) -> dict[str, dict[str, Any]]:
    source = (root / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    pattern = re.compile(r'"([^"]+)"\s*:\s*_setup_enemy\(e,"([^"]+)",(\d+),\[(\d+),(\d+)\],(\d+),"([^"]+)"\)')
    result: dict[str, dict[str, Any]] = {}
    for encounter_id, name, hp, low, high, fear, signature in pattern.findall(source):
        result[encounter_id] = {
            "name": name,
            "hp": int(hp),
            "damage": [int(low), int(high)],
            "fear": int(fear),
            "signature": signature,
        }
    return result


def chapter_for_encounter(encounter_id: str) -> int | None:
    match = re.match(r"c(\d{2})_", encounter_id)
    return int(match.group(1)) if match else None


def nearest_curve_value(curve: dict[int, float], level: int) -> float:
    checkpoint = min(curve, key=lambda value: abs(value - level))
    return curve[checkpoint]


def _contract_rank(contract: dict[str, Any]) -> str:
    tier = str(contract.get("tier", ""))
    encounter_id = str(contract.get("id", ""))
    if tier == "chapter_boss":
        return "boss"
    if tier == "deep_vestige_boss":
        return "deep_boss"
    if tier == "miniboss":
        if encounter_id.startswith(("va_", "vs_", "vn_", "vv_", "vm_", "vz_", "vy_")):
            return "deep_miniboss"
        return "miniboss"
    return ""


def simulate_bosses(root: Path, sim: Simulation, party_curve: dict[int, float]) -> None:
    scripted = parse_scripted_enemies(root)
    contracts = load_json(root, "data/boss_design_contracts.json").get("bosses", [])
    contract_by_id = {str(item.get("id", "")): item for item in contracts}
    rows: list[dict[str, Any]] = []
    for encounter_id, enemy in scripted.items():
        contract = contract_by_id.get(encounter_id)
        if not contract:
            continue
        rank = _contract_rank(contract)
        if not rank:
            continue
        chapter = chapter_for_encounter(encounter_id)
        target_level = CHAPTER_TARGET_LEVELS.get(chapter or 8, 40)
        if rank.startswith("deep_"):
            target_level = min(50, target_level + 4)
        party_dpr = max(1.0, nearest_curve_value(party_curve, target_level))
        rounds = float(enemy["hp"]) / party_dpr
        avg_damage = sum(enemy["damage"]) / 2.0
        rows.append({
            "encounter_id": encounter_id,
            "name": enemy["name"],
            "rank": rank,
            "target_level": target_level,
            "hp": enemy["hp"],
            "avg_enemy_damage": round(avg_damage, 2),
            "fear": enemy["fear"],
            "skill_only_party_dpr": round(party_dpr, 2),
            "raw_rounds_to_zero_hp": round(rounds, 2),
        })
    sim.report["scripted_bosses"] = rows
    sim.check("Boss : rencontres scriptées simulées", len(rows) >= 30, f"simulées={len(rows)}")
    too_short = [row["encounter_id"] for row in rows if row["rank"] in {"boss", "deep_boss"} and row["raw_rounds_to_zero_hp"] < 1.5]
    sim.warn("Boss potentiellement trop courts sans leurs résistances/puzzles", bool(too_short), ", ".join(too_short))


def simulate_normal_pack(root: Path, sim: Simulation, party_curve: dict[int, float]) -> None:
    enemies = {int(item["id"]): item for item in load_json(root, "data/enemies.json")}
    pack = [enemies[value] for value in [1, 8, 10]]
    hp = sum(int(item["hp"]) for item in pack)
    avg_incoming = sum((item["damage"][0] + item["damage"][1]) / 2.0 for item in pack)
    rows = []
    for level in LEVEL_CHECKPOINTS:
        dpr = max(1.0, party_curve[level])
        rows.append({"level": level, "pack_hp": hp, "party_skill_only_dpr": round(dpr, 2), "rounds_to_clear": round(hp / dpr, 2), "enemy_pack_avg_damage_per_round": round(avg_incoming, 2)})
    sim.report["normal_pack"] = rows


def simulate_companions(root: Path, sim: Simulation) -> None:
    creatures = load_json(root, "data/capturable_creatures.json")
    rows = []
    for level in LEVEL_CHECKPOINTS:
        damages = []
        for creature in creatures:
            damage_range = creature.get("base_damage", [1, 2])
            base = (float(damage_range[0]) + float(damage_range[1])) / 2.0
            damages.append(base * (1.0 + float(level - 1) * 0.05))
        rows.append({
            "level": level,
            "ordinary_companion_avg_damage": round(sum(damages) / max(1, len(damages)), 2),
            "ordinary_companion_min_damage": round(min(damages), 2) if damages else 0.0,
            "ordinary_companion_max_damage": round(max(damages), 2) if damages else 0.0,
        })
    sim.report["ordinary_companion_damage_curve"] = rows
    sim.check("Compagnons : créatures ordinaires simulées", bool(creatures), f"créatures={len(creatures)}")


def xp_needed(start_level: int, target_level: int) -> int:
    return sum(50 + level * 25 for level in range(start_level, target_level))


def simulate_xp(root: Path, sim: Simulation) -> None:
    ui_source = (root / "scripts/ui/main.gd").read_text(encoding="utf-8")
    bridge = (root / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    match = re.search(r"HeroSkillManager\.grant_xp\(hero_value,\s*(\d+)\)", ui_source)
    shared_xp = int(match.group(1)) if match else 0
    scaled_campaign = "func _campaign_xp_target()" in bridge and "_grant_campaign_xp_bonus()" in bridge
    campaign_targets = {}
    if scaled_campaign:
        for chapter in range(1, 11):
            base = 90 + chapter * 10
            campaign_targets[str(chapter)] = {"normal": base, "miniboss": base + 80, "boss": base + 170}
    rows = []
    for target in [16, 32, 48, 50]:
        needed = xp_needed(3, target)
        victories = math.ceil(needed / shared_xp) if shared_xp > 0 else None
        rows.append({"target_level": target, "xp_needed_from_level_3": needed, "prototype_victories_at_shared_xp": victories})
    sim.report["xp_pacing"] = {"shared_ui_xp": shared_xp, "campaign_scaled_xp": scaled_campaign, "campaign_targets": campaign_targets, "prototype_only_targets": rows}
    sim.check("XP : récompense partagée détectée", shared_xp > 0, str(shared_xp))
    sim.check("XP : campagne possède une courbe accélérée", scaled_campaign)
    level_48_victories = next(row["prototype_victories_at_shared_xp"] for row in rows if row["target_level"] == 48)
    sim.warn("Progression XP extrêmement longue jusqu'aux ultimes de niveau 48", (not scaled_campaign) and bool(level_48_victories and level_48_victories > 300), f"{level_48_victories} victoires théoriques avec seulement {shared_xp} XP/victoire")


def simulate_ngplus(root: Path, sim: Simulation) -> None:
    ngplus = load_json(root, "data/world/new_game_plus.json")
    diff = ngplus.get("difficulty_per_cycle", {})
    hp_pct = float(diff.get("enemy_hp_pct", 0))
    damage_pct = float(diff.get("enemy_damage_pct", 0))
    fear_pct = float(diff.get("enemy_fear_pct", 0))
    final = parse_scripted_enemies(root).get("c10_boss_final", {})
    rows = []
    previous_hp = 0.0
    monotonic = True
    for cycle in range(0, 6):
        hp_mult = 1.0 + cycle * hp_pct / 100.0
        damage_mult = 1.0 + cycle * damage_pct / 100.0
        fear_mult = 1.0 + cycle * fear_pct / 100.0
        scaled_hp = float(final.get("hp", 0)) * hp_mult
        monotonic = monotonic and scaled_hp >= previous_hp
        previous_hp = scaled_hp
        base_damage = final.get("damage", [0, 0])
        rows.append({"cycle": cycle, "hp_multiplier": round(hp_mult, 2), "damage_multiplier": round(damage_mult, 2), "fear_multiplier": round(fear_mult, 2), "final_boss_hp": int(round(scaled_hp)), "final_boss_avg_damage": round(((base_damage[0] + base_damage[1]) / 2.0) * damage_mult, 2), "final_boss_fear": int(round(float(final.get("fear", 0)) * fear_mult))})
    sim.report["ngplus_cycles"] = rows
    sim.check("NG+ : croissance des PV monotone", monotonic)
    sim.check("NG+ : multiplicateurs positifs", hp_pct > 0 and damage_pct > 0 and fear_pct > 0, str(diff))


def simulate_economy(root: Path, sim: Simulation) -> None:
    ui_source = (root / "scripts/ui/main.gd").read_text(encoding="utf-8")
    bridge = (root / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    generic_gold_match = re.search(r"func finish_victory\(\).*?GameState\.gold \+= (\d+)", ui_source, re.S)
    generic_essence_match = re.search(r"func finish_victory\(\).*?GameState\.essence \+= (\d+)", ui_source, re.S)
    generic_gold = int(generic_gold_match.group(1)) if generic_gold_match else 0
    generic_essence = int(generic_essence_match.group(1)) if generic_essence_match else 0
    bridge_has_loot = "_apply_loot(pending_loot)" in bridge and '"gold":65' in bridge
    bridge_compensates = "_remove_shared_ui_currency_reward()" in bridge and "SHARED_UI_GOLD_REWARD" in bridge and "SHARED_UI_ESSENCE_REWARD" in bridge
    major_gold = 65 if bridge_compensates else generic_gold + 65
    major_essence = 12 if bridge_compensates else generic_essence + 12
    deep_gold = 80 if bridge_compensates else generic_gold + 80
    deep_essence = 18 if bridge_compensates else generic_essence + 18
    boss_rules = load_json(root, "data/world/new_game_plus.json").get("boss_recruitment", {})
    boss_catalog = load_json(root, "data/world/ngplus_boss_recruits.json")
    boss_capture_disabled = boss_rules.get("enabled") is False and boss_catalog.get("recruits", []) == [] and boss_catalog.get("capture_rules", {}) == {}
    sim.report["economy"] = {
        "generic_victory": {"gold": generic_gold, "essence": generic_essence},
        "campaign_bridge_has_separate_loot": bridge_has_loot,
        "campaign_bridge_removes_shared_reward": bridge_compensates,
        "effective_campaign_major_boss": {"gold": major_gold, "essence": major_essence},
        "effective_deep_boss": {"gold": deep_gold, "essence": deep_essence},
        "boss_capture_enabled": not boss_capture_disabled,
        "boss_capture_essence_costs": {},
    }
    sim.check("Économie campagne : récompense prototype neutralisée avant le butin routé", (not bridge_has_loot) or bridge_compensates)
    sim.check("Économie NG+ : aucun coût de capture de boss actif", boss_capture_disabled)
    sim.warn("Risque de double récompense sur les combats routés par AshlandsCombatBridge", generic_gold > 0 and generic_essence > 0 and bridge_has_loot and not bridge_compensates, f"finish_victory ajoute +{generic_gold} Or/+{generic_essence} Essence et aucun correctif du bridge n'est détecté")


def audit_combat_code(root: Path, sim: Simulation) -> None:
    # Les contrôles détaillés d'usage des statistiques et du tour complet vivent
    # dans combat_turn_audit et sont intégrés par combat_economy_sim_v2.
    sim.report.setdefault("hero_skill_stat_usage", {"produced_stats": [], "consumed_by_main_combat": [], "potentially_inert_in_main_combat": []})


def run(root: Path = ROOT) -> Simulation:
    sim = Simulation()
    party_curve = party_damage_curve(root, sim)
    simulate_normal_pack(root, sim, party_curve)
    simulate_bosses(root, sim, party_curve)
    simulate_companions(root, sim)
    simulate_xp(root, sim)
    simulate_ngplus(root, sim)
    simulate_economy(root, sim)
    audit_combat_code(root, sim)
    return sim


def write_report(root: Path, sim: Simulation) -> Path:
    out = root / "reports" / "combat-economy-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {"summary": {"checks": len(sim.checks), "errors": len(sim.errors), "warnings": len(sim.warnings)}, "checks": sim.checks, "warnings": sim.warnings, "simulation": sim.report}
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    sim = run(args.root)
    path = write_report(args.root, sim)
    for check in sim.checks:
        print(("PASS" if check["ok"] else "FAIL"), "-", check["name"], check["detail"])
    for warning in sim.warnings:
        print("WARN -", warning["name"], warning["detail"])
    print(f"RESULT: {len(sim.errors)} error(s), {len(sim.warnings)} warning(s) — {path}")
    return 1 if sim.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
