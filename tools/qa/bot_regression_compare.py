from __future__ import annotations

import json
from pathlib import Path

BASELINE = Path("data/qa/regression_baseline.json")
REPORT_DIR = Path("reports")
OUTPUT = REPORT_DIR / "player-bot-v13-regression-baseline.json"


def _failure_count(payload: dict) -> int:
    value = payload.get("failures", [])
    if isinstance(value, list):
        return len(value)
    if isinstance(value, int):
        return value
    return 0


def main() -> int:
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    failures: list[str] = []
    rows: list[dict] = []

    for filename, rules in baseline.get("sentinels", {}).items():
        path = REPORT_DIR / filename
        if not path.exists():
            failures.append(f"missing_report:{filename}")
            rows.append({"report": filename, "status": "missing"})
            continue
        payload = json.loads(path.read_text(encoding="utf-8"))
        failure_count = _failure_count(payload)
        cases = int(payload.get("cases", payload.get("campaign_cycles", payload.get("runs", 0) if isinstance(payload.get("runs", 0), int) else 0)))
        row = {
            "report": filename,
            "status": payload.get("status", "unknown"),
            "failures": failure_count,
            "cases": cases,
        }
        max_failures = int(rules.get("max_failures", 0))
        if failure_count > max_failures:
            failures.append(f"failure_regression:{filename}:{failure_count}>{max_failures}")
        if "min_cases" in rules and cases < int(rules["min_cases"]):
            failures.append(f"coverage_regression:{filename}:{cases}<{int(rules['min_cases'])}")
        rows.append(row)

    report = {
        "schema_version": 13,
        "suite": "player_bot_v13_regression_baseline",
        "baseline": str(BASELINE),
        "rows": rows,
        "failures": failures,
        "status": "passed" if not failures else "failed",
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if failures:
        for failure in failures:
            print(f"PLAYER_BOT_V13: {failure}")
        return 1
    print(f"PLAYER_BOT_V13_OK reports={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
