#!/usr/bin/env python3
"""Prépare cinq sessions naïves sans fabriquer de résultat humain."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/playtest_readiness_contract.json"
REPORT_TEMPLATE_PATH = ROOT / "reports/veilleurs_player_validation_template.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _git_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def _observer_sheet(tester_id: str, commit: str, scenarios: list[str]) -> str:
    scenario_lines = "\n".join(f"- [ ] {scenario}" for scenario in scenarios)
    return f"""# LITD : Les Veilleurs — observation testeur naïf {tester_id}

Build commit : `{commit or 'A_COMPLETER'}`

## Règles observateur

- Ne pas expliquer où cliquer tant qu'il n'y a pas blocage total.
- Ne pas suggérer la stratégie attendue.
- Noter le premier geste, les hésitations, demandes d'aide et erreurs de saisie.
- Toute intervention orale est comptée comme `coach_intervention_count`.
- Aucun PASS/FAIL n'est présaisi dans cette fiche.

## Scénarios à couvrir

{scenario_lines}

## Mesures à relever par scénario

- first_action :
- hesitation_count : 0
- help_request_count : 0
- coach_intervention_count : 0
- misinput_count : 0
- blocking_issue_count : 0
- player_explanation :
- observer_notes :

## Questions de fin de session

1. Quel était selon toi ton objectif immédiat ?
2. Comment savais-tu quelle compétence et quelle cible choisir ?
3. À quoi servait le ciblage anatomique ?
4. Qu'est-ce qui a provoqué les changements de Peur/Folie que tu as remarqués ?
5. Qu'est-ce qui a changé au Sanctuaire à cause de l'expédition ?
6. Quel élément t'a le plus fait hésiter ?
"""


def prepare_pack(output_dir: Path, count: int, build_commit: str) -> Path:
    contract = _load(CONTRACT_PATH)
    minimum = int(contract["rules"]["minimum_naive_testers"])
    if count < minimum:
        raise ValueError(f"count={count} inférieur au minimum naïf {minimum}")

    template = _load(REPORT_TEMPLATE_PATH)
    scenarios = list(contract["measurement"]["required_scenarios"])
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest = {
        "schema_version": 1,
        "project": contract["project"],
        "purpose": "naive_player_validation_pack",
        "build_commit": build_commit,
        "validation_status": "NOT_RUN",
        "testers": [],
    }

    for index in range(1, count + 1):
        tester_id = f"naive-{index:02d}"
        session_dir = output_dir / tester_id
        session_dir.mkdir(parents=True, exist_ok=True)

        report = json.loads(json.dumps(template))
        report["build_commit"] = build_commit
        report["tested_at"] = ""
        report["testers"] = [tester_id]
        report["notes"] = ["Session préparée uniquement ; aucun résultat humain saisi."]
        for gate in report.get("gates", []):
            gate["status"] = "NOT_RUN"
            gate["evidence"] = []

        (session_dir / "player_validation.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        (session_dir / "observer_notes.md").write_text(
            _observer_sheet(tester_id, build_commit, scenarios), encoding="utf-8"
        )
        (session_dir / "measurement_events.jsonl").write_text("", encoding="utf-8")
        (session_dir / "session_manifest.json").write_text(
            json.dumps(
                {
                    "tester_id": tester_id,
                    "prior_litd_experience": False,
                    "build_commit": build_commit,
                    "status": "NOT_RUN",
                    "required_scenarios": scenarios,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        manifest["testers"].append(tester_id)

    (output_dir / "PACK_MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return output_dir


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "local/playtests/naive-pack")
    parser.add_argument("--count", type=int, default=5)
    parser.add_argument("--build-commit", default="")
    args = parser.parse_args()
    commit = args.build_commit or _git_commit()
    output = prepare_pack(args.output_dir, args.count, commit)
    print(f"VEILLEURS_NAIVE_TESTER_PACK_OK path={output} count={args.count} commit={commit}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
