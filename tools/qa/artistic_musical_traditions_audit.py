#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_artistic_musical_traditions(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/artistic_musical_traditions.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre artistique et musical absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre artistique vise un autre univers")
    if data.get("schema_version") != 1:
        errors.append("Version de schéma artistique inattendue")
    if data.get("canon_version") != "1.0.0":
        errors.append("Version canonique artistique incompatible")

    rules = data.get("core_rules", {})
    for key in ("art_is_not_ethnicity", "city_is_not_single_style"):
        if rules.get(key) is not True:
            errors.append(f"Règle artistique obligatoire absente ou fausse: {key}")
    for key in (
        "single_official_concorde_art",
        "single_official_concorde_music",
        "art_adds_universal_stat",
        "art_adds_parallel_progression_tree",
        "real_world_reference_library_is_diegetic_canon",
        "prototype_music_tracks_are_diegetic_canon",
        "signature_franchise_theme_locked",
        "mature_concorde_aesthetic_exists_in_litd2",
    ):
        if rules.get(key) is not False:
            errors.append(f"Garde-fou artistique violé: {key}")

    ecologies = data.get("regional_ecologies", [])
    if len(ecologies) != 6:
        errors.append("La passe doit conserver six écologies artistiques régionales de la Concorde mature")
    regions = {str(item.get("region", "")) for item in ecologies if isinstance(item, dict)}
    required_regions = {"Jian-Lu", "Sorye", "Dhor-Khal", "Lhaor", "Tessen", "Orun-Saï"}
    if regions != required_regions:
        errors.append("Les écologies artistiques ne couvrent pas exactement les six grandes cités de référence")
    ids = [str(item.get("id", "")) for item in ecologies if isinstance(item, dict)]
    if not all(ids) or len(ids) != len(set(ids)):
        errors.append("Identifiants artistiques absents ou dupliqués")
    for ecology in ecologies:
        if ecology.get("exclusive_to_region") is not False:
            errors.append(f"Une écologie artistique a été rendue exclusive à sa région: {ecology.get('id')}")
        for field in ("drivers", "forms", "musical_tendencies", "contradiction"):
            if not ecology.get(field):
                errors.append(f"Écologie artistique insuffisamment définie: {ecology.get('id')} / {field}")

    functions = data.get("shared_musical_functions", [])
    expected_functions = ["pulse", "line", "resonance", "plurality", "return", "silence"]
    if functions != expected_functions:
        errors.append("Les six fonctions musicales transversales doivent rester simples et stables")
    function_policy = data.get("shared_musical_function_policy", {})
    if function_policy.get("production_design_vocabulary") is not True:
        errors.append("Les fonctions musicales doivent rester un vocabulaire de conception")
    for key in ("diegetic_universal_theory", "official_scale", "official_mode", "official_tuning", "official_meter"):
        if function_policy.get(key) is not False:
            errors.append(f"Une théorie musicale universelle a été inventée: {key}")

    instruments = data.get("instrument_policy", {})
    if instruments.get("named_diegetic_instruments_locked") is not False:
        errors.append("Les instruments diégétiques nommés restent ouverts")
    if instruments.get("start_from_material_and_function") is not True:
        errors.append("Les instruments fictifs doivent partir de la matière et de la fonction")
    if instruments.get("rename_sensitive_real_instrument_and_claim_original") is not False:
        errors.append("Un instrument réel sensible ne peut pas être renommé puis revendiqué comme original")
    if len(instruments.get("fictional_instrument_requires", [])) < 5:
        errors.append("La conception d'instruments fictifs manque de contraintes matérielles ou sociales")

    remanence = data.get("remanence_model", {})
    if remanence.get("layers") != ["form", "attribution", "context", "interpretation"]:
        errors.append("Les quatre couches de Rémanence artistique doivent être conservées")
    if remanence.get("layers_can_diverge") is not True:
        errors.append("Les couches de Rémanence artistique doivent pouvoir diverger")
    if remanence.get("historical_original_is_automatically_artistically_best") is not False:
        errors.append("L'original historique ne doit pas être automatiquement déclaré artistiquement supérieur")
    if len(remanence.get("transmission_states", [])) < 10:
        errors.append("La Rémanence artistique manque d'états de transmission")

    chronology = {str(item.get("era", "")): item for item in data.get("chronology", []) if isinstance(item, dict)}
    if chronology.get("litd2_last_war", {}).get("mature_concorde_ecologies_exist") is not False:
        errors.append("L'esthétique mature de la Concorde ne doit pas exister dans LITD2")
    if chronology.get("post_sarn_long_assemblies_veilleurs", {}).get("mature_concorde_ecologies_exist") is not False:
        errors.append("Les écologies matures ne doivent pas être figées pendant Les Veilleurs")
    if chronology.get("mature_concorde_litd1_prefall", {}).get("mature_concorde_ecologies_exist") is not True:
        errors.append("Les écologies régionales doivent être reconnaissables dans la Concorde mature")
    if chronology.get("litd1_post_fall", {}).get("mature_concorde_ecologies_exist") != "fragmented":
        errors.append("La Chute doit fragmenter les réseaux artistiques sans effacer leur Rémanence")

    gameplay = data.get("gameplay_rules", {})
    for key in (
        "art_is_fourth_mandatory_progression_system",
        "critical_main_plot_can_be_permanently_locked_by_art_school",
        "music_can_mark_morally_correct_choice",
    ):
        if gameplay.get(key) is not False:
            errors.append(f"Garde-fou gameplay artistique violé: {key}")
    if len(gameplay.get("uses", [])) < 6:
        errors.append("Les usages gameplay artistiques sont insuffisamment horizontaux")

    staging = data.get("staging_rules", {})
    if staging.get("pillar_8_central") is not True:
        errors.append("Le pilier 8 doit rester central pour les arts et la musique")
    if staging.get("explain_every_artwork_by_exposition") is not False:
        errors.append("Les œuvres ne doivent pas être systématiquement expliquées par exposition")
    if staging.get("silence_is_valid_staging") is not True:
        errors.append("Le silence doit rester un outil de mise en scène valide")
    if staging.get("music_moralizes_political_choice") is not False:
        errors.append("La musique ne doit pas moraliser les choix politiques")

    body = data.get("body_consequence_rules", {})
    if body.get("gore_required_in_every_art_context") is not False:
        errors.append("Le gore ne doit pas être obligatoire dans chaque contexte artistique")
    if body.get("persistent_injury_can_change_artistic_practice") is not True:
        errors.append("Les blessures persistantes doivent pouvoir affecter une pratique artistique")

    real = data.get("real_world_reference_guardrails", {})
    if real.get("reference_library") != "docs/BIBLIOTHEQUE_ARTISTIQUE_MONDE.md":
        errors.append("La bibliothèque artistique mondiale n'est plus référencée correctement")
    if real.get("diegetic_canon") is not False:
        errors.append("La bibliothèque réelle ne doit jamais devenir du canon diégétique")
    if real.get("single_source_copy_allowed") is not False:
        errors.append("La copie d'une source réelle unique ne peut pas être autorisée")
    if real.get("sacred_or_community_motif_as_generic_decoration") is not False:
        errors.append("Les motifs sacrés ou communautaires réels ne peuvent pas devenir une décoration générique")
    if real.get("deep_transformation_required") is not True:
        errors.append("La transformation profonde des références réelles doit rester obligatoire")

    production = data.get("production_music_guardrails", {})
    if production.get("catalog") != "data/music_library.json" or production.get("guide") != "docs/design/music_library.md":
        errors.append("Les sources de la bibliothèque musicale de production ont changé")
    if production.get("catalog_is_prototype_production_tool") is not True:
        errors.append("Le catalogue musical doit rester un outil de production/prototype")
    if production.get("catalog_tracks_are_world_canon") is not False:
        errors.append("Les pistes candidates ne doivent pas devenir des œuvres du monde")
    if production.get("final_original_identity_still_required") is not True:
        errors.append("L'identité musicale originale finale doit rester un objectif")
    if production.get("signature_theme_locked_by_this_pass") is not False:
        errors.append("Cette passe ne doit pas verrouiller un thème signature non audité")

    outer = data.get("outer_world_policy", {})
    if outer.get("single_aesthetic_per_polity") is not False:
        errors.append("Les puissances extérieures ne doivent pas recevoir une esthétique unique")
    if outer.get("detailed_outer_traditions_locked") is not False:
        errors.append("Les traditions artistiques extérieures détaillées restent ouvertes")

    effrie = data.get("effrie_guardrail", {})
    if effrie.get("tribe_artistic_traditions") != "unconfirmed":
        errors.append("Les traditions artistiques de la tribu d'Èffrie doivent rester non confirmées")
    if effrie.get("tribe_music") != "unconfirmed" or effrie.get("tribe_symbols") != "unconfirmed":
        errors.append("La musique et les symboles de la tribu d'Èffrie doivent rester non confirmés")
    if effrie.get("must_remain_unconfirmed_here") is not True:
        errors.append("Le garde-fou artistique d'Èffrie a été retiré")

    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "conditional",
        "P3_philosophy_psychology": "pass_central",
        "P4_accessible_human_depth": "pass_central",
        "P5_strong_narrative": "pass_central",
        "P6_interconnection": "pass_central",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass_central",
        "P9_simple_deep_readable_gameplay": "pass_central",
    }
    if data.get("pillar_validation", {}) != expected_pillars:
        errors.append("Validation des neuf piliers artistiques incomplète ou modifiée")

    if data.get("supersedes_generic_open_space") != "traditions artistiques et musicales régionales de la Concorde":
        errors.append("Le registre doit résoudre explicitement l'ancien espace de conception artistique")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source artistique absente: {source}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "regional_ecologies": len(ecologies),
            "musical_functions": len(functions),
            "remanence_states": len(remanence.get("transmission_states", [])),
            "open_design_spaces": len(data.get("open_design_spaces", [])),
        },
    }


if __name__ == "__main__":
    report = audit_artistic_musical_traditions(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
