#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_regional_martial_schools(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/regional_martial_schools.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre des écoles martiales régionales absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre martial vise un autre univers")
    if data.get("schema_version") != 1:
        errors.append("Version de schéma martiale inattendue")
    if data.get("canon_version") != "1.0.0":
        errors.append("Version canonique martiale incompatible")

    rules = data.get("core_rules", {})
    required_true = ("school_is_not_ethnicity", "school_is_not_class", "school_is_not_religion", "school_is_not_political_authority", "cross_training_allowed")
    for key in required_true:
        if rules.get(key) is not True:
            errors.append(f"Règle martiale obligatoire absente ou fausse: {key}")
    for key in ("single_official_concorde_style", "mature_schools_exist_in_litd2", "schools_add_separate_skill_trees", "schools_add_new_progression_currency"):
        if rules.get(key) is not False:
            errors.append(f"Garde-fou martial obligatoire violé: {key}")

    names = data.get("design_name_policy", {})
    if names.get("school_names_are_translated_design_labels") is not True:
        errors.append("Les noms d'écoles doivent rester des traductions de conception tant que les langues locales sont ouvertes")
    if names.get("local_diegetic_names_locked") is not False:
        errors.append("Les noms diégétiques locaux ne doivent pas être inventés avant les langues correspondantes")

    breath = data.get("khen_breath", {})
    if breath.get("name") != "Souffle de Khen":
        errors.append("Le Souffle de Khen doit rester l'héritage transversal canonique")
    for key in ("is_seventh_school", "is_magic", "is_build_path"):
        if breath.get(key) is not False:
            errors.append(f"Le Souffle de Khen ne doit pas devenir: {key}")
    if breath.get("first_breath_attested") is not True:
        errors.append("Le Premier Souffle de Khen attesté a été perdu")

    schools = data.get("mature_concorde_schools", [])
    if len(schools) != 6:
        errors.append("La passe doit conserver exactement six grandes traditions régionales de la Concorde mature")
    ids = [str(item.get("id", "")) for item in schools]
    if not all(ids) or len(ids) != len(set(ids)):
        errors.append("Identifiants martiaux absents ou dupliqués")
    required_regions = {"Jian-Lu", "Sorye", "Dhor-Khal", "Lhaor", "Tessen", "Orun-Saï"}
    if {str(item.get("region", "")) for item in schools} != required_regions:
        errors.append("Les six traditions régionales ne couvrent pas exactement les six grandes cités de référence")
    for school in schools:
        if school.get("exclusive_to_region") is not False:
            errors.append(f"Une école a été rendue exclusive à sa région: {school.get('id')}")
        if not school.get("focus") or not school.get("strengths") or not school.get("limitation"):
            errors.append(f"École insuffisamment lisible ou sans limite: {school.get('id')}")

    chrono = {str(item.get("era")): item for item in data.get("chronology", [])}
    if chrono.get("litd2_last_war", {}).get("mature_six_schools_exist") is not False:
        errors.append("Les six écoles matures ne doivent pas exister pendant LITD2")
    if chrono.get("post_sarn_long_assemblies_veilleurs", {}).get("mature_six_schools_exist") is not False:
        errors.append("Les six écoles matures ne doivent pas être figées pendant Les Veilleurs")
    if chrono.get("mature_concorde_litd1_prefall", {}).get("mature_six_schools_exist") is not True:
        errors.append("Les six écoles doivent être reconnues à l'époque de la Concorde mature")

    integration = data.get("game_integration", {})
    litd1 = integration.get("litd1", {})
    litd2 = integration.get("litd2", {})
    veilleurs = integration.get("les_veilleurs", {})
    if litd1.get("replace_three_skill_trees") is not False or litd1.get("new_parallel_progression_layer") is not False:
        errors.append("Les écoles ne doivent pas remplacer ni doubler les trois arbres de LITD1")
    if litd2.get("replace_body_mind_politics") is not False or litd2.get("replace_run_weapons") is not False:
        errors.append("Les écoles ne doivent pas remplacer les builds ou armes de LITD2")
    if veilleurs.get("assign_four_protagonists_to_four_classes") is not False:
        errors.append("Les quatre protagonistes des Veilleurs ne doivent pas être réduits à quatre classes martiales")

    body = data.get("body_consequence_rules", {})
    if body.get("gore_bonus_by_school") is not False:
        errors.append("Le gore ne doit jamais devenir un bonus identitaire d'école")
    if body.get("anatomical_result_depends_on_systemic_physics_and_body_state") is not True:
        errors.append("Les conséquences corporelles doivent rester systémiques")
    if body.get("nonlethal_actions_can_still_injure") is not True:
        errors.append("Les actions non létales doivent conserver des conséquences corporelles possibles")

    tournaments = data.get("grand_tournaments", {})
    if tournaments.get("exist_in_litd2") is not False:
        errors.append("Les Grands Tournois ne doivent pas être rétro-projetés dans LITD2")
    if tournaments.get("victory_grants_territorial_or_political_power") is not False:
        errors.append("Une victoire de tournoi ne doit jamais accorder de pouvoir territorial ou politique")

    outer = data.get("outer_world_policy", {})
    if outer.get("single_style_per_polity") is not False:
        errors.append("Les civilisations extérieures ne doivent pas être réduites à une école unique")
    if outer.get("named_outer_schools_locked") is not False:
        errors.append("Les écoles étrangères nommées restent ouvertes pour une passe dédiée")

    effrie = data.get("effrie_guardrail", {})
    if effrie.get("tribe_martial_practice") != "unconfirmed" or effrie.get("must_remain_unconfirmed_here") is not True:
        errors.append("L'art martial de la tribu d'Èffrie doit rester non confirmé")

    if data.get("supersedes_generic_open_space") != "écoles martiales régionales":
        errors.append("Le registre doit explicitement résoudre l'ancien espace de conception martial")

    pillars = data.get("pillar_validation", {})
    expected = {
        "P1_character_creation": "pass_central",
        "P2_systemic_gore": "pass_central",
        "P3_philosophy_psychology": "pass",
        "P4_accessible_human_depth": "pass",
        "P5_strong_narrative": "pass",
        "P6_interconnection": "pass_central",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass",
        "P9_simple_deep_readable_gameplay": "pass_central",
    }
    if pillars != expected:
        errors.append("Validation des neuf piliers martiaux incomplète ou modifiée")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source martiale absente: {source}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "regional_schools": len(schools),
            "khen_breath_functions": len(breath.get("functions", [])),
            "chronology_eras": len(chrono),
            "open_design_spaces": len(data.get("open_design_spaces", [])),
        },
    }


if __name__ == "__main__":
    report = audit_regional_martial_schools(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
