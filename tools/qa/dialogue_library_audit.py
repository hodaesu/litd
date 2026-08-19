#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_TECHNIQUES = {
    "objective_and_tactic",
    "tactic_shift",
    "subtext_gap",
    "status_reversal",
    "interruption",
    "silence_as_reply",
    "voice_syntax",
    "character_specific_exposition",
    "dramatic_irony",
    "scene_turn",
}

REQUIRED_STAGING = {
    "implied_stage_action",
    "blocking_as_power",
    "object_business",
    "entrance_reframe",
    "public_private_shift",
    "shared_task_dialogue",
    "physical_contradiction",
    "offstage_pressure",
}

REQUIRED_SOURCES = {
    "Folger Shakespeare Library",
    "Royal Shakespeare Company — Shakespeare Learning Zone",
    "Project Gutenberg",
    "Gallica / Bibliothèque nationale de France",
}


def run(root: Path = ROOT) -> dict:
    library_path = root / "data/dialogue_library.json"
    runtime_path = root / "scripts/core/narrative_library.gd"
    smoke_path = root / "scripts/core/narrative_library_smoke_test.gd"
    guide_path = root / "docs/design/dialogue_library.md"
    dialogues_path = root / "data/dialogues.json"

    library = json.loads(library_path.read_text(encoding="utf-8"))
    runtime = runtime_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    guide = guide_path.read_text(encoding="utf-8")
    dialogues = json.loads(dialogues_path.read_text(encoding="utf-8"))

    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Dialogue : schéma v1", int(library.get("version", 0)) >= 1)
    check("Dialogue : source de design", library.get("design_source") == "dialogue_and_staging_library_pass_16")

    basis = library.get("research_basis", [])
    source_names = {str(item.get("source", "")) for item in basis if isinstance(item, dict)}
    for source in REQUIRED_SOURCES:
        check(f"Dialogue : source {source}", source in source_names)

    protocol = library.get("rights_and_originality_protocol", {})
    check("Dialogue : aucun extrait stocké", protocol.get("stored_text_policy") == "metadata_and_abstract_techniques_only")
    check("Dialogue : interdictions suffisantes", len(protocol.get("forbidden", [])) >= 6)
    check("Dialogue : règles de reconstruction suffisantes", len(protocol.get("required", [])) >= 8)
    check(
        "Dialogue : traduction traitée séparément",
        any("traduction" in str(item).lower() for item in protocol.get("forbidden", [])),
    )
    check(
        "Dialogue : imitation de voix rejetée",
        any("imiter" in str(item).lower() for item in protocol.get("forbidden", [])),
    )

    axes = library.get("quality_axes", [])
    axis_ids = {str(item.get("id", "")) for item in axes if isinstance(item, dict)}
    check("Dialogue : au moins douze axes qualité", len(axis_ids) >= 12)
    for axis_id in ["scene_objective", "voice_specificity", "subtext", "listening", "status", "rhythm", "staging", "originality"]:
        check(f"Dialogue : axe {axis_id}", axis_id in axis_ids)

    techniques = library.get("dialogue_techniques", [])
    technique_ids = {str(item.get("id", "")) for item in techniques if isinstance(item, dict)}
    check("Dialogue : au moins trente-cinq techniques", len(technique_ids) >= 35)
    for technique_id in sorted(REQUIRED_TECHNIQUES):
        check(f"Dialogue : technique {technique_id}", technique_id in technique_ids)

    staging = library.get("staging_techniques", [])
    staging_ids = {str(item.get("id", "")) for item in staging if isinstance(item, dict)}
    check("Mise en scène : au moins quinze techniques", len(staging_ids) >= 15)
    for staging_id in sorted(REQUIRED_STAGING):
        check(f"Mise en scène : technique {staging_id}", staging_id in staging_ids)

    patterns = library.get("scene_patterns", [])
    pattern_ids = {str(item.get("id", "")) for item in patterns if isinstance(item, dict)}
    check("Dialogue : au moins huit patrons abstraits de scène", len(pattern_ids) >= 8)
    check("Dialogue : négociation", "negotiation" in pattern_ids)
    check("Dialogue : confession", "confession" in pattern_ids)
    check("Dialogue : audience publique", "public_hearing" in pattern_ids)
    check("Dialogue : après-coup calme", "quiet_aftermath" in pattern_ids)

    corpus = library.get("public_domain_corpus", [])
    check("Corpus : au moins dix familles de domaine public", len(corpus) >= 10)
    references: list[str] = []
    for family in corpus:
        if not isinstance(family, dict):
            continue
        refs = family.get("references", [])
        if isinstance(refs, list):
            references.extend(str(value) for value in refs)
    check("Corpus : au moins soixante-quinze références", len(references) >= 75, str(len(references)))
    for token in ["Shakespeare", "Molière", "Marivaux", "Oscar Wilde", "Henrik Ibsen", "Anton Chekhov", "Jane Austen", "Dostoevsky", "Victor Hugo", "Cervantes"]:
        check(f"Corpus : {token}", any(token.lower() in ref.lower() for ref in references))

    modern = library.get("copyrighted_or_modern_reference_only", {})
    modern_refs = modern.get("references", []) if isinstance(modern, dict) else []
    check("Références modernes : au moins six entrées", len(modern_refs) >= 6)
    check("Références modernes : politique sans texte", "Aucun texte" in str(modern.get("policy", "")))
    check("Références modernes : uniquement étude abstraite", all("study_only" in item for item in modern_refs if isinstance(item, dict)))

    voice_fields = library.get("voice_design_fields", [])
    check("Voix : au moins douze dimensions", len(voice_fields) >= 12)
    check("Voix : mode de mensonge", "lying_mode" in voice_fields)
    check("Voix : comportement du silence", "silence_behavior" in voice_fields)

    checklist = library.get("production_checklist", [])
    anti_patterns = library.get("anti_patterns", [])
    check("Production : checklist substantielle", len(checklist) >= 12)
    check("Production : anti-patterns substantiels", len(anti_patterns) >= 10)
    check(
        "Production : interdit exposition artificielle",
        any("faits qu'ils connaissent déjà" in str(item) for item in anti_patterns),
    )
    check(
        "Production : interdit fantasy générique uniforme",
        any("pseudo-médiéval" in str(item) for item in anti_patterns),
    )

    lower_library = library_path.read_text(encoding="utf-8").lower()
    for forbidden_key in ['"excerpt"', '"quote"', '"sample_dialogue"', '"verbatim"']:
        check(f"Droits : aucune clé {forbidden_key}", forbidden_key not in lower_library)

    for token in [
        'const DIALOGUE_PATH := "res://data/dialogue_library.json"',
        "var dialogue_data: Dictionary",
        "func dialogue_quality_axes()",
        "func dialogue_techniques()",
        "func dialogue_technique(",
        "func staging_techniques()",
        "func staging_technique(",
        "func dialogue_public_domain_corpus()",
        "func dialogue_originality_protocol()",
        "func dialogue_voice_fields()",
        "func dialogue_production_checklist()",
        "func dialogue_coverage()",
    ]:
        check(f"Runtime : {token}", token in runtime)

    check("Smoke : dialogue chargé", "NarrativeLibrary.dialogue_data" in smoke)
    check("Smoke : couverture dialogue", "NarrativeLibrary.dialogue_coverage()" in smoke)
    check("Smoke : action scénique implicite", 'staging_technique("implied_stage_action")' in smoke)
    check("Smoke : politique moderne sans texte", "dialogue_modern_reference_policy" in smoke)

    check("Documentation : dialogue comme action", "une réplique ne doit pas seulement signifier" in guide)
    check("Documentation : mise en scène textuelle", "Mise en scène textuelle" in guide)
    check("Documentation : références protégées encadrées", "Aucune réplique, aucun extrait" in guide)
    check("Documentation : test des noms", "Retirer les noms des personnages" in guide)

    check("Dialogues existants : données encore lisibles", isinstance(dialogues, list) and len(dialogues) >= 2)
    check("Dialogues existants : locuteurs et texte présents", all(isinstance(item, dict) and item.get("speaker") and item.get("text") for item in dialogues))

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "dialogue-library-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
