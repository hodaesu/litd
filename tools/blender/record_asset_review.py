#!/usr/bin/env python3
"""Record auditable approval decisions for rendered Blender assets."""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.blender.generate_visual_review_queue import OUTPUT as QUEUE_PATH

DECISIONS = ROOT / "reports/asset_review_decisions.json"


def load_queue(path: Path = QUEUE_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def record_review(job_id: str, gate_results: dict[str, bool], decision: str, note: str,
                  decisions: dict | None = None, queue: dict | None = None, timestamp: str | None = None) -> dict:
    if decision not in ("approved", "changes_requested"):
        raise ValueError("decision must be approved or changes_requested")
    queue = queue or load_queue()
    review = next((item for item in queue["reviews"] if item["job_id"] == job_id), None)
    if review is None:
        raise KeyError(f"unknown visual review job: {job_id}")
    expected = set(review["gates"])
    if set(gate_results) != expected:
        raise ValueError("gate results must cover exactly the job review gates")
    if decision == "approved" and not all(gate_results.values()):
        raise ValueError("an asset cannot be approved while a review gate fails")
    decisions = decisions or {"version": 1, "reviews": {}}
    event = {
        "timestamp": timestamp or datetime.now(timezone.utc).isoformat(),
        "decision": decision, "gates": gate_results, "note": note,
    }
    record = decisions["reviews"].setdefault(job_id, {"history": []})
    record["status"] = decision
    record["history"].append(event)
    return decisions


def build_summary(decisions: dict, queue: dict | None = None) -> dict:
    queue = queue or load_queue()
    statuses = {job_id: record["status"] for job_id, record in decisions.get("reviews", {}).items()}
    counts = {
        "approved": sum(status == "approved" for status in statuses.values()),
        "changes_requested": sum(status == "changes_requested" for status in statuses.values()),
    }
    counts["pending"] = queue["review_count"] - counts["approved"] - counts["changes_requested"]
    return {"total": queue["review_count"], **counts}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("job_id")
    parser.add_argument("--decision", required=True, choices=("approved", "changes_requested"))
    parser.add_argument("--gates", type=Path, required=True, help="JSON object mapping every gate to true/false")
    parser.add_argument("--note", default="")
    parser.add_argument("--output", type=Path, default=DECISIONS)
    args = parser.parse_args()
    current = json.loads(args.output.read_text(encoding="utf-8")) if args.output.exists() else None
    results = json.loads(args.gates.read_text(encoding="utf-8"))
    updated = record_review(args.job_id, results, args.decision, args.note, current)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(build_summary(updated), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
