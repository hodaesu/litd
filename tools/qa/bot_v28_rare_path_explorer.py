#!/usr/bin/env python3
"""Bot v28: deterministic rare-path explorer for expedition pacing, Light and Remanence.

Targets boundary values and low-frequency combinations instead of sampling only average runs.
The model follows the validated Les Veilleurs expedition envelope and emits exact replay keys.
"""
from __future__ import annotations

import json
import random
from collections import Counter
from pathlib import Path
from typing import Any

OUT = Path("reports/player-bot-v28-rare-path-explorer.json")
SEEDS = [2801, 2802, 2803, 2804, 2805]
RUNS_PER_SEED = 400
LIGHT_BOUNDARIES = [100, 76, 75, 51, 50, 26, 25, 1]


def light_state(value: int) -> str:
    if 76 <= value <= 100:
        return "clear"
    if 51 <= value <= 75:
        return "low"
    if 26 <= value <= 50:
        return "dark"
    if 1 <= value <= 25:
        return "critical"
    return "out_of_contract"


def run_case(rng: random.Random, seed: int, case_index: int) -> dict[str, Any]:
    generated_rooms = rng.randint(18, 24)
    visited_rooms = rng.randint(12, 17)
    ordinary_combats = rng.randint(4, 6)
    difficult_combats = rng.randint(0, 1)
    events = rng.randint(3, 5)
    discoveries = rng.randint(2, 4)
    meaningful_loot = rng.randint(3, 5)
    major_branches = rng.randint(2, 4)
    extraction_windows = rng.randint(2, 3)

    # Force boundary coverage regularly, otherwise evolve Light through a deterministic run.
    if case_index % 8 == 0:
        light = LIGHT_BOUNDARIES[(case_index // 8) % len(LIGHT_BOUNDARIES)]
    else:
        light = max(1, min(100, 100 - rng.randint(0, 95)))

    act = 1 + min(4, int((visited_rooms - 1) * 5 / 17))
    rare_event = rng.random() < (0.06 if act < 4 else 0.16)
    remanence = rare_event and act >= 4 and rng.random() < 0.55
    deep_branch = major_branches >= 4 and visited_rooms >= 16
    critical_branch = light <= 25 and deep_branch
    rare_combo = remanence and critical_branch

    return {
        "seed": seed,
        "case_index": case_index,
        "replay_key": f"{seed}:{case_index}",
        "generated_rooms": generated_rooms,
        "visited_rooms": visited_rooms,
        "ordinary_combats": ordinary_combats,
        "difficult_combats": difficult_combats,
        "events": events,
        "discoveries": discoveries,
        "meaningful_loot": meaningful_loot,
        "major_branches": major_branches,
        "extraction_windows": extraction_windows,
        "act": act,
        "light": light,
        "light_state": light_state(light),
        "rare_event": rare_event,
        "remanence": remanence,
        "deep_branch": deep_branch,
        "critical_branch": critical_branch,
        "rare_combo": rare_combo,
    }


def main() -> int:
    cases: list[dict[str, Any]] = []
    light_counts: Counter[str] = Counter()
    act_counts: Counter[int] = Counter()
    boundary_hits: Counter[int] = Counter()
    rare_event_count = 0
    remanence_count = 0
    critical_branch_count = 0
    rare_combo_count = 0
    envelope_errors: list[dict[str, Any]] = []

    for seed in SEEDS:
        rng = random.Random(seed)
        for case_index in range(RUNS_PER_SEED):
            case = run_case(rng, seed, case_index)
            cases.append(case)
            light_counts[case["light_state"]] += 1
            act_counts[case["act"]] += 1
            if case["light"] in LIGHT_BOUNDARIES:
                boundary_hits[case["light"]] += 1
            rare_event_count += int(case["rare_event"])
            remanence_count += int(case["remanence"])
            critical_branch_count += int(case["critical_branch"])
            rare_combo_count += int(case["rare_combo"])

            checks = {
                "generated_rooms": 18 <= case["generated_rooms"] <= 24,
                "visited_rooms": 12 <= case["visited_rooms"] <= 17,
                "ordinary_combats": 4 <= case["ordinary_combats"] <= 6,
                "difficult_combats": 0 <= case["difficult_combats"] <= 1,
                "events": 3 <= case["events"] <= 5,
                "discoveries": 2 <= case["discoveries"] <= 4,
                "meaningful_loot": 3 <= case["meaningful_loot"] <= 5,
                "major_branches": 2 <= case["major_branches"] <= 4,
                "extraction_windows": 2 <= case["extraction_windows"] <= 3,
                "light_contract": case["light_state"] != "out_of_contract",
            }
            failed = [name for name, ok in checks.items() if not ok]
            if failed:
                envelope_errors.append({"replay_key": case["replay_key"], "failed": failed})

    missing_light_states = [state for state in ("clear", "low", "dark", "critical") if light_counts[state] == 0]
    missing_boundaries = [value for value in LIGHT_BOUNDARIES if boundary_hits[value] == 0]
    findings: list[dict[str, Any]] = []
    if missing_light_states:
        findings.append({"code": "light_state_uncovered", "severity": "high", "states": missing_light_states})
    if missing_boundaries:
        findings.append({"code": "light_boundary_uncovered", "severity": "high", "values": missing_boundaries})
    if remanence_count == 0:
        findings.append({"code": "remanence_uncovered", "severity": "high"})
    if critical_branch_count == 0:
        findings.append({"code": "critical_deep_branch_uncovered", "severity": "high"})
    if rare_combo_count == 0:
        findings.append({"code": "remanence_critical_branch_combo_uncovered", "severity": "medium"})
    if envelope_errors:
        findings.append({"code": "expedition_envelope_violation", "severity": "high", "count": len(envelope_errors)})

    status = "failed" if any(f["severity"] == "high" for f in findings) else "passed"
    report = {
        "bot": "v28",
        "status": status,
        "method": "targeted deterministic rare-path exploration",
        "seeds": SEEDS,
        "runs_per_seed": RUNS_PER_SEED,
        "total_cases": len(cases),
        "expedition_envelope": {
            "generated_rooms": [18, 24],
            "visited_rooms": [12, 17],
            "ordinary_combats": [4, 6],
            "difficult_combats": [0, 1],
            "events": [3, 5],
            "discoveries": [2, 4],
            "meaningful_loot": [3, 5],
            "major_branches": [2, 4],
            "extraction_windows": [2, 3],
        },
        "light_contract": {"clear": [76, 100], "low": [51, 75], "dark": [26, 50], "critical": [1, 25]},
        "coverage": {
            "light_states": dict(light_counts),
            "light_boundary_hits": {str(k): boundary_hits[k] for k in LIGHT_BOUNDARIES},
            "acts": {str(k): v for k, v in sorted(act_counts.items())},
            "rare_events": rare_event_count,
            "remanence": remanence_count,
            "critical_deep_branches": critical_branch_count,
            "rare_combinations": rare_combo_count,
        },
        "findings": findings,
        "envelope_errors": envelope_errors[:50],
        "rare_replay_cases": [c for c in cases if c["rare_combo"]][:50],
        "note": "Targeted model-level explorer. v27 requires runtime evidence so this signal cannot substitute for Godot production tests.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PLAYER_BOT_V28_{status.upper()} cases={len(cases)} remanence={remanence_count} rare_combo={rare_combo_count}")
    return 1 if status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
