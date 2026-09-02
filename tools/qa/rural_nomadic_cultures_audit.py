#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_rural_nomadic_cultures(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/rural_nomadic_cultures.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Registre cultures rurales/nomades absent"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("Le registre rural vise un autre univers")
    if data.get("schema_version") != 1 or data.get("canon_version") != "1.0.0":
        errors.append("Version du registre rural incompatible")

    rules = data.get("core_rules", {})
    false_rules = (
        "rural_means_backward",
        "nomadism_is_ethnicity",
        "city_represents_entire_region",
        "rural_origin_grants_biological_stats",
        "mobile_community_lacks_institutions_by_definition",
        "countryside_is_resource_only_space",
    )
    for key in false_rules:
        if rules.get(key) is not False:
            errors.append(f"Garde-fou rural violé: {key}")
    for key in ("rural_and_urban_interdependence_is_canonical", "mobility_can_be_chosen_seasonal_or_forced"):
        if rules.get(key) is not True:
            errors.append(f"Principe rural obligatoire absent: {key}")

    lifeways = {str(item.get("id")): item for item in data.get("lifeways", []) if isinstance(item, dict)}
    expected = {
        "lhaor_basin_garden_communities",
        "jian_lu_river_communities",
        "dhor_khal_satellite_workshop_villages",
        "tessen_artisan_agricultural_rings",
        "orun_sai_caravan_networks",
        "transhumant_pastoral_networks",
    }
    if set(lifeways) != expected:
        errors.append(f"Les six modes de vie canoniques doivent rester présents: {sorted(lifeways)}")

    pastoral = lifeways.get("transhumant_pastoral_networks", {})
    if pastoral.get("name_locked") is not False:
        errors.append("Un nom continental de peuple pastoral a été inventé")
    if pastoral.get("livestock_species_locked") is not False:
        errors.append("Une espèce de bétail a été verrouillée sans source")
    if "not_single_ethnicity" not in pastoral.get("guardrails", []):
        errors.append("La transhumance ne doit pas devenir une ethnie unique")

    caravan = lifeways.get("orun_sai_caravan_networks", {})
    if "caravan_not_automatically_nomadic" not in caravan.get("guardrails", []):
        errors.append("Une caravane ne doit pas être automatiquement définie comme nomade")

    lhaor = lifeways.get("lhaor_basin_garden_communities", {})
    if "not_druid_culture_by_default" not in lhaor.get("guardrails", []):
        errors.append("Lhaor ne doit pas devenir une culture druidique générique")

    chronology = {str(item.get("era")): item for item in data.get("chronology", []) if isinstance(item, dict)}
    required_eras = {"litd2_last_war", "post_sarn_long_assemblies", "les_veilleurs", "mature_concorde_prefall", "litd1_post_fall"}
    if not required_eras <= set(chronology):
        errors.append("Chronologie rurale inter-jeux incomplète")
    if chronology.get("litd2_last_war", {}).get("mature_concorde_rural_policy_exists") is not False:
        errors.append("LITD2 ne doit pas déjà posséder la politique rurale mature de la Concorde")
    if "local_knowledge_beats_old_maps" not in chronology.get("litd1_post_fall", {}).get("features", []):
        errors.append("LITD1 doit permettre au savoir local de dépasser les anciennes cartes")

    gameplay = data.get("gameplay", {})
    for key in ("new_build_path", "universal_rural_survival_meter", "automatic_nomad_bonus", "village_is_quest_dispenser_only", "caravan_is_shop_only", "refugee_choice_has_universal_moral_score"):
        if gameplay.get(key) is not False:
            errors.append(f"Garde-fou gameplay rural violé: {key}")
    if len(gameplay.get("horizontal_uses", [])) < 8:
        errors.append("Les usages gameplay ruraux sont trop pauvres")

    remanence = data.get("remanence", {})
    if remanence.get("model") != ["source", "transmission", "transformation"]:
        errors.append("La Rémanence rurale doit conserver source/transmission/transformation")
    if len(remanence.get("examples", [])) < 6:
        errors.append("La Rémanence rurale manque d'exemples structurants")

    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "pass_conditional",
        "P3_philosophy_psychology": "pass",
        "P4_accessible_human_depth": "pass_central",
        "P5_strong_narrative": "pass",
        "P6_interconnection": "pass_central",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass",
        "P9_simple_deep_readable_gameplay": "pass",
    }
    if data.get("pillar_validation") != expected_pillars:
        errors.append("Validation des neuf piliers ruraux modifiée ou incomplète")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source rurale absente: {source}")

    doc = root / "docs/LITD_UNIVERSE_CULTURES_RURALES_NOMADES.md"
    if not doc.is_file():
        errors.append("Document cultures rurales/nomades absent")
    else:
        text = doc.read_text(encoding="utf-8").lower()
        for token in ("rural ne signifie ni arriéré", "nomade ne désigne pas une ethnie", "bassins-jardins de lhaor", "réseaux caravaniers d'orun-saï", "réseaux pastoraux et transhumants", "rémanence", "pilier"):
            if token not in text:
                errors.append(f"Document rural incomplet: {token}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "lifeways": len(lifeways),
            "chronology_eras": len(chronology),
            "remanence_examples": len(remanence.get("examples", [])),
        },
    }


def main() -> int:
    report = audit_rural_nomadic_cultures(ROOT)
    out = ROOT / "reports" / "rural-nomadic-cultures-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
