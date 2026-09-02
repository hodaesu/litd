#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_EVENT_COUNT = 18
EXPECTED_CASCADE_COUNT = 4
EXPECTED_HEROES = {
    "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
    "hero.marec", "hero.zeje", "hero.anouk",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_systemic_cross_runtime(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    registry_path = root / "universe/lore/contextual_quest_cross_ramifications.json"
    presentation_path = root / "data/narrative/systemic_cross_runtime.json"
    runtime_path = root / "scripts/core/systemic_cross_runtime.gd"
    community_path = root / "scripts/core/community_runtime.gd"
    project_path = root / "project.godot"
    save_path = root / "scripts/core/save_manager.gd"
    politics_path = root / "scripts/core/political_state.gd"
    smoke_path = root / "scripts/core/systemic_cross_smoke_test.gd"
    bootstrap_path = root / "scripts/core/systemic_cross_smoke_bootstrap.gd"
    scene_path = root / "scenes/tests/systemic_cross_smoke.tscn"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"

    paths = [
        registry_path, presentation_path, runtime_path, community_path, project_path,
        save_path, politics_path, smoke_path, bootstrap_path, scene_path, godot_ci_path,
    ]
    for path in paths:
        if not path.is_file():
            errors.append(f"Fichier requis absent: {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    registry = load(registry_path)
    presentation = load(presentation_path)
    runtime = runtime_path.read_text(encoding="utf-8")
    community = community_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    save = save_path.read_text(encoding="utf-8")
    politics = politics_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    bootstrap = bootstrap_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")

    event_ids = {str(item.get("id", "")) for item in registry.get("cross_events", [])}
    cascade_ids = {str(item.get("id", "")) for item in registry.get("compound_cascades", [])}
    presentation_events = set(map(str, presentation.get("events", {}).keys()))
    presentation_cascades = set(map(str, presentation.get("cascades", {}).keys()))
    if len(event_ids) != EXPECTED_EVENT_COUNT:
        errors.append(f"Le canon doit exposer {EXPECTED_EVENT_COUNT} événements, trouvé {len(event_ids)}")
    if len(cascade_ids) != EXPECTED_CASCADE_COUNT:
        errors.append(f"Le canon doit exposer {EXPECTED_CASCADE_COUNT} cascades, trouvé {len(cascade_ids)}")
    if presentation_events != event_ids:
        errors.append(f"Présentations événementielles désynchronisées: manquantes={sorted(event_ids-presentation_events)}, en trop={sorted(presentation_events-event_ids)}")
    if presentation_cascades != cascade_ids:
        errors.append(f"Présentations de cascades désynchronisées: manquantes={sorted(cascade_ids-presentation_cascades)}, en trop={sorted(presentation_cascades-cascade_ids)}")

    rules = presentation.get("rules", {})
    for key in ["rumor_sources_preserved", "hero_lines_require_living_speaker", "cross_events_apply_once", "cascades_apply_once"]:
        if rules.get(key) is not True:
            errors.append(f"Règle runtime {key} doit rester true")
    for key in ["new_universal_meter", "global_morality_score"]:
        if rules.get(key) is not False:
            errors.append(f"Règle runtime {key} doit rester false")

    speakers: set[str] = set()
    rumor_reliabilities: set[str] = set()
    for section_name in ["events", "cascades"]:
        for item_id, item_value in presentation.get(section_name, {}).items():
            item = item_value if isinstance(item_value, dict) else {}
            if not item.get("title") or not item.get("fact"):
                errors.append(f"Présentation incomplète pour {item_id}")
            if not item.get("rumors"):
                errors.append(f"Au moins une rumeur qualitative est requise pour {item_id}")
            if not item.get("visual") or not item.get("audio") or not item.get("population"):
                errors.append(f"Cues Sanctuaire incomplets pour {item_id}")
            for rumor in item.get("rumors", []):
                if isinstance(rumor, dict):
                    rumor_reliabilities.add(str(rumor.get("reliability", "")))
                    if not rumor.get("text"):
                        errors.append(f"Rumeur sans texte dans {item_id}")
            for line in item.get("dialogue", []):
                if not isinstance(line, dict):
                    errors.append(f"Dialogue mal formé dans {item_id}")
                    continue
                speaker = str(line.get("speaker_id", ""))
                speakers.add(speaker)
                if speaker not in EXPECTED_HEROES or not line.get("text"):
                    errors.append(f"Dialogue conditionnel invalide dans {item_id}: {line!r}")
    if not {"confirmed", "direct", "reported", "variable", "unreliable"}.issubset(rumor_reliabilities):
        errors.append("Le runtime doit préserver plusieurs degrés de fiabilité des rumeurs")

    runtime_tokens = [
        "func record_contextual_choice", "func record_external_trigger", "func _sync_campaign_flags_and_evaluate",
        "CampaignState.chapter_flags", "func _event_ready", "func _cascade_ready",
        "applied_events.has", "applied_cascades.has", "func serialize", "func deserialize",
        "CommunityRuntime.record_systemic_cross_event", "DecisionMemoryRuntime.prepare_party",
        "FieldMemoryRuntime.prepare_party", "RelationshipRuntime.relation", "PsychologyRuntime.record_external_fear",
        "func route_state", "func market_price_modifier", "economy_tags", "route_states",
        "func _named_death_payload", "func _emit_dialogues", "GameState.alive_heroes",
    ]
    for token in runtime_tokens:
        if token not in runtime:
            errors.append(f"Runtime systémique incomplet: {token}")
    forbidden_runtime = ["reputation_score", "morality_score", "alignment_score", "ProgressBar", "global_reputation"]
    for token in forbidden_runtime:
        if token in runtime:
            errors.append(f"Jauge/score interdit dans le runtime systémique: {token}")

    community_tokens = [
        "func record_systemic_cross_event", "systemic_visual_cues", "systemic_audio_cues", "systemic_population_cues",
        '"source_id": item_id', '"reliability": str(rumor.get("reliability"',
        '"systemic_visual_cues": systemic_visual_cues.duplicate()',
        '"systemic_audio_cues": systemic_audio_cues.duplicate()',
        '"systemic_population_cues": systemic_population_cues.duplicate()',
    ]
    for token in community_tokens:
        if token not in community:
            errors.append(f"Pont Communauté/Sanctuaire incomplet: {token}")

    if 'SystemicCrossRuntime="*res://scripts/core/systemic_cross_runtime.gd"' not in project:
        errors.append("SystemicCrossRuntime doit être un autoload")
    if project.find("CommunityRuntime=") > project.find("SystemicCrossRuntime="):
        errors.append("CommunityRuntime doit être chargé avant SystemicCrossRuntime")
    if project.find("SystemicCrossRuntime=") > project.find("SanctuaryState="):
        errors.append("SystemicCrossRuntime doit être chargé avant SanctuaryState")

    for token in [
        '"systemic_cross": SystemicCrossRuntime.serialize()',
        'SystemicCrossRuntime.deserialize(payload.get("systemic_cross",{}))',
        'payload["systemic_cross"] = payload.get("systemic_cross",{})',
        'SAVE_VERSION := "0.31"',
    ]:
        if token not in save:
            errors.append(f"Sauvegarde systémique incomplète: {token}")

    if "SystemicCrossRuntime.market_price_modifier()" not in politics:
        errors.append("L'économie existante doit consommer le modificateur systémique")
    if "reputation +=" in runtime or "PoliticalState.reputation" in runtime:
        errors.append("Les croisements ne doivent pas transformer les conséquences en réputation morale")

    smoke_tokens = [
        "cross.food.local_security_and_grain_bridge", "cascade.winter_refugee_pressure",
        "cross.relationship.named_death_after_difficult_choice", "Iria Sen",
        "serialize()", "deserialize(", "applied_event_ids().count", "PoliticalState.price_modifier()",
    ]
    for token in smoke_tokens:
        if token not in smoke:
            errors.append(f"Smoke systémique incomplet: {token}")
    if 'preload("res://scripts/core/systemic_cross_smoke_test.gd")' not in bootstrap:
        errors.append("Bootstrap smoke systémique absent ou incorrect")
    if "systemic_cross_smoke_bootstrap.gd" not in scene:
        errors.append("Scène smoke systémique non reliée au bootstrap")
    if "systemic_cross_smoke.tscn" not in godot_ci:
        errors.append("Le smoke systémique doit être exécuté par run_godot_ci.sh")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "events": len(event_ids),
            "cascades": len(cascade_ids),
            "dialogue_speakers": sorted(speakers),
            "rumor_reliabilities": sorted(rumor_reliabilities),
        },
    }


if __name__ == "__main__":
    report = audit_systemic_cross_runtime(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
