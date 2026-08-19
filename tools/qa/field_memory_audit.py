#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/field_memory.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/field_memory_runtime.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v20.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/field_memory_smoke_test.gd").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Terrain : schéma v1", int(data.get("version", 0)) >= 1)
    vectors = data.get("decision_vectors", {})
    for key in ["creature_recruited", "boss_spared", "boss_executed", "expedition_retreat", "aid_survivors", "keep_resources"]:
        check(f"Terrain : vecteur {key}", key in vectors)
    check("Terrain : boss narratifs seulement", 1 <= len(data.get("boss_outcomes", {})) < 10)
    check("Terrain : conséquence différée créature", "creature_proved_itself" in data.get("reevaluations", {}))
    check("Terrain : conséquences différées pardon", {"spared_enemy_helped", "spared_enemy_betrayed"}.issubset(data.get("reevaluations", {}).keys()))

    for token in [
        "CreatureManager.creature_captured", "CreatureManager.creature_leveled",
        "ExpeditionManager.expedition_ended", "AshlandsCombatBridge.ashlands_combat_finished",
        'hero["field_memories"]', "func record_boss_outcome", "func record_resource_choice",
        "func record_expedition_retreat", "func reevaluate", '"witness_mode": "direct"'
    ]:
        check(f"Runtime terrain : {token}", token in runtime)
    check("Runtime terrain : réutilise les convictions", 'hero.get("convictions"' in runtime and "DecisionMemoryRuntime.prepare_party" in runtime)
    check("Runtime terrain : relations influencées", "RelationshipRuntime.relation" in runtime and "later_convergence" in runtime)
    check("Runtime terrain : pas de jauge", "ProgressBar" not in runtime)

    check("UI : Main utilise v20", 'res://scripts/ui/main_v20.gd' in scene)
    check("UI : v20 conserve v19", 'extends "res://scripts/ui/main_v19.gd"' in ui and 'res://scripts/ui/main_v19.gd' in scene)
    check("UI : décision post-boss", "BossOutcomeDecision" in ui and "ÉPARGNER" in ui and "ACHEVER" in ui)
    check("UI : décision post-boss bloque les clics", "MOUSE_FILTER_STOP" in ui)
    check("UI : mémoires terrain visibles en mots", "MÉMOIRES DE LA COMPAGNIE" in ui and "recent_field_memory_lines" in ui)
    check("UI : aucune nouvelle jauge", "ProgressBar.new()" not in ui)

    check("Projet : FieldMemoryRuntime autoload", 'FieldMemoryRuntime="*res://scripts/core/field_memory_runtime.gd"' in project)
    check("Sauvegarde : party persiste les mémoires", '"party": GameState.party' in save and 'GameState.party = payload.get("party"' in save)
    check("Smoke : témoins directs couverts", "witness_mode" in smoke)
    check("Smoke : boss couvert", "record_boss_outcome" in smoke)
    check("Smoke : ressource couverte", "record_resource_choice" in smoke)
    check("Smoke : réévaluation couverte", "creature_proved_itself" in smoke)
    check("Godot CI : smoke terrain branché", "field_memory_smoke.tscn" in godot_ci)
    check("CI : audit terrain branché", "python -m tools.qa.field_memory_audit" in ci)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "field-memory-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
