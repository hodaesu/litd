#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path

OUT = Path('reports/player-bot-v31-fleet-efficiency.json')
REPORTS = Path('reports')

def load(path: Path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return None

def main() -> int:
    bot_reports = sorted(REPORTS.glob('player-bot-v*.json'))
    statuses = {'passed':0,'failed':0,'skipped':0,'unknown':0}
    failure_signatures = set()
    finding_count = 0
    useful_reports = 0
    for path in bot_reports:
        data = load(path)
        if not isinstance(data, dict):
            statuses['unknown'] += 1
            continue
        status = str(data.get('status','unknown')).lower()
        if status in {'success','ok'}: status = 'passed'
        if status in {'failure','error'}: status = 'failed'
        statuses[status if status in statuses else 'unknown'] += 1
        local_findings = []
        for key in ('failures','findings','blocked','candidates','missing_runtime_domains'):
            value = data.get(key)
            if isinstance(value, list):
                local_findings.extend(value)
        if local_findings:
            useful_reports += 1
        finding_count += len(local_findings)
        for item in local_findings:
            try:
                failure_signatures.add(json.dumps(item, sort_keys=True, ensure_ascii=False))
            except TypeError:
                failure_signatures.add(str(item))
    total = len(bot_reports)
    unique_findings = len(failure_signatures)
    duplicate_ratio = 0.0 if finding_count == 0 else round(1.0 - unique_findings / finding_count, 4)
    signal_ratio = 0.0 if total == 0 else round(useful_reports / total, 4)
    maturity = 'mature' if total >= 20 and duplicate_ratio < 0.75 else 'growing'
    recommendation = 'freeze_new_bot_numbers_and_optimize_existing_fleet' if maturity == 'mature' else 'continue_only_for_uncovered_domains'
    report = {
        'bot':'v31','status':'passed','report_count':total,'statuses':statuses,'finding_count':finding_count,'unique_finding_signatures':unique_findings,'duplicate_ratio':duplicate_ratio,'signal_ratio':signal_ratio,'maturity':maturity,'recommendation':recommendation,
        'stop_rule': {
            'freeze_when': 'major gameplay domains are covered and new bots mostly duplicate existing findings',
            'after_freeze': 'improve, merge, shard or retire existing bots; add a new numbered bot only for a genuinely new mechanic or blind spot'
        }
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False)+'\n', encoding='utf-8')
    print(f"PLAYER_BOT_V31_OK reports={total} unique={unique_findings} maturity={maturity}")
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
