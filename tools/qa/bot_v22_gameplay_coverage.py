#!/usr/bin/env python3
"""Bot v22: gameplay-situation coverage aggregator.

Combines the presence and contents of upstream reports to show which gameplay domains are
actually exercised. It intentionally reports gaps instead of pretending code coverage equals
gameplay coverage.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORT_DIR = Path("reports")
OUT = REPORT_DIR / "player-bot-v22-gameplay-coverage.json"

DOMAIN_SOURCES = {
    "expedition": ["player-bot-autotest.json", "player-bot-v6-real-campaign.json"],
    "combat": ["player-bot-v2-autotest.json", "player-bot-v3-build-matrix.json", "player-bot-v4-factorial-matrix.json"],
    "campaign": ["player-bot-v5-longitudinal-campaign.json", "player-bot-v6-real-campaign.json", "player-bot-v21-longhaul-campaign.json"],
    "economy": ["player-bot-v7-sanctuary-economy.json", "player-bot-v19-economy-stress.json", "player-bot-v21-longhaul-campaign.json"],
    "save_load": ["player-bot-v9-save-integrity.json"],
    "ui": ["player-bot-v10-sanctuary-ui-smoke.json"],
    "tactical_invariants": ["player-bot-v11-tactical-property-fuzzer.json", "player-bot-v12-regression-replay.json"],
    "skill_usage": ["player-bot-v18-skill-usage-coverage.json"],
    "player_profiles": ["player-bot-v20-player-profiles.json"],
    "exploits": ["player-bot-v24-exploit-hunter.json"],
    "stateful_chaos": ["player-bot-v25-stateful-chaos.json"],
}


def read_json(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    domains: dict[str, Any] = {}
    uncovered: list[str] = []
    degraded: list[str] = []
    for domain, filenames in DOMAIN_SOURCES.items():
        sources = []
        observed = False
        for filename in filenames:
            report = read_json(REPORT_DIR / filename)
            if report is None:
                sources.append({"file": filename, "available": False})
                continue
            observed = True
            sources.append({
                "file": filename,
                "available": True,
                "status": report.get("status", "unknown"),
                "method": report.get("method"),
            })
        status = "covered" if observed else "uncovered"
        if observed and all(s.get("status") in {"skipped", "unknown", None} for s in sources if s.get("available")):
            status = "degraded"
        domains[domain] = {"status": status, "sources": sources}
        if status == "uncovered":
            uncovered.append(domain)
        elif status == "degraded":
            degraded.append(domain)

    total = len(domains)
    covered = sum(1 for d in domains.values() if d["status"] == "covered")
    coverage_ratio = covered / total if total else 0.0
    findings: list[dict[str, Any]] = []
    if coverage_ratio < 0.70:
        findings.append({"code": "gameplay_coverage_low", "severity": "high", "coverage_ratio": round(coverage_ratio, 4)})
    if uncovered:
        findings.append({"code": "uncovered_domains", "severity": "medium", "domains": uncovered})
    if degraded:
        findings.append({"code": "degraded_domains", "severity": "low", "domains": degraded})

    status = "failed" if any(f["severity"] == "high" for f in findings) else "passed"
    OUT.write_text(json.dumps({
        "bot": "v22",
        "status": status,
        "method": "cross-suite gameplay-domain coverage aggregation",
        "coverage_ratio": round(coverage_ratio, 4),
        "covered_domains": covered,
        "total_domains": total,
        "domains": domains,
        "findings": findings,
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"PLAYER_BOT_V22_{status.upper()} coverage={covered}/{total}")
    return 1 if status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
