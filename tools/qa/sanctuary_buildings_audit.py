#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    v14 = (root / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    v15 = (root / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    v16 = (root / "scripts/ui/main_v16.gd").read_text(encoding="utf-8")
    psychology = (root / "scripts/core/psychology_runtime.gd").read_text(encoding="utf-8")
    psychology_events = json.loads((root / "data/psychology_events.json").read_text(encoding="utf-8"))
    campaign = (root / "scripts/core/campaign_state.gd").read_text(encoding="utf-8")
    mobile = (root / "scripts/core/mobile_touch_smoke_test.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/sanctuary_buildings_smoke_test.gd").read_text(encoding="utf-8")
    ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Sanctuaire : Main utilise v16", 'res://scripts/ui/main_v16.gd' in scene)
    check("Sanctuaire : v16 conserve les bâtiments v15", 'extends "res://scripts/ui/main_v15.gd"' in v16)
    check("Sanctuaire : v15 conserve la couche mobile v14", 'extends "res://scripts/ui/main_v14.gd"' in v15)
    check("Sanctuaire : couche mobile conserve v13", 'extends "res://scripts/ui/main_v13.gd"' in v14)

    for screen_name, func_name in [("chapel", "show_chapel"), ("tavern", "show_tavern"), ("memorial", "show_memorial")]:
        check(f"{screen_name} : écran routé", f"{func_name}()" in v16)
        check(f"{screen_name} : bouton retour", "RETOUR AU SANCTUAIRE" in v16 or "RETOUR AU SANCTUAIRE" in v15)
        check(f"{screen_name} : audité sur mobile", f'"{screen_name}"' in mobile)

    event_ids = {event.get("id") for event in psychology_events.get("events", [])}
    for required in [
        "sanctuary_chapel_appease",
        "sanctuary_shared_meal",
        "sanctuary_memorial_remembrance",
    ]:
        check(f"Psychologie : événement {required}", required in event_ids and required in v16)

    check("Psychologie : une seule jauge visible", "ProgressBar.new()" in v16 and "PEUR · %s · %d/100" in v16)
    check("Psychologie : Folie devient trace durable", "mental_summary" in v16 and 'psychology["traits"]' in psychology and 'psychology["traumas"]' in psychology)
    check("Psychologie : Espoir n'est plus incrémenté dans v16", 'hero["hope"] +=' not in v16 and 'candidate["hope"] =' in v16)
    check("Psychologie : manifestations d'Espoir historisées", 'psychology["hope_history"]' in psychology and "feedback_requested.emit" in psychology)

    check("Chapelle : coût en or explicite", "PSY_CHAPEL_APPEASE_GOLD: int = 12" in v16 and "GameState.gold -= PSY_CHAPEL_APPEASE_GOLD" in v16)
    check("Chapelle : stabilise sans effacer les traces", "madness_exposure" in v16 and "sans supprimer les traces durables" in v16)
    check("Chapelle : traitement bloqué sans or", "GameState.gold < PSY_CHAPEL_APPEASE_GOLD" in v16)

    check("Taverne : rumeurs liées aux objectifs actifs", "_tavern_rumor()" in v16 and "ÉCOUTER LES RUMEURS" in v16)
    check("Taverne : repas consomme un vivre", "PSY_TAVERN_MEAL_SUPPLIES: int = 1" in v16 and "GameState.supplies -= PSY_TAVERN_MEAL_SUPPLIES" in v16)
    check("Taverne : repas agit sur tout le groupe vivant", "GameState.alive_heroes()" in v16 and '"sanctuary_shared_meal"' in v16)

    check("Mémorial : effet gratuit", "Aucun coût." in v16)
    check("Mémorial : flag unique par chapitre", "_memorial_flag()" in v16 and "CampaignState.current_chapter_id" in v16)
    check("Mémorial : flag persistant dans CampaignState", "chapter_flags" in campaign and '"chapter_flags"' in campaign and "set_chapter_flag" in campaign)
    check("Mémorial : répétition désactivée", "DÉJÀ HONORÉ CE CHAPITRE" in v16 and "gather.disabled = honored" in v16)

    check("Sanctuaire : héritage v15 conserve le remplacement des doublons", v15.count("_keep_last_button_with_text") >= 1 and "_add_functional_sanctuary_button" in v15)
    check("Sanctuaire : smoke fonctionnel branché dans Godot CI", "sanctuary_buildings_smoke.tscn" in ci and "SANCTUARY_BUILDINGS_SMOKE_OK" in smoke)
    check("Sanctuaire : smoke couvre les trois bâtiments", all(token in smoke for token in ["APAISER", "ÉCOUTER LES RUMEURS", "REPAS PARTAGÉ", "SE RECUEILLIR"]))
    check("Psychologie : smoke dédié branché dans CI", "psychology_smoke.tscn" in ci)

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
