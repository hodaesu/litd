#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_religions_beliefs(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/religions_beliefs.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre religions/croyances absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre religieux vise un autre univers")
    if data.get("schema_version") != 1:
        errors.append("Version de schéma religieux inattendue")
    if data.get("canon_version") != "1.0.0":
        errors.append("Version canonique religieuse incompatible")

    rules = data.get("core_rules", {})
    if rules.get("religions_are_socially_real") is not True:
        errors.append("Les religions doivent exister socialement dans le monde")
    for key in (
        "metaphysical_interpretation_is_automatically_fact",
        "three_awakenings_are_religion",
        "religion_is_ethnicity",
        "belief_grants_biological_stats",
        "single_official_concorde_theology",
        "religion_is_fourth_awakening",
        "all_believers_share_one_moral_alignment",
        "all_nonbelievers_share_one_moral_alignment",
        "supernatural_effect_proves_theology",
    ):
        if rules.get(key) is not False:
            errors.append(f"Garde-fou religieux violé: {key}")

    layers = data.get("epistemic_layers", [])
    expected_layers = [
        "observed_phenomenon",
        "testimony",
        "interpretation",
        "doctrine",
        "institution",
        "unknown",
    ]
    if layers != expected_layers:
        errors.append("Les six niveaux de preuve religieux doivent rester explicites")

    policy = data.get("epistemic_policy", {})
    if policy.get("working_power_proves_effect_only") is not True:
        errors.append("Un pouvoir fonctionnel doit au minimum prouver son effet")
    if policy.get("working_power_proves_metaphysical_explanation") is not False:
        errors.append("Un pouvoir fonctionnel ne peut pas prouver automatiquement sa théologie")
    if policy.get("independent_evidence_required_to_promote_interpretation_to_fact") is not True:
        errors.append("Une interprétation ne peut devenir fait sans preuve indépendante")

    awakenings = data.get("three_awakenings", {})
    if awakenings.get("religious_system") is not False:
        errors.append("Les Trois Éveils ne sont pas une religion")
    if not all(awakenings.get(k) is True for k in ("compatible_with_religion", "compatible_with_agnosticism", "compatible_with_atheism_or_nontheism")):
        errors.append("Les Trois Éveils doivent rester compatibles avec croyance, doute et non-théisme")
    if awakenings.get("sanctuaries_are_temples_by_default") is not False:
        errors.append("Les Sanctuaires ne sont pas des temples par défaut")

    concorde = data.get("concorde_mature", {})
    if concorde.get("religiously_plural") is not True:
        errors.append("La Concorde mature doit rester religieusement plurielle")
    if concorde.get("official_confederal_theology") is not False:
        errors.append("Une théologie confédérale unique a été inventée")
    if concorde.get("belief_and_nonbelief_can_coexist") is not True:
        errors.append("La coexistence croyance/non-croyance doit rester possible")

    azravel = data.get("azravel", {})
    if azravel.get("polity_type") != "theocratic_kingdom":
        errors.append("Azravel doit rester un royaume théocratique")
    if azravel.get("dominant_faith_exists") is not True:
        errors.append("La foi dominante d'Azravel a disparu")
    if azravel.get("dominant_faith_name_locked") is not False:
        errors.append("Le nom de la foi d'Azravel ne doit pas être inventé dans cette passe")
    required_structures = {"festivals", "marriages", "funerals", "calendar", "mutual_aid"}
    if not required_structures <= set(azravel.get("faith_structures", [])):
        errors.append("La fonction sociale de la foi d'Azravel est incomplète")
    required_plurality = {
        "sincere_believers",
        "religious_minorities",
        "independent_mystics",
        "heterodox_currents",
        "theologians_opposed_to_central_power",
    }
    if not required_plurality <= set(azravel.get("internal_plurality", [])):
        errors.append("La pluralité interne d'Azravel a été simplifiée")
    if azravel.get("post_fall_religious_fear_used_for_purges") is not True:
        errors.append("Les purges religieuses post-Chute d'Azravel doivent rester documentées")
    if azravel.get("saint_of_the_rift_title_proves_supernatural_sainthood") is not False:
        errors.append("Le titre Saint de la Faille ne doit pas prouver une sainteté surnaturelle")

    supernatural = data.get("veil_and_supernatural", {})
    for key in ("veil_is_confirmed_deity", "veil_is_confirmed_spirit", "veil_is_confirmed_afterlife", "veil_is_confirmed_realm_of_dead", "raised_dead_prove_soul_return"):
        if supernatural.get(key) is not False:
            errors.append(f"La cosmologie du Voile a été suraffirmée: {key}")
    if supernatural.get("ultimate_nature") != "unknown":
        errors.append("La nature métaphysique ultime du Voile doit rester inconnue")
    if supernatural.get("raised_dead_identity_requires_separate_investigation") is not True:
        errors.append("L'identité des morts relevés doit rester une question distincte")

    effrie = data.get("effrie", {})
    if effrie.get("from_dragon_venerating_tribe") is not True:
        errors.append("La tribu d'Èffrie doit rester liée à la vénération des dragons")
    if effrie.get("tribe_once_lived_in_harmony_with_dragons") is not True:
        errors.append("L'ancienne harmonie avec les dragons doit rester canonique")
    if effrie.get("has_dragon_related_powers") is not True:
        errors.append("Les pouvoirs draconiques d'Èffrie doivent rester canon")
    for key in ("tribe_name", "pact", "theology", "priests", "rites", "symbols", "territory", "power_origin", "dragon_ancestry", "veil_link"):
        if effrie.get(key) != "unconfirmed":
            errors.append(f"Le détail d'Èffrie doit rester non confirmé ici: {key}")
    if effrie.get("legacy_vharren_or_pact_concepts_override_current_canon") is not False:
        errors.append("Les anciens concepts Vharren/Pacte ne peuvent pas écraser le canon")

    post = data.get("post_fall_guardrails", {})
    for key in ("new_cult_is_automatically_evil", "old_religion_is_automatically_wise", "atheist_is_automatically_rational", "believer_is_automatically_credulous"):
        if post.get(key) is not False:
            errors.append(f"Caricature religieuse interdite: {key}")

    remanence = data.get("remanence", {})
    if remanence.get("model") != ["source", "transmission", "transformation"]:
        errors.append("La Rémanence religieuse doit conserver source/transmission/transformation")
    if len(remanence.get("forms", [])) < 10:
        errors.append("La Rémanence religieuse manque de formes de transmission")

    chronology = {str(item.get("era", "")): item for item in data.get("chronology", []) if isinstance(item, dict)}
    if chronology.get("litd2_last_war", {}).get("mature_concorde_religious_policy_exists") is not False:
        errors.append("La politique religieuse mature de la Concorde ne doit pas déjà exister dans LITD2")
    if chronology.get("post_sarn_long_assemblies", {}).get("three_awakenings_stabilize_as_common_human_framework_not_theology") is not True:
        errors.append("Les Longues Assemblées doivent séparer cadre humain commun et théologie")
    if chronology.get("mature_concorde_prefall", {}).get("religious_plurality_normalized") is not True:
        errors.append("La pluralité religieuse doit être ancienne avant LITD1")

    gameplay = data.get("gameplay", {})
    for key in ("universal_faith_meter", "fourth_build_path", "universal_morality_score", "critical_plot_permanently_locked_by_belief", "worldview_grants_power_bonus_by_default"):
        if gameplay.get(key) is not False:
            errors.append(f"Garde-fou gameplay religieux violé: {key}")
    if gameplay.get("alternate_evidence_paths_required") is not True:
        errors.append("Les preuves critiques doivent avoir des voies alternatives")
    if len(gameplay.get("horizontal_uses", [])) < 8:
        errors.append("Les usages gameplay religieux sont trop étroits")

    staging = data.get("staging", {})
    if staging.get("pillar_8_central") is not True:
        errors.append("Le pilier 8 doit rester central")
    if staging.get("religious_scene_is_doctrine_exposition_by_default") is not False:
        errors.append("Une scène religieuse ne doit pas devenir une exposition doctrinale par défaut")
    if staging.get("music_or_light_confirms_divine_moral_approval") is not False:
        errors.append("La mise en scène ne doit pas confirmer automatiquement une approbation divine")
    if staging.get("crowds_are_monolithic_belief_blocks") is not False:
        errors.append("Les foules religieuses ne doivent pas être monolithiques")

    body = data.get("body_and_death", {})
    if body.get("gore_required_in_every_religious_scene") is not False:
        errors.append("Le gore ne doit pas être imposé à toutes les scènes religieuses")
    for key in ("persistent_injury_can_change_ritual_practice", "mutilated_body_can_create_funeral_conflict", "raised_dead_can_destabilize_personhood_categories", "adapted_rite_can_become_remanence"):
        if body.get(key) is not True:
            errors.append(f"Conséquence corporelle religieuse manquante: {key}")

    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "pass_conditional",
        "P3_philosophy_psychology": "pass_central",
        "P4_accessible_human_depth": "pass_central",
        "P5_strong_narrative": "pass_central",
        "P6_interconnection": "pass_central",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass_central",
        "P9_simple_deep_readable_gameplay": "pass_central",
    }
    if data.get("pillar_validation", {}) != expected_pillars:
        errors.append("Validation des neuf piliers religieux incomplète ou modifiée")

    if data.get("supersedes_generic_open_space") != "religions, croyances et relation au surnaturel":
        errors.append("La passe doit résoudre explicitement l'espace de conception religieux")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source religieuse absente: {source}")

    doc = root / "docs/LITD_UNIVERSE_RELIGIONS_CROYANCES.md"
    if not doc.is_file():
        errors.append("Document canonique religions/croyances absent")
    else:
        text = doc.read_text(encoding="utf-8").lower()
        for token in ("trois éveils ne sont pas une religion", "azravel", "èffrie", "six niveaux", "rémanence", "gore", "pilier 8", "jauge universelle de foi"):
            if token not in text:
                errors.append(f"Document religieux incomplet: {token}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "epistemic_layers": len(layers),
            "remanence_forms": len(remanence.get("forms", [])),
            "post_fall_responses": len(data.get("post_fall_responses", [])),
            "open_design_spaces": len(data.get("open_design_spaces", [])),
        },
    }


def main() -> int:
    report = audit_religions_beliefs(ROOT)
    out = ROOT / "reports" / "religions-beliefs-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
