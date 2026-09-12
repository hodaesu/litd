#!/usr/bin/env python3
"""Audit GitHub repository protection against the canonical LITD policy."""
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
        if not isinstance(row, dict) or row.get("enforcement") not in {"active", "evaluate"}:
            continue
        target = row.get("target")
        if target not in {None, "branch"}:
            continue
        cond = row.get("conditions", {}).get("ref_name", {}) if isinstance(row.get("conditions"), dict) else {}
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
    for rs in matching:
        bypass = rs.get("bypass_actors", [])
        if isinstance(bypass, list):
            bypass_entries += len(bypass)
        for rule in rs.get("rules", []) if isinstance(rs.get("rules"), list) else []:
            if not isinstance(rule, dict):
                continue
            rtype = rule.get("type")
            if isinstance(rtype, str):
                rule_types.add(rtype)
            if rtype == "required_status_checks":
                params = rule.get("parameters", {})
                checks = params.get("required_status_checks", []) if isinstance(params, dict) else []
                for check in checks:
                    if isinstance(check, dict) and isinstance(check.get("context"), str):
                        contexts.add(check["context"])

    if required.get("pull_request_required") is True and not (protected or "pull_request" in rule_types):
        findings.append("pull_request_not_enforced")
    if required.get("force_push_forbidden") is True and matching and "non_fast_forward" not in rule_types:
        findings.append("force_push_not_forbidden")
    if required.get("branch_deletion_forbidden") is True and matching and "deletion" not in rule_types:
        findings.append("branch_deletion_not_forbidden")
    if required.get("bypass_allowed") is False and bypass_entries:
        findings.append("ruleset_bypass_present")

    required_checks = required.get("required_status_checks", [])
    if isinstance(required_checks, list):
        if matching:
            missing = sorted(set(required_checks) - contexts)
            if missing:
                findings.append("missing_required_status_checks:" + ",".join(missing))
        elif not protected:
            findings.append("required_status_checks_not_enforced")

    compliant = not findings and (protected or bool(matching))
    if not protected and not matching:
        findings.append("main_has_no_server_side_protection")
        compliant = False

    return {
        "kind": "LITD_REPOSITORY_GOVERNANCE_AUDIT",
        "target_branch": branch,
        "protected_branch_flag": protected,
        "matching_rulesets": len(matching),
        "rule_types": sorted(rule_types),
        "required_status_contexts_observed": sorted(contexts),
        "status": "COMPLIANT" if compliant else "NON_COMPLIANT",
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
    policy = json.loads(Path(a.policy).read_text())
    branch_payload = json.loads(Path(a.branch_json).read_text())
    rulesets = json.loads(Path(a.rulesets_json).read_text())
    result = audit(policy, branch_payload, rulesets)
    out = Path(a.output); out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "findings": result["findings"]}, sort_keys=True))
    return 0 if result["status"] == "COMPLIANT" else 2


if __name__ == "__main__":
    raise SystemExit(main())
