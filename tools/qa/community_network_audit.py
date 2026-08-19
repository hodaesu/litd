#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/community_network.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/community_runtime.gd").read_text(encoding="utf-8")
    sanctuary = (root / "scripts/core/sanctuary_state.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v22.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    game_state = (root / "scripts/core/game_state.gd").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/community_network_smoke_test.gd").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Communauté : schéma v1+", int(data.get("version", 0)) >= 1)
    people = {str(item.get("id", "")): item for item in data.get("people", [])}
    check("Communauté : Mara, Yoren et Iven persistants", {"mara_three_marks", "yoren_three_marks", "iven_three_marks"} <= people.keys())
    transitions = data.get("encounter_transitions", {})
    check("Communauté : décision du village intégrée", "c01_village_survivors" in transitions)
    check("Communauté : retour du relais intégré", "c03_survivor_outpost" in transitions)
    check("Communauté : refus ne tue pas automatiquement les survivants", "c03_survivors_without_aid" in transitions)
    check("Communauté : Témoin épargné circule dans la mémoire collective", "c03_spared_witness_return" in transitions)
    quests = {str(item.get("id", "")): item for item in data.get("quests", [])}
    check("Quêtes émergentes : au moins deux branches concrètes", {"q_iven_erased_days", "q_yoren_false_exit"} <= quests.keys())
    check(
        "Quêtes émergentes : objectifs utilisent le monde existant",
        quests.get("q_iven_erased_days", {}).get("objective", {}).get("id") == "ev_korem_redaction"
        and quests.get("q_yoren_false_exit", {}).get("objective", {}).get("id") == "ev_purge_protocol",
    )

    for token in [
        "func sanctuary_people", "func recent_rumor_lines", "func listen_next_rumor",
        "func offer_quest", "func accept_quest", "func quest_entries",
        "func facts_for_scope", "func knows_fact", "func serialize", "func deserialize",
        "FieldEncounterRuntime.encounter_resolved", "CreatureManager.creature_captured",
        "Chapter03Runtime.evidence_discovered", "AshlandsRuntime.zone_discovered"
    ]:
        check(f"Runtime communauté : {token}", token in runtime)
    check("Runtime communauté : pas de score moral global", "reputation_score" not in runtime and "alignment" not in runtime and "ProgressBar" not in runtime)

    check("Sanctuaire : cues visuels issus des personnes", "CommunityRuntime.sanctuary_visual_cues" in sanctuary)
    check("Sanctuaire : population issue des personnes", "CommunityRuntime.sanctuary_population_cues" in sanctuary)
    check("Sanctuaire : ambiance issue des personnes", "CommunityRuntime.sanctuary_audio_cues" in sanctuary)

    check("UI : Main utilise v22", 'res://scripts/ui/main_v22.gd' in scene)
    check("UI : v22 conserve v21", 'extends "res://scripts/ui/main_v21.gd"' in ui and 'res://scripts/ui/main_v21.gd' in scene)
    check("UI : communauté accessible", '"community"' in ui or 'res://scripts/ui/main_v21.gd' in scene)
    check("UI : quêtes narrées", "NarrativeLibrary.quest_state_text" in ui and "ACCEPTER L'HISTOIRE" in ui)
    check("UI : aucune nouvelle jauge", "ProgressBar.new()" not in ui)

    check("Projet : CommunityRuntime autoload", 'CommunityRuntime="*res://scripts/core/community_runtime.gd"' in project)
    check("Nouvelle partie : signal de reset communautaire", "signal new_game_reset" in game_state and "new_game_reset.emit()" in game_state)
    check("Sauvegarde : communauté persistante", '"community": CommunityRuntime.serialize()' in save and 'CommunityRuntime.deserialize(payload.get("community",{}))' in save)
    check("Sauvegarde : version historique conservée", 'SAVE_VERSION := "0.31"' in save)

    for token in ["c01_village_survivors", "c03_survivor_outpost", "q_iven_erased_days", "collective_memory", "serialize"]:
        check(f"Smoke communauté : {token}", token in smoke)
    check("Godot CI : smoke communauté branché", "community_network_smoke.tscn" in godot_ci)
    check("CI : audit communauté branché", "python -m tools.qa.community_network_audit" in ci)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "community-network-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
