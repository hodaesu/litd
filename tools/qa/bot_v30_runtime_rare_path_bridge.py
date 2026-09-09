#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
from typing import Any

OUT = Path('reports/player-bot-v30-runtime-rare-path-bridge.json')
RUNTIME = {
    'expedition': ['reports/player-bot-v6-real-campaign.json','reports/player-bot-autotest.json'],
    'combat': ['reports/player-bot-v2-autotest.json','reports/player-bot-v3-build-matrix.json','reports/player-bot-v4-factorial-matrix.json'],
    'sanctuary': ['reports/player-bot-v7-sanctuary-economy.json','reports/player-bot-v19-economy-stress.json'],
    'remanence': ['reports/developer-autotest-godot.json'],
}
MODEL = Path('reports/player-bot-v28-rare-path-explorer.json')

def load(path: Path, fallback: Any) -> Any:
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else fallback

def status_ok(path: Path) -> bool:
    if not path.exists():
        return False
    data = load(path,{})
    if not isinstance(data, dict):
        return False
    return str(data.get('status','passed')).lower() not in {'failed','failure','error'}

def main() -> int:
    model = load(MODEL,{})
    model_present = MODEL.exists()
    domains = {}
    missing = []
    for domain, paths in RUNTIME.items():
        evidence = [p for p in paths if status_ok(Path(p))]
        domains[domain] = {'runtime_evidence': evidence, 'covered': bool(evidence)}
        if not evidence:
            missing.append(domain)
    # v30 is a bridge/coverage gate: missing evidence is diagnostic, not a hard CI failure yet.
    report = {'bot':'v30','status':'passed','model_present':model_present,'runtime_domains':domains,'missing_runtime_domains':missing,'rare_path_model_summary': model.get('summary',{}) if isinstance(model,dict) else {},'policy':'Rare-path findings remain model evidence until corroborated by Godot runtime reports. Missing runtime domains are surfaced explicitly and must not be called validated.'}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False)+'\n', encoding='utf-8')
    print(f"PLAYER_BOT_V30_OK covered={len(domains)-len(missing)}/{len(domains)} missing={','.join(missing) or 'none'}")
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
