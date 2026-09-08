#!/usr/bin/env python3
"""Agrège les mesures observées sans décider automatiquement d'un PASS humain."""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/playtest_readiness_contract.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def summarize(pack_dir: Path) -> dict[str, Any]:
    contract = _load(CONTRACT_PATH)
    required_fields = set(contract["measurement"]["required_observation_fields"])
    allowed_scenarios = set(contract["measurement"]["required_scenarios"])
    manifest_path = pack_dir / "PACK_MANIFEST.json"
    if not manifest_path.is_file():
        raise ValueError("PACK_MANIFEST.json manquant")
    manifest = _load(manifest_path)
    pack_commit = str(manifest.get("build_commit", ""))

    totals: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "observations": 0,
            "testers": set(),
            "hesitation_count": 0,
            "help_request_count": 0,
            "coach_intervention_count": 0,
            "misinput_count": 0,
            "blocking_issue_count": 0,
            "player_explanation_count": 0,
        }
    )
    errors: list[str] = []

    for tester_id in manifest.get("testers", []):
        events_path = pack_dir / tester_id / "measurement_events.jsonl"
        if not events_path.is_file():
            errors.append(f"{tester_id}: measurement_events.jsonl manquant")
            continue
        for line_number, raw in enumerate(events_path.read_text(encoding="utf-8").splitlines(), 1):
            if not raw.strip():
                continue
            try:
                event = json.loads(raw)
            except json.JSONDecodeError as exc:
                errors.append(f"{tester_id}:{line_number}: JSON invalide: {exc}")
                continue
            missing = sorted(field for field in required_fields if field not in event)
            if missing:
                errors.append(f"{tester_id}:{line_number}: champs manquants {missing}")
                continue
            if event["tester_id"] != tester_id:
                errors.append(f"{tester_id}:{line_number}: tester_id incohérent")
            if pack_commit and event["build_commit"] != pack_commit:
                errors.append(f"{tester_id}:{line_number}: build_commit incohérent")
            scenario_id = str(event["scenario_id"])
            if scenario_id not in allowed_scenarios:
                errors.append(f"{tester_id}:{line_number}: scénario inconnu {scenario_id}")
                continue
            for field in (
                "hesitation_count",
                "help_request_count",
                "coach_intervention_count",
                "misinput_count",
                "blocking_issue_count",
            ):
                if not isinstance(event[field], int) or event[field] < 0:
                    errors.append(f"{tester_id}:{line_number}: {field} invalide")

            bucket = totals[scenario_id]
            bucket["observations"] += 1
            bucket["testers"].add(tester_id)
            for field in (
                "hesitation_count",
                "help_request_count",
                "coach_intervention_count",
                "misinput_count",
                "blocking_issue_count",
            ):
                if isinstance(event[field], int) and event[field] >= 0:
                    bucket[field] += event[field]
            if str(event.get("player_explanation", "")).strip():
                bucket["player_explanation_count"] += 1

    scenarios: dict[str, Any] = {}
    for scenario_id in contract["measurement"]["required_scenarios"]:
        bucket = totals[scenario_id]
        scenarios[scenario_id] = {
            **{k: v for k, v in bucket.items() if k != "testers"},
            "distinct_testers": len(bucket["testers"]),
        }

    return {
        "schema_version": 1,
        "project": contract["project"],
        "build_commit": pack_commit,
        "pack_validation_status": manifest.get("validation_status", "NOT_RUN"),
        "automatic_human_gate_decision": "FORBIDDEN",
        "scenario_metrics": scenarios,
        "errors": errors,
        "requires_human_review": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_dir", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    payload = summarize(args.pack_dir)
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 1 if payload["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
