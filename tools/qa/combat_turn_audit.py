#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED_STATS = {
    "damage_bonus", "critical_chance", "damage_percent", "break_chance", "bleed_chance",
    "physical_resistance", "fear_resistance", "guard_power", "max_hp", "riposte_chance",
    "madness_resistance", "max_madness", "stun_chance", "execute_percent", "healing_power",
    "max_hope", "party_heal", "precision",
}


def run(root: Path = ROOT) -> dict:
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    versions = {i: (root / f"scripts/ui/main_v{i}.gd").read_text(encoding="utf-8") for i in range(2, 13)}
    base = (root / "scripts/ui/main.gd").read_text(encoding="utf-8")
    hero_skills = (root / "scripts/core/hero_skill_manager.gd").read_text(encoding="utf-8")
    sources = [base] + [versions[i] for i in range(2, 13)]
    effective_combat = "\n".join(sources)

    checks: list[dict] = []
    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Main utilise combat v12", 'res://scripts/ui/main_v12.gd' in scene)
    for child in range(12, 2, -1):
        parent = child - 1
        check(f"Combat v{child} conserve v{parent}", f'extends "res://scripts/ui/main_v{parent}.gd"' in versions[child])
    check("Combat v3 conserve le moteur v2", 'extends "res://scripts/ui/main_v2.gd"' in versions[3])
    check("Combat v2 hérite de l'UI stable", 'extends "res://scripts/ui/main.gd"' in versions[2])
    v2 = versions[2]
    check("Round suit les héros ayant agi", "acted_hero_ids" in v2 and "_mark_hero_acted" in v2)
    check("Héros actif choisi parmi les non-joués", "func _active_round_hero()" in v2 and "acted_hero_ids.get" in v2)
    check("Combat effectif n'utilise pas alive_heroes()[0]", all("alive_heroes()[0]" not in source for source in sources[1:]))
    check("Compagnon agit en fin de round", "func _finish_party_round()" in v2 and v2.count("CreatureManager.companion_turn") == 1)
    check("Ennemis agissent après le groupe", "_finish_party_round()" in v2 and "enemy_turn()" in v2)
    check("Nouveau round après le tour ennemi", "_reset_round_state()" in v2)

    produced = set(re.findall(r'"([a-z_]+)"', hero_skills)) & REQUIRED_STATS
    consumed = set(re.findall(r'\.get\("([a-z_]+)"', effective_combat)) & REQUIRED_STATS
    missing = sorted(produced - consumed)
    check("Toutes les stats d'arbres sont consommées", not missing, ", ".join(missing))
    for stat in ["damage_percent", "execute_percent", "max_hp", "party_heal", "madness_resistance", "max_madness"]:
        check(f"Stat auparavant inerte branchée : {stat}", stat in consumed)
    check("PV max synchronisés sans empilement infini", "skill_max_hp_applied" in v2)
    check("Peur extrême peut alimenter la Folie", "base_madness_gain" in v2 and "madness_resistance" in effective_combat)
    check("Soin cible un allié blessé", "_hero_heal_action" in effective_combat and "left_ratio" in effective_combat)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
        "produced_stats": sorted(produced),
        "consumed_stats": sorted(consumed),
        "missing_stats": missing,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "combat-turn-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
