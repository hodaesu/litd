#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_living_cultures(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/living_cultures.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Atlas structuré des cultures vivantes absent"], "warnings": []}

    data = load(path)
    statuses = set(data.get("status_values", []))
    kinds = set(data.get("culture_kind_values", []))
    channels = set(data.get("continuity_channel_values", []))

    if data.get("universe_id") != "litd_universe":
        errors.append("L'atlas culturel vise un autre univers")
    if data.get("canon_version") != "1.0.0":
        errors.append("L'atlas culturel utilise une version canonique incompatible")
    if data.get("schema_version") != 1:
        errors.append("Version de schéma inattendue pour l'atlas culturel")

    rules = data.get("identity_rules", {})
    required_true_rules = {
        "ethnicity_is_not_culture",
        "city_is_not_ethnicity",
        "religion_is_not_ethnicity",
        "language_is_not_biology",
        "no_intrinsic_stats_from_ethnicity_sex_or_skin_color",
        "populations_are_not_collectively_guilty_for_governments",
    }
    for key in required_true_rules:
        if rules.get(key) is not True:
            errors.append(f"Règle identitaire obligatoire absente ou fausse: {key}")

    language = data.get("language_policy", {})
    if language.get("world_multilingual") is not True:
        errors.append("Le monde doit rester explicitement multilingue")
    if language.get("concorde_single_common_language") != "unconfirmed":
        errors.append("Une langue commune unique de la Concorde ne doit pas être inventée")
    if language.get("named_language_families") != "unconfirmed":
        errors.append("Les familles linguistiques ne sont pas encore verrouillées")

    cultures = data.get("cultures", [])
    ids = [str(item.get("id", "")) for item in cultures]
    if not all(ids) or len(ids) != len(set(ids)):
        errors.append("Identifiants culturels absents ou dupliqués")
    culture_map = {str(item["id"]): item for item in cultures if item.get("id")}

    required_cultures = {
        "culture.concorde_common",
        "culture.jian_lu",
        "culture.sorye",
        "culture.dhor_khal",
        "culture.lhaor",
        "culture.tessen",
        "culture.orun_sai",
        "culture.varkhane",
        "culture.namar",
        "culture.azravel",
        "culture.kor_em",
        "culture.effrie_dragon_tribe",
    }
    missing_cultures = sorted(required_cultures.difference(culture_map))
    if missing_cultures:
        errors.append(f"Cultures canoniques manquantes: {missing_cultures}")

    for culture_id, culture in culture_map.items():
        if culture.get("status") not in statuses:
            errors.append(f"Statut culturel invalide: {culture_id}")
        if culture.get("kind") not in kinds:
            errors.append(f"Type culturel invalide: {culture_id}")
        for source in culture.get("sources", []):
            if not (root / str(source)).is_file():
                errors.append(f"Source absente pour {culture_id}: {source}")
        for channel in culture.get("continuity_channels", []):
            if channel not in channels:
                errors.append(f"Canal de continuité inconnu pour {culture_id}: {channel}")

    concorde = culture_map.get("culture.concorde_common", {})
    relation = str(concorde.get("three_awakenings_relation", "")).lower()
    if "sans constituer une religion" not in relation:
        errors.append("Les Trois Éveils doivent rester explicitement distincts d'une religion")
    if concorde.get("religion") == "single_religion":
        errors.append("La Concorde ne peut pas être réduite à une religion unique")

    jian_lu = culture_map.get("culture.jian_lu", {})
    if "polyglotte" not in str(jian_lu.get("language", "")).lower():
        errors.append("Jian-Lu doit rester explicitement polyglotte")

    orun_sai = culture_map.get("culture.orun_sai", {})
    if "traduction" not in str(orun_sai.get("language", "")).lower():
        errors.append("Orun-Saï doit conserver son rôle de traduction")

    varkhane = culture_map.get("culture.varkhane", {})
    vark_identity = str(varkhane.get("identity", "")).lower()
    if "nombreux peuples" not in vark_identity or "langues" not in vark_identity:
        errors.append("Varkhane doit rester une identité impériale plurielle")

    azravel = culture_map.get("culture.azravel", {})
    az_identity = str(azravel.get("identity", "")).lower()
    if "minorités" not in az_identity or "hétérodoxes" not in az_identity:
        errors.append("Azravel doit conserver sa diversité religieuse interne")

    dragon = culture_map.get("culture.effrie_dragon_tribe", {})
    if dragon.get("name") != "Tribu d'Èffrie liée aux dragons":
        errors.append("Le nom propre de la tribu d'Èffrie ne doit pas être inventé")
    if dragon.get("scope") != "unknown":
        errors.append("Le territoire de la tribu d'Èffrie doit rester inconnu")
    if dragon.get("language") != "unconfirmed":
        errors.append("La langue de la tribu d'Èffrie doit rester non confirmée")
    guardrails = " ".join(str(item).lower() for item in dragon.get("guardrails", []))
    for required in ("aucun pacte ancestral", "aucune ascendance draconique", "aucun lien au voile"):
        if required not in guardrails:
            errors.append(f"Garde-fou draconique absent: {required}")

    ancient = data.get("ancient_heritage_sources", [])
    ancient_ids = [str(item.get("id", "")) for item in ancient]
    if len(ancient_ids) != len(set(ancient_ids)) or not all(ancient_ids):
        errors.append("Identifiants d'héritages antiques absents ou dupliqués")
    for item in ancient:
        direct_desc = item.get("direct_modern_ethnic_descendants")
        if direct_desc not in (None, "unconfirmed"):
            errors.append(f"Descendance ethnique moderne inventée pour {item.get('id')}")
        direct_regime = item.get("direct_legal_or_moral_continuity_to_modern_regimes")
        if direct_regime is True:
            errors.append(f"Continuité juridique ou morale directe inventée pour {item.get('id')}")
        for channel in item.get("survival_channels", []):
            if channel not in channels:
                errors.append(f"Canal antique inconnu pour {item.get('id')}: {channel}")

    migrations = data.get("migration_history", [])
    migration_ids = {str(item.get("id", "")) for item in migrations}
    required_migrations = {
        "migration.last_war_displacements",
        "migration.long_assemblies_mixing",
        "migration.mature_concord_nodes",
        "migration.post_fall_refugees",
    }
    if not required_migrations.issubset(migration_ids):
        errors.append("La chronologie des grands brassages culturels est incomplète")
    for item in migrations:
        if item.get("status") not in statuses:
            errors.append(f"Statut de migration invalide: {item.get('id')}")
        for source in item.get("sources", []):
            if not (root / str(source)).is_file():
                errors.append(f"Source de migration absente pour {item.get('id')}: {source}")

    remanence = data.get("cross_game_remanence", [])
    rem_map = {str(item.get("id", "")): item for item in remanence}
    for required in (
        "remanence.litd2_to_veilleurs.culture",
        "remanence.veilleurs_to_litd1.culture",
        "remanence.dragons_to_litd1",
    ):
        if required not in rem_map:
            errors.append(f"Chaîne de Rémanence culturelle absente: {required}")
    for item in remanence:
        for channel in item.get("channels", []):
            if channel not in channels:
                errors.append(f"Canal de Rémanence inconnu pour {item.get('id')}: {channel}")
    dragon_rem = rem_map.get("remanence.dragons_to_litd1", {})
    if "Aucune extension vers LITD2 ou Les Veilleurs" not in str(dragon_rem.get("guardrail", "")):
        errors.append("Le lien draconique ne doit pas être rétro-projeté vers les jeux antérieurs")

    open_spaces = set(data.get("open_design_spaces", []))
    for required_open in (
        "familles linguistiques",
        "langue ou langues véhiculaires",
        "écoles martiales régionales",
        "écoles artistiques et musicales",
        "religions de la Concorde",
        "cultures rurales et nomades",
        "peuples conscients non humains",
        "nom et histoire détaillée de la tribu d'Èffrie",
    ):
        if required_open not in open_spaces:
            errors.append(f"Espace de conception ouvert perdu: {required_open}")

    pillars = data.get("pillar_validation", {})
    expected_pillars = {
        "P1_character_creation": "pass",
        "P2_systemic_gore": "conditional",
        "P3_philosophy_psychology": "pass",
        "P4_accessible_human_depth": "pass",
        "P5_strong_narrative": "pass",
        "P6_interconnection": "pass",
        "P7_knowledge_remanence": "pass_central",
        "P8_dialogue_staging": "pass",
        "P9_simple_deep_readable_gameplay": "pass",
    }
    if pillars != expected_pillars:
        errors.append("Validation des neuf piliers incomplète ou modifiée")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source générale absente: {source}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "cultures": len(cultures),
            "migrations": len(migrations),
            "ancient_heritages": len(ancient),
            "remanence_chains": len(remanence),
            "open_design_spaces": len(open_spaces),
        },
    }


if __name__ == "__main__":
    report = audit_living_cultures(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
