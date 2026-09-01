#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit(root: Path) -> dict[str, Any]:
    base = root / "universe/lore"
    errors: list[str] = []
    warnings: list[str] = []
    canon_path = base / "canon_registry.json"
    projects_path = base / "projects.json"
    timeline_path = base / "timeline_master.json"
    if not canon_path.is_file() or not projects_path.is_file():
        return {"ok": False, "errors": ["Registre canonique ou registre des projets absent"], "warnings": [], "summary": {}}

    canon = load(canon_path)
    registry = load(projects_path)
    universe_id = canon.get("universe_id")
    canon_version = canon.get("canon_version")
    if registry.get("universe_id") != universe_id:
        errors.append("Le registre des projets vise un autre univers")

    facts = canon.get("facts", [])
    fact_ids = [str(item.get("id", "")) for item in facts]
    if not all(fact_ids) or len(fact_ids) != len(set(fact_ids)):
        errors.append("Les identifiants de faits canoniques sont absents ou dupliqués")
    fact_map = {str(item["id"]): item for item in facts if item.get("id")}
    allowed_statuses = {"fixed", "open", "perspective"}
    for fact in facts:
        if fact.get("status") not in allowed_statuses:
            errors.append(f"Statut canonique invalide : {fact.get('id')}")
        for source in fact.get("sources", []):
            if not (root / source).is_file():
                errors.append(f"Source canonique absente pour {fact.get('id')} : {source}")

    timeline = canon.get("timeline", [])
    anchor_ids = [str(item.get("id", "")) for item in timeline]
    anchor_orders = [int(item.get("order", -1)) for item in timeline]
    anchors = {str(item.get("id", "")): int(item.get("order", -1)) for item in timeline}
    if not all(anchor_ids) or len(anchor_ids) != len(set(anchor_ids)):
        errors.append("Les ancres temporelles sont absentes ou dupliquées")
    if len(anchor_orders) != len(set(anchor_orders)):
        errors.append("Deux ancres temporelles utilisent le même ordre")

    projects = registry.get("projects", [])
    project_ids = [str(item.get("id", "")) for item in projects]
    if not all(project_ids) or len(project_ids) != len(set(project_ids)):
        errors.append("Les identifiants de projets sont absents ou dupliqués")
    project_id_set = set(project_ids)

    claim_ids: set[str] = set()
    entity_ids: set[str] = set()
    event_ids: set[str] = set()
    contribution_count = 0
    for project in projects:
        project_id = str(project.get("id", ""))
        if project.get("canon_version") != canon_version:
            errors.append(f"{project_id} ne cible pas la version canonique {canon_version}")
        manifests = project.get("contributions", [])
        if project.get("status") == "active" and not manifests:
            errors.append(f"Le projet actif {project_id} ne déclare aucune contribution")
        for relative in manifests:
            path = root / str(relative)
            if not path.is_file():
                errors.append(f"Manifeste absent pour {project_id} : {relative}")
                continue
            contribution_count += 1
            manifest = load(path)
            if manifest.get("universe_id") != universe_id:
                errors.append(f"{relative} vise un autre univers")
            if manifest.get("project_id") != project_id:
                errors.append(f"{relative} appartient à {manifest.get('project_id')} au lieu de {project_id}")
            if manifest.get("canon_version") != canon_version:
                errors.append(f"{relative} utilise une version canonique incompatible")
            for source in manifest.get("sources", []):
                if not (root / source).is_file():
                    errors.append(f"Source narrative absente dans {relative} : {source}")
            for claim in manifest.get("claims", []):
                claim_id = str(claim.get("id", ""))
                if not claim_id or claim_id in claim_ids:
                    errors.append(f"Claim absente ou dupliquée : {claim_id or '<vide>'}")
                claim_ids.add(claim_id)
                fact_id = str(claim.get("fact_id", ""))
                fact = fact_map.get(fact_id)
                if fact is None:
                    errors.append(f"{claim_id} référence un fait inconnu : {fact_id}")
                    continue
                operation = str(claim.get("operation", ""))
                allowed = set(fact.get("allowed_operations", ["affirm"]))
                if fact.get("status") == "fixed":
                    allowed = {"affirm"}
                if operation not in allowed:
                    errors.append(f"{claim_id} utilise l'opération interdite {operation} sur {fact_id}")
                if operation == "affirm" and claim.get("value") != fact.get("value"):
                    errors.append(f"Contradiction : {claim_id} ne respecte pas la valeur de {fact_id}")
            for entity in manifest.get("entities", []):
                entity_id = str(entity.get("id", ""))
                if not entity_id or entity_id in entity_ids:
                    errors.append(f"Entité absente ou dupliquée : {entity_id or '<vide>'}")
                entity_ids.add(entity_id)
            for event in manifest.get("events", []):
                event_id = str(event.get("id", ""))
                if not event_id or event_id in event_ids:
                    errors.append(f"Événement absent ou dupliqué : {event_id or '<vide>'}")
                event_ids.add(event_id)
                anchor = str(event.get("timeline_anchor", ""))
                if anchor not in anchors:
                    errors.append(f"{event_id} utilise une ancre temporelle inconnue : {anchor}")
                    continue
                for before in event.get("before", []):
                    if before not in anchors:
                        errors.append(f"{event_id} référence une borne future inconnue : {before}")
                    elif anchors[anchor] >= anchors[before]:
                        errors.append(f"Chronologie impossible : {event_id} doit précéder {before}")
                for after in event.get("after", []):
                    if after not in anchors:
                        errors.append(f"{event_id} référence une borne passée inconnue : {after}")
                    elif anchors[anchor] <= anchors[after]:
                        errors.append(f"Chronologie impossible : {event_id} doit suivre {after}")

    master_event_count = 0
    master_character_count = 0
    if not timeline_path.is_file():
        errors.append("Chronologie maîtresse absente : universe/lore/timeline_master.json")
    else:
        master = load(timeline_path)
        if master.get("universe_id") != universe_id:
            errors.append("La chronologie maîtresse vise un autre univers")
        if master.get("canon_version") != canon_version:
            errors.append("La chronologie maîtresse utilise une version canonique incompatible")

        certainty_values = set(master.get("certainty_values", []))
        canon_status_values = set(master.get("canon_status_values", []))
        required_certainties = {"locked", "approximate", "relative_only", "unknown"}
        required_timeline_statuses = {"canon", "working_canon", "branched", "deprecated"}
        if certainty_values != required_certainties:
            errors.append("La chronologie maîtresse ne déclare pas exactement les niveaux de certitude attendus")
        if canon_status_values != required_timeline_statuses:
            errors.append("La chronologie maîtresse ne déclare pas exactement les statuts canoniques attendus")

        origin = master.get("time_origin", {})
        if origin.get("anchor") != "event.fall" or origin.get("relative_year") != 0:
            errors.append("La Chute doit rester l'an 0 de la chronologie maîtresse")

        characters = master.get("characters", [])
        master_character_count = len(characters)
        character_ids = [str(item.get("id", "")) for item in characters]
        if not all(character_ids) or len(character_ids) != len(set(character_ids)):
            errors.append("Les personnages de la chronologie maîtresse sont absents ou dupliqués")
        character_map = {str(item["id"]): item for item in characters if item.get("id")}
        for character in characters:
            character_id = str(character.get("id", ""))
            if character.get("canon_status") not in canon_status_values:
                errors.append(f"Statut temporel invalide pour {character_id}")
            earliest = str(character.get("earliest_anchor", ""))
            latest = str(character.get("latest_anchor", ""))
            if earliest and earliest not in anchors:
                errors.append(f"{character_id} utilise une première ancre inconnue : {earliest}")
            if latest and latest not in anchors:
                errors.append(f"{character_id} utilise une dernière ancre inconnue : {latest}")
            if earliest in anchors and latest in anchors and anchors[earliest] > anchors[latest]:
                errors.append(f"Fenêtre temporelle impossible pour {character_id}")

        master_events = master.get("events", [])
        master_event_count = len(master_events)
        master_event_ids = [str(item.get("id", "")) for item in master_events]
        if not all(master_event_ids) or len(master_event_ids) != len(set(master_event_ids)):
            errors.append("Les événements de la chronologie maîtresse sont absents ou dupliqués")
        master_event_map = {str(item["id"]): item for item in master_events if item.get("id")}

        required_event_fields = {
            "id", "label", "era", "relative_year", "relative_label", "certainty",
            "timeline_anchor", "sources", "game", "characters", "remanence_links", "canon_status"
        }
        dated_events: list[tuple[int, float, str]] = []
        for event in master_events:
            event_id = str(event.get("id", ""))
            missing = sorted(required_event_fields.difference(event.keys()))
            if missing:
                errors.append(f"{event_id or '<événement>'} manque des champs : {', '.join(missing)}")
                continue
            anchor = str(event.get("timeline_anchor", ""))
            if anchor not in anchors:
                errors.append(f"{event_id} utilise une ancre maîtresse inconnue : {anchor}")
                anchor_order = None
            else:
                anchor_order = anchors[anchor]
            if event.get("certainty") not in certainty_values:
                errors.append(f"Niveau de certitude invalide pour {event_id}")
            if event.get("canon_status") not in canon_status_values:
                errors.append(f"Statut canonique temporel invalide pour {event_id}")
            relative_year = event.get("relative_year")
            if relative_year is not None and not isinstance(relative_year, (int, float)):
                errors.append(f"Année relative invalide pour {event_id}")
            elif relative_year is not None and anchor_order is not None:
                dated_events.append((anchor_order, float(relative_year), event_id))
            for source in event.get("sources", []):
                if not (root / str(source)).is_file():
                    errors.append(f"Source temporelle absente pour {event_id} : {source}")
            for game_id in event.get("game", []):
                if game_id != "shared" and game_id not in project_id_set:
                    errors.append(f"{event_id} référence un jeu inconnu : {game_id}")
            for character_id in event.get("characters", []):
                character = character_map.get(str(character_id))
                if character is None:
                    errors.append(f"{event_id} référence un personnage inconnu : {character_id}")
                    continue
                earliest = str(character.get("earliest_anchor", ""))
                if anchor_order is not None and earliest in anchors and anchor_order < anchors[earliest]:
                    errors.append(
                        f"Conflit personnage/chronologie : {character_id} apparaît dans {event_id} "
                        f"avant sa première ancre autorisée {earliest}"
                    )
                latest = str(character.get("latest_anchor", ""))
                if anchor_order is not None and latest in anchors and anchor_order > anchors[latest]:
                    warnings.append(
                        f"Fenêtre tardive à confirmer : {character_id} apparaît dans {event_id} "
                        f"après {latest}"
                    )
            for linked_event in event.get("remanence_links", []):
                if str(linked_event) not in master_event_map:
                    errors.append(f"{event_id} possède une Rémanence vers un événement inconnu : {linked_event}")
            formation_order = event.get("formation_order")
            if formation_order is not None:
                formation_ids = [str(item) for item in formation_order]
                if len(formation_ids) != len(set(formation_ids)):
                    errors.append(f"Ordre de formation dupliqué dans {event_id}")
                unknown = [item for item in formation_ids if item not in character_map]
                if unknown:
                    errors.append(f"Ordre de formation de {event_id} contient des personnages inconnus : {unknown}")

        dated_events.sort()
        for previous, current in zip(dated_events, dated_events[1:]):
            previous_order, previous_year, previous_id = previous
            current_order, current_year, current_id = current
            if current_order > previous_order and current_year < previous_year:
                errors.append(
                    f"Dates absolues incohérentes : {current_id} ({current_year:g}) "
                    f"est placé après {previous_id} ({previous_year:g})"
                )

        fall = master_event_map.get("history.fall")
        if fall is None or fall.get("relative_year") != 0 or fall.get("timeline_anchor") != "event.fall":
            errors.append("L'événement history.fall doit matérialiser la Chute à l'an 0")

        veilleurs = master_event_map.get("veilleurs.campaign")
        if veilleurs:
            if veilleurs.get("characters"):
                warnings.append("Les identités des quatre protagonistes de Les Veilleurs ne sont pas verrouillées : ne pas les renseigner encore")
            if anchors.get(str(veilleurs.get("timeline_anchor")), -1) >= anchors.get("era.late_concord", 10**9):
                errors.append("Les Veilleurs doit rester antérieur aux derniers temps de la Concorde")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "canon_version": canon_version,
            "facts": len(facts),
            "projects": len(projects),
            "contributions": contribution_count,
            "claims": len(claim_ids),
            "entities": len(entity_ids),
            "events": len(event_ids),
            "master_timeline_events": master_event_count,
            "master_timeline_characters": master_character_count,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Vérifie la continuité entre les jeux de LITD Universe")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = audit(args.root.resolve())
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
