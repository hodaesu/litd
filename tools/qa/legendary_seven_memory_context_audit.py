#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
HEROES = {
    "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
    "hero.marec", "hero.zeje", "hero.anouk",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _safe_id(value: str) -> str:
    return value.replace(".", "_").replace(":", "_").replace("/", "_")


def _relationship_topics(afterlives: dict[str, Any]) -> set[str]:
    topics: set[str] = set()
    for section_name in ("family_profiles", "cascade_profiles"):
        section = afterlives.get(section_name, {})
        if not isinstance(section, dict):
            continue
        for value in section.values():
            profile = value if isinstance(value, dict) else {}
            topic = str(profile.get("relationship_topic", "")).strip()
            if topic:
                topics.add(topic)
    return topics


def audit_legendary_seven_memory_context(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    contexts_path = root / "data/narrative/legendary_seven_relationship_memory_contexts.json"
    afterlives_path = root / "data/narrative/systemic_cross_afterlives.json"
    sources_path = root / "data/narrative/systemic_cross_runtime.json"
    runtime_path = root / "scripts/core/legendary_seven_relationship_runtime.gd"
    smoke_path = root / "scripts/core/legendary_seven_relationship_smoke_test.gd"
    doc_path = root / "docs/LITD1_SEPT_MEMOIRES_RELATIONNELLES_V1.md"

    required = [contexts_path, afterlives_path, sources_path, runtime_path, smoke_path, doc_path]
    for path in required:
        if not path.is_file():
            errors.append(f"Fichier requis absent: {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    contexts = load(contexts_path)
    afterlives = load(afterlives_path)
    sources = load(sources_path)
    runtime = runtime_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    doc = doc_path.read_text(encoding="utf-8")

    rules = contexts.get("rules", {})
    for key in [
        "no_new_relationship_meter", "exact_event_id_marks_scene_seen",
        "same_stage_may_return_for_distinct_memory", "generic_stage_line_is_preserved",
        "dead_hero_never_speaks", "memory_context_is_not_moral_verdict",
        "unknown_topic_falls_back_to_generic_scene", "event_override_never_changes_source_fact",
    ]:
        if rules.get(key) is not True:
            errors.append(f"Garde-fou mémoire manquant ou faux: {key}")
    if int(rules.get("max_spoken_lines_per_scene", 99)) > 2:
        errors.append("Une scène contextuelle ne doit pas dépasser deux prises de parole")

    expected_topics = _relationship_topics(afterlives)
    topics_value = contexts.get("topics", {})
    topics = topics_value if isinstance(topics_value, dict) else {}
    if set(topics) != expected_topics:
        errors.append(
            "Les contextes mémoire doivent couvrir exactement les relationship_topic systémiques: "
            f"manquants={sorted(expected_topics-set(topics))}, en trop={sorted(set(topics)-expected_topics)}"
        )
    if len(topics) != 11:
        errors.append(f"La V1 doit couvrir 11 familles de mémoire, trouvé {len(topics)}")

    for topic, raw in topics.items():
        profile = raw if isinstance(raw, dict) else {}
        if not str(profile.get("stage_direction_suffix", "")).strip():
            errors.append(f"Mise en scène mémoire absente: {topic}")
        voices_value = profile.get("voices", {})
        voices = voices_value if isinstance(voices_value, dict) else {}
        if set(voices) != HEROES:
            errors.append(f"Les sept voix doivent être couvertes pour {topic}")
        for hero_id, text in voices.items():
            if not str(text).strip():
                errors.append(f"Réplique mémoire vide: {topic}/{hero_id}")

    source_ids = set()
    for section_name in ("events", "cascades"):
        section = sources.get(section_name, {})
        if isinstance(section, dict):
            source_ids.update(_safe_id(str(key)) for key in section.keys())
    overrides_value = contexts.get("event_overrides", {})
    overrides = overrides_value if isinstance(overrides_value, dict) else {}
    if not overrides:
        errors.append("Au moins une surcharge d'événement exact est requise")
    unknown_overrides = set(overrides) - source_ids
    if unknown_overrides:
        errors.append(f"Surcharges pointant vers des sources inexistantes: {sorted(unknown_overrides)}")

    required_exact = {
        "cross_food_local_security_and_grain_bridge",
        "cross_funeral_body_return_and_medical_corridor",
        "cross_epistemic_clinical_record_and_probable_identity",
        "cross_azravel_evidence_and_protected_registry",
        "cross_relationship_named_death_after_difficult_choice",
        "cascade_winter_refugee_pressure",
    }
    if not required_exact.issubset(overrides):
        errors.append(f"Surcharges structurantes manquantes: {sorted(required_exact-set(overrides))}")
    for source_id in required_exact:
        profile = overrides.get(source_id, {}) if isinstance(overrides.get(source_id, {}), dict) else {}
        if not str(profile.get("stage_direction_suffix", "")).strip():
            errors.append(f"Surcharge exacte sans mise en scène: {source_id}")
        pair_lines = profile.get("pair_lines", {}) if isinstance(profile.get("pair_lines", {}), dict) else {}
        line = pair_lines.get("aurelien_mathilde", {}) if isinstance(pair_lines.get("aurelien_mathilde", {}), dict) else {}
        if str(line.get("speaker_id", "")) not in {"hero.aurelien", "hero.mathilde"} or not str(line.get("text", "")).strip():
            errors.append(f"Aurélien ↔ Mathilde doit avoir une variante exacte pour {source_id}")

    runtime_tokens = [
        "MEMORY_CONTEXT_PATH", "func memory_topic_count", "func _latest_unseen_memory",
        "func _memory_topic_profile", "func _memory_event_override", "func _memory_line_for",
        "func _source_token_from_event_id", "func _scene_marker", '"memory_event_id"',
        '"memory_source_id"', '"memory_chapter_id"', '"memory_context_applied"',
        "NARRATIVE_SEEN_LIMIT", "_stage_priority(stage) + (5 if not memory.is_empty() else 0)",
    ]
    for token in runtime_tokens:
        if token not in runtime:
            errors.append(f"Runtime mémoire incomplet: {token}")
    for forbidden in ["relationship_score", "romance_score", "global_approval", "morality_score"]:
        if forbidden in runtime:
            errors.append(f"Score interdit trouvé dans le runtime mémoire: {forbidden}")

    smoke_tokens = [
        "memory_topic_count() == 11", "memory_context_applied", "memory_event_id",
        "same stage may replay for a distinct exact memory", "same exact memory must not replay",
        "exact route memory must change Aurélien-Mathilde staging",
    ]
    for token in smoke_tokens:
        if token not in smoke:
            errors.append(f"Smoke mémoire incomplet: {token}")

    for phrase in [
        "mémoire exacte", "11 familles de mémoire", "Aurélien ↔ Mathilde",
        "aucune jauge", "event_id", "Un héros mort ne parle jamais",
    ]:
        if phrase not in doc:
            errors.append(f"Documentation mémoire incomplète: {phrase}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "topics": len(topics),
            "heroes_per_topic": len(HEROES),
            "event_overrides": len(overrides),
            "expected_systemic_topics": len(expected_topics),
        },
    }


if __name__ == "__main__":
    report = audit_legendary_seven_memory_context(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
