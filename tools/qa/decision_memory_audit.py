#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_CONVICTIONS = {"solidarity", "security", "civic_process", "mercy", "openness", "pragmatism", "autonomy", "justice"}
EXPECTED_HEROES = {"aurelien", "malvor", "lysandra", "darius"}
EXPECTED_QUESTS = {"ashlands_refugee_gate", "ashlands_first_blood", "ashlands_conscious_creature"}


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/hero_decision_memory.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/decision_memory_runtime.gd").read_text(encoding="utf-8")
    bridge = (root / "scripts/core/decision_memory_political_bridge.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v19.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/decision_memory_smoke_test.gd").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Mémoire décisions : schéma v1", int(data.get("version", 0)) >= 1)
    check("Mémoire décisions : huit convictions", set(map(str, data.get("convictions", []))) == EXPECTED_CONVICTIONS)
    check("Mémoire décisions : profils des quatre héros test", EXPECTED_HEROES <= set(map(str, data.get("hero_profiles", {}).keys())))
    check("Mémoire décisions : trois choix politiques couverts", EXPECTED_QUESTS <= set(map(str, data.get("choice_vectors", {}).keys())))
    for quest_id in EXPECTED_QUESTS:
        check(f"Mémoire décisions : choix vectorisés pour {quest_id}", len(data.get("choice_vectors", {}).get(quest_id, {})) >= 3)
    check("Mémoire décisions : conséquences différées", len(data.get("social_reevaluations", {})) >= 4)
    check("Mémoire décisions : convergence relationnelle", "reevaluation_convergence" in data.get("relationship_effects", {}))
    check("Mémoire décisions : divergence relationnelle", "reevaluation_divergence" in data.get("relationship_effects", {}))

    for token in [
        "func record_political_choice", "func record_social_event", "func decision_summary",
        "func recent_memory_lines", "func conviction_summary", 'hero["convictions"]',
        'hero["decision_memories"]', "_apply_reevaluation_relationships"
    ]:
        check(f"Runtime mémoire : {token}", token in runtime)
    check("Runtime mémoire : opinions peuvent changer", 'memory["stance"] = new_stance' in runtime and '"previous_stance"' in runtime)
    check("Runtime mémoire : pas de jauge dédiée", "ProgressBar" not in runtime)
    check("Runtime mémoire : relations influencées", "RelationshipRuntime.relation" in runtime and "mistrust" in runtime and "resentment" in runtime)

    check("Bridge : décisions politiques détectées", "PoliticalState.completed_quests" in bridge and "PoliticalState.quest_choice" in bridge)
    check("Bridge : événements sociaux différés détectés", "PoliticalState.seen_events" in bridge and "record_social_event" in bridge)

    check("UI : Main utilise v19", 'res://scripts/ui/main_v19.gd' in scene)
    check("UI : v19 conserve v18", 'extends "res://scripts/ui/main_v18.gd"' in ui and 'res://scripts/ui/main_v18.gd' in scene)
    check("UI : mémoire racontée en prose", "MÉMOIRES DE DÉCISION" in ui and "recent_memory_lines" in ui)
    check("UI : aucune nouvelle jauge dans v19", "ProgressBar" not in ui)

    check("Projet : DecisionMemoryRuntime autoload", 'DecisionMemoryRuntime="*res://scripts/core/decision_memory_runtime.gd"' in project)
    check("Projet : bridge politique autoload", 'DecisionMemoryBridge="*res://scripts/core/decision_memory_political_bridge.gd"' in project)
    check("Sauvegarde : mémoire embarquée dans party", '"party": GameState.party' in save and 'GameState.party = payload.get("party"' in save)
    check("Smoke : convictions persistantes", 'serialized.contains("convictions")' in smoke)
    check("Smoke : décisions persistantes", 'serialized.contains("decision_memories")' in smoke)
    check("Smoke : changement d'avis couvert", 'Darius must be able to change his mind' in smoke)
    check("Smoke : conséquence non rejouable", 'must never be applied twice' in smoke)
    check("Godot CI : smoke mémoire branché", "decision_memory_smoke.tscn" in godot_ci)
    check("CI : audit mémoire branché", "python -m tools.qa.decision_memory_audit" in ci)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "decision-memory-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
