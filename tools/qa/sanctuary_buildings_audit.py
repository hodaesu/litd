#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    v14 = (root / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    v15 = (root / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    campaign = (root / "scripts/core/campaign_state.gd").read_text(encoding="utf-8")
    mobile = (root / "scripts/core/mobile_touch_smoke_test.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/sanctuary_buildings_smoke_test.gd").read_text(encoding="utf-8")
    ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Sanctuaire : Main utilise v15", 'res://scripts/ui/main_v15.gd' in scene)
    check("Sanctuaire : v15 conserve la couche mobile v14", 'extends "res://scripts/ui/main_v14.gd"' in v15)
    check("Sanctuaire : couche mobile conserve v13", 'extends "res://scripts/ui/main_v13.gd"' in v14)

    for screen_name, func_name in [("chapel", "show_chapel"), ("tavern", "show_tavern"), ("memorial", "show_memorial")]:
        check(f"{screen_name} : écran routé", f'"{screen_name}"' in v15 and f"{func_name}()" in v15)
        check(f"{screen_name} : bouton retour", "RETOUR AU SANCTUAIRE" in v15)
        check(f"{screen_name} : audité sur mobile", f'"{screen_name}"' in mobile)

    check("Chapelle : coût en or explicite", "CHAPEL_APPEASE_GOLD: int = 12" in v15 and "GameState.gold -= CHAPEL_APPEASE_GOLD" in v15)
    check("Chapelle : réduit Peur et Folie", "CHAPEL_FEAR_REDUCTION: int = 18" in v15 and "CHAPEL_MADNESS_REDUCTION: int = 4" in v15)
    check("Chapelle : augmente Espoir", "CHAPEL_HOPE_GAIN: int = 4" in v15 and 'hero["hope"]' in v15)
    check("Chapelle : traitement bloqué sans or", "GameState.gold < CHAPEL_APPEASE_GOLD" in v15)

    check("Taverne : rumeurs liées aux objectifs actifs", "CampaignState.active_main_quests()" in v15 and "ÉCOUTER LES RUMEURS" in v15)
    check("Taverne : repas consomme un vivre", "TAVERN_MEAL_SUPPLIES: int = 1" in v15 and "GameState.supplies -= TAVERN_MEAL_SUPPLIES" in v15)
    check("Taverne : repas agit sur tout le groupe vivant", "for hero_value in GameState.alive_heroes()" in v15 and "TAVERN_FEAR_REDUCTION" in v15 and "TAVERN_HOPE_GAIN" in v15)

    check("Mémorial : effet gratuit", "Aucun coût : le souvenir n'est pas une marchandise." in v15)
    check("Mémorial : flag unique par chapitre", 'return "memorial_honored_%s" % CampaignState.current_chapter_id' in v15)
    check("Mémorial : flag persistant dans CampaignState", "chapter_flags" in campaign and '"chapter_flags"' in campaign and "set_chapter_flag" in campaign)
    check("Mémorial : répétition désactivée", "DÉJÀ HONORÉ CE CHAPITRE" in v15 and "gather.disabled = honored" in v15)

    check("Sanctuaire : doublons remplacés par les boutons fonctionnels", v15.count("_keep_last_button_with_text") >= 1 and "_add_functional_sanctuary_button" in v15)
    check("Sanctuaire : smoke fonctionnel branché dans Godot CI", "sanctuary_buildings_smoke.tscn" in ci and "SANCTUARY_BUILDINGS_SMOKE_OK" in smoke)
    check("Sanctuaire : smoke couvre les trois bâtiments", all(token in smoke for token in ["APAISER", "ÉCOUTER LES RUMEURS", "REPAS PARTAGÉ", "SE RECUEILLIR"]))

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "sanctuary-buildings-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
