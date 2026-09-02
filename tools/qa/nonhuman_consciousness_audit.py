#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_nonhuman_consciousness(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/nonhuman_consciousness.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre consciences non humaines absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre de conscience vise un autre univers")
    if data.get("schema_version") != 1 or data.get("canon_version") != "1.0.0":
        errors.append("Version du registre de conscience incompatible")

    rules = data.get("core_rules", {})
    expected_false = (
        "humanlike_body_required_for_personhood",
        "human_speech_required_for_personhood",
        "reactivity_automatically_proves_consciousness",
        "strangeness_automatically_proves_consciousness",
        "single_case_defines_entire_category",
        "personhood_requires_metaphysical_soul_proof",
    )
    for key in expected_false:
        if rules.get(key) is not False:
            errors.append(f"Garde-fou de conscience violé: {key}")
    for key in ("clear_refusal_must_be_respected", "uncertainty_can_remain_canonical"):
        if rules.get(key) is not True:
            errors.append(f"Principe de conscience obligatoire absent: {key}")

    indicators = set(data.get("agency_indicators", []))
    required_indicators = {"stable_refusal", "vocabulary_correction", "persistent_preference", "negotiation_or_limit_setting", "self_other_distinction"}
    if not required_indicators <= indicators:
        errors.append("Les indices d'agence essentiels sont incomplets")

    entities = data.get("entities", {})
    saen = entities.get("saen", {})
    if saen.get("status") != "documented_conscious_interlocutor":
        errors.append("Saen doit rester un interlocuteur conscient documenté")
    if saen.get("ontology") != "unknown":
        errors.append("La nature ontologique de Saen doit rester inconnue")
    for claim in ("responds", "corrects_human_categories", "expresses_preferences", "expresses_refusal", "asks_humans_to_listen_to_others"):
        if claim not in saen.get("confirmed", []):
            errors.append(f"Comportement canonique de Saen absent: {claim}")
    for forbidden in ("human", "known_species", "spirit", "dead_soul", "representative_of_all_absents"):
        if forbidden not in saen.get("unconfirmed", []):
            errors.append(f"Limite ontologique de Saen absente: {forbidden}")

    absents = entities.get("absents", {})
    for key in ("single_species_confirmed", "single_civilization_confirmed", "single_collective_will_confirmed", "saen_represents_all"):
        if absents.get(key) is not False:
            errors.append(f"Les Absents ont été simplifiés à tort: {key}")

    frontier = entities.get("frontier", {})
    if frontier.get("causal_reactivity_confirmed") is not True:
        errors.append("La réactivité causale de la Frontière doit rester documentée")
    if frontier.get("consciousness_confirmed") is not False or frontier.get("hostility_confirmed") is not False:
        errors.append("La Frontière ne doit pas être anthropomorphisée")

    creatures = entities.get("memory_reacting_creatures", {})
    if creatures.get("route_reproduction_observed") is not True:
        errors.append("Le comportement mémoriel de créature a disparu")
    if creatures.get("memory_mechanism_confirmed") is not False or creatures.get("consciousness_confirmed_from_this_behavior_alone") is not False:
        errors.append("Le comportement d'une créature ne doit pas sur-prouver conscience ou mémoire")

    dragons = entities.get("dragons", {})
    for key in ("existence_in_history_confirmed", "effrie_powers_related", "tribe_venerated_dragons", "historical_harmony_with_tribe"):
        if dragons.get(key) is not True:
            errors.append(f"Fait draconique canonique absent: {key}")
    for key in ("full_language_confirmed", "political_structure_confirmed", "religious_demand_confirmed", "ancestry_link_confirmed", "veil_link_confirmed", "ancestral_pact_confirmed"):
        if dragons.get(key) is not False:
            errors.append(f"Suraffirmation draconique interdite: {key}")

    consent = data.get("consent_policy", {})
    for key in ("capture_after_clear_refusal_allowed", "recruitment_after_clear_refusal_allowed", "invasive_experiment_after_clear_refusal_allowed"):
        if consent.get(key) is not False:
            errors.append(f"Refus non respecté: {key}")
    if consent.get("uncertain_being_can_still_receive_precautionary_protection") is not True:
        errors.append("L'incertitude ne doit pas empêcher une protection de précaution")

    gameplay = data.get("gameplay", {})
    for key in ("universal_consciousness_stat", "personhood_is_xp_bonus", "all_intelligent_beings_have_peaceful_solution", "all_combat_against_conscious_beings_is_morally_identical", "uncertainty_removes_consequences"):
        if gameplay.get(key) is not False:
            errors.append(f"Garde-fou gameplay conscience violé: {key}")

    body = data.get("body_and_gore", {})
    if body.get("nonhuman_anatomy_is_exotic_spectacle") is not False:
        errors.append("L'anatomie non humaine ne doit pas devenir un spectacle exotique")
    if body.get("recognized_person_is_automatic_crafting_material") is not False:
        errors.append("Une personne reconnue ne peut pas devenir automatiquement un matériau de craft")

    remanence = data.get("remanence", {})
    if remanence.get("model") != ["source", "transmission", "transformation"]:
        errors.append("La Rémanence des consciences doit conserver source/transmission/transformation")
    if len(remanence.get("forms", [])) < 6:
        errors.append("Les formes de Rémanence des consciences sont trop pauvres")

    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "pass",
        "P3_philosophy_psychology": "pass_central",
        "P4_accessible_human_depth": "pass_central",
        "P5_strong_narrative": "pass_central",
        "P6_interconnection": "pass",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass_central",
        "P9_simple_deep_readable_gameplay": "pass",
    }
    if data.get("pillar_validation") != expected_pillars:
        errors.append("Validation des neuf piliers des consciences modifiée ou incomplète")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source conscience absente: {source}")

    doc = root / "docs/LITD_UNIVERSE_CONSCIENCES_NON_HUMAINES.md"
    if not doc.is_file():
        errors.append("Document consciences non humaines absent")
    else:
        text = doc.read_text(encoding="utf-8").lower()
        for token in ("saen : interlocuteur confirmé", "les absents", "la frontière", "règle de refus", "dragons", "statistique universelle", "rémanence"):
            if token not in text:
                errors.append(f"Document consciences non humaines incomplet: {token}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "agency_indicators": len(indicators),
            "entities": len(entities),
            "remanence_forms": len(remanence.get("forms", [])),
        },
    }


def main() -> int:
    report = audit_nonhuman_consciousness(ROOT)
    out = ROOT / "reports" / "nonhuman-consciousness-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
