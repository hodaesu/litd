from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORTS = Path("reports")
OUT = REPORTS / "player-bot-v14-failure-triage.json"

RULES = {
    "targeting": ["target", "range", "rank", "position", "no_progress", "softlock"],
    "save": ["save", "load", "snapshot", "checksum", "identity"],
    "economy": ["gold", "essence", "market", "recruit", "economy", "reserve"],
    "ui": ["ui", "screen", "sanctuary", "tavern", "market_screen"],
    "campaign": ["expedition", "extract", "room", "campaign", "progression", "xp"],
    "companion": ["companion", "creature"],
}


def load_json(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else None
    except Exception:
        return None


def flatten_issue(value: Any) -> str:
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    except Exception:
        return repr(value)


def classify(text: str) -> str:
    low = text.lower()
    best = "unknown"
    best_score = 0
    for domain, words in RULES.items():
        score = sum(1 for word in words if word in low)
        if score > best_score:
            best = domain
            best_score = score
    return best


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    files = sorted(REPORTS.glob("player-bot-v*.json"))
    findings: list[dict[str, Any]] = []
    by_domain: dict[str, int] = {}
    unreadable: list[str] = []

    for path in files:
        report = load_json(path)
        if report is None:
            unreadable.append(path.name)
            continue
        suite = str(report.get("suite", path.stem))
        issues: list[Any] = []
        for key in ("failures", "alerts", "regressions"):
            value = report.get(key, [])
            if isinstance(value, list):
                issues.extend(value)
        if str(report.get("status", "")).lower() == "failed" and not issues:
            issues.append({"code": "suite_failed_without_structured_issue"})
        for issue in issues:
            text = flatten_issue(issue)
            domain = classify(text)
            by_domain[domain] = by_domain.get(domain, 0) + 1
            findings.append({
                "suite": suite,
                "source": path.name,
                "domain": domain,
                "issue": issue,
            })

    priority = sorted(by_domain.items(), key=lambda item: (-item[1], item[0]))
    report = {
        "schema_version": 14,
        "suite": "player_bot_v14_failure_triage",
        "reports_scanned": len(files),
        "findings": findings,
        "by_domain": by_domain,
        "priority": [{"domain": key, "count": count} for key, count in priority],
        "unreadable_reports": unreadable,
        "status": "passed" if not unreadable else "failed",
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PLAYER_BOT_V14_OK reports={len(files)} findings={len(findings)} priority={priority[:3]}")
    return 0 if not unreadable else 1


if __name__ == "__main__":
    raise SystemExit(main())
