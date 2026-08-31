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
    anchors = {str(item.get("id", "")): int(item.get("order", -1)) for item in timeline}
    if "" in anchors or len(anchors) != len(timeline):
        errors.append("Les ancres temporelles sont absentes ou dupliquées")

    projects = registry.get("projects", [])
    project_ids = [str(item.get("id", "")) for item in projects]
    if not all(project_ids) or len(project_ids) != len(set(project_ids)):
        errors.append("Les identifiants de projets sont absents ou dupliqués")

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
