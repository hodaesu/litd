#!/usr/bin/env python3
"""Audit GitHub repository rulesets against the canonical LITD policy."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _active_main_rules(rulesets: Any, branch: str) -> list[dict[str, Any]]:
    if not isinstance(rulesets, list):
        return []
    out: list[dict[str, Any]] = []
    for row in rulesets:
        if not isinstance(row, dict) or row.get("enforcement") != "active":
            continue
        if row.get("target") not in {None, "branch"}:
            continue
        conditions = row.get("conditions")
        cond = conditions.get("ref_name", {}) if isinstance(conditions, dict) else {}
        include = cond.get("include", []) if isinstance(cond, dict) else []
        if include and not any(x in {branch, f"refs/heads/{branch}", "~DEFAULT_BRANCH"} for x in include):
            continue
        out.append(row)
    return out


def audit(policy: dict[str, Any], branch_payload: dict[str, Any], rulesets: Any) -> dict[str, Any]:
    if policy.get("kind") != "LITD_REPOSITORY_GOVERNANCE_POLICY":
        raise ValueError("invalid repository governance policy")
    branch = policy.get("target_branch")
    if not isinstance(branch, str) or not branch:
        raise ValueError("target_branch required")
    required = policy.get("required")
    if not isinstance(required, dict):
        raise ValueError("required policy block missing")

    findings: list[str] = []
    protected = branch_payload.get("protected") is True
    matching = _active_main_rules(rulesets, branch)

    rule_types: set[str] = set()
    contexts: set[str] = set()
    bypass_entries = 0
    conversation_resolution = False
    strict_status_checks = False

    for rs in matching:
        bypass = rs.get("bypass_actors", [])
        if isinstance(bypass, list):
            bypass_entries += len(bypass)
        rules = rs.get("rules", []) if isinstance(rs.get("rules"), list) else []
        for rule in rules:
            if not isinstance(rule, dict):
                continue
            rtype = rule.get("type")
            if isinstance(rtype, str):
                rule_types.add(rtype)
            params = rule.get("parameters", {}) if isinstance(rule.get("parameters"), dict) else {}
            if rtype == "pull_request":
                conversation_resolution = conversation_resolution or params.get("required_review_thread_resolution") is True
            if rtype == "required_status_checks":
                strict_status_checks = strict_status_checks or params.get("strict_required_status_checks_policy") is True
                checks = params.get("required_status_checks", [])
                if isinstance(checks, list):
                    for check in checks:
                        if isinstance(check, dict) and isinstance(check.get("context"), str):
                            contexts.add(check["context"])

    if not matching:
        findings.append("main_has_no_active_ruleset")
    if required.get("pull_request_required") is True and "pull_request" not in rule_types:
        findings.append("pull_request_not_enforced")
    if required.get("direct_push_forbidden") is True and ("pull_request" not in rule_types or bypass_entries):
        findings.append("direct_push_not_fully_forbidden")
    if required.get("force_push_forbidden") is True and "non_fast_forward" not in rule_types:
        findings.append("force_push_not_forbidden")
    if required.get("branch_deletion_forbidden") is True and "deletion" not in rule_types:
        findings.append("branch_deletion_not_forbidden")
    if required.get("require_conversation_resolution") is True and not conversation_resolution:
        findings.append("conversation_resolution_not_required")
    if required.get("require_up_to_date_before_merge") is True and not strict_status_checks:
        findings.append("strict_status_checks_not_required")
    if required.get("bypass_allowed") is False and bypass_entries:
        findings.append("ruleset_bypass_present")

    required_checks = required.get("required_status_checks", [])
    if not isinstance(required_checks, list) or not all(isinstance(x, str) and x for x in required_checks):
        raise ValueError("required_status_checks must be a string list")
    missing = sorted(set(required_checks) - contexts)
    if missing:
        findings.append("missing_required_status_checks:" + ",".join(missing))

    return {
        "kind": "LITD_REPOSITORY_GOVERNANCE_AUDIT",
        "target_branch": branch,
        "protected_branch_flag": protected,
        "matching_active_rulesets": len(matching),
        "rule_types": sorted(rule_types),
        "required_status_contexts_observed": sorted(contexts),
        "conversation_resolution_required_observed": conversation_resolution,
        "strict_status_checks_observed": strict_status_checks,
        "bypass_entries_observed": bypass_entries,
        "status": "COMPLIANT" if not findings else "NON_COMPLIANT",
        "findings": findings,
        "core_write_allowed": False,
        "automatic_policy_change_allowed": False,
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--policy", required=True)
    p.add_argument("--branch-json", required=True)
    p.add_argument("--rulesets-json", required=True)
    p.add_argument("--output", default="reports/repository-governance-audit.json")
    a = p.parse_args()
    policy = json.loads(Path(a.policy).read_text(encoding="utf-8"))
    branch_payload = json.loads(Path(a.branch_json).read_text(encoding="utf-8"))
    rulesets = json.loads(Path(a.rulesets_json).read_text(encoding="utf-8"))
    result = audit(policy, branch_payload, rulesets)
    out = Path(a.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "findings": result["findings"]}, sort_keys=True))
    return 0 if result["status"] == "COMPLIANT" else 2


if __name__ == "__main__":
    raise SystemExit(main())
