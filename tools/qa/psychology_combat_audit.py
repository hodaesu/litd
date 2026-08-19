#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_BANDS = {"calm", "uneasy", "afraid", "terrified", "panic"}


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/psychology_events.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/psychology_runtime.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v16.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/psychology_smoke_test.gd").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Psychologie combat : schéma v2", int(data.get("version", 0)) >= 2)
    bands = {str(item.get("id", "")) for item in data.get("fear_bands", [])}
    check("Psychologie combat : cinq paliers de Peur", bands == EXPECTED_BANDS, str(sorted(bands)))

    combat_rules = data.get("combat_rules", {})
    band_rules = combat_rules.get("bands", {})
    check("Psychologie combat : règle par palier", set(band_rules) == EXPECTED_BANDS, str(sorted(band_rules)))
    check(
        "Psychologie combat : Effrayé pénalise précision dégâts soins",
        all(int(band_rules.get("afraid", {}).get(key, 0)) < 0 for key in ["precision", "damage_percent", "healing_power"]),
    )
    check(
        "Psychologie combat : Terrifié est plus sévère qu'Effrayé",
        int(band_rules.get("terrified", {}).get("precision", 0)) < int(band_rules.get("afraid", {}).get("precision", 0)),
    )
    panic = combat_rules.get("panic", {})
    check("Psychologie combat : Panique redescend après crise", 0 < int(panic.get("fear_after_crisis", 0)) < 100)
    check("Psychologie combat : Espoir redescend davantage la Panique", int(panic.get("fear_after_resolve", 100)) < int(panic.get("fear_after_crisis", 0)))
    check("Psychologie combat : Espoir ne se cumule pas", int(panic.get("resolve_charges_max", 0)) == 1)

    traits = data.get("trait_definitions", {})
    check("Psychologie combat : traces modulent les malus", bool(traits) and all("fear_penalty_scale" in rule for rule in traits.values()))
    check("Psychologie combat : traces orientent la crise", bool(traits) and all(rule.get("panic_reaction") in {"freeze", "retreat"} for rule in traits.values()))

    for token in ["func combat_modifiers", "func combat_status_text", "func resolve_panic_action", 'psychology["resolve_charges"]']:
        check(f"Runtime : {token}", token in runtime)
    check("Runtime : Espoir prépare une résolution", "hope_manifestation_resolve_charges" in runtime and "resolve_charges_max" in runtime)
    check("Runtime : Panique résolue ne consomme pas l'action", '"consume_action": false' in runtime)
    check("Runtime : Panique non résolue consomme l'action", '"consume_action": true' in runtime)

    check("UI : applique les malus psychologiques aux bonus", "func hero_bonuses" in ui and "PsychologyRuntime.combat_modifiers" in ui)
    check("UI : intercepte la Panique avant l'action", "func hero_action" in ui and "PsychologyRuntime.resolve_panic_action" in ui)
    check("UI : recul de Panique utilise les rangs tactiques", "_move_hero_relative(hero, 1)" in ui)
    check("UI : conséquence psychologique visible sans nouvelle jauge", "PsychologyRuntime.combat_status_text" in ui and "Espoir prêt contre la Panique" in ui)
    check("UI : Folie héritée neutralisée", 'hero["madness"] = int(before.get("madness"' in ui)
    check("UI : Espoir hérité neutralisé", 'hero["hope"] = int(before.get("hope"' in ui)
    check("UI : aucune incrémentation numérique active de Folie", 'hero["madness"] +=' not in ui)
    check("UI : aucune incrémentation numérique active d'Espoir", 'hero["hope"] +=' not in ui)

    for token in ["resolve_charges", "combat_modifiers", "resolve_panic_action", "panic_memory"]:
        check(f"Smoke psychologie : couvre {token}", token in smoke)
    check("CI : audit psychologie combat branché", "python -m tools.qa.psychology_combat_audit" in ci)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "psychology-combat-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
