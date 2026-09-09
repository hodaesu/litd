from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORTS = Path("reports")
V3_SHARDS = 4
V4_SHARDS = 6
V3_EXPECTED_RUNS = 12
V3_EXPECTED_SCENARIOS = 36
V4_EXPECTED_CASES = 60
V4_EXPECTED_RUNS = 120
V4_EXPECTED_SCENARIOS = 240


def load_shards(pattern: str, expected: int) -> list[dict[str, Any]]:
    paths = sorted(REPORTS.glob(pattern))
    if len(paths) != expected:
        raise RuntimeError(f"{pattern}: expected {expected} shards, got {len(paths)}")
    shards = [json.loads(path.read_text(encoding="utf-8")) for path in paths]
    indices = sorted(int(shard.get("shard_index", -1)) for shard in shards)
    if indices != list(range(expected)):
        raise RuntimeError(f"{pattern}: invalid shard indices {indices}")
    failed = [int(s.get("shard_index", -1)) for s in shards if s.get("status") != "passed" or s.get("failures")]
    if failed:
        raise RuntimeError(f"{pattern}: failed shards {failed}")
    return shards


def write_report(name: str, report: dict[str, Any]) -> None:
    REPORTS.mkdir(parents=True, exist_ok=True)
    (REPORTS / name).write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def aggregate_usage(rows: list[dict[str, Any]]) -> dict[str, int]:
    usage: dict[str, int] = {}
    for row in rows:
        for skill_id, count in row.get("skill_usage", {}).items():
            usage[str(skill_id)] = usage.get(str(skill_id), 0) + int(count)
    return usage


def aggregate_v3() -> None:
    shards = load_shards("player-bot-v3-build-matrix-shard-*.json", V3_SHARDS)
    builds: list[dict[str, Any]] = []
    results: list[dict[str, Any]] = []
    for shard in shards:
        builds.extend(shard.get("builds", []))
        results.extend(shard.get("results", []))
    if len(builds) != V3_SHARDS:
        raise RuntimeError(f"v3: expected 4 builds, got {len(builds)}")
    if len(results) != V3_EXPECTED_RUNS:
        raise RuntimeError(f"v3: expected {V3_EXPECTED_RUNS} runs, got {len(results)}")
    scenario_count = sum(len(row.get("scenarios", [])) for row in results)
    if scenario_count != V3_EXPECTED_SCENARIOS:
        raise RuntimeError(f"v3: expected {V3_EXPECTED_SCENARIOS} scenarios, got {scenario_count}")

    scenarios = shards[0]["scenarios"]
    summary: dict[str, Any] = {}
    for build in builds:
        build_id = str(build.get("id", "build"))
        rows = [row for row in results if str(row.get("build_id", "")) == build_id]
        wins = sum(int(row.get("wins", 0)) for row in rows)
        attempts = len(rows) * len(scenarios)
        summary[build_id] = {
            "win_rate": wins / max(1, attempts),
            "avg_actions": sum(int(row.get("actions", 0)) for row in rows) / max(1, len(rows)),
            "avg_deaths": sum(int(row.get("deaths", 0)) for row in rows) / max(1, len(rows)),
            "avg_damage": sum(int(row.get("damage", 0)) for row in rows) / max(1, len(rows)),
            "avg_healing": sum(int(row.get("healing", 0)) for row in rows) / max(1, len(rows)),
            "skill_usage": aggregate_usage(rows),
        }

    alerts: list[dict[str, Any]] = []
    rates = [float(row.get("win_rate", 0.0)) for row in summary.values()]
    mean = sum(rates) / max(1, len(rates))
    dominance = float(shards[0]["thresholds"]["dominance_gap"])
    underperform = float(shards[0]["thresholds"]["underperform_gap"])
    for build_id, row in summary.items():
        rate = float(row.get("win_rate", 0.0))
        if rate - mean >= dominance:
            alerts.append({"severity": "high", "code": "dominant_build", "build_id": build_id, "win_rate": rate, "mean": mean})
        elif mean - rate >= underperform:
            alerts.append({"severity": "medium", "code": "underperforming_build", "build_id": build_id, "win_rate": rate, "mean": mean})
        for skill_id, uses in row.get("skill_usage", {}).items():
            if int(uses) <= 1:
                alerts.append({"severity": "low", "code": "rarely_used_skill", "build_id": build_id, "skill_id": skill_id, "uses": int(uses)})

    report = {
        "schema_version": 3,
        "suite": "player_bot_v3_build_matrix",
        "driver": "real_main_controller_sharded",
        "shard_count": V3_SHARDS,
        "seeds": shards[0]["seeds"],
        "scenarios": scenarios,
        "builds": builds,
        "results": results,
        "summary": summary,
        "alerts": alerts,
        "failures": [],
        "thresholds": shards[0]["thresholds"],
        "duration_ms": sum(int(s.get("duration_ms", 0)) for s in shards),
        "coverage": {"runs": len(results), "scenarios": scenario_count},
        "status": "passed",
    }
    write_report("player-bot-v3-build-matrix.json", report)


def accumulate_dimension(dimension: dict[str, Any], key: str, wins: int, attempts: int) -> None:
    cell = dimension.setdefault(key, {"wins": 0, "attempts": 0})
    cell["wins"] += wins
    cell["attempts"] += attempts


def dimension_gap_alerts(alerts: list[dict[str, Any]], dimension: dict[str, Any], name: str, gap_limit: float) -> None:
    if len(dimension) < 2:
        return
    rates = {key: float(value.get("win_rate", 0.0)) for key, value in dimension.items()}
    min_key = min(rates, key=rates.get)
    max_key = max(rates, key=rates.get)
    gap = rates[max_key] - rates[min_key]
    if gap >= gap_limit:
        alerts.append({"severity": "high", "code": "factor_gap", "dimension": name, "best": max_key, "best_rate": rates[max_key], "worst": min_key, "worst_rate": rates[min_key], "gap": gap})


def aggregate_v4() -> None:
    shards = load_shards("player-bot-v4-factorial-matrix-shard-*.json", V4_SHARDS)
    cases: list[dict[str, Any]] = []
    results: list[dict[str, Any]] = []
    for shard in shards:
        cases.extend(shard.get("cases", []))
        results.extend(shard.get("results", []))
    if len(cases) != V4_EXPECTED_CASES:
        raise RuntimeError(f"v4: expected {V4_EXPECTED_CASES} cases, got {len(cases)}")
    if len(results) != V4_EXPECTED_RUNS:
        raise RuntimeError(f"v4: expected {V4_EXPECTED_RUNS} runs, got {len(results)}")
    scenario_count = sum(len(row.get("scenarios", [])) for row in results)
    if scenario_count != V4_EXPECTED_SCENARIOS:
        raise RuntimeError(f"v4: expected {V4_EXPECTED_SCENARIOS} scenarios, got {scenario_count}")

    scenario_defs = shards[0]["scenarios"]
    dimensions: dict[str, dict[str, Any]] = {"build": {}, "level": {}, "rarity": {}, "companion": {}, "policy": {}, "scenario": {}}
    for row in results:
        wins = int(row.get("wins", 0))
        attempts = len(scenario_defs)
        accumulate_dimension(dimensions["build"], str(row.get("build_id", "build")), wins, attempts)
        accumulate_dimension(dimensions["level"], str(row.get("level", 1)), wins, attempts)
        accumulate_dimension(dimensions["rarity"], str(row.get("rarity", "common")), wins, attempts)
        accumulate_dimension(dimensions["companion"], "with" if bool(row.get("companion", False)) else "without", wins, attempts)
        accumulate_dimension(dimensions["policy"], str(row.get("policy", "balanced")), wins, attempts)
        for scenario in row.get("scenarios", []):
            key = f"{scenario.get('scenario_id', 'scenario')}@L{int(row.get('level', 1))}"
            accumulate_dimension(dimensions["scenario"], key, 1 if bool(scenario.get("victory", False)) else 0, 1)
    for dimension in dimensions.values():
        for cell in dimension.values():
            cell["win_rate"] = int(cell.get("wins", 0)) / max(1, int(cell.get("attempts", 0)))

    thresholds = shards[0]["thresholds"]
    dominance = float(thresholds["dominance_gap"])
    alerts: list[dict[str, Any]] = []
    for name in ("build", "rarity", "companion", "policy"):
        dimension_gap_alerts(alerts, dimensions[name], name, dominance)
    hard = float(thresholds["boss_too_hard_below"])
    easy = float(thresholds["boss_too_easy_above"])
    for key, cell in dimensions["scenario"].items():
        rate = float(cell.get("win_rate", 0.0))
        if key.startswith("boss_d5") and rate < hard:
            alerts.append({"severity": "high", "code": "boss_too_hard_for_level", "scenario": key, "win_rate": rate})
        elif key.startswith("boss_d5") and rate > easy:
            alerts.append({"severity": "medium", "code": "boss_too_easy_for_level", "scenario": key, "win_rate": rate})

    report = {
        "schema_version": 4,
        "suite": "player_bot_v4_factorial_matrix",
        "driver": "real_main_controller_sharded",
        "shard_count": V4_SHARDS,
        "levels": shards[0]["levels"],
        "rarities": shards[0]["rarities"],
        "policies": shards[0]["policies"],
        "companion_states": shards[0]["companion_states"],
        "seeds": shards[0]["seeds"],
        "scenarios": scenario_defs,
        "cases": cases,
        "results": results,
        "summary": dimensions,
        "alerts": alerts,
        "failures": [],
        "thresholds": thresholds,
        "duration_ms": sum(int(s.get("duration_ms", 0)) for s in shards),
        "coverage": {"cases": len(cases), "runs": len(results), "scenarios": scenario_count},
        "status": "passed",
    }
    write_report("player-bot-v4-factorial-matrix.json", report)


def main() -> int:
    try:
        aggregate_v3()
        aggregate_v4()
    except Exception as exc:
        print(f"BOT_MATRIX_AGGREGATE_ERROR: {exc}")
        return 1
    print("BOT_MATRIX_AGGREGATE_OK v3_runs=12 v3_scenarios=36 v4_runs=120 v4_scenarios=240")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
