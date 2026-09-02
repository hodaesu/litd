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


def audit_systemic_cross_afterlife(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    canon_path = root / "universe/lore/contextual_quest_cross_ramifications.json"
    data_path = root / "data/narrative/systemic_cross_afterlives.json"
    runtime_path = root / "scripts/core/systemic_cross_afterlife_runtime.gd"
    project_path = root / "project.godot"
    smoke_path = root / "scripts/core/systemic_cross_afterlife_smoke_test.gd"
    bootstrap_path = root / "scripts/core/systemic_cross_afterlife_smoke_bootstrap.gd"
    scene_path = root / "scenes/tests/systemic_cross_afterlife_smoke.tscn"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"

    required = [canon_path, data_path, runtime_path, project_path, smoke_path, bootstrap_path, scene_path, godot_ci_path]
    for path in required:
        if not path.is_file():
            errors.append(f"Fichier requis absent: {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    canon = load(canon_path)
    data = load(data_path)
    runtime = runtime_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    bootstrap = bootstrap_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")

    rules = data.get("rules", {})
    for key in [
        "no_new_ui", "no_global_morality_score", "source_trace_never_deleted",
        "rumor_never_replaces_fact", "contradiction_may_remain_unresolved",
        "relationship_echoes_are_non_numeric", "hero_lines_require_living_present_speaker",
        "one_afterlife_beat_per_sanctuary_entry", "immediate_scene_has_priority",
    ]:
        if rules.get(key) is not True:
            errors.append(f"Règle différée {key} doit rester true")
    if int(rules.get("echo_chapter_offset", 0)) < 1:
        errors.append("Un écho différé ne peut pas apparaître dans le chapitre source")
    if int(rules.get("remanence_chapter_offset", 0)) <= int(rules.get("echo_chapter_offset", 0)):
        errors.append("La Rémanence doit émerger après le premier écho, pas en même temps")

    canon_families = {str(item.get("family", "")) for item in canon.get("cross_events", []) if str(item.get("family", ""))}
    profiles = data.get("family_profiles", {})
    profile_families = set(map(str, profiles.keys()))
    if canon_families != profile_families:
        errors.append(
            "Profils différés désynchronisés avec les familles canoniques: "
            f"manquants={sorted(canon_families-profile_families)}, en trop={sorted(profile_families-canon_families)}"
        )

    cascade_ids = {str(item.get("id", "")) for item in canon.get("compound_cascades", []) if str(item.get("id", ""))}
    cascade_profiles = data.get("cascade_profiles", {})
    if set(map(str, cascade_profiles.keys())) != cascade_ids:
        errors.append("Chaque cascade systémique doit posséder une transmission différée et une Rémanence propres")

    used_heroes: set[str] = set()
    required_profile_fields = [
        "echo_rumor", "echo_opening", "echo_closing", "silence", "dialogue",
        "relationship_topic", "remanence_label", "remanence_form", "remanence_trace", "remanence_rumor",
    ]
    all_profiles: dict[str, Any] = {**profiles, **cascade_profiles}
    for profile_id, raw in all_profiles.items():
        profile = raw if isinstance(raw, dict) else {}
        for field in required_profile_fields:
            value = profile.get(field)
            if field == "dialogue":
                if not isinstance(value, dict) or not value:
                    errors.append(f"Dialogue différé absent pour {profile_id}")
            elif not str(value or "").strip():
                errors.append(f"Champ {field} absent pour {profile_id}")
        dialogue = profile.get("dialogue", {}) if isinstance(profile.get("dialogue", {}), dict) else {}
        for hero_id, text in dialogue.items():
            if hero_id not in EXPECTED_HEROES:
                errors.append(f"Héros non canonique dans un dialogue différé: {profile_id} -> {hero_id}")
            else:
                used_heroes.add(hero_id)
            if not str(text).strip():
                errors.append(f"Réplique différée vide: {profile_id} -> {hero_id}")
        if "always" in str(profile.get("echo_rumor", "")).lower() or "toujours été" in str(profile.get("echo_rumor", "")).lower():
            warnings.append(f"Vérifier que le texte de {profile_id} ne transforme pas une rumeur en vérité ancienne")

    if used_heroes != EXPECTED_HEROES:
        errors.append(f"Les Sept doivent tous disposer d'au moins une voix différée potentielle: {sorted(used_heroes)}")

    relationship_meanings = data.get("relationship_meanings", {})
    for key in ["shared_burden", "friction", "grief", "none"]:
        meaning = relationship_meanings.get(key, {}) if isinstance(relationship_meanings, dict) else {}
        if not str(meaning.get("tag", "")).strip() or not str(meaning.get("description", "")).strip():
            errors.append(f"Sens relationnel incomplet pour {key}")

    runtime_tokens = [
        "func relation_history_for", "func remanences", "func present_next_pending_beat",
        "SystemicCrossRuntime.applied_events", "SystemicCrossRuntime.applied_cascades",
        '"SOURCE"', '"TRANSMISSION"', '"REMANENCE"',
        '"status": "emergent_not_objective_truth"', '"numeric_score": false',
        "CommunityRuntime.record_systemic_cross_event", "SystemicCrossNarrativeRuntime.has_pending_scene()",
        "SystemicCrossNarrativeRuntime.scene_presented.connect", "GameState.alive_heroes()",
        "source_trace_preserved", "presented_phases", "afterlife",
    ]
    for token in runtime_tokens:
        if token not in runtime:
            errors.append(f"Runtime des conséquences différées incomplet: {token}")
    for forbidden in ["ProgressBar", "morality_score", "alignment_score", "global_approval", "truth_score"]:
        if forbidden in runtime:
            errors.append(f"Score/UI interdit dans le runtime différé: {forbidden}")
    if "func serialize" in runtime or "func deserialize" in runtime:
        warnings.append("La couche différée devrait préférer la persistance dans l'état source SystemicCrossRuntime plutôt qu'un second silo de sauvegarde")

    autoload = 'SystemicCrossAfterlifeRuntime="*res://scripts/core/systemic_cross_afterlife_runtime.gd"'
    if autoload not in project:
        errors.append("SystemicCrossAfterlifeRuntime doit être un autoload")
    if project.find("SystemicCrossNarrativeRuntime=") > project.find("SystemicCrossAfterlifeRuntime="):
        errors.append("La scène immédiate doit être chargée avant sa couche de conséquences différées")
    if project.find("SystemicCrossAfterlifeRuntime=") > project.find("SanctuaryState="):
        errors.append("La couche différée doit être prête avant SanctuaryState")

    smoke_tokens = [
        "No delayed echo may appear in the same chapter", "plan unique",
        "relationship echo", "numeric_score", "immediate sanctuary consequence must keep priority",
        "SOURCE -> TRANSMISSION -> REMANENCE", "source_trace_preserved",
        "emergent_not_objective_truth", "persist through the existing systemic-cross save payload",
    ]
    for token in smoke_tokens:
        if token not in smoke:
            errors.append(f"Smoke différé incomplet: {token}")
    if 'preload("res://scripts/core/systemic_cross_afterlife_smoke_test.gd")' not in bootstrap:
        errors.append("Bootstrap du smoke différé absent")
    if "systemic_cross_afterlife_smoke_bootstrap.gd" not in scene:
        errors.append("Scène du smoke différé non reliée au bootstrap")
    if "systemic_cross_afterlife_smoke.tscn" not in godot_ci:
        errors.append("Le smoke différé doit être exécuté par le wrapper Godot CI")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "families": len(canon_families),
            "cascades": len(cascade_ids),
            "heroes_with_delayed_voice": sorted(used_heroes),
            "relationship_meanings": len(relationship_meanings),
        },
    }


if __name__ == "__main__":
    report = audit_systemic_cross_afterlife(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
