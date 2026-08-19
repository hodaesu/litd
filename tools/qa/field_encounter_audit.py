#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/field_encounters.json").read_text(encoding="utf-8"))
    memory = json.loads((root / "data/field_memory.json").read_text(encoding="utf-8"))
    survival = json.loads((root / "data/levels/ashlands_survival_rules.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/field_encounter_runtime.gd").read_text(encoding="utf-8")
    trigger = (root / "scripts/world/field_encounter_trigger.gd").read_text(encoding="utf-8")
    injector = (root / "scripts/world/field_encounter_injector.gd").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/field_encounter_smoke_test.gd").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    encounters = {str(item.get("id", "")): item for item in data.get("encounters", [])}
    check("Schéma rencontres réactives", int(data.get("version", 0)) >= 1)
    check("Rencontres structurantes", {"c01_village_survivors", "c03_survivor_outpost", "c03_survivors_without_aid", "c03_spared_witness_return"} <= encounters.keys())

    c01 = encounters.get("c01_village_survivors", {})
    choices = {str(item.get("id", "")): item for item in c01.get("choices", [])}
    check("Survivants au village chapitre I", int(c01.get("chapter", 0)) == 1 and c01.get("zone_id") == "zone_02_village_ravage")
    check("Trois choix terrain", {"full_aid", "stabilize", "keep"} <= choices.keys())
    full_cost = choices.get("full_aid", {}).get("cost", {})
    partial_cost = choices.get("stabilize", {}).get("cost", {})
    inventory_keys = set(map(str, survival.get("expedition_inventory", {}).keys()))
    check("Coûts ressources réelles", set(full_cost) | set(partial_cost) <= inventory_keys and int(full_cost.get("food", 0)) > 0 and int(partial_cost.get("bandages", 0)) > 0)
    check("Conserver les réserves sans coût", choices.get("keep", {}).get("cost", {}) == {})

    outpost = encounters.get("c03_survivor_outpost", {})
    refused = encounters.get("c03_survivors_without_aid", {})
    witness = encounters.get("c03_spared_witness_return", {})
    check("Retour survivants aidés", outpost.get("source_event") == "c01_village_survivors" and int(outpost.get("chapter", 0)) == 3)
    check("Variantes aide/stabilisation", {"aided", "stabilized"} <= set(outpost.get("variants", {})))
    check("Retour survivants sans aide", refused.get("source_outcomes") == ["refused"])
    boss_condition = witness.get("requires_boss_outcome", {})
    check("Retour conditionnel Témoin épargné", boss_condition.get("encounter_id") == "c01_boss_ash_witness" and boss_condition.get("outcome") == "spared")

    reevaluations = memory.get("reevaluations", {})
    check("Réévaluation survivants aidés", "survivors_returned_help" in reevaluations)
    check("Réévaluation survie autonome", "survivors_survived_without_aid" in reevaluations)

    for token in ["func encounters_for", "func resolve_choice", "func resolve_return", "ExpeditionManager.consume_bundle", "FieldMemoryRuntime.record_resource_choice", "FieldMemoryRuntime.reevaluate", "func serialize", "func deserialize"]:
        check("Runtime : " + token, token in runtime)
    check("Aucune jauge morale", "ProgressBar" not in runtime and "ProgressBar" not in trigger)
    check("Choix impayable désactivé", "button.disabled = not ExpeditionManager.can_pay(cost)" in runtime)
    check("Area3D interactive", "extends Area3D" in trigger and "func interact" in trigger)
    check("Blockout visible avant Blender", "CapsuleMesh" in trigger and "Label3D" in trigger)
    check("Injection dans GeneratedBlockout", "GeneratedBlockout" in injector and "FieldEncounterTrigger.new()" in injector)

    runtime_pos = project.find('FieldEncounterRuntime="*res://scripts/core/field_encounter_runtime.gd"')
    game_pos = project.find('GameState="*res://scripts/core/game_state.gd"')
    check("Autoload runtime avant GameState", runtime_pos >= 0 and game_pos >= 0 and runtime_pos < game_pos)
    check("Autoload injecteur", 'FieldEncounterInjector="*res://scripts/world/field_encounter_injector.gd"' in project)
    check("Sauvegarde état global", '"field_encounters": FieldEncounterRuntime.serialize()' in save and 'FieldEncounterRuntime.deserialize(payload.get("field_encounters",{}))' in save)
    check("Compatibilité sauvegarde 0.31", 'SAVE_VERSION := "0.31"' in save and 'payload.get("field_encounters",{})' in save)
    check("Smoke couvre manque ressources", "insufficient_resources" in smoke)
    check("Smoke Godot branché", "field_encounter_smoke.tscn" in godot_ci)
    check("Audit CI branché", "python -m tools.qa.field_encounter_audit" in ci)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "field-encounter-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
