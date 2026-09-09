#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
from typing import Any

PROMOTER = Path('reports/player-bot-v26-regression-promoter.json')
V11 = Path('reports/player-bot-v11-tactical-property-fuzzer.json')
V12 = Path('reports/player-bot-v12-regression-replay.json')
OUT = Path('reports/player-bot-v29-replay-proof-gate.json')

def load(path: Path, fallback: Any) -> Any:
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else fallback

def main() -> int:
    proposals = load(PROMOTER, {'candidates': []}).get('candidates', [])
    v11 = load(V11, {'failures': []})
    v12 = load(V12, {})
    failures = v11.get('failures', []) if isinstance(v11, dict) else []
    v12_blob = json.dumps(v12, sort_keys=True, ensure_ascii=False)
    proofs = []
    blocked = []
    for candidate in proposals if isinstance(proposals, list) else []:
        if not isinstance(candidate, dict):
            continue
        seed = candidate.get('seed')
        case_index = candidate.get('case_index')
        prop = candidate.get('property')
        source_match = any(isinstance(f, dict) and f.get('seed') == seed and f.get('case_index') == case_index and f.get('property') == prop for f in failures)
        replay_match = str(candidate.get('semantic_key', '')) in v12_blob or str(candidate.get('id', '')) in v12_blob
        row = {'id': candidate.get('id'), 'seed': seed, 'case_index': case_index, 'property': prop, 'source_failure_reconfirmed': source_match, 'permanent_replay_present': replay_match}
        if source_match and replay_match:
            row['promotion_ready'] = True
            proofs.append(row)
        else:
            row['promotion_ready'] = False
            row['block_reason'] = 'missing_permanent_replay' if source_match else 'source_failure_not_reconfirmed'
            blocked.append(row)
    report = {'bot':'v29','status':'passed','promotion_ready':proofs,'blocked':blocked,'ready_count':len(proofs),'blocked_count':len(blocked),'policy':'No v26 proposal may enter the permanent corpus until its source failure is reconfirmed and a permanent v12 replay exists.'}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False)+'\n', encoding='utf-8')
    print(f"PLAYER_BOT_V29_OK ready={len(proofs)} blocked={len(blocked)}")
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
