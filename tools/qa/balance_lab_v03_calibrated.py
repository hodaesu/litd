from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Any

from tools.qa import balance_lab_v03 as base

MODEL_VERSION = "0.3-synthetic-calibrated"


def _injury(
    rng: random.Random,
    damage: float,
    target: base.Actor,
    metrics: base.RunMetrics,
    bonus: float = 0.0,
) -> None:
    """Calibrated injury resolver for the easy SIM_001 reference encounter."""
    ratio = damage / max(20.0, target.max_hp * 0.30)
    roll = rng.random() + bonus
    severity = None
    if ratio > 1.45 and roll > 1.20:
        severity = "critical"
    elif ratio > 1.10 and roll > 1.14:
        severity = "severe"
    elif ratio > 0.82 and roll > 1.06:
        severity = "moderate"
    elif ratio > 0.48 and roll > 0.94:
        severity = "light"
    if severity:
        target.injuries.append(severity)
        metrics.injuries[severity] += 1
        if severity == "critical" and rng.random() < 0.015:
            metrics.injuries["mutilation"] += 1
        if severity in {"moderate", "severe", "critical"} and rng.random() < 0.42:
            target.bleed = min(3, target.bleed + (2 if severity == "critical" else 1))


def _add_injury_guardrails(report: dict[str, Any]) -> None:
    targets = report["targets"]
    injuries = report["body"]["injuries_per_run"]
    checks = (
        ("light_injuries_per_combat", float(injuries.get("light", 0.0)), "medium"),
        ("moderate_injuries_per_combat", float(injuries.get("moderate", 0.0)), "medium"),
        ("severe_injuries_per_combat", float(injuries.get("severe", 0.0)), "high"),
        ("critical_injuries_per_combat", float(injuries.get("critical", 0.0)), "high"),
    )
    for code, value, severity in checks:
        low, high = [float(x) for x in targets[code]]
        if not low <= value <= high:
            report["alerts"].append(
                {
                    "severity": severity,
                    "code": code,
                    "detail": f"{value:.4f} outside [{low:.4f},{high:.4f}]",
                }
            )
    report["ok"] = not any(a["severity"] == "high" for a in report["alerts"])


def _write_markdown(report: dict[str, Any], path: Path) -> None:
    injuries = report["body"]["injuries_per_run"]
    out = [
        "# LITD BalanceLab v0.3 — SIM_001",
        "",
        f"- Runs: **{report['runs']}**",
        f"- Seed: **{report['seed']}**",
        f"- Hero win rate: **{report['outcomes']['hero_win_rate']:.2%}**",
        f"- Average rounds: **{report['rounds']['mean']:.2f}**",
        f"- Hit rate: **{report['combat']['hit_rate']:.2%}**",
        f"- Hero death rate / slot: **{report['outcomes']['hero_death_rate_per_slot']:.2%}**",
        f"- Light injuries / combat: **{injuries.get('light', 0):.3f}**",
        f"- Moderate injuries / combat: **{injuries.get('moderate', 0):.3f}**",
        f"- Severe injuries / combat: **{injuries.get('severe', 0):.3f}**",
        f"- Critical injuries / combat: **{injuries.get('critical', 0):.3f}**",
        f"- Mutilations / combat: **{injuries.get('mutilation', 0):.4f}**",
        "",
        "## Alerts",
        "",
    ]
    if report["alerts"]:
        for alert in report["alerts"]:
            out.append(
                f"- **{alert['severity'].upper()}** `{alert['code']}` — {alert['detail']}"
            )
    else:
        out.append("- None")
    out += [
        "",
        "> Measured synthetic pre-Godot contract model. Godot runtime validation and human playtests remain required.",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="LITD BalanceLab v0.3 calibrated SIM_001 runner")
    parser.add_argument("--runs", type=int, default=10000)
    parser.add_argument("--seed", type=int, default=31003)
    parser.add_argument("--report", type=Path, default=Path("reports/balance-lab-v03.json"))
    parser.add_argument("--csv", type=Path, default=Path("reports/balance-lab-v03-runs.csv"))
    parser.add_argument("--markdown", type=Path, default=Path("reports/balance-lab-v03.md"))
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    base._injury = _injury
    report, rows = base.build_report(max(100, args.runs), args.seed)
    report["model_version"] = MODEL_VERSION
    report["model_status"] = "measured_synthetic_pre_godot_contract_model"
    _add_injury_guardrails(report)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    base._write_csv(rows, args.csv)
    _write_markdown(report, args.markdown)

    print(f"BALANCE_LAB_V03_CALIBRATED scenario={base.SCENARIO_ID} runs={report['runs']} seed={args.seed}")
    print("OUTCOMES", json.dumps(report["outcomes"], sort_keys=True))
    print("ROUNDS", json.dumps(report["rounds"], sort_keys=True))
    for alert in report["alerts"]:
        print(f"ALERT {alert['severity'].upper()} {alert['code']}: {alert['detail']}")
    print(f"REPORT {args.report}")
    return 1 if args.strict and not report["ok"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
