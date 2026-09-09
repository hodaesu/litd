from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORTS = Path("reports")
SOURCE = REPORTS / "player-bot-v11-tactical-property-fuzzer.json"
OUT = REPORTS / "player-bot-v15-case-minimizer.json"

KEEP_KEYS = {
    "position_contract": {"hero", "skill", "allowed", "expected", "actual"},
    "targetable_equivalence": {"hero", "skill", "enemy_index", "enemies", "expected", "actual"},
    "dead_enemy_targetable": {"hero", "skill", "enemy_index", "enemies"},
    "enemy_position_out_of_range": {"position", "enemies"},
    "enemy_position_duplicate": {"position", "enemies"},
    "movement_position_out_of_range": {"delta", "enemies"},
    "movement_position_duplicate": {"delta", "enemies"},
    "movement_changed_roster": {"delta", "before", "after"},
}


def shrink_hero(hero: Any) -> Any:
    if not isinstance(hero, dict):
        return hero
    return {k: hero[k] for k in ("class_id", "combat_position", "hp") if k in hero}


def shrink_skill(skill: Any) -> Any:
    if not isinstance(skill, dict):
        return skill
    return {k: skill[k] for k in ("id", "effect", "source_stat", "status", "branch") if k in skill}


def shrink_enemies(enemies: Any, enemy_index: int | None = None) -> Any:
    if not isinstance(enemies, list):
        return enemies
    compact = []
    for index, enemy in enumerate(enemies):
        if not isinstance(enemy, dict):
            continue
        row = {k: enemy[k] for k in ("combat_uid", "hp", "combat_position") if k in enemy}
        row["index"] = index
        compact.append(row)
    if enemy_index is None:
        return compact
    relevant = [row for row in compact if row.get("index") == enemy_index]
    front = [row for row in compact if row.get("combat_position") in (0, 1)]
    merged: list[dict[str, Any]] = []
    seen = set()
    for row in relevant + front:
        key = row.get("index")
        if key not in seen:
            seen.add(key)
            merged.append(row)
    return merged or compact


def minimize_failure(failure: dict[str, Any]) -> dict[str, Any]:
    prop = str(failure.get("property", "unknown"))
    data = failure.get("data", {})
    if not isinstance(data, dict):
        data = {}
    keep = KEEP_KEYS.get(prop, set(data.keys()))
    minimal = {k: data[k] for k in keep if k in data}
    if "hero" in minimal:
        minimal["hero"] = shrink_hero(minimal["hero"])
    if "skill" in minimal:
        minimal["skill"] = shrink_skill(minimal["skill"])
    enemy_index = minimal.get("enemy_index") if isinstance(minimal.get("enemy_index"), int) else None
    if "enemies" in minimal:
        minimal["enemies"] = shrink_enemies(minimal["enemies"], enemy_index)
    return {
        "seed": failure.get("seed"),
        "case_index": failure.get("case_index"),
        "property": prop,
        "minimal": minimal,
        "replay_key": f"{failure.get('seed')}:{failure.get('case_index')}",
    }


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    if not SOURCE.exists():
        report = {"schema_version": 15, "suite": "player_bot_v15_case_minimizer", "status": "skipped", "reason": "v11_report_missing", "cases": []}
        OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PLAYER_BOT_V15_SKIP v11_report_missing")
        return 0

    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    failures = source.get("failures", []) if isinstance(source, dict) else []
    cases = [minimize_failure(item) for item in failures if isinstance(item, dict)]
    report = {
        "schema_version": 15,
        "suite": "player_bot_v15_case_minimizer",
        "source_failures": len(failures) if isinstance(failures, list) else 0,
        "cases": cases,
        "status": "passed",
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PLAYER_BOT_V15_OK minimized={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
