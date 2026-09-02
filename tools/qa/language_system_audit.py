#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_language_system(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/language_system.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre linguistique absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le système linguistique vise un autre univers")
    if data.get("schema_version") != 1:
        errors.append("Version de schéma linguistique inattendue")
    if data.get("canon_version") != "1.0.0":
        errors.append("Version canonique linguistique incompatible")
    if data.get("world_multilingual") is not True:
        errors.append("Le monde doit rester explicitement multilingue")

    identity = data.get("identity_rules", {})
    for key in (
        "language_is_not_ethnicity",
        "city_is_not_language",
        "language_has_no_intrinsic_combat_stats",
        "personal_names_can_cross_languages",
    ):
        if identity.get(key) is not True:
            errors.append(f"Règle identitaire linguistique absente ou fausse: {key}")

    contact = data.get("contact_register", {})
    if contact.get("native_language") is not False:
        errors.append("Le registre de passage ne doit pas devenir une langue maternelle obligatoire")
    if contact.get("single_standardized_language") is not False:
        errors.append("Le registre de passage ne doit pas devenir une langue unique standardisée")
    if contact.get("replaces_local_languages") is not False:
        errors.append("Le registre de passage ne doit pas remplacer les langues locales")
    if contact.get("regional_variants") is not True:
        errors.append("Le registre de passage doit conserver des variantes régionales")
    if contact.get("emerges_after_sarn") is not True:
        errors.append("Le registre de passage ne doit pas être rétro-projeté comme système stabilisé avant Sarn")

    families = data.get("family_policy", {})
    if families.get("multiple_human_language_families_exist") is not True:
        errors.append("La pluralité des familles linguistiques humaines doit être conservée")
    if families.get("city_may_contain_multiple_families") is not True:
        errors.append("Une cité doit pouvoir contenir plusieurs familles linguistiques")
    if families.get("foreign_polity_is_not_single_language") is not True:
        errors.append("Une puissance étrangère ne doit pas être réduite à une langue unique")
    if families.get("ancient_language_is_not_automatic_modern_ancestor") is not True:
        errors.append("Les langues anciennes ne doivent pas devenir automatiquement ancêtres des langues modernes")

    states = data.get("comprehension_states", [])
    if states != ["fluent", "familiar", "mediated", "fragmentary", "unknown"]:
        errors.append("Les cinq états de compréhension doivent rester simples et stables")

    gameplay = data.get("gameplay_rules", {})
    if gameplay.get("critical_information_can_be_permanently_blocked_by_language") is not False:
        errors.append("La langue ne doit jamais bloquer définitivement une information critique")
    if gameplay.get("combat_critical_information_requires_unknown_language_reading") is not False:
        errors.append("Une information de combat urgente ne doit pas dépendre d'une langue inconnue")
    if gameplay.get("language_choice_can_be_only_route_to_canonical_ending") is not False:
        errors.append("Une langue ne doit pas être la seule route vers une fin canonique")
    if gameplay.get("language_familiarity_is_horizontal") is not True:
        errors.append("La familiarité linguistique doit rester une progression horizontale")
    if len(gameplay.get("valid_alternate_resolution_channels", [])) < 4:
        errors.append("Les informations linguistiques critiques doivent avoir plusieurs voies alternatives")

    eras = {str(item.get("era")): item for item in data.get("era_model", [])}
    for era in (
        "litd2_last_war",
        "post_sarn_long_assemblies_veilleurs",
        "mature_concorde_litd1_prefall",
        "litd1_post_fall",
    ):
        if era not in eras:
            errors.append(f"Ère linguistique manquante: {era}")
    if eras.get("litd2_last_war", {}).get("continental_register_stable") is not False:
        errors.append("LITD2 ne doit pas posséder un registre continental déjà stabilisé")

    ancient = data.get("ancient_language_guardrails", {})
    for key in ("ashai_direct_ancestor", "or_silex_direct_ancestor", "saan_direct_ancestor"):
        if ancient.get(key) != "unconfirmed":
            errors.append(f"Filiation linguistique antique inventée: {key}")

    effrie = data.get("effrie_guardrail", {})
    if effrie.get("tribe_language") != "unconfirmed" or effrie.get("must_remain_unconfirmed_in_this_system") is not True:
        errors.append("La langue de la tribu d'Èffrie doit rester non confirmée")

    open_spaces = set(data.get("open_design_spaces", []))
    for required in (
        "diegetic_family_names",
        "local_language_names",
        "scripts",
        "phonologies",
        "grammars",
        "effrie_tribe_language",
        "nonhuman_communication_systems",
    ):
        if required not in open_spaces:
            errors.append(f"Espace linguistique ouvert perdu: {required}")

    pillars = data.get("pillar_validation", {})
    expected = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "conditional",
        "P3_philosophy_psychology": "pass",
        "P4_accessible_human_depth": "pass",
        "P5_strong_narrative": "pass",
        "P6_interconnection": "pass_central",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass",
        "P9_simple_deep_readable_gameplay": "pass_central",
    }
    if pillars != expected:
        errors.append("Validation des neuf piliers linguistiques incomplète ou modifiée")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source linguistique absente: {source}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "comprehension_states": len(states),
            "eras": len(eras),
            "alternate_resolution_channels": len(gameplay.get("valid_alternate_resolution_channels", [])),
            "open_design_spaces": len(open_spaces),
        },
    }


if __name__ == "__main__":
    report = audit_language_system(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
