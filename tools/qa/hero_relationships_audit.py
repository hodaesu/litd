#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_METRICS = {"trust", "admiration", "mistrust", "resentment"}


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/hero_relationships.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/relationship_runtime.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v18.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/relationship_smoke_test.gd").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Relations : schéma v1", int(data.get("version", 0)) >= 1)
    check("Relations : quatre tendances", set(map(str, data.get("metrics", []))) == EXPECTED_METRICS)
    thresholds = data.get("thresholds", {})
    check("Relations : confiance forte définie", int(thresholds.get("strong_trust", 0)) > 0)
    check("Relations : interposition limitée aux situations critiques", int(thresholds.get("interpose_fear", 0)) >= 70 and 0 < float(thresholds.get("interpose_hp_ratio", 0)) < 0.5)
    events = data.get("events", {})
    for event_id in ["heal", "critical_heal", "interpose", "boss_finisher", "shared_meal", "sanctuary_reconcile", "sanctuary_opening"]:
        check(f"Relations : événement {event_id}", event_id in events)

    for token in [
        "func record_heal", "func record_boss_finisher", "func try_interpose",
        "func on_hero_fallen", "func sanctuary_conversation", "func combat_modifiers",
        "func pair_descriptor", 'hero["relationships"]'
    ]:
        check(f"Runtime relations : {token}", token in runtime)
    check("Runtime relations : pertes affectent PsychologyRuntime", "PsychologyRuntime.record_external_fear" in runtime and '"bond_loss"' in runtime)
    check("Runtime relations : pas de jauge dédiée", "ProgressBar" not in runtime)

    check("UI : Main utilise v18", 'res://scripts/ui/main_v18.gd' in scene)
    check("UI : v18 conserve v17", 'extends "res://scripts/ui/main_v17.gd"' in ui and 'res://scripts/ui/main_v17.gd' in scene)
    check("UI : soins construisent les liens", "RelationshipRuntime.record_heal" in ui)
    check("UI : alliés peuvent s'interposer", "RelationshipRuntime.try_interpose" in ui)
    check("UI : boss finisher nourrit l'admiration", "RelationshipRuntime.record_boss_finisher" in ui)
    check("UI : chute d'un proche a une conséquence", "RelationshipRuntime.on_hero_fallen" in ui)
    check("UI : Taverne montre des mots plutôt que quatre jauges", "LIENS MARQUANTS" in ui and "pair_summaries" in ui and "ProgressBar.new()" not in ui)
    check("UI : conversation limitée par chapitre", "relationship_conversation_%s" in ui and "CampaignState.set_chapter_flag" in ui)
    check("UI : Mémorial révèle un lien conservé", "LIEN CONSERVÉ" in ui and "memorial_line" in ui)

    check("Projet : RelationshipRuntime autoload", 'RelationshipRuntime="*res://scripts/core/relationship_runtime.gd"' in project)
    check("Sauvegarde : la compagnie entière est sérialisée", '"party": GameState.party' in save and 'GameState.party = payload.get("party"' in save)
    check("Smoke : persistance embarquée dans party", 'serialized.contains("relationships")' in smoke)
    check("Smoke : interposition couverte", "try_interpose" in smoke)
    check("Smoke : perte d'un proche couverte", "on_hero_fallen" in smoke)
    check("Godot CI : smoke relations branché", "relationship_smoke.tscn" in godot_ci)
    check("CI : audit relations branché", "python -m tools.qa.hero_relationships_audit" in ci)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "hero-relationships-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
