#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_world_geography(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    path = root / "universe/lore/world_geography.json"
    if not path.is_file():
        return {"ok": False, "errors": ["Géographie maîtresse absente"], "warnings": []}

    data = load(path)
    if data.get("universe_id") != "litd_universe":
        errors.append("La géographie vise un autre univers")
    if data.get("schema_version") != 1:
        errors.append("Version de schéma géographique inattendue")
    if data.get("status") != "core_topology_locked_metric_cartography_open":
        errors.append("Le statut doit distinguer topologie canonique et cartographie métrique ouverte")

    rules = data.get("cartographic_rules", {})
    required_true = (
        "map_is_historical_source",
        "two_authentic_maps_may_conflict",
        "map_must_carry_period_or_provenance",
    )
    required_false = (
        "single_eternal_political_map",
        "political_border_is_geological_truth",
        "city_is_single_language",
        "region_is_ethnicity",
        "civilization_is_biological_homeland",
        "exact_coordinates_locked",
        "exact_distances_locked",
        "final_coastline_locked",
        "post_fall_external_world_complete_map_known",
    )
    for key in required_true:
        if rules.get(key) is not True:
            errors.append(f"Règle géographique obligatoire absente ou fausse: {key}")
    for key in required_false:
        if rules.get(key) is not False:
            errors.append(f"Garde-fou cartographique violé: {key}")

    cities = data.get("concorde_geography", {}).get("six_reference_cities", [])
    expected_cities = {"jian_lu", "sorye", "dhor_khal", "lhaor", "tessen", "orun_sai"}
    city_ids = {str(item.get("id", "")) for item in cities}
    if city_ids != expected_cities:
        errors.append("La géographie doit couvrir exactement les six grandes cités de référence")
    for city in cities:
        if city.get("exact_coordinates") is not None:
            errors.append(f"Coordonnées inventées avant cartographie artistique: {city.get('id')}")
        if not city.get("built_form") or not city.get("major_flows"):
            errors.append(f"Ville insuffisamment ancrée géographiquement: {city.get('id')}")

    war = data.get("last_war_geography", {})
    powers = {str(item.get("id", "")) for item in war.get("political_spaces", [])}
    expected_powers = {
        "last_war.azravel", "last_war.erhal", "last_war.kharad",
        "last_war.sarn", "last_war.namar", "last_war.odran",
    }
    if powers != expected_powers:
        errors.append("Les six puissances de la Dernière Guerre ne sont pas toutes présentes")
    corridor = war.get("battle_corridor", [])
    if len(corridor) != 8:
        errors.append("Les huit lieux de bataille de la Dernière Guerre doivent être ancrés")
    if [int(item.get("order", 0)) for item in corridor] != list(range(1, 9)):
        errors.append("L'ordre géographique des huit batailles a été perdu")

    ancient = data.get("ancient_geography", {})
    anchors = {str(item.get("id", "")) for item in ancient.get("known_anchors", [])}
    for required in ("fond_de_nhal", "reseau_des_seuils", "noeud_de_saan", "dhal", "var_silem", "esh"):
        if required not in anchors:
            errors.append(f"Ancre antique ou Grande Fermeture absente: {required}")

    rec = data.get("external_geography_reconciliation", {})
    records = {str(item.get("name", "")): item for item in rec.get("records", [])}
    for name in ("Varkhane", "Kor-Em", "Namar", "Azravel"):
        if name not in records:
            errors.append(f"Registre extérieur non réconcilié: {name}")
    for name in ("Namar", "Azravel"):
        if records.get(name, {}).get("continuity_status") != "requires_dedicated_lineage_reconciliation":
            errors.append(f"La continuité historique de {name} a été inventée au lieu d'être signalée")

    post = data.get("post_fall_geography", {})
    if post.get("external_world_map") != "unknown_by_design":
        errors.append("La carte complète du monde extérieur post-Chute doit rester inconnue")
    if int(post.get("litd1_campaign_center", -1)) != 24:
        errors.append("Le centre chronologique de LITD1 doit rester vers +24")

    maps = data.get("map_history", [])
    map_ids = {str(item.get("id", "")) for item in maps}
    for required in (
        "closure_red_maps", "three_maps_war", "last_war_operational_maps",
        "concorde_passage_maps", "project_threshold_network_maps", "post_fall_recovery_maps",
    ):
        if required not in map_ids:
            errors.append(f"Couche cartographique historique absente: {required}")

    gameplay = data.get("gameplay_translation", {})
    for key in ("map_is_never_omniscient", "player_can_compare_map_layers", "local_knowledge_can_correct_archive", "geography_can_be_knowledge_remanence_source"):
        if gameplay.get(key) is not True:
            errors.append(f"Traduction gameplay géographique absente: {key}")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source géographique absente: {source}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "cities": len(cities),
            "war_battle_locations": len(corridor),
            "ancient_anchors": len(anchors),
            "map_layers": len(maps),
            "open_cartography_fields": len(data.get("open_cartography", [])),
        },
    }


if __name__ == "__main__":
    report = audit_world_geography(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
