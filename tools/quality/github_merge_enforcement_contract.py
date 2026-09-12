#!/usr/bin/env python3
"""Fail-closed audit of GitHub-side merge enforcement for LITD main.

The in-repository MERGE_EXECUTION contract is not sufficient by itself: GitHub
must also refuse merges that do not pass the required Merge Execution Gate.
This module evaluates a live branch snapshot plus detailed repository rulesets.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

EXPECTED_BRANCH = "main"
EXPECTED_REF = "refs/heads/main"
EXPECTED_CHECK = "Merge Execution Gate"
REQUIRED_RULE_TYPES = {"pull_request", "required_status_checks", "deletion", "non_fast_forward"}


def _targets_main(ruleset: dict[str, Any]) -> bool:
    if ruleset.get("target") != "branch" or ruleset.get("enforcement") != "active":
        return False
    ref = ruleset.get("conditions", {}).get("ref_name", {})
    include = ref.get("include", [])
    exclude = ref.get("exclude", [])
    if not isinstance(include, list) or not isinstance(exclude, list):
        return False
    included = EXPECTED_REF in include or "~DEFAULT_BRANCH" in include or "~ALL" in include
    excluded = EXPECTED_REF in exclude or "~DEFAULT_BRANCH" in exclude
    return included and not excluded


def _status_check_blockers(rule: dict[str, Any]) -> list[str]:
    blockers: list[str] = []
    params = rule.get("parameters", {})
    checks = params.get("required_status_checks", [])
    present = isinstance(checks, list) and any(
        isinstance(item, dict) and item.get("context") == EXPECTED_CHECK for item in checks
    )
    if not present:
        blockers.append("merge_execution_gate_not_required")
    # The required checks must be evaluated against the latest base. Otherwise a
    # MERGE_EXECUTION receipt can be valid for an observed base that has since moved.
    if params.get("strict_required_status_checks_policy") is not True:
        blockers.append("required_checks_not_strict_to_latest_base")
    return blockers


def _strict_ruleset(ruleset: dict[str, Any]) -> tuple[bool, list[str]]:
    blockers: list[str] = []
    bypass = ruleset.get("bypass_actors", [])
    if bypass not in ([], None):
        blockers.append("ruleset_has_bypass_actors")

    rules = ruleset.get("rules", [])
    if not isinstance(rules, list):
        return False, blockers + ["ruleset_rules_invalid"]
    by_type = {rule.get("type"): rule for rule in rules if isinstance(rule, dict)}
    missing = sorted(REQUIRED_RULE_TYPES - set(by_type))
    if missing:
        blockers.extend(f"missing_rule:{rule_type}" for rule_type in missing)
    status_rule = by_type.get("required_status_checks")
    if status_rule is not None:
        blockers.extend(_status_check_blockers(status_rule))
    return not blockers, blockers


def evaluate(branch: dict[str, Any], rulesets: list[dict[str, Any]]) -> dict[str, Any]:
    blockers: list[str] = []
    if branch.get("name") != EXPECTED_BRANCH:
        blockers.append("wrong_branch_snapshot")
    if branch.get("protected") is not True:
        blockers.append("main_not_protected")

    matching = [ruleset for ruleset in rulesets if isinstance(ruleset, dict) and _targets_main(ruleset)]
    if not matching:
        blockers.append("no_active_main_ruleset")
        strict_match = None
        ruleset_diagnostics: list[dict[str, Any]] = []
    else:
        strict_match = None
        ruleset_diagnostics = []
        for ruleset in matching:
            ok, reasons = _strict_ruleset(ruleset)
            ruleset_diagnostics.append({
                "id": ruleset.get("id"),
                "name": ruleset.get("name"),
                "strict": ok,
                "blockers": reasons,
            })
            if ok and strict_match is None:
                strict_match = ruleset
        if strict_match is None:
            blockers.append("no_ruleset_enforces_merge_execution_gate_without_bypass")

    verified = not blockers
    return {
        "kind": "LITD_GITHUB_MERGE_ENFORCEMENT_AUDIT",
        "repository": "hodaesu/litd",
        "branch": EXPECTED_BRANCH,
        "required_check": EXPECTED_CHECK,
        "strict_latest_base_required": True,
        "status": "EXTERNAL_MERGE_ENFORCEMENT_VERIFIED" if verified else "EXTERNAL_MERGE_ENFORCEMENT_BLOCKED",
        "external_merge_enforcement_verified": verified,
        "blockers": blockers,
        "matching_rulesets": ruleset_diagnostics,
        "required_rule_types": sorted(REQUIRED_RULE_TYPES),
        "authority": "audit_only_no_repository_settings_mutation",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", required=True)
    parser.add_argument("--rulesets", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()
    branch = json.loads(Path(args.branch).read_text(encoding="utf-8"))
    rulesets = json.loads(Path(args.rulesets).read_text(encoding="utf-8"))
    if not isinstance(branch, dict):
        raise ValueError("branch snapshot must be an object")
    if not isinstance(rulesets, list):
        raise ValueError("rulesets snapshot must be a list")
    result = evaluate(branch, rulesets)
    rendered = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["external_merge_enforcement_verified"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
