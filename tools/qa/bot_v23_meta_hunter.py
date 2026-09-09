#!/usr/bin/env python3
"""Bot v23: search upstream balance reports for dominant strategies/builds.

The bot is schema-tolerant: it recursively finds case-like dictionaries containing outcomes
and categorical dimensions, then ranks combinations by observed win rate. High-confidence
large gaps are treated as regressions; small samples are warnings only.
"""
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

REPORT_DIR = Path("reports")
OUT = REPORT_DIR / "player-bot-v23-meta-hunter.json"
SOURCES = [
    REPORT_DIR / "player-bot-v3-build-matrix.json",
    REPORT_DIR / "player-bot-v4-factorial-matrix.json",
    REPORT_DIR / "player-bot-v20-player-profiles.json",
]
DIMENSIONS = ("build", "build_id", "policy", "rarity", "level", "companion", "hero_class", "class_id")


def load(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def walk(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def outcome(row: dict[str, Any]) -> tuple[float, float] | None:
    # returns wins, samples
    try:
        if "win_rate" in row:
            samples = float(row.get("samples", row.get("runs", row.get("combats", 1))))
            samples = max(samples, 1.0)
            return float(row["win_rate"]) * samples, samples
        if "wins" in row:
            samples = float(row.get("samples", row.get("runs", row.get("combats", row.get("wins", 0) + row.get("losses", 0)))))
            if samples <= 0:
                return None
            return float(row["wins"]), samples
        if "victory" in row and isinstance(row["victory"], bool):
            return (1.0 if row["victory"] else 0.0), 1.0
    except (TypeError, ValueError):
        return None
    return None


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    aggregates: dict[str, dict[str, dict[str, float]]] = {
        d: defaultdict(lambda: {"wins": 0.0, "samples": 0.0}) for d in DIMENSIONS
    }
    available: list[str] = []
    for path in SOURCES:
        report = load(path)
        if report is None:
            continue
        available.append(path.name)
        for row in walk(report):
            result = outcome(row)
            if result is None:
                continue
            wins, samples = result
            for dim in DIMENSIONS:
                if dim not in row:
                    continue
                value = str(row[dim])
                aggregates[dim][value]["wins"] += wins
                aggregates[dim][value]["samples"] += samples

    rankings: dict[str, Any] = {}
    findings: list[dict[str, Any]] = []
    for dim, values in aggregates.items():
        rows = []
        for value, stats in values.items():
            if stats["samples"] <= 0:
                continue
            rows.append({"value": value, "samples": int(stats["samples"]), "win_rate": stats["wins"] / stats["samples"]})
        rows.sort(key=lambda r: (-r["win_rate"], -r["samples"], r["value"]))
        rankings[dim] = rows
        stable = [r for r in rows if r["samples"] >= 8]
        if len(stable) >= 2:
            gap = stable[0]["win_rate"] - stable[-1]["win_rate"]
            if gap > 0.35:
                findings.append({
                    "code": "dominant_dimension_value",
                    "severity": "high" if stable[0]["samples"] >= 20 else "medium",
                    "dimension": dim,
                    "dominant": stable[0],
                    "weakest": stable[-1],
                    "gap": round(gap, 4),
                })
        for row in stable:
            if row["win_rate"] >= 0.95 and row["samples"] >= 20:
                findings.append({"code": "near_guaranteed_win_strategy", "severity": "high", "dimension": dim, "strategy": row})

    status = "skipped" if not available else ("failed" if any(f["severity"] == "high" for f in findings) else "passed")
    OUT.write_text(json.dumps({
        "bot": "v23",
        "status": status,
        "method": "schema-tolerant dominant-strategy mining",
        "sources": available,
        "rankings": rankings,
        "findings": findings,
        "thresholds": {"stable_min_samples": 8, "high_confidence_samples": 20, "dominance_gap": 0.35, "near_guaranteed_win_rate": 0.95},
    }, indent=2, sort_keys=True), encoding="utf-8")
    print(f"PLAYER_BOT_V23_{status.upper()} findings={len(findings)}")
    return 1 if status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
