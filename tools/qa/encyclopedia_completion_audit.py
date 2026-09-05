#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_encyclopedia(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    base = root / "universe/lore"
    paths = {
        "geography": base / "world_geography.json",
        "language": base / "language_atlas.json",
        "culture": base / "concorde_cultural_atlas.json",
        "bestiary": base / "historical_bestiary.json",
        "biographies": base / "legendary_seven_biographies.json",
        "manifest": base / "encyclopedia_completion_manifest.json",
    }
    for key, path in paths.items():
        if not path.is_file():
            errors.append(f"Fichier encyclopédique absent: {key} -> {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    language = load(paths["language"])
    culture = load(paths["culture"])
    bestiary = load(paths["bestiary"])
    bios = load(paths["biographies"])
    manifest = load(paths["manifest"])
    geography = load(paths["geography"])

    for label, data in (("language", language), ("culture", culture), ("bestiary", bestiary), ("biographies", bios), ("manifest", manifest)):
        if data.get("universe_id") != "litd_universe":
            errors.append(f"{label}: mauvais univers")
        if data.get("canon_version") != "1.0.0":
            errors.append(f"{label}: version canonique incompatible")
        if data.get("schema_version") != 1:
            errors.append(f"{label}: version de schéma inattendue")

    # Langues: assez concrètes pour la production, sans essentialisme ni fausse filiation antique.
    families = language.get("families", [])
    languages = language.get("regional_languages", [])
    scripts = language.get("writing_systems", [])
    registers = language.get("professional_registers", [])
    drift = language.get("semantic_drift", [])
    translation_errors = language.get("translation_error_patterns", [])
    if len(families) < 5:
        errors.append("Atlas linguistique: moins de cinq familles de catalogue")
    if len(languages) < 12:
        errors.append("Atlas linguistique: couverture régionale insuffisante")
    if len(scripts) < 8 or len(registers) < 8:
        errors.append("Atlas linguistique: écritures ou registres professionnels insuffisants")
    if len(drift) < 8 or len(translation_errors) < 8:
        errors.append("Atlas linguistique: Rémanence sémantique insuffisante")
    if language.get("naming_policy", {}).get("effrie_tribe_language") != "unconfirmed":
        errors.append("La langue de la tribu d'Èffrie a été inventée")
    if language.get("core_rules", {}).get("city_can_be_multilingual") is not True:
        errors.append("Une ville doit pouvoir rester multilingue")
    ancient = language.get("ancient_documents", [])
    for item in ancient:
        if item.get("direct_modern_ancestor") != "unconfirmed":
            errors.append(f"Filiation antique inventée: {item.get('tradition')}")

    # Culture: pluralité religieuse, six villes, six écoles parentes et dix-huit lignées.
    guard = culture.get("guardrails", {})
    if guard.get("three_awakenings_are_religion") is not False:
        errors.append("Les Trois Éveils ont été transformés en religion")
    if guard.get("religious_metaphysics_are_fact_by_default") is not False:
        errors.append("Une théologie a été transformée en fait métaphysique")
    religions = culture.get("religious_traditions", [])
    if len(religions) < 6:
        errors.append("Atlas culturel: pluralité religieuse insuffisante")
    for item in religions:
        if item.get("metaphysical_truth") != "unconfirmed":
            errors.append(f"Religion présentée comme vérité métaphysique: {item.get('id')}")
    lineages = culture.get("martial_lineages", [])
    expected_parents = {
        "martial.jian_lu.three_supports",
        "martial.sorye.body_measure",
        "martial.dhor_khal.forge_anchor",
        "martial.lhaor.flexible_branch",
        "martial.tessen.open_circles",
        "martial.orun_sai.long_step",
    }
    lineage_parents = {str(item.get("parent", "")) for item in lineages}
    if len(lineages) != 18 or lineage_parents != expected_parents:
        errors.append("Les dix-huit lignées ne couvrent pas exactement les six écoles régionales")
    cities = culture.get("cities", [])
    city_ids = {str(item.get("id", "")) for item in cities}
    expected_cities = {"jian_lu", "sorye", "dhor_khal", "lhaor", "tessen", "orun_sai"}
    if city_ids != expected_cities:
        errors.append("Les six cités de référence ne sont pas toutes détaillées")
    geography_cities = {
        str(item.get("id", ""))
        for item in geography.get("concorde_geography", {}).get("six_reference_cities", [])
    }
    if geography_cities != expected_cities:
        errors.append("L'atlas culturel diverge de la géographie maîtresse")
    if len(culture.get("artistic_traditions", [])) < 12:
        errors.append("Traditions artistiques régionales insuffisantes")
    if len(culture.get("historical_figures", [])) < 12:
        errors.append("Personnages historiques secondaires insuffisants")
    if len(culture.get("material_culture", [])) != 6:
        errors.append("La culture matérielle doit couvrir les six régions de référence")
    if len(culture.get("calendars_and_festivals", {}).get("regional_festivals", [])) != 6:
        errors.append("Les six fêtes régionales de référence sont incomplètes")
    if culture.get("calendars_and_festivals", {}).get("archival_dating", {}).get("is_religious_calendar") is not False:
        errors.append("La datation de Concordance ne doit pas devenir calendrier religieux")

    # Bestiaire: origine explicitement incertaine quand elle l'est et dragons protégés.
    entries = bestiary.get("entries", [])
    if len(entries) < 14:
        errors.append("Bestiaire historique V1 trop court")
    bestiary_ids = {str(item.get("id", "")) for item in entries}
    for required in ("species.dragon", "species.stone_watcher", "enemy.hungry_ghoul", "enemy.oni", "enemy.jorogumo", "phenomenon.manifestation_destructive"):
        if required not in bestiary_ids:
            errors.append(f"Entrée de bestiaire obligatoire absente: {required}")
    dragon = next((item for item in entries if item.get("id") == "species.dragon"), {})
    dragon_guard = set(dragon.get("guardrails", []))
    for required in ("pas de langue draconique confirmée", "pas de Pacte confirmé", "pas d'ascendance draconique confirmée", "pas de lien au Voile confirmé"):
        if required not in dragon_guard:
            errors.append(f"Garde-fou dragon absent: {required}")
    manifestations = next((item for item in entries if item.get("id") == "phenomenon.manifestation_destructive"), {})
    if manifestations.get("consciousness") != "unknown_by_design":
        errors.append("La conscience commune des Manifestations a été inventée")

    # Sept: exactement sept, bon ordre, pas de destin ou d'origine d'Èffrie inventés.
    expected_order = ["hero.zeje", "hero.anouk", "hero.marec", "hero.mathilde", "hero.effrie", "hero.aurelien", "hero.lya"]
    if bios.get("formation_order") != expected_order:
        errors.append("Ordre de formation des Sept modifié")
    heroes = bios.get("heroes", [])
    if len(heroes) != 7 or [item.get("id") for item in sorted(heroes, key=lambda x: int(x.get("formation_rank", 99)))] != expected_order:
        errors.append("Les biographies ne couvrent pas exactement les Sept dans l'ordre canonique")
    effrie = next((item for item in heroes if item.get("id") == "hero.effrie"), {})
    unknown_origin = set(effrie.get("unknown_origin", []))
    for fragment in ("langue", "théologie", "Pacte éventuel", "ascendance draconique", "lien au Voile"):
        if fragment not in unknown_origin:
            errors.append(f"Inconnue d'Èffrie perdue: {fragment}")
    for hero in heroes:
        if hero.get("fate_after_campaign") != "open":
            errors.append(f"Destin post-campagne inventé: {hero.get('id')}")

    # Manifeste: demande utilisateur couverte et inconnues préservées.
    requested = manifest.get("requested_domains", [])
    if len(requested) < 18 or not all(str(item.get("status", "")).startswith("complete_v1") for item in requested):
        errors.append("Le manifeste ne marque pas toutes les passes encyclopédiques comme complètes V1")
    if manifest.get("encyclopedia_v1_complete") is not True:
        errors.append("L'encyclopédie V1 n'est pas déclarée complète")
    open_items = " ".join(str(v) for v in manifest.get("intentionally_open_after_v1", []))
    for token in ("Èffrie", "métaphysiques", "communication non humains", "coordonnées"):
        if token not in open_items:
            errors.append(f"Le manifeste ne protège plus une inconnue majeure: {token}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "language_families": len(families),
            "regional_languages": len(languages),
            "religious_traditions": len(religions),
            "martial_lineages": len(lineages),
            "cities": len(cities),
            "bestiary_entries": len(entries),
            "legendary_biographies": len(heroes),
            "requested_domains": len(requested),
        },
    }


if __name__ == "__main__":
    report = audit_encyclopedia(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
