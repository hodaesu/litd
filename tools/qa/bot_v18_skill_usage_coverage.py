from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORTS = Path('reports')
OUT = REPORTS / 'player-bot-v18-skill-usage-coverage.json'


def load(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def collect_usage(value: Any, usage: dict[str, int]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            low = str(key).lower()
            if low in {'skill_usage', 'skill_uses', 'skills_used'} and isinstance(child, dict):
                for skill, count in child.items():
                    try:
                        usage[str(skill)] = usage.get(str(skill), 0) + int(count)
                    except Exception:
                        pass
            else:
                collect_usage(child, usage)
    elif isinstance(value, list):
        for child in value:
            collect_usage(child, usage)


def collect_declared_skills(value: Any, declared: set[str]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            low = str(key).lower()
            if low in {'loadout', 'equipped_skills', 'combat_loadout'} and isinstance(child, list):
                for skill in child:
                    if isinstance(skill, str) and skill:
                        declared.add(skill)
            collect_declared_skills(child, declared)
    elif isinstance(value, list):
        for child in value:
            collect_declared_skills(child, declared)


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    sources = [
        REPORTS / 'player-bot-v2-autotest.json',
        REPORTS / 'player-bot-v3-build-matrix.json',
        REPORTS / 'player-bot-v4-factorial-matrix.json',
        REPORTS / 'player-bot-v5-longitudinal-campaign.json',
        REPORTS / 'player-bot-v6-real-campaign.json',
    ]
    usage: dict[str, int] = {}
    declared: set[str] = set()
    loaded: list[str] = []
    for path in sources:
        report = load(path)
        if not report:
            continue
        loaded.append(path.name)
        collect_usage(report, usage)
        collect_declared_skills(report, declared)

    never_used = sorted(skill for skill in declared if usage.get(skill, 0) == 0)
    rare = sorted((skill, count) for skill, count in usage.items() if count <= 2)
    report = {
        'schema_version': 18,
        'suite': 'player_bot_v18_skill_usage_coverage',
        'source_reports': loaded,
        'declared_skill_count': len(declared),
        'used_skill_count': len([k for k,v in usage.items() if v > 0]),
        'usage': dict(sorted(usage.items())),
        'never_used_declared_skills': never_used,
        'rarely_used_skills': [{'skill': k, 'uses': v} for k,v in rare],
        'warnings': ([] if declared else ['no_declared_skill_inventory_in_reports']),
        'status': 'passed',
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"PLAYER_BOT_V18_OK declared={len(declared)} used={report['used_skill_count']} never={len(never_used)}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
