from __future__ import annotations

import json
import os
from pathlib import Path

OUT = Path('reports/player-bot-v17-change-impact-mapper.json')

RULES = {
    'combat': ['scripts/core/combat_', 'scripts/ui/main_v3', 'data/skills', 'data/enemies'],
    'campaign': ['scripts/core/expedition_', 'scripts/qa/player_bot_v5', 'scripts/qa/player_bot_v6', 'data/expedition'],
    'sanctuary': ['veilleurs_market_service', 'veilleurs_hero_recruitment_service', 'sanctuary_economy_rules', 'main_v44', 'main_v45'],
    'save': ['save_manager', 'serialize', 'deserialize'],
    'ui': ['scripts/ui/', 'scenes/Main.tscn'],
    'qa': ['scripts/qa/', 'tools/qa/', '.github/workflows/developer-autotest.yml'],
}

BOT_GROUPS = {
    'combat': ['v8','v11','v12','v2','v3','v4'],
    'campaign': ['v5','v6','v16'],
    'sanctuary': ['v7','v10','v19'],
    'save': ['v9','v13'],
    'ui': ['v10'],
    'qa': ['v13','v14','v15','v16','v17','v18','v19'],
}


def classify(path: str) -> set[str]:
    result: set[str] = set()
    low = path.lower()
    for domain, needles in RULES.items():
        if any(n.lower() in low for n in needles):
            result.add(domain)
    if not result:
        result.add('unknown')
    return result


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    raw = os.environ.get('CHANGED_FILES', '')
    files = [line.strip() for line in raw.splitlines() if line.strip()]
    domains: set[str] = set()
    by_file = []
    for path in files:
        d = sorted(classify(path))
        by_file.append({'path': path, 'domains': d})
        domains.update(d)
    selected: set[str] = set()
    if 'unknown' in domains or not files:
        selected.update(['v8','v9','v10','v11','v12','v13','v14','v15','v16','v17','v18','v19'])
    for domain in domains:
        selected.update(BOT_GROUPS.get(domain, []))
    report = {
        'schema_version': 17,
        'suite': 'player_bot_v17_change_impact_mapper',
        'changed_files': files,
        'classification': by_file,
        'domains': sorted(domains),
        'recommended_bots': sorted(selected),
        'status': 'passed',
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('PLAYER_BOT_V17_OK bots=' + ','.join(sorted(selected)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
