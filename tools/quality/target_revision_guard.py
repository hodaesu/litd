#!/usr/bin/env python3
"""Guard LITD canonical target revisions from self-serving implementation changes.

A Pull Request that changes canonical design rules must be a governance-only
change. It cannot also change gameplay/runtime implementation. Target revision
proposals are evidence-bearing governance documents; they never authorize a
direct Core write.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Iterable

TARGET_FILES = {
    "docs/knowledge/design-targets.json",
    "docs/knowledge/guardian-rules.yml",
    "data/roguelike/balance_targets.json",
    "data/roguelike/balance_matrix.json",
    "data/roguelike/roguelike_rules.json",
}

IMPLEMENTATION_PREFIXES = (
    "scripts/",
    "scenes/",
    "data/characters/",
    "data/enemies/",
    "data/items/",
    "data/equipment/",
    "data/skills/",
    "addons/",
    "project.godot",
)

PROPOSAL_PREFIX = "docs/knowledge/decisions/target-revisions/"
ALLOWED_DECISION = "PROPOSE_TARGET_REVISION"
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def _is_target_file(path: str) -> bool:
    return path in TARGET_FILES


def _is_implementation_file(path: str) -> bool:
    return any(path == prefix or path.startswith(prefix) for prefix in IMPLEMENTATION_PREFIXES)


def _is_proposal_file(path: str) -> bool:
    return path.startswith(PROPOSAL_PREFIX) and path.endswith(".json") and not path.endswith(".example.json")


def classify_changed_paths(paths: Iterable[str]) -> dict[str, list[str]]:
    normalized = sorted({str(path).strip() for path in paths if str(path).strip()})
    return {
        "targets": [path for path in normalized if _is_target_file(path)],
        "implementation": [path for path in normalized if _is_implementation_file(path)],
        "proposals": [path for path in normalized if _is_proposal_file(path)],
        "all": normalized,
    }


def validate_target_revision_proposal(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if payload.get("kind") != "LITD_TARGET_REVISION_PROPOSAL":
        errors.append("invalid_kind")
    if payload.get("decision") != ALLOWED_DECISION:
        errors.append("invalid_decision")
    if payload.get("core_write_allowed") is not False:
        errors.append("direct_core_write_forbidden")

    target_ids = payload.get("target_ids")
    if not isinstance(target_ids, list) or not target_ids or not all(isinstance(x, str) and x.strip() for x in target_ids):
        errors.append("target_ids_required")

    evidence = payload.get("evidence_refs")
    if not isinstance(evidence, list) or not evidence or not all(isinstance(x, str) and x.strip() for x in evidence):
        errors.append("evidence_refs_required")

    rationale = payload.get("rationale")
    if not isinstance(rationale, str) or len(rationale.strip()) < 40:
        errors.append("rationale_too_short")

    candidate_hash = payload.get("candidate_hash")
    if candidate_hash is not None and (not isinstance(candidate_hash, str) or not HEX64.fullmatch(candidate_hash)):
        errors.append("invalid_candidate_hash")

    old_values = payload.get("old_values")
    new_values = payload.get("new_values")
    if not isinstance(old_values, dict) or not old_values:
        errors.append("old_values_required")
    if not isinstance(new_values, dict) or not new_values:
        errors.append("new_values_required")
    if isinstance(old_values, dict) and isinstance(new_values, dict) and old_values == new_values:
        errors.append("no_effective_revision")

    return errors


def evaluate_revision_change(paths: Iterable[str], proposals: list[dict[str, Any]]) -> dict[str, Any]:
    classified = classify_changed_paths(paths)
    target_change = bool(classified["targets"])
    implementation_change = bool(classified["implementation"])

    reasons: list[str] = []
    if target_change and implementation_change:
        reasons.append("target_and_implementation_must_be_separate_prs")
    if target_change and not classified["proposals"]:
        reasons.append("target_revision_proposal_required")
    if target_change and len(classified["proposals"]) != len(proposals):
        reasons.append("proposal_files_not_loaded")

    proposal_errors: list[dict[str, Any]] = []
    for index, proposal in enumerate(proposals):
        errors = validate_target_revision_proposal(proposal)
        if errors:
            proposal_errors.append({"index": index, "errors": errors})

    if proposal_errors:
        reasons.append("invalid_target_revision_proposal")

    return {
        "kind": "LITD_TARGET_REVISION_GUARD",
        "status": "BLOCK" if reasons else "PASS",
        "target_change": target_change,
        "implementation_change": implementation_change,
        "targets": classified["targets"],
        "implementation": classified["implementation"],
        "proposal_files": classified["proposals"],
        "proposal_errors": proposal_errors,
        "reasons": reasons,
        "core_write_allowed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Guard canonical LITD target revisions")
    parser.add_argument("--changed-files", type=Path, required=True)
    parser.add_argument("--proposal", action="append", type=Path, default=[])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    paths = [line.strip() for line in args.changed_files.read_text(encoding="utf-8").splitlines() if line.strip()]
    proposals = [json.loads(path.read_text(encoding="utf-8")) for path in args.proposal]
    result = evaluate_revision_change(paths, proposals)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "reasons": result["reasons"]}, sort_keys=True))
    return 1 if result["status"] == "BLOCK" else 0


if __name__ == "__main__":
    raise SystemExit(main())
