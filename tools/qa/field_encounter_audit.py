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
    controller = (root / "scripts/world/exploration_party_controller.gd").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/field_encounter_smoke_test.gd").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Rencontres réactives : schéma v1", int(data.get("version", 0)) >= 1)
    encounters = {str(item.get("id", "")): item for item in data.get("encounters", [])}
    expected = {
        "c01_village_survivors",
        "c03_survivor_outpost",
        "c03_survivors_without_aid",
        "c03_spared_witness_return",
    }
    check("Rencontres réactives : quatre situations structurantes", expected <= encounters.keys())

    c01 = encounters.get("c01_village_survivors", {})
    check("Survivants : rencontre dans le village du chapitre I", int(c01.get("chapter", 0)) == 1 and c01.get("zone_id") == "zone_02_village_ravage")
    choices = {str(item.get("id", "")): item for item in c01.get("choices", [])}
    check("Survivants : trois décisions", {"full_aid", "stabilize", "keep"} <= choices.keys())
    full_cost = choices.get("full_aid", {}).get("cost", {})
    partial_cost = choices.get("stabilize", {}).get("cost", {})
    check("Survivants : aide complète coûte des vivres réels", int(full_cost.get("food", 0)) > 0 and int(full_cost.get("water", 0)) > 0 and int(full_cost.get("medicine", 0)) > 0)
    check("Survivants : stabilisation coûte du matériel réel", int(partial_cost.get("bandages", 0)) > 0 and int(partial_cost.get("medicine", 0)) > 0)
    check("Survivants : garder les réserves est un vrai choix sans coût artificiel", choices.get("keep", {}).get("cost", {}) == {})
    inventory_keys = set(map(str, survival.get("expedition_inventory", {}).keys()))
    used_keys = set(map(str, full_cost.keys())) | set(map(str, partial_cost.keys()))
    check("Survivants : coûts compatibles avec l'inventaire d'expédition", used_keys <= inventory_keys)

    outpost = encounters.get("c03_survivor_outpost", {})
    refused_return = encounters.get("c03_survivors_without_aid", {})
    check("Retour : les survivants aidés reviennent au chapitre III", int(outpost.get("chapter", 0)) == 3 and outpost.get("source_event") == "c01_village_survivors")
    check("Retour : aide complète et stabilisation donnent des variantes distinctes", {"aided", "stabilized"} <= set(map(str, outpost.get("variants", {}).keys())))
    check("Retour : le refus n'efface pas les survivants du monde", refused_return.get("source_outcomes") == ["refused"] and int(refused_return.get("chapter", 0)) == 3)

    witness = encounters.get("c03_spared_witness_return", {})
    boss_condition = witness.get("requires_boss_outcome", {})
    check("Retour ennemi : dépend réellement du boss épargné", boss_condition.get("encounter_id") == "c01_boss_ash_witness" and boss_condition.get("outcome") == "spared")
    check("Retour ennemi : réévalue la mémoire de clémence", witness.get("reevaluation") == "spared_enemy_helped")

    reevaluations = memory.get("reevaluations", {})
    check("Mémoire : retour positif des survivants", "survivors_returned_help" in reevaluations)
    check("Mémoire : survie autonome après refus", "survivors_survived_without_aid" in reevaluations)

    for token in [
        "func encounters_for", "func can_spawn", "func open_encounter", "func resolve_choice",
        "func resolve_return", "ExpeditionManager.can_pay", "ExpeditionManager.consume_bundle",
        "FieldMemoryRuntime.record_resource_choice", "FieldMemoryRuntime.reevaluate",
        '"witnesses"', "func serialize", "func deserialize"
    ]:
        check(f"Runtime rencontre : {token}", token in runtime)
    check("Runtime rencontre : pas de jauge morale", "ProgressBar" not in runtime)
    check("Runtime rencontre : choix impayable désactivé", "button.disabled = not ExpeditionManager.can_pay(cost)" in runtime)
    check("Runtime rencontre : mouvement suspendu pendant le choix", 'get_nodes_in_group("player_party")' in runtime and "set_physics_process(false)" in runtime)

    check("Déclencheur 3D : Area3D interactive", "extends Area3D" in trigger and "func interact" in trigger)
    check("Déclencheur 3D : blockout visible avant Blender", "CapsuleMesh" in trigger and "Label3D" in trigger and "BlockoutVisual" in trigger)
    check("Contrôleur exploration : sait appeler interact", 'has_method("interact")' in controller and "target.interact()" in controller)
    check("Injecteur : écoute le chargement des zones", "AshlandsSceneRouter.zone_load_finished" in injector and "AshlandsRuntime.zone_discovered" in injector)
    check("Injecteur : place les rencontres dans le blockout", "GeneratedBlockout" in injector and "FieldEncounterTrigger.new()" in injector)

    check("Projet : FieldEncounterRuntime autoload avant GameState", project.find('FieldEncounterRuntime="*res://scripts/core/field_encounter_runtime.gd"') < project.find('GameState="*res://scripts/core/game_state.gd"'))
    check("Projet : injecteur réactif autoload", 'FieldEncounterInjector="*res://scripts/world/field_encounter_injector.gd"' in project)
    check("Sauvegarde : état global des rencontres persistant", '"field_encounters": FieldEncounterRuntime.serialize()' in save and 'FieldEncounterRuntime.deserialize(payload.get("field_encounters",{}))' in save)
    check("Sauvegarde : version 0.32 ou ultérieure", 'SAVE_VERSION := "0.32"' in save)

    for token in ["c01_village_survivors", "c03_survivor_outpost", "spared", "insufficient_resources", "serialize"]:
        check(f"Smoke rencontre : {token}", token in smoke)
    check("Godot CI : smoke rencontre branché", "field_encounter_smoke.tscn" in godot_ci)
    check("CI : audit rencontre branché", "python -m tools.qa.field_encounter_audit" in ci)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


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
