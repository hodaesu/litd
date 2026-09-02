#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_HEROES = {
    "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
    "hero.marec", "hero.zeje", "hero.anouk",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_systemic_cross_narrative(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    canon_path = root / "universe/lore/contextual_quest_cross_ramifications.json"
    scenes_path = root / "data/narrative/systemic_cross_sanctuary_scenes.json"
    runtime_path = root / "scripts/core/systemic_cross_narrative_runtime.gd"
    project_path = root / "project.godot"
    save_path = root / "scripts/core/save_manager.gd"
    smoke_path = root / "scripts/core/systemic_cross_narrative_smoke_test.gd"
    bootstrap_path = root / "scripts/core/systemic_cross_narrative_smoke_bootstrap.gd"
    scene_path = root / "scenes/tests/systemic_cross_narrative_smoke.tscn"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"

    required_paths = [
        canon_path, scenes_path, runtime_path, project_path, save_path,
        smoke_path, bootstrap_path, scene_path, godot_ci_path,
    ]
    for path in required_paths:
        if not path.is_file():
            errors.append(f"Fichier requis absent: {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    canon = load(canon_path)
    scene_data = load(scenes_path)
    runtime = runtime_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    save = save_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    bootstrap = bootstrap_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")

    event_ids = {str(item.get("id", "")) for item in canon.get("cross_events", [])}
    cascade_ids = {str(item.get("id", "")) for item in canon.get("compound_cascades", [])}
    expected_ids = event_ids | cascade_ids
    scenes = scene_data.get("scenes", {})
    scene_ids = set(map(str, scenes.keys()))
    if scene_ids != expected_ids:
        errors.append(
            "Scènes désynchronisées avec le canon: "
            f"manquantes={sorted(expected_ids-scene_ids)}, en trop={sorted(scene_ids-expected_ids)}"
        )

    rules = scene_data.get("rules", {})
    true_rules = [
        "no_new_ui", "one_scene_per_sanctuary_entry", "no_protagonist_emotion_imposed",
        "objects_carry_subtext", "silence_is_action", "hero_lines_require_living_speaker",
    ]
    for key in true_rules:
        if rules.get(key) is not True:
            errors.append(f"Règle narrative {key} doit rester true")
    if rules.get("scene_replays") is not False:
        errors.append("Les scènes systémiques déjà vues ne doivent jamais être rejouées automatiquement")
    if int(rules.get("max_spoken_hero_lines", 0)) != 2:
        errors.append("La limite de répliques parlées doit rester fixée à 2 par scène")

    used_heroes: set[str] = set()
    for scene_id, raw in scenes.items():
        item = raw if isinstance(raw, dict) else {}
        for key in ["title", "location", "task", "opening", "closing"]:
            if not str(item.get(key, "")).strip():
                errors.append(f"Champ {key} absent dans {scene_id}")
        dialogue = item.get("dialogue", [])
        if not isinstance(dialogue, list) or len(dialogue) > 2:
            errors.append(f"Dialogue trop long ou mal formé dans {scene_id}")
            dialogue = []
        for line in dialogue:
            speaker = str(line.get("speaker_id", "")) if isinstance(line, dict) else ""
            if speaker not in EXPECTED_HEROES:
                errors.append(f"Intervenant non canonique dans {scene_id}: {speaker}")
            else:
                used_heroes.add(speaker)
            if not isinstance(line, dict) or not str(line.get("text", "")).strip():
                errors.append(f"Réplique vide dans {scene_id}")
        reactions = item.get("silent_reactions", [])
        if not isinstance(reactions, list) or not reactions:
            errors.append(f"Au moins une réaction silencieuse est requise dans {scene_id}")
        for reaction in reactions if isinstance(reactions, list) else []:
            hero_id = str(reaction.get("hero_id", "")) if isinstance(reaction, dict) else ""
            if hero_id not in EXPECTED_HEROES:
                errors.append(f"Réaction silencieuse attribuée à un héros inconnu dans {scene_id}: {hero_id}")
            if not isinstance(reaction, dict) or not str(reaction.get("text", "")).strip():
                errors.append(f"Réaction silencieuse vide dans {scene_id}")
        all_text = " ".join(str(item.get(key, "")) for key in ["task", "opening", "closing"]).lower()
        forbidden_directing = [
            "le joueur ressent", "le joueur a peur", "le joueur baisse les yeux",
            "le protagoniste ressent", "le protagoniste sourit", "le protagoniste pleure",
        ]
        for fragment in forbidden_directing:
            if fragment in all_text:
                errors.append(f"Émotion/posture imposée au protagoniste dans {scene_id}: {fragment}")

    if used_heroes != EXPECTED_HEROES:
        errors.append(f"Les sept héros doivent avoir au moins une possibilité de parole: présents={sorted(used_heroes)}")

    death_scene = scenes.get("cross.relationship.named_death_after_difficult_choice", {})
    death_blob = json.dumps(death_scene, ensure_ascii=False)
    for token in ["{dead_name}", "{cause}"]:
        if token not in death_blob:
            errors.append(f"La scène de mort nommée doit conserver le token dynamique {token}")

    runtime_tokens = [
        "func queue_scene", "func present_next_pending_scene", "func resolved_scene",
        "SystemicCrossRuntime.cross_event_applied.connect", "SystemicCrossRuntime.cascade_applied.connect",
        "GameState.screen_requested.connect", 'screen_name != "sanctuary"',
        "GameState.alive_heroes()", "seen_scene_ids.has", "pending_scene_ids.has",
        "func serialize", "func deserialize", "_replace_tokens", "max_spoken_hero_lines",
        "SCÈNE AU SANCTUAIRE", "scene_silence_selected.emit",
    ]
    for token in runtime_tokens:
        if token not in runtime:
            errors.append(f"Runtime narratif incomplet: {token}")
    for forbidden in ["ProgressBar", "morality_score", "alignment_score", "reputation_score"]:
        if forbidden in runtime:
            errors.append(f"UI/score interdit dans le runtime narratif: {forbidden}")

    autoload = 'SystemicCrossNarrativeRuntime="*res://scripts/core/systemic_cross_narrative_runtime.gd"'
    if autoload not in project:
        errors.append("SystemicCrossNarrativeRuntime doit être un autoload")
    if project.find("SystemicCrossRuntime=") > project.find("SystemicCrossNarrativeRuntime="):
        errors.append("SystemicCrossRuntime doit être chargé avant la couche narrative")
    if project.find("SystemicCrossNarrativeRuntime=") > project.find("SanctuaryState="):
        errors.append("La couche narrative doit être chargée avant SanctuaryState")

    for token in [
        '"systemic_cross_narrative": SystemicCrossNarrativeRuntime.serialize()',
        'SystemicCrossNarrativeRuntime.deserialize(payload.get("systemic_cross_narrative",{}))',
        'payload["systemic_cross_narrative"] = payload.get("systemic_cross_narrative",{})',
        'SAVE_VERSION := "0.31"',
    ]:
        if token not in save:
            errors.append(f"Persistance narrative incomplète: {token}")

    smoke_tokens = [
        "pending_scene_count() == 1", "scene_seen(scene_id)", "SCÈNE AU SANCTUAIRE",
        "A dead hero must never speak", "Iria Sen", "saturation du passage",
        "serialize()", "deserialize(narrative_snapshot)", "must not replay",
    ]
    for token in smoke_tokens:
        if token not in smoke:
            errors.append(f"Smoke narratif incomplet: {token}")
    if 'preload("res://scripts/core/systemic_cross_narrative_smoke_test.gd")' not in bootstrap:
        errors.append("Bootstrap du smoke narratif absent")
    if "systemic_cross_narrative_smoke_bootstrap.gd" not in scene:
        errors.append("Scène smoke narrative non reliée au bootstrap")
    if "systemic_cross_narrative_smoke.tscn" not in godot_ci:
        errors.append("Le smoke narratif doit être exécuté par le wrapper Godot CI")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "scenes": len(scene_ids),
            "cross_events": len(event_ids),
            "cascades": len(cascade_ids),
            "speaking_heroes": sorted(used_heroes),
        },
    }


if __name__ == "__main__":
    report = audit_systemic_cross_narrative(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
