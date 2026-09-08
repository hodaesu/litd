#!/usr/bin/env python3
"""Prépare une session locale de premier playtest des Veilleurs sans fabriquer de PASS."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "reports/veilleurs_player_validation_template.json"


def _git_commit(root: Path) -> str:
    run = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    value = run.stdout.strip()
    return value if run.returncode == 0 and value else "UNKNOWN_COMMIT"


def _safe_slug(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9._-]+", "-", value)
    return value.strip("-._") or "tester"


def prepare_session(root: Path, tester_id: str, platform_name: str, device: str) -> Path:
    template = json.loads((root / TEMPLATE.relative_to(ROOT)).read_text(encoding="utf-8"))
    commit = _git_commit(root)
    now = datetime.now(timezone.utc)
    tested_at = now.isoformat()
    session_id = f"{now.strftime('%Y%m%dT%H%M%SZ')}_{commit[:8]}_{_safe_slug(tester_id)}"
    target = root / "local/playtests" / session_id
    target.mkdir(parents=True, exist_ok=False)

    report = template
    report["build_commit"] = commit
    report["tested_at"] = tested_at
    report["testers"] = [tester_id]
    report["notes"] = [
        "Session préparée automatiquement ; aucun gate n'est validé automatiquement.",
        f"Plateforme prévue : {platform_name}",
        f"Appareil/poste : {device}",
    ]
    report_path = target / "player_validation.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    metadata = {
        "session_id": session_id,
        "project": "LITD : Les Veilleurs",
        "chapter": "Chapitre I — Survivre aux Terres de Cendre",
        "build_commit": commit,
        "prepared_at": tested_at,
        "tester_id": tester_id,
        "platform": platform_name,
        "device": device,
        "report": str(report_path.relative_to(root)),
        "status": "PREPARED_NOT_RUN",
    }
    (target / "session.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    notes = f"""# LITD : Les Veilleurs — notes d'observation

Session : `{session_id}`  
Commit : `{commit}`  
Testeur : `{tester_id}`  
Plateforme : `{platform_name}`  
Appareil/poste : `{device}`

## Règle d'observation

Ne pas expliquer l'interface ou la solution pendant une mesure de compréhension, sauf blocage total. Noter d'abord ce que le joueur tente spontanément.

## Chronologie libre

- Première hésitation :
- Première action erronée :
- Premier moment où le joueur verbalise correctement la logique du combat :
- Premier moment de confusion anatomique :
- Première réaction Peur/Folie :
- Premier blocage d'exploration :
- Première conséquence comprise au Sanctuaire :

## Combat — `combat_decision_readability`

- Le joueur sait-il qui agit ?
- Identifie-t-il les cibles possibles ?
- Anticipe-t-il l'effet probable de l'action ?
- Explique-t-il correctement pourquoi le résultat s'est produit ?

## Anatomie — `anatomy_causality`

- Le ciblage anatomique est-il compris comme un choix fonctionnel ?
- Le joueur relie-t-il perte de fonction et conséquence tactique ?

## Peur / Folie — `fear_madness_clarity`

- Le joueur comprend-il la cause du changement ?
- Identifie-t-il un contre-jeu lorsqu'il existe ?

## Boucle Chapitre I

- L'exploration est-elle lisible sans être sur-expliquée ?
- Le retour au Sanctuaire donne-t-il le sentiment que l'expédition a laissé une trace ?

## Fin de session

- Trois choses comprises sans aide :
- Trois confusions principales :
- Action que le joueur pensait possible mais qui ne l'était pas :
- Information qu'il cherchait mais n'a pas trouvée :
- Moment le plus tendu :
- Moment le plus intéressant :
- Moment le plus frustrant :
- Problèmes bloquants ouverts :

Ne remplir `player_validation.json` en `PASS`, `FAIL` ou `BLOCKED` qu'après observation réelle. Le validateur du dépôt contrôle ensuite les preuves requises.
"""
    (target / "observer_notes.md").write_text(notes, encoding="utf-8")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(ROOT))
    parser.add_argument("--tester-id", default="developer-selftest")
    parser.add_argument("--platform", default="windows")
    parser.add_argument("--device", default="PC Windows")
    args = parser.parse_args()

    root = Path(args.repo).resolve()
    target = prepare_session(root, args.tester_id, args.platform, args.device)
    print(f"VEILLEURS_FIRST_PLAYTEST_SESSION_PREPARED={target}")
    print("STATUS=PREPARED_NOT_RUN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
