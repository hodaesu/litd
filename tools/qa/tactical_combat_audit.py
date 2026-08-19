#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERO_IDS = {"aurelien", "malvor", "lysandra", "darius"}
RANKS = {1, 2, 3, 4}


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/combat_tactics.json").read_text(encoding="utf-8"))
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    v3 = (root / "scripts/ui/main_v3.gd").read_text(encoding="utf-8")
    v4 = (root / "scripts/ui/main_v4.gd").read_text(encoding="utf-8")
    v5 = (root / "scripts/ui/main_v5.gd").read_text(encoding="utf-8")
    v6 = (root / "scripts/ui/main_v6.gd").read_text(encoding="utf-8")
    v12 = (root / "scripts/ui/main_v12.gd").read_text(encoding="utf-8")
    v13 = (root / "scripts/ui/main_v13.gd").read_text(encoding="utf-8")
    v14 = (root / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    v15 = (root / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    formation = data.get("initial_formation", {})
    check("Tactique : quatre héros positionnés", set(formation) == HERO_IDS, str(formation))
    check("Tactique : quatre rangs initiaux uniques", set(map(int, formation.values())) == RANKS, str(formation))
    profiles = data.get("hero_profiles", {})
    check("Tactique : profil pour chaque héros", set(profiles) == HERO_IDS, str(sorted(profiles)))
    for hero_id, profile in profiles.items():
        for key in ["preferred_ranks", "strike_from", "strike_targets", "heavy_from", "heavy_targets"]:
            values = {int(value) for value in profile.get(key, [])}
            check(f"{hero_id} : {key} borné aux rangs 1–4", bool(values) and values <= RANKS, str(sorted(values)))
        technique = profile.get("technique", {})
        from_ranks = {int(value) for value in technique.get("from", [])}
        target_ranks = {int(value) for value in technique.get("targets", [])}
        check(f"{hero_id} : technique nommée", bool(technique.get("id")) and bool(technique.get("name")), str(technique))
        check(f"{hero_id} : technique utilisable depuis un rang valide", bool(from_ranks) and from_ranks <= RANKS, str(sorted(from_ranks)))
        check(f"{hero_id} : cibles de technique valides", target_ranks <= RANKS, str(sorted(target_ranks)))
        if technique.get("kind") == "enemy":
            check(f"{hero_id} : technique offensive possède des cibles", bool(target_ranks), str(technique))

    synergies = data.get("synergies", [])
    check("Tactique : trois synergies de formation", len(synergies) >= 3, str([item.get("id") for item in synergies]))
    check("Tactique : IDs de synergie uniques", len({item.get("id") for item in synergies}) == len(synergies))

    check("Main utilise combat v15", 'res://scripts/ui/main_v15.gd' in scene)
    check("Combat v15 conserve v14", 'extends "res://scripts/ui/main_v14.gd"' in v15)
    check("Combat v14 conserve v13", 'extends "res://scripts/ui/main_v13.gd"' in v14)
    check("Combat v13 conserve v12", 'extends "res://scripts/ui/main_v12.gd"' in v13)
    check("Combat v12 conserve v11", 'extends "res://scripts/ui/main_v11.gd"' in v12)
    check("Combat v6 conserve v5", 'extends "res://scripts/ui/main_v5.gd"' in v6)
    check("Combat v5 conserve le démembrement v4", 'extends "res://scripts/ui/main_v4.gd"' in v5)
    check("Combat v4 conserve la tactique v3", 'extends "res://scripts/ui/main_v3.gd"' in v4)
    check("Combat v3 hérite du moteur 4 héros", 'extends "res://scripts/ui/main_v2.gd"' in v3)
    check("Déplacement avant/arrière présent", '_move_active_hero(-1)' in v3 and '_move_active_hero(1)' in v3)
    check("Déplacement consomme l'action", 'func _move_active_hero' in v3 and '_complete_hero_action(hero)' in v3)
    check("Portée dépend du rang du héros", '_can_use_attack_from_rank' in v3 and '_hero_rank(hero)' in v3)
    check("Ciblage dépend du rang ennemi", '_selected_target_for' in v3 and '_enemy_rank(selected)' in v3)
    check("Ennemis possèdent leur ciblage positionnel", 'func _legal_enemy_targets' in v3 and 'enemy_rank <= 2' in v3)
    check("Boss peuvent menacer toute la formation", 'return GameState.alive_heroes()' in v3 and 'is_boss' in v3)
    check("Techniques positionnelles actives", 'hero_action("technique")' in v3 and 'func _use_tactical_technique' in v3)
    check("Malvor garantit la rupture", 'target["broken"] = 2' in v3)
    check("Darius possède une posture de riposte", 'tactical_riposte_round' in v3 and '+ 20' in v3)
    check("Aurélien applique une marque du Voile", 'veil_mark_charges' in v3 and '_apply_veil_mark_damage' in v3)
    check("Lysandra réduit la Peur du groupe", 'ally["fear"] = maxi(0' in v3)
    check("Mur de la Veille branché", '_frontline_wall_active' in v3 and 'physical_resistance' in v3)
    check("Concorde du Voile branchée", '_veil_concord_active' in v3 and 'fear_resistance' in v3)
    check("Faille préparée branchée", '_opening_exploit_active' in v3)
    check("Tactique v5 peut déplacer les rangs ennemis", '_move_enemy_relative' in v5)
    check("Tactique v5 peut déplacer les rangs héros", '_move_hero_relative' in v5)
    check("Tactique v6 ajoute les manœuvres de familles", '_apply_enemy_family_maneuvers' in v6 and '_execute_family_effect' in v6)
    check("UI v14 impose des cibles tactiles", 'MOBILE_MIN_TOUCH_HEIGHT' in v14 and 'MOBILE_MIN_TOUCH_WIDTH' in v14)
    check("UI v15 conserve la couche tactile", 'extends "res://scripts/ui/main_v14.gd"' in v15)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "tactical-combat-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
