#!/usr/bin/env python3
from __future__ import annotations

import itertools
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
HEROES = {
    "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
    "hero.marec", "hero.zeje", "hero.anouk",
}
STAGES = {"opening", "friction", "rupture", "repair", "durable", "bereavement"}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_legendary_seven_relationships(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    core_path = root / "universe/lore/legendary_seven_relationships.json"
    dialogue_paths = [root / f"data/narrative/legendary_seven_relationship_dialogues_{i}.json" for i in range(1, 4)]
    runtime_path = root / "scripts/core/legendary_seven_relationship_runtime.gd"
    smoke_path = root / "scripts/core/legendary_seven_relationship_smoke_test.gd"
    bootstrap_path = root / "scripts/core/legendary_seven_relationship_smoke_bootstrap.gd"
    scene_path = root / "scenes/tests/legendary_seven_relationship_smoke.tscn"
    project_path = root / "project.godot"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"
    doc_path = root / "docs/LITD1_SEPT_RELATIONS_EVOLUTIVES_V1.md"

    required = [core_path, *dialogue_paths, runtime_path, smoke_path, bootstrap_path, scene_path, project_path, godot_ci_path, doc_path]
    for path in required:
        if not path.is_file():
            errors.append(f"Fichier requis absent: {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    core = load(core_path)
    runtime = runtime_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    bootstrap = bootstrap_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")
    doc = doc_path.read_text(encoding="utf-8")

    if set(core.get("heroes", [])) != HEROES:
        errors.append("Le registre doit contenir exactement les Sept héros canoniques")
    rules = core.get("rules", {})
    for key in [
        "no_new_relationship_meter", "states_are_derived_not_stored_scores",
        "use_existing_relationship_runtime", "one_pair_scene_per_sanctuary_entry",
        "systemic_scenes_have_priority", "afterlife_beats_have_priority",
        "dead_hero_never_speaks", "created_protagonist_posture_never_imposed",
        "not_every_pair_comments_on_every_event", "trust_and_disagreement_may_coexist",
        "bereavement_is_not_moral_verdict", "romance_is_never_inferred_from_trust",
        "old_graphic_relationship_labels_do_not_override_current_registry",
    ]:
        if rules.get(key) is not True:
            errors.append(f"Garde-fou relationnel manquant ou faux: {key}")
    if int(rules.get("pair_count", 0)) != 21:
        errors.append("pair_count doit rester à 21")
    if int(rules.get("max_spoken_lines_per_scene", 99)) > 2:
        errors.append("Une scène relationnelle ne doit pas dépasser deux prises de parole")

    pairs = core.get("pairs", [])
    if len(pairs) != 21:
        errors.append(f"Le registre doit contenir exactement 21 couples, trouvé {len(pairs)}")
    expected_pairs = {frozenset(pair) for pair in itertools.combinations(HEROES, 2)}
    actual_pairs: set[frozenset[str]] = set()
    pair_ids: set[str] = set()
    for raw in pairs:
        pair = raw if isinstance(raw, dict) else {}
        pair_id = str(pair.get("id", ""))
        heroes = pair.get("heroes", [])
        if not pair_id or pair_id in pair_ids:
            errors.append(f"Identifiant de couple vide ou dupliqué: {pair_id!r}")
        pair_ids.add(pair_id)
        if not isinstance(heroes, list) or len(heroes) != 2 or any(hero not in HEROES for hero in heroes):
            errors.append(f"Couple invalide {pair_id}: {heroes}")
            continue
        actual_pairs.add(frozenset(map(str, heroes)))
        for field in ["bond_type", "romance_status", "affection_axis", "central_disagreement", "evolution"]:
            if not str(pair.get(field, "")).strip():
                errors.append(f"Champ {field} manquant pour {pair_id}")
        if pair.get("romance_status") != "not_canonized":
            errors.append(f"Aucune romance ne doit être canonisée par cette passe: {pair_id}")
    if actual_pairs != expected_pairs:
        errors.append("Les 21 couples ne couvrent pas exactement toutes les combinaisons possibles des Sept")

    by_id = {str(pair.get("id", "")): pair for pair in pairs if isinstance(pair, dict)}
    if by_id.get("marec_anouk", {}).get("bond_type") != "fraternal":
        errors.append("Marec ↔ Anouk doit rester strictement fraternel")
    if by_id.get("mathilde_marec", {}).get("bond_type") != "maternal_protective":
        errors.append("Mathilde ↔ Marec doit conserver son socle maternel/protecteur")
    if by_id.get("mathilde_anouk", {}).get("bond_type") != "protective_quasi_maternal":
        errors.append("Mathilde ↔ Anouk doit conserver son socle protecteur quasi maternel")
    if by_id.get("aurelien_mathilde", {}).get("romance_status") != "not_canonized":
        errors.append("L'ancienne romance Aurélien ↔ Mathilde ne doit pas être verrouillée par cette passe")

    dialogues: dict[str, Any] = {}
    used_speakers: set[str] = set()
    for path in dialogue_paths:
        pack = load(path)
        for raw in pack.get("pairs", []):
            pair = raw if isinstance(raw, dict) else {}
            pair_id = str(pair.get("id", ""))
            if pair_id in dialogues:
                errors.append(f"Couple dupliqué dans les packs de dialogues: {pair_id}")
            dialogues[pair_id] = pair
    if set(dialogues) != pair_ids:
        errors.append(f"Packs dialogues désynchronisés: manquants={sorted(pair_ids-set(dialogues))}, en trop={sorted(set(dialogues)-pair_ids)}")

    for pair_id, pair in dialogues.items():
        heroes = set(map(str, pair.get("heroes", [])))
        stages = pair.get("stages", {}) if isinstance(pair.get("stages", {}), dict) else {}
        if set(stages) != STAGES:
            errors.append(f"États incomplets pour {pair_id}: {sorted(set(stages))}")
        for stage in STAGES:
            data = stages.get(stage, {}) if isinstance(stages.get(stage, {}), dict) else {}
            if not str(data.get("stage_direction", "")).strip():
                errors.append(f"Mise en scène absente pour {pair_id}/{stage}")
            if stage == "bereavement":
                lines = data.get("survivor_lines", {}) if isinstance(data.get("survivor_lines", {}), dict) else {}
                if set(lines) != heroes:
                    errors.append(f"Le deuil doit couvrir les deux survivants possibles pour {pair_id}")
                for hero_id, text in lines.items():
                    if not str(text).strip():
                        errors.append(f"Réplique de deuil vide {pair_id}/{hero_id}")
                    used_speakers.add(str(hero_id))
            else:
                line = data.get("line", {}) if isinstance(data.get("line", {}), dict) else {}
                speaker = str(line.get("speaker_id", ""))
                if speaker not in heroes:
                    errors.append(f"Le locuteur {speaker} n'appartient pas au couple {pair_id}/{stage}")
                if not str(line.get("text", "")).strip():
                    errors.append(f"Réplique vide {pair_id}/{stage}")
                if speaker:
                    used_speakers.add(speaker)
    if used_speakers != HEROES:
        errors.append(f"Les Sept doivent tous avoir une voix potentielle: {sorted(used_speakers)}")

    runtime_tokens = [
        "RelationshipRuntime.pair_state", "RelationshipRuntime.relation",
        "func relationship_stage_for_ids", "func present_best_pending_scene",
        "SystemicCrossNarrativeRuntime.has_pending_scene()",
        "SystemicCrossAfterlifeRuntime.pending_beat_count()",
        '"desaccord_persistant"', '"responsabilite_partagee"',
        '"bereavement"', '"narrative_seen"', '"qualitative_tag"',
        '_stage_seen(left, right, pair_id, "repair")',
    ]
    for token in runtime_tokens:
        if token not in runtime:
            errors.append(f"Runtime relationnel incomplet: {token}")
    for forbidden in ["ProgressBar", "relationship_score", "romance_score", "alignment_score", "global_approval", "morality_score"]:
        if forbidden in runtime:
            errors.append(f"Jauge/score interdit trouvé dans le runtime: {forbidden}")
    if "func serialize" in runtime or "func deserialize" in runtime:
        warnings.append("Le runtime des Sept devrait continuer à persister via les relations existantes, pas un silo de sauvegarde séparé")

    autoload = 'LegendarySevenRelationshipRuntime="*res://scripts/core/legendary_seven_relationship_runtime.gd"'
    if autoload not in project:
        errors.append("LegendarySevenRelationshipRuntime doit être un autoload")
    if project.find("SystemicCrossAfterlifeRuntime=") > project.find("LegendarySevenRelationshipRuntime="):
        errors.append("Les conséquences systémiques différées doivent être chargées avant les relations évolutives")
    if project.find("LegendarySevenRelationshipRuntime=") > project.find("SanctuaryState="):
        errors.append("Le runtime des Sept doit être prêt avant SanctuaryState")

    smoke_tokens = [
        "pair_count() == 21", "not_canonized", "maternal_protective", "fraternal",
        '== "opening"', '== "friction"', '== "rupture"', '== "repair"',
        '== "durable"', '== "bereavement"', "dead hero must never speak",
        "repair must be transitional", "systemic priority must block pair dialogue",
    ]
    for token in smoke_tokens:
        if token not in smoke:
            errors.append(f"Smoke des relations des Sept incomplet: {token}")
    if 'preload("res://scripts/core/legendary_seven_relationship_smoke_test.gd")' not in bootstrap:
        errors.append("Bootstrap du smoke des Sept absent")
    if "legendary_seven_relationship_smoke_bootstrap.gd" not in scene:
        errors.append("Scène smoke des Sept non reliée au bootstrap")
    if "legendary_seven_relationship_smoke.tscn" not in godot_ci:
        errors.append("Le smoke des Sept doit être exécuté par le wrapper Godot CI")

    for phrase in ["21 couples", "aucune jauge", "Marec ↔ Anouk", "Mathilde ↔ Marec", "Aurélien ↔ Mathilde", "ne verrouille aucune romance"]:
        if phrase not in doc:
            errors.append(f"Documentation relationnelle incomplète: {phrase}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "heroes": len(HEROES),
            "pairs": len(actual_pairs),
            "dialogue_pairs": len(dialogues),
            "stages_per_pair": len(STAGES),
            "speakers": sorted(used_speakers),
        },
    }


if __name__ == "__main__":
    report = audit_legendary_seven_relationships(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
