#!/usr/bin/env python3
"""Bot v20: compare several player-behaviour profiles against existing combat/campaign telemetry.

This bot is deliberately diagnostic: it consumes real bot reports when available and produces
profile-specific risk signals without fabricating a pass from missing upstream data.
"""
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

REPORT_DIR = Path("reports")
OUT = REPORT_DIR / "player-bot-v20-player-profiles.json"
SOURCES = [
    REPORT_DIR / "player-bot-v4-factorial-matrix.json",
    REPORT_DIR / "player-bot-v5-longitudinal-campaign.json",
    REPORT_DIR / "player-bot-v6-real-campaign.json",
]

PROFILES = {
    "beginner": {"preferred_policy": "survival", "risk_tolerance": 0.20},
    "cautious": {"preferred_policy": "survival", "risk_tolerance": 0.35},
    "aggressive": {"preferred_policy": "aggressive", "risk_tolerance": 0.75},
    "optimizer": {"preferred_policy": "balanced", "risk_tolerance": 0.55},
    "loot_hunter": {"preferred_policy": "aggressive", "risk_tolerance": 0.65},
    "extractor": {"preferred_policy": "survival", "risk_tolerance": 0.25},
}


def load(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def iter_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from iter_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_dicts(child)


def policy_stats(report: dict[str, Any]) -> dict[str, dict[str, float]]:
    agg: dict[str, dict[str, float]] = defaultdict(lambda: {"samples": 0.0, "wins": 0.0, "deaths": 0.0})
    for row in iter_dicts(report):
        policy = row.get("policy") or row.get("behaviour") or row.get("behavior")
        if not isinstance(policy, str):
            continue
        key = policy.lower()
        if key not in {"aggressive", "balanced", "survival"}:
            continue
        samples = row.get("samples", row.get("combats", row.get("runs", 1)))
        wins = row.get("wins")
        win_rate = row.get("win_rate")
        deaths = row.get("deaths", 0)
        try:
            samples_f = max(1.0, float(samples))
            if wins is None and win_rate is not None:
                wins_f = float(win_rate) * samples_f
            else:
                wins_f = float(wins or (1 if row.get("victory") is True else 0))
            deaths_f = float(deaths or (1 if row.get("dead") is True else 0))
        except (TypeError, ValueError):
            continue
        agg[key]["samples"] += samples_f
        agg[key]["wins"] += wins_f
        agg[key]["deaths"] += deaths_f
    for values in agg.values():
        samples = max(1.0, values["samples"])
        values["win_rate"] = values["wins"] / samples
        values["death_rate"] = values["deaths"] / samples
    return dict(agg)


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    loaded = {path.name: load(path) for path in SOURCES}
    available = {name: report for name, report in loaded.items() if report is not None}
    combined: dict[str, dict[str, float]] = defaultdict(lambda: {"samples": 0.0, "wins": 0.0, "deaths": 0.0})
    for report in available.values():
        for policy, stats in policy_stats(report).items():
            combined[policy]["samples"] += stats["samples"]
            combined[policy]["wins"] += stats["wins"]
            combined[policy]["deaths"] += stats["deaths"]
    for stats in combined.values():
        n = max(1.0, stats["samples"])
        stats["win_rate"] = stats["wins"] / n
        stats["death_rate"] = stats["deaths"] / n

    findings: list[dict[str, Any]] = []
    profiles: dict[str, Any] = {}
    for name, config in PROFILES.items():
        policy = config["preferred_policy"]
        stats = combined.get(policy)
        if not stats:
            profiles[name] = {"policy": policy, "status": "unobserved"}
            continue
        death_rate = stats["death_rate"]
        win_rate = stats["win_rate"]
        status = "ok"
        if death_rate > max(0.50, 1.0 - config["risk_tolerance"]):
            status = "fragile"
            findings.append({"profile": name, "code": "profile_fragility", "severity": "medium", "death_rate": round(death_rate, 4)})
        profiles[name] = {
            "policy": policy,
            "status": status,
            "samples": int(stats["samples"]),
            "win_rate": round(win_rate, 4),
            "death_rate": round(death_rate, 4),
        }

    observed_rates = [v["win_rate"] for v in combined.values() if v.get("samples", 0) > 0]
    if len(observed_rates) >= 2 and max(observed_rates) - min(observed_rates) > 0.35:
        findings.append({
            "code": "policy_outcome_gap",
            "severity": "high",
            "gap": round(max(observed_rates) - min(observed_rates), 4),
            "message": "Player policy changes victory rate by more than 35 percentage points.",
        })

    status = "skipped" if not available else ("failed" if any(f.get("severity") == "high" for f in findings) else "passed")
    payload = {
        "bot": "v20",
        "status": status,
        "method": "multi-profile analysis over real upstream bot telemetry",
        "profiles": profiles,
        "policy_stats": combined,
        "findings": findings,
        "missing_sources": [name for name, report in loaded.items() if report is None],
    }
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    print(f"PLAYER_BOT_V20_{status.upper()} profiles={len(profiles)} findings={len(findings)}")
    return 1 if status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
