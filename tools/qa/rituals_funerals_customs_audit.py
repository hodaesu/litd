#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_rituals_funerals_customs(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/rituals_funerals_customs.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre rites/funérailles/coutumes absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre rituel vise un autre univers")
    if data.get("schema_version") != 1 or data.get("canon_version") != "1.0.0":
        errors.append("Version du registre rituel incompatible")

    rules = data.get("core_rules", {})
    false_rules = (
        "single_shared_concorde_liturgy",
        "ritual_is_automatically_religious",
        "three_awakenings_ceremony_is_religious_by_default",
        "single_funeral_method",
        "single_confederal_calendar",
        "unknown_dead_may_receive_invented_names",
        "memorial_requires_body",
        "centralized_memorial_is_automatically_progress",
        "body_is_trophy_or_generic_resource",
        "ritual_grants_universal_moral_bonus",
        "ritual_can_reverse_litd1_permadeath",
    )
    for key in false_rules:
        if rules.get(key) is not False:
            errors.append(f"Garde-fou rituel violé: {key}")
    for key in ("local_and_religious_variation_is_normal", "identity_accuracy_over_symbolic_completion"):
        if rules.get(key) is not True:
            errors.append(f"Principe rituel manquant: {key}")

    layers = data.get("social_layers", {})
    if set(layers) != {"family_community", "civic", "religious"}:
        errors.append("Les trois couches familiale/civique/religieuse doivent rester distinctes")
    if layers.get("religious", {}).get("metaphysical_claim_is_automatically_fact") is not False:
        errors.append("Un rite religieux ne peut pas prouver automatiquement sa métaphysique")

    funerals = data.get("funerary_principles", {})
    return_name = funerals.get("return_the_name", {})
    if return_name.get("canonical_principle") is not True:
        errors.append("Le principe de restitution du nom doit rester canonique")
    if return_name.get("invent_missing_identity") is not False:
        errors.append("Un nom inconnu ne doit pas être inventé")
    if return_name.get("body_required_for_memorial") is not False:
        errors.append("Un mémorial doit rester possible sans dépouille")

    memory = funerals.get("memory_distribution", {})
    if memory.get("shared_memorial_allowed") is not True or memory.get("local_memorial_allowed") is not True:
        errors.append("Mémoire locale et mémoire partagée doivent rester toutes deux possibles")
    if memory.get("centralization_required") is not False:
        errors.append("La mémoire ne doit pas être centralisée par défaut")

    protocol = data.get("post_fall_body_protocol", {})
    for key in ("identify_when_possible", "document_condition", "isolate_or_secure_dangerous_body"):
        if protocol.get(key) is not True:
            errors.append(f"Protocole post-Chute incomplet: {key}")
    for key in ("body_recovery_always_required", "practical_danger_proves_soul_or_possession", "raised_dead_identity_is_automatically_same_person"):
        if protocol.get(key) is not False:
            errors.append(f"Suraffirmation post-Chute interdite: {key}")

    passage = data.get("three_awakenings_passage_ceremonies", {})
    if passage.get("exist_in_mature_concorde") is not True:
        errors.append("Les cérémonies éducatives locales des Trois Éveils ont disparu")
    for key in ("religious_by_default", "single_continental_name", "single_required_age", "single_identical_form", "magical_initiation", "ethnic_membership_test"):
        if passage.get(key) is not False:
            errors.append(f"Cérémonie des Trois Éveils surdéfinie: {key}")

    sarn = data.get("sarn_commemorations", {})
    if sarn.get("exist") is not True:
        errors.append("Les commémorations de Sarn doivent exister")
    for key in ("victory_festival", "single_confederal_holiday", "transmit_hereditary_guilt"):
        if sarn.get(key) is not False:
            errors.append(f"Commémoration de Sarn incorrecte: {key}")

    tournaments = data.get("grand_tournaments", {})
    if tournaments.get("major_public_ceremony") is not True:
        errors.append("Les Grands Tournois doivent rester une grande cérémonie publique")
    if tournaments.get("victory_grants_sovereignty") is not False:
        errors.append("Une victoire au tournoi ne peut pas donner de souveraineté")

    chronology = {str(item.get("era")): item for item in data.get("chronology", []) if isinstance(item, dict)}
    required_eras = {"litd2_last_war", "post_sarn_long_assemblies", "les_veilleurs", "mature_concorde_prefall", "litd1_post_fall"}
    if set(chronology) != required_eras:
        errors.append("Chronologie rituelle incomplète")
    if chronology.get("litd2_last_war", {}).get("mature_concorde_rites_exist") is not False:
        errors.append("Les rites matures de la Concorde ne doivent pas exister dans LITD2")
    if "persistent_corpses" not in chronology.get("litd1_post_fall", {}).get("features", []):
        errors.append("LITD1 doit conserver les cadavres persistants dans la couche rituelle")

    gameplay = data.get("gameplay", {})
    for key in ("universal_ritual_meter", "mandatory_funeral_minigame_per_death", "universal_hope_bonus_per_funeral", "generic_resurrection_rite", "litd1_permadeath_reversed", "effects_are_universal_moral_reward"):
        if gameplay.get(key) is not False:
            errors.append(f"Garde-fou gameplay rituel violé: {key}")
    if len(gameplay.get("possible_actions", [])) < 6:
        errors.append("Les rites doivent produire des choix concrets sans nouvelle jauge")

    body = data.get("body_and_gore", {})
    if body.get("pillar_2_applies_when_body_present") is not True:
        errors.append("Le pilier 2 doit s'appliquer quand un corps est présent")
    for key in ("mutilation_can_change_identification", "incomplete_body_can_change_ritual", "reanimation_can_change_recovery", "family_reaction_can_change", "memory_form_can_change", "tactical_risk_can_change"):
        if body.get(key) is not True:
            errors.append(f"Conséquence corporelle manquante: {key}")
    if body.get("gore_exists_to_make_funeral_spectacular") is not False:
        errors.append("Le gore funéraire ne doit pas devenir décoratif")

    staging = data.get("staging", {})
    for key in ("names_over_heroic_summary", "objects_and_empty_space_can_carry_scene", "crowds_react_individually", "ritual_can_be_incomplete_or_interrupted"):
        if staging.get(key) is not True:
            errors.append(f"Principe de mise en scène rituel manquant: {key}")
    for key in ("doctrine_exposition_by_default", "music_or_light_confirms_divine_truth"):
        if staging.get(key) is not False:
            errors.append(f"Mise en scène rituelle invalide: {key}")

    remanence = data.get("remanence", {})
    if remanence.get("model") != ["source", "transmission", "transformation"]:
        errors.append("La Rémanence rituelle doit rester source/transmission/transformation")
    if remanence.get("surviving_form_proves_original_meaning") is not False:
        errors.append("Une forme rituelle survivante ne prouve pas son sens d'origine")

    open_spaces = set(data.get("open_design_spaces", []))
    required_open = {
        "six_city_detailed_funeral_rites",
        "azravel_detailed_rites",
        "effrie_tribe_rites",
        "conscious_nonhuman_funeral_customs",
        "objective_soul_or_afterlife",
    }
    if not required_open <= open_spaces:
        errors.append("Des zones rituelles volontairement ouvertes ont été refermées trop tôt")

    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "pass_central_when_body_present",
        "P3_philosophy_psychology": "pass_central",
        "P4_accessible_human_depth": "pass_central",
        "P5_strong_narrative": "pass_central",
        "P6_interconnection": "pass_central",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass_central",
        "P9_simple_deep_readable_gameplay": "pass_central",
    }
    if data.get("pillar_validation") != expected_pillars:
        errors.append("Validation des neuf piliers rituels incomplète")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source rituelle absente: {source}")

    religion_path = root / "universe/lore/religions_beliefs.json"
    if religion_path.is_file():
        religion = load(religion_path)
        if religion.get("three_awakenings", {}).get("religious_system") is not False:
            errors.append("Conflit: les Trois Éveils sont devenus une religion")
        effrie = religion.get("effrie", {})
        if effrie.get("rites") != "unconfirmed":
            errors.append("Les rites de la tribu d'Èffrie doivent rester non confirmés")

    doc = root / "docs/LITD_UNIVERSE_RITES_FUNERAILLES_COUTUMES.md"
    if not doc.is_file():
        errors.append("Document canonique rites/funérailles/coutumes absent")
    else:
        text = doc.read_text(encoding="utf-8").lower()
        for token in ("rendre le nom", "mémoire locale", "sarn", "grands tournois", "lita 2" if False else "litd 2", "les veilleurs", "litd 1", "rémanence rituelle", "gore systémique"):
            if token not in text:
                errors.append(f"Document rituel incomplet: {token}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "chronology_eras": len(chronology),
            "remanence_forms": len(remanence.get("forms", [])),
            "open_design_spaces": len(open_spaces),
        },
    }


def main() -> int:
    report = audit_rituals_funerals_customs(ROOT)
    out = ROOT / "reports" / "rituals-funerals-customs-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
