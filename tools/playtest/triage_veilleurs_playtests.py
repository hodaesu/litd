#!/usr/bin/env python3
"""Triage les observations de playtest sans décider d'un gate humain.

Le script transforme les métriques brutes des cinq sessions en une file de
revue : scénarios à traiter d'abord, hypothèses de correction pertinentes et
systèmes de maturité concernés. Il n'écrit jamais dans le registre de maturité
et n'émet jamais de PASS/FAIL automatique.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.playtest.summarize_naive_playtests import summarize

ROOT = Path(__file__).resolve().parents[2]
READINESS_PATH = ROOT / "data/veilleurs/playtest_readiness_contract.json"
MATURITY_PATH = ROOT / "data/veilleurs/system_maturity_registry.json"

SCENARIO_TO_SYSTEM = {
    "combat_decision_readability": "combat_core",
    "anatomy_causality": "anatomy_combat",
    "fear_madness_clarity": "psychology_combat",
    "exploration_route_clarity": "chapter_one_loop",
    "sanctuary_consequence_loop": "chapter_one_loop",
    "first_session_onboarding": "chapter_one_loop",
}

SCENARIO_TO_FIX_IDS = {
    "combat_decision_readability": ["target_feedback", "action_consequence_preview"],
    "anatomy_causality": ["target_feedback", "action_consequence_preview"],
    "fear_madness_clarity": ["cause_effect_feedback"],
    "exploration_route_clarity": ["route_affordance"],
    "sanctuary_consequence_loop": ["sanctuary_persistence_feedback"],
    "first_session_onboarding": [],
}


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _priority(metrics: dict[str, Any]) -> tuple[str, list[str]]:
    """Classe l'urgence de revue, jamais la réussite du gate."""
    reasons: list[str] = []
    if metrics.get("blocking_issue_count", 0) > 0:
        reasons.append("problème bloquant observé")
        return "P0", reasons

    signals = (
        ("coach_intervention_count", "intervention du modérateur"),
        ("misinput_count", "erreur de saisie / cible"),
        ("help_request_count", "demande d'aide"),
        ("hesitation_count", "hésitation"),
    )
    for key, label in signals:
        value = metrics.get(key, 0)
        if isinstance(value, int) and value > 0:
            reasons.append(f"{label}: {value}")
    if reasons:
        return "P1", reasons

    observations = metrics.get("observations", 0)
    explanations = metrics.get("player_explanation_count", 0)
    if observations > 0 and explanations < observations:
        reasons.append("explication joueur manquante sur une ou plusieurs observations")
        return "P2", reasons

    if observations == 0:
        reasons.append("aucune observation")
        return "P2", reasons

    reasons.append("aucun signal quantitatif de friction détecté; revue humaine requise")
    return "P3", reasons


def build_triage(pack_dir: Path) -> dict[str, Any]:
    readiness = _load(READINESS_PATH)
    maturity = _load(MATURITY_PATH)
    summary = summarize(pack_dir)

    fixes = {
        item["id"]: item
        for item in readiness.get("probable_fix_hypotheses", [])
        if isinstance(item, dict) and item.get("id")
    }
    systems = {
        item["id"]: item
        for item in maturity.get("systems", [])
        if isinstance(item, dict) and item.get("id")
    }

    minimum_testers = int(readiness["rules"]["minimum_naive_testers"])
    queue: list[dict[str, Any]] = []
    per_system: dict[str, dict[str, Any]] = {}

    for scenario_id in readiness["measurement"]["required_scenarios"]:
        metrics = dict(summary["scenario_metrics"].get(scenario_id, {}))
        priority, reasons = _priority(metrics)
        system_id = SCENARIO_TO_SYSTEM.get(scenario_id)
        fix_ids = SCENARIO_TO_FIX_IDS.get(scenario_id, [])
        candidate_fixes = []
        for fix_id in fix_ids:
            fix = fixes.get(fix_id)
            if fix:
                candidate_fixes.append(
                    {
                        "id": fix_id,
                        "trigger": fix.get("trigger", ""),
                        "candidate_fix": fix.get("candidate_fix", ""),
                        "apply_before_evidence": bool(fix.get("apply_before_evidence", False)),
                    }
                )

        distinct = int(metrics.get("distinct_testers", 0) or 0)
        dataset_complete_for_review = (
            not summary["errors"]
            and distinct >= minimum_testers
            and int(metrics.get("observations", 0) or 0) >= minimum_testers
        )
        entry = {
            "scenario_id": scenario_id,
            "system_id": system_id,
            "priority": priority,
            "priority_reasons": reasons,
            "metrics": metrics,
            "candidate_fixes": candidate_fixes,
            "dataset_complete_for_review": dataset_complete_for_review,
            "automatic_gate_decision": "FORBIDDEN",
            "human_review_required": True,
        }
        queue.append(entry)

        if system_id:
            bucket = per_system.setdefault(
                system_id,
                {
                    "label": systems.get(system_id, {}).get("label_fr", system_id),
                    "current_stage": systems.get(system_id, {}).get("current_stage"),
                    "next_gate": systems.get(system_id, {}).get("next_gate"),
                    "scenario_ids": [],
                    "highest_priority": "P3",
                    "dataset_complete_for_review": True,
                    "automatic_transition": "FORBIDDEN",
                    "transition_review": "NOT_READY",
                },
            )
            bucket["scenario_ids"].append(scenario_id)
            bucket["dataset_complete_for_review"] = (
                bucket["dataset_complete_for_review"] and dataset_complete_for_review
            )
            if int(priority[1]) < int(bucket["highest_priority"][1]):
                bucket["highest_priority"] = priority

    for system_id, bucket in per_system.items():
        next_gate = bucket.get("next_gate")
        matching = [q for q in queue if q["scenario_id"] == next_gate]
        if matching and matching[0]["dataset_complete_for_review"]:
            bucket["transition_review"] = "HUMAN_REVIEW_REQUIRED"
        else:
            bucket["transition_review"] = "NOT_READY"

    priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    queue.sort(key=lambda item: (priority_order[item["priority"]], item["scenario_id"]))

    return {
        "schema_version": 1,
        "project": readiness["project"],
        "purpose": "post_playtest_triage",
        "build_commit": summary.get("build_commit", ""),
        "source_pack_validation_status": summary.get("pack_validation_status", "NOT_RUN"),
        "automatic_human_gate_decision": "FORBIDDEN",
        "automatic_maturity_transition": "FORBIDDEN",
        "requires_human_review": True,
        "data_errors": list(summary.get("errors", [])),
        "priority_queue": queue,
        "systems": per_system,
        "rules": {
            "priority_is_not_gate_status": True,
            "candidate_fix_is_not_approval": True,
            "registry_write_allowed": False,
            "minimum_naive_testers_for_dataset_review": minimum_testers,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Triage post-playtest Les Veilleurs")
    parser.add_argument("pack_dir", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    payload = build_triage(args.pack_dir)
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 1 if payload["data_errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
