#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_contextual_beliefs_rites_quests(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/contextual_beliefs_rites_quests.json"
    religion_path = root / "universe/lore/religions_beliefs.json"
    nonhuman_path = root / "universe/lore/nonhuman_consciousness.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre croyances/rites contextuels absent"], "warnings": []}
    if not religion_path.is_file() or not nonhuman_path.is_file():
        return {"ok": False, "errors": ["Registres religieux ou consciences non humaines absents"], "warnings": []}

    data = load(path)
    religion = load(religion_path)
    nonhuman = load(nonhuman_path)

    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre contextuel vise un autre univers")
    if data.get("schema_version") != 1 or data.get("canon_version") != "1.0.0":
        errors.append("Version du registre contextuel incompatible")

    rules = data.get("core_rules", {})
    for key in ("contextual_rites_create_complete_theology", "working_power_proves_theology", "ritual_practice_is_automatic_religion", "character_belief_grants_stat_bonus", "quest_requires_single_correct_worldview"):
        if rules.get(key) is not False:
            errors.append(f"Garde-fou contextuel violé: {key}")
    if rules.get("open_cosmology_remains_open") is not True:
        errors.append("La cosmologie ouverte doit rester ouverte")

    azravel = data.get("azravel", {})
    if azravel.get("dominant_faith_name_locked") is not False or azravel.get("deity_model_locked") is not False or azravel.get("afterlife_locked") is not False:
        errors.append("Azravel a reçu une théologie complète non autorisée")
    az_practices = {str(item.get("id")): item for item in azravel.get("practices", []) if isinstance(item, dict)}
    if set(az_practices) != {"two_witness_vigil", "open_door_table", "reading_of_margins"}:
        errors.append("Les trois pratiques contextuelles d'Azravel doivent rester présentes")
    if az_practices.get("two_witness_vigil", {}).get("rules", []).count("no_soul_claim_required") != 1:
        errors.append("La Veille des Deux Témoins ne doit pas prouver l'âme")
    if az_practices.get("open_door_table", {}).get("religious_interpretation_required") is not False:
        errors.append("La Table de la Porte Ouverte doit pouvoir être pratiquée sans théologie obligatoire")

    lysandra = data.get("lysandra", {})
    if lysandra.get("institution_name_locked") is not False:
        errors.append("L'institution exacte de Lysandra ne doit pas être inventée")
    if lysandra.get("miracle_term_proves_theology") is not False:
        errors.append("Le terme miracle de Lysandra ne doit pas prouver une théologie")
    ly_practices = {str(item.get("id")): item for item in lysandra.get("practices", []) if isinstance(item, dict)}
    if set(ly_practices) != {"state_knowledge_hope_unknown", "hands_before_words", "miracle_not_verdict"}:
        errors.append("Les trois pratiques personnelles de Lysandra sont incomplètes")
    if ly_practices.get("state_knowledge_hope_unknown", {}).get("sequence") != ["known", "hoped", "unknown"]:
        errors.append("Lysandra doit distinguer savoir, espoir et inconnu")
    if ly_practices.get("hands_before_words", {}).get("sequence", [])[-1:] != ["optional_religious_words"]:
        errors.append("Le soin concret de Lysandra doit précéder ses mots religieux")

    zeje = data.get("zeje", {})
    if zeje.get("final_geographic_origin_locked_by_this_pass") is not False:
        errors.append("La variante géographique de Zejé a été verrouillée sans résolution")
    if zeje.get("prophet_status") is not False:
        errors.append("Zejé ne doit pas devenir prophète")
    ze_practices = {str(item.get("id")): item for item in zeje.get("practices", []) if isinstance(item, dict)}
    if set(ze_practices) != {"three_verifications", "versions_notebook", "dead_name_protocol"}:
        errors.append("Les pratiques de Zejé sont incomplètes")
    dims = ze_practices.get("three_verifications", {}).get("dimensions", {})
    if set(dims) != {"body", "spirit", "city"}:
        errors.append("Les Trois Vérifications de Zejé doivent suivre Corps, Esprit et Cité")
    if ze_practices.get("three_verifications", {}).get("truth_spell") is not False:
        errors.append("Les Trois Vérifications ne doivent pas devenir un sort de vérité")

    effrie = data.get("effrie", {})
    for key in ("tribe_name_locked", "ancestral_pact_locked", "dragon_ancestry_locked", "dragon_language_locked", "veil_link_locked", "veneration_means_divinity_required"):
        if effrie.get(key) is not False:
            errors.append(f"Suraffirmation d'Èffrie interdite: {key}")
    ef_practices = {str(item.get("id")): item for item in effrie.get("practices", []) if isinstance(item, dict)}
    if set(ef_practices) != {"restrained_step", "do_not_take_everything", "incomplete_story"}:
        errors.append("Les trois pratiques contextuelles d'Èffrie sont incomplètes")
    if ef_practices.get("restrained_step", {}).get("verbal_dragon_permission_required") is not False:
        errors.append("Le Pas Retenu ne doit pas inventer une permission verbale draconique")
    power = effrie.get("power_interpretation", {})
    for key in ("proves_dragon_ancestry", "proves_divine_election", "proves_ownership_of_dragons", "proves_right_to_rule_tribe", "proves_ancestral_pact", "proves_veil_link"):
        if power.get(key) is not False:
            errors.append(f"Les pouvoirs d'Èffrie sur-prouvent quelque chose: {key}")

    # Compatibilité avec le registre religieux générique : les pratiques contextuelles
    # ne doivent pas être réinterprétées comme théologie complète ou ancien Pacte.
    religion_effrie = religion.get("effrie", {})
    for key in ("tribe_name", "pact", "theology", "priests", "rites", "symbols", "territory", "power_origin", "dragon_ancestry", "veil_link"):
        if religion_effrie.get(key) != "unconfirmed":
            errors.append(f"Le registre religieux générique d'Èffrie doit rester ouvert: {key}")
    if religion_effrie.get("legacy_vharren_or_pact_concepts_override_current_canon") is not False:
        errors.append("Vharren/Pacte ne doivent pas reprendre priorité")

    dragons = nonhuman.get("entities", {}).get("dragons", {})
    for key in ("full_language_confirmed", "political_structure_confirmed", "ancestry_link_confirmed", "veil_link_confirmed", "ancestral_pact_confirmed"):
        if dragons.get(key) is not False:
            errors.append(f"Le cas Èffrie a contaminé le canon draconique: {key}")

    quests = {str(item.get("id")): item for item in data.get("quest_hooks", []) if isinstance(item, dict)}
    required_quests = {
        "lhaor_seeds_that_remain",
        "orun_sai_road_without_grave",
        "azravel_burned_margins",
        "azravel_table_still_open",
        "lysandra_what_miracle_proves",
        "zeje_three_versions_same_dead",
        "effrie_not_ours",
        "saen_ask_before_pulling",
        "dhor_khal_bridge_two_valleys",
    }
    if set(quests) != required_quests:
        errors.append("Les neuf hooks de quêtes/régions doivent rester présents")
    if quests.get("zeje_three_versions_same_dead", {}).get("valid_resolution_can_be_unknown") is not True:
        errors.append("L'incertitude doit rester une résolution valide dans la quête de Zejé")
    if quests.get("effrie_not_ours", {}).get("visible_dragon_required") is not False:
        errors.append("La quête d'Èffrie ne doit pas exiger un dragon visible")
    if quests.get("effrie_not_ours", {}).get("pact_revelation_required") is not False:
        errors.append("La quête d'Èffrie ne doit pas révéler automatiquement un Pacte")
    if quests.get("saen_ask_before_pulling", {}).get("required_rule") != "clear_refusal_changes_permitted_actions":
        errors.append("La quête de Saen doit matérialiser le consentement")

    gameplay = data.get("gameplay", {})
    for key in ("fourth_build_path", "faith_meter", "ritual_meter", "consciousness_stat", "religious_or_ethnic_bonus", "universal_morality_reward"):
        if gameplay.get(key) is not False:
            errors.append(f"Garde-fou gameplay contextuel violé: {key}")
    if gameplay.get("depth_from_existing_system_interactions") is not True:
        errors.append("La profondeur doit venir des systèmes existants")

    if len(data.get("remanence_chains", [])) < 6:
        errors.append("Les chaînes de Rémanence contextuelles sont insuffisantes")

    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "pass",
        "P3_philosophy_psychology": "pass_central",
        "P4_accessible_human_depth": "pass_central",
        "P5_strong_narrative": "pass_central",
        "P6_interconnection": "pass",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass_central",
        "P9_simple_deep_readable_gameplay": "pass_central",
    }
    if data.get("pillar_validation") != expected_pillars:
        errors.append("Validation des neuf piliers contextuels modifiée ou incomplète")

    protected = set(data.get("protected_open_fields", []))
    required_open = {"azravel_faith_name", "azravel_deities", "azravel_afterlife", "lysandra_exact_institution", "zeje_final_geographic_origin", "effrie_tribe_name", "effrie_ancestral_pact", "dragon_language", "dragon_political_society", "dragon_ancestry", "dragons_veil_link", "saen_metaphysical_nature"}
    if not required_open <= protected:
        errors.append("Des inconnues protégées ont disparu")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source contextuelle absente: {source}")

    doc = root / "docs/LITD_UNIVERSE_CAS_RITUELS_PERSONNAGES_REGIONS.md"
    if not doc.is_file():
        errors.append("Document cas rituels/personnages/régions absent")
    else:
        text = doc.read_text(encoding="utf-8").lower()
        for token in ("veille des deux témoins", "table de la porte ouverte", "dire ce que l'on sait", "les mains avant les mots", "les trois vérifications", "le pas retenu", "ce qui ne nous appartient pas", "demander avant de tirer", "rémanence"):
            if token not in text:
                errors.append(f"Document contextuel incomplet: {token}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "azravel_practices": len(az_practices),
            "lysandra_practices": len(ly_practices),
            "zeje_practices": len(ze_practices),
            "effrie_practices": len(ef_practices),
            "quest_hooks": len(quests),
        },
    }


def main() -> int:
    report = audit_contextual_beliefs_rites_quests(ROOT)
    out = ROOT / "reports" / "contextual-beliefs-rites-quests-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
