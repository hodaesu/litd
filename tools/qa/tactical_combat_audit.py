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
    source = (root / "scripts/ui/main_v3.gd").read_text(encoding="utf-8")
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

    check("Main utilise combat tactique v3", 'res://scripts/ui/main_v3.gd' in scene)
    check("Combat v3 hérite du moteur 4 héros", 'extends "res://scripts/ui/main_v2.gd"' in source)
    check("Déplacement avant/arrière présent", '_move_active_hero(-1)' in source and '_move_active_hero(1)' in source)
    check("Déplacement consomme l'action", 'func _move_active_hero' in source and '_complete_hero_action(hero)' in source)
    check("Portée dépend du rang du héros", '_can_use_attack_from_rank' in source and '_hero_rank(hero)' in source)
    check("Ciblage dépend du rang ennemi", '_selected_target_for' in source and '_enemy_rank(selected)' in source)
    check("Ennemis possèdent leur ciblage positionnel", 'func _legal_enemy_targets' in source and 'enemy_rank <= 2' in source)
    check("Boss peuvent menacer toute la formation", 'return GameState.alive_heroes()' in source and 'is_boss' in source)
    check("Techniques positionnelles actives", 'hero_action("technique")' in source and 'func _use_tactical_technique' in source)
    check("Malvor garantit la rupture", 'target["broken"] = 2' in source)
    check("Darius possède une posture de riposte", 'tactical_riposte_round' in source and '+ 20' in source)
    check("Aurélien applique une marque du Voile", 'veil_mark_charges' in source and '_apply_veil_mark_damage' in source)
    check("Lysandra réduit la Peur du groupe", 'ally["fear"] = maxi(0' in source)
    check("Mur de la Veille branché", '_frontline_wall_active' in source and 'physical_resistance' in source)
    check("Concorde du Voile branchée", '_veil_concord_active' in source and 'fear_resistance' in source)
    check("Faille préparée branchée", '_opening_exploit_active' in source)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


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
