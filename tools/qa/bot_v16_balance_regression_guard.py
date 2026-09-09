from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORTS = Path("reports")
BASELINE = Path("data/qa/balance_regression_baseline.json")
OUT = REPORTS / "player-bot-v16-balance-regression-guard.json"


def load(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def metric(report: dict[str, Any], *path: str, default: Any = 0) -> Any:
    value: Any = report
    for key in path:
        if not isinstance(value, dict) or key not in value:
            return default
        value = value[key]
    return value


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    baseline = load(BASELINE)
    thresholds = baseline.get("thresholds", {}) if isinstance(baseline, dict) else {}

    v4 = load(REPORTS / "player-bot-v4-factorial-matrix.json")
    v6 = load(REPORTS / "player-bot-v6-real-campaign.json")
    v7 = load(REPORTS / "player-bot-v7-sanctuary-economy.json")
    v11 = load(REPORTS / "player-bot-v11-tactical-property-fuzzer.json")

    regressions: list[dict[str, Any]] = []
    observations: dict[str, Any] = {}

    companion = metric(v4, "summary", "companion", default={})
    if isinstance(companion, dict):
        with_rate = float(metric(companion, "with", "win_rate", default=0.0))
        without_rate = float(metric(companion, "without", "win_rate", default=0.0))
        gap = abs(with_rate - without_rate)
        observations["v4_companion_win_rate_gap"] = gap
        limit = float(thresholds.get("v4_companion_win_rate_gap_max", 0.30))
        if gap > limit:
            regressions.append({"code": "companion_win_rate_gap", "value": gap, "limit": limit})

    alerts = v4.get("alerts", []) if isinstance(v4.get("alerts", []), list) else []
    max_factor_gap = 0.0
    for alert in alerts:
        if isinstance(alert, dict) and alert.get("code") == "factor_gap":
            max_factor_gap = max(max_factor_gap, float(alert.get("gap", 0.0)))
    observations["v4_max_factor_gap"] = max_factor_gap
    factor_limit = float(thresholds.get("v4_factor_gap_max", 0.35))
    if max_factor_gap > factor_limit:
        regressions.append({"code": "factor_gap", "value": max_factor_gap, "limit": factor_limit})

    campaigns = v6.get("campaigns", []) if isinstance(v6.get("campaigns", []), list) else []
    v6_victories = sum(int(row.get("victories", 0)) for row in campaigns if isinstance(row, dict))
    observations["v6_victories"] = v6_victories
    min_victories = int(thresholds.get("v6_min_victories_for_economy_checks", 3))
    if v6 and v6_victories < min_victories:
        regressions.append({"code": "v6_insufficient_victories", "value": v6_victories, "minimum": min_victories})

    v7_cycles = int(v7.get("campaign_cycles", v7.get("cycles", 0))) if v7 else 0
    v7_failures = v7.get("failures", []) if isinstance(v7.get("failures", []), list) else []
    observations["v7_cycles"] = v7_cycles
    observations["v7_failures"] = len(v7_failures)
    if v7:
        min_cycles = int(thresholds.get("v7_min_cycles", 250))
        max_failures = int(thresholds.get("v7_max_failures", 0))
        if v7_cycles < min_cycles:
            regressions.append({"code": "v7_coverage_drop", "value": v7_cycles, "minimum": min_cycles})
        if len(v7_failures) > max_failures:
            regressions.append({"code": "v7_failures", "value": len(v7_failures), "maximum": max_failures})

    v11_checks = int(v11.get("property_checks", 0)) if v11 else 0
    v11_failures = v11.get("failures", []) if isinstance(v11.get("failures", []), list) else []
    observations["v11_property_checks"] = v11_checks
    observations["v11_failures"] = len(v11_failures)
    if v11:
        min_checks = int(thresholds.get("v11_min_property_checks", 15000))
        max_failures = int(thresholds.get("v11_max_failures", 0))
        if v11_checks < min_checks:
            regressions.append({"code": "v11_coverage_drop", "value": v11_checks, "minimum": min_checks})
        if len(v11_failures) > max_failures:
            regressions.append({"code": "v11_property_failures", "value": len(v11_failures), "maximum": max_failures})

    missing = [name for name, report in (("v4", v4), ("v6", v6), ("v7", v7), ("v11", v11)) if not report]
    report = {
        "schema_version": 16,
        "suite": "player_bot_v16_balance_regression_guard",
        "observations": observations,
        "regressions": regressions,
        "missing_reports": missing,
        "status": "passed" if not regressions else "failed",
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PLAYER_BOT_V16 status={report['status']} regressions={len(regressions)} missing={missing}")
    return 0 if not regressions else 1


if __name__ == "__main__":
    raise SystemExit(main())
