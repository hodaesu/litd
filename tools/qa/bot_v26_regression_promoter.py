#!/usr/bin/env python3
"""Bot v26: promote minimized discoveries into the permanent regression corpus.

CI mode writes a deterministic promotion artifact. --apply updates the source corpus locally
when write access is intentionally available. Existing cases are deduplicated by semantic key.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

MINIMIZED = Path("reports/player-bot-v15-case-minimizer.json")
CORPUS = Path("data/qa/regression_replay_cases.json")
OUT = Path("reports/player-bot-v26-regression-promoter.json")


def stable_key(case: dict[str, Any]) -> str:
    payload = {
        "property": case.get("property"),
        "minimal": case.get("minimal", {}),
    }
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def load_json(path: Path, fallback: Any) -> Any:
    if not path.exists():
        return fallback
    return json.loads(path.read_text(encoding="utf-8"))


def to_replay_case(item: dict[str, Any]) -> dict[str, Any]:
    minimal = item.get("minimal", {}) if isinstance(item.get("minimal"), dict) else {}
    key = stable_key(item)
    replay: dict[str, Any] = {
        "id": f"auto_{item.get('property', 'unknown')}_{key}",
        "source": "v26_auto_promotion",
        "seed": item.get("seed"),
        "case_index": item.get("case_index"),
        "property": item.get("property", "unknown"),
        "replay_key": item.get("replay_key"),
        "minimal": minimal,
        "semantic_key": key,
    }
    return replay


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Append new auto cases to the source corpus.")
    args = parser.parse_args()

    minimized = load_json(MINIMIZED, {"cases": []})
    source_cases = minimized.get("cases", []) if isinstance(minimized, dict) else []
    corpus = load_json(CORPUS, {"schema_version": 1, "cases": []})
    existing = corpus.get("cases", []) if isinstance(corpus, dict) else []
    existing_ids = {str(c.get("id")) for c in existing if isinstance(c, dict)}
    existing_semantic = {str(c.get("semantic_key")) for c in existing if isinstance(c, dict) and c.get("semantic_key")}

    candidates: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for item in source_cases if isinstance(source_cases, list) else []:
        if not isinstance(item, dict):
            continue
        replay = to_replay_case(item)
        if replay["id"] in existing_ids or replay["semantic_key"] in existing_semantic:
            skipped.append({"id": replay["id"], "reason": "duplicate"})
            continue
        candidates.append(replay)
        existing_ids.add(replay["id"])
        existing_semantic.add(replay["semantic_key"])

    applied = False
    if args.apply and candidates:
        updated = dict(corpus) if isinstance(corpus, dict) else {"schema_version": 1}
        updated["cases"] = list(existing) + candidates
        CORPUS.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        applied = True

    report = {
        "bot": "v26",
        "status": "passed",
        "source": str(MINIMIZED),
        "corpus": str(CORPUS),
        "candidates": candidates,
        "candidate_count": len(candidates),
        "duplicates_skipped": skipped,
        "applied": applied,
        "mode": "apply" if args.apply else "ci_proposal",
        "note": "CI is read-only by policy; candidates are emitted as an artifact. --apply performs the deterministic source update when explicitly invoked.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PLAYER_BOT_V26_OK candidates={len(candidates)} duplicates={len(skipped)} applied={applied}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
