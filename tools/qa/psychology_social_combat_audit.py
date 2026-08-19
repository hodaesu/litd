#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/psychology_social_combat.json").read_text(encoding="utf-8"))
    director = (root / "scripts/core/psychology_combat_director.gd").read_text(encoding="utf-8")
    v2 = (root / "scripts/ui/main_v2.gd").read_text(encoding="utf-8")
    v17 = (root / "scripts/ui/main_v17.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/psychology_smoke_test.gd").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("UI : Main route v17", 'res://scripts/ui/main_v17.gd' in scene and 'script = ExtResource("1")' in scene)
    check("UI : v17 conserve v16", 'extends "res://scripts/ui/main_v16.gd"' in v17)
    check("Runtime : directeur autoloadé", 'PsychologyCombatDirector="*res://scripts/core/psychology_combat_director.gd"' in project)

    check("Combat : hook sélection ennemi", "func _select_enemy_target" in v2 and "_select_enemy_target(enemy, targets)" in v2)
    check("Combat : hook pression post-attaque", "func _after_enemy_attack" in v2 and "_after_enemy_attack(enemy, target, damage, fear_gain)" in v2)
    check("Combat : hook compagnon", "func _before_companion_turn" in v2 and "_before_companion_turn()" in v2)
    check("v17 : sélection psychologique branchée", "PsychologyCombatDirector.select_enemy_target" in v17)
    check("v17 : pression psychologique branchée", "PsychologyCombatDirector.apply_enemy_pressure" in v17)
    check("v17 : intervention compagnon branchée", "PsychologyCombatDirector.companion_intervention" in v17)
    check("v17 : menace lisible sans nouvelle jauge", "MENACE ·" in v17 and "ProgressBar.new()" not in v17)

    targeting = data.get("targeting", {})
    check("IA : la Peur influence la cible", float(targeting.get("fear_weight", 0)) > 0)
    check("IA : bonus Terrifié", float(targeting.get("terrified_bonus", 0)) > 0)
    check("IA : bonus Panique", float(targeting.get("panic_bonus", 0)) > float(targeting.get("terrified_bonus", 0)))
    check("IA : traumatismes lisibles", float(targeting.get("trauma_bonus", 0)) > 0 and 'psychology.get("traumas", [])' in director)

    roles = data.get("companion_roles", {})
    for species in ["hungry_ghoul", "oni", "jorogumo"]:
        check(f"Compagnon : rôle {species}", species in roles)
    check("Compagnon : Oni protecteur", bool(roles.get("oni", {}).get("guard", False)))
    check("Compagnon : Jorōgumo peut manifester l'Espoir", roles.get("jorogumo", {}).get("hope_event") == "combat_ally_support")

    boss = data.get("boss_overrides", {}).get("c01_boss_ash_witness", {})
    check("Boss : Témoin des Cendres ciblage dédié", float(boss.get("fear_target_bonus", 0)) > 0)
    check("Boss : Témoin des Cendres pression dédiée", int(boss.get("pressure_bonus", 0)) > 0)
    check("Boss : ligne contextuelle", "Témoin" in str(boss.get("line", "")))

    check("Smoke : ciblage social couvert", "select_enemy_target" in smoke and "Fear-aware enemies" in smoke)
    check("Smoke : intervention compagnon couverte", "companion_intervention" in smoke and "Protective Oni" in smoke)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "psychology-social-combat-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
