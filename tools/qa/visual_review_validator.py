#!/usr/bin/env python3
"""Validate an Art Bible comparison report for the vertical slice."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/visual_vertical_slice.json"


def validate_review(review: dict, contract: dict) -> list[str]:
    errors: list[str] = []
    cfg = contract["visual_review"]
    criteria = cfg["criteria"]
    scores = review.get("scores", {})
    for criterion in criteria:
        value = scores.get(criterion)
        if value is None:
            errors.append(f"missing score: {criterion}")
            continue
        if not isinstance(value, (int, float)) or value < 0 or value > 5:
            errors.append(f"invalid score: {criterion}")
    if errors:
        return errors
    average = sum(float(scores[c]) for c in criteria) / len(criteria)
    if average < float(cfg["passing_average"]):
        errors.append(f"average below threshold: {average:.2f}")
    for criterion in cfg["blocking_criteria"]:
        if float(scores[criterion]) < 4.0:
            errors.append(f"blocking criterion below 4: {criterion}")
    if not bool(review.get("approved", False)):
        errors.append("human review not approved")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("review", type=Path)
    parser.add_argument("--contract", type=Path, default=CONTRACT_PATH)
    args = parser.parse_args()
    contract = json.loads(args.contract.read_text(encoding="utf-8"))
    review = json.loads(args.review.read_text(encoding="utf-8"))
    errors = validate_review(review, contract)
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("VISUAL_REVIEW_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
