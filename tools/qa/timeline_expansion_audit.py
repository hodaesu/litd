#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_timeline_expansion(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    timeline_path = root / "universe/lore/timeline_master.json"
    canon_path = root / "universe/lore/canon_registry.json"
    if not timeline_path.is_file() or not canon_path.is_file():
        return {"ok": False, "errors": ["Chronologie maîtresse ou registre canonique absent"], "warnings": []}

    master = load(timeline_path)
    canon = load(canon_path)
    certainty_values = set(master.get("certainty_values", []))
    status_values = set(master.get("canon_status_values", []))
    anchors = {str(item.get("id")) for item in canon.get("timeline", [])}
    characters = {str(item.get("id")): item for item in master.get("characters", [])}
    events = {str(item.get("id")): item for item in master.get("events", [])}

    if master.get("schema_version", 0) < 2:
        errors.append("La chronologie détaillée doit utiliser schema_version >= 2")

    def check_collection(name: str) -> dict[str, dict[str, Any]]:
        items = master.get(name, [])
        ids = [str(item.get("id", "")) for item in items]
        if not all(ids) or len(ids) != len(set(ids)):
            errors.append(f"Identifiants absents ou dupliqués dans {name}")
        result = {str(item["id"]): item for item in items if item.get("id")}
        for item in items:
            item_id = str(item.get("id", "<sans-id>"))
            certainty = item.get("certainty")
            if certainty is not None and certainty not in certainty_values:
                errors.append(f"Niveau de certitude invalide dans {name}: {item_id} -> {certainty}")
            if item.get("canon_status") not in status_values:
                errors.append(f"Statut canonique invalide dans {name}: {item_id}")
            for source in item.get("sources", []):
                if not (root / str(source)).is_file():
                    errors.append(f"Source absente dans {name} pour {item_id}: {source}")
        return result

    civilizations = check_collection("civilizations")
    institutions = check_collection("institutions")
    sites = check_collection("sites")
    threads = check_collection("knowledge_threads")

    for civ_id, civ in civilizations.items():
        start = civ.get("start_year")
        end = civ.get("end_year")
        if not isinstance(start, (int, float)) or not isinstance(end, (int, float)):
            errors.append(f"Période numérique absente pour {civ_id}")
        elif start >= end:
            errors.append(f"Période inversée pour {civ_id}: {start} >= {end}")
        elif end >= 0:
            errors.append(f"Civilisation ancienne non antérieure à la Chute: {civ_id}")

    expected_ranges = {
        "civilization.ashai_nhal": (-4450, -3520),
        "civilization.or_silex": (-3260, -2470),
        "civilization.watchers_saan": (-2910, -1980),
        "civilization.vaor_khal": (-2870, -2010),
        "civilization.lyr_mar": (-2680, -1760),
        "civilization.sahm_ir": (-2440, -1510),
        "civilization.ydris": (-2190, -1280),
    }
    for civ_id, expected in expected_ranges.items():
        civ = civilizations.get(civ_id)
        if civ is None:
            errors.append(f"Civilisation canonique absente: {civ_id}")
        elif (civ.get("start_year"), civ.get("end_year")) != expected:
            errors.append(f"Dates désynchronisées pour {civ_id}: attendu {expected}")

    for site_id, site in sites.items():
        origin = site.get("origin_civilization")
        if origin and str(origin) not in civilizations:
            errors.append(f"Site {site_id} référence une civilisation inconnue: {origin}")

    for institution_id, institution in institutions.items():
        for key in ("timeline_anchor", "emergence_after", "explicit_convergence_anchor", "mature_anchor", "start_after", "mature_before_or_at"):
            value = institution.get(key)
            if value is not None and str(value) not in anchors:
                errors.append(f"Institution {institution_id} référence une ancre inconnue via {key}: {value}")

    for thread_id, thread in threads.items():
        linked_character = thread.get("linked_character")
        if linked_character and str(linked_character) not in characters:
            errors.append(f"Fil {thread_id} référence un personnage inconnu: {linked_character}")
        for event_id in thread.get("sequence", []):
            if str(event_id) not in events:
                errors.append(f"Fil {thread_id} référence un événement inconnu: {event_id}")

    seven = events.get("litd1.seven.formation")
    if seven is None:
        errors.append("Événement de formation des Sept absent")
    else:
        known = seven.get("known_formation_positions")
        expected = {"2": "hero.anouk", "5": "hero.effrie"}
        if known != expected:
            errors.append(f"Positions connues des Sept incorrectes: {known!r}")
        if seven.get("complete_formation_order") != "unconfirmed":
            errors.append("L'ordre complet des Sept ne doit pas être inventé")
        if "formation_order" in seven:
            errors.append("L'ancien ordre complet extrapolé des Sept ne doit plus être présent")

    anouk = characters.get("hero.anouk", {})
    effrie = characters.get("hero.effrie", {})
    if anouk.get("formation_position") != 2 or anouk.get("signature_magic") != "La Trame":
        errors.append("Anouk doit rester 2e des Sept et sa magie doit rester La Trame")
    if effrie.get("formation_position") != 5:
        errors.append("Èffrie doit rester 5e des Sept")
    if "dragon" not in str(effrie.get("dragon_link", "")):
        errors.append("Le lien draconique confirmé d'Èffrie est absent")

    trame = threads.get("thread.anouk_trame", {})
    if trame.get("origin_period") != "unknown" or trame.get("certainty") != "unknown":
        errors.append("L'origine historique de la Trame doit rester inconnue")

    dragons = threads.get("thread.effrie_dragon_heritage", {})
    if dragons.get("origin_period") != "before_litd1_formation_undated":
        errors.append("L'héritage draconique d'Èffrie doit rester non daté au-delà de son antériorité à sa formation")

    remanence = threads.get("thread.litd2_remanence_vestige", {})
    if remanence.get("origin_civilization") is not None:
        errors.append("La civilisation d'origine du Vestige de LITD2 doit rester inconnue")
    if remanence.get("origin_period") != "ancient_unknown":
        errors.append("La période d'origine du Vestige doit rester anciennement indéterminée")

    sanctuary = institutions.get("institution.first_sanctuaries", {})
    if sanctuary.get("start_after") != "event.night_of_sarn":
        errors.append("Les premiers Sanctuaires de mémoire doivent rester postérieurs à Sarn")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "civilizations": len(civilizations),
            "institutions": len(institutions),
            "sites": len(sites),
            "knowledge_threads": len(threads),
        },
    }


if __name__ == "__main__":
    report = audit_timeline_expansion(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
