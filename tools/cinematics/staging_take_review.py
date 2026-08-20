#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
BLOCKING = ROOT / "data/demo_cinematic_blocking.json"
DEFAULT_OUTPUT = ROOT / "reports/staging-take-review.json"

CRITERIA = [
    "physical_objective_readability",
    "character_body_identity",
    "listener_reaction_truth",
    "gesture_economy",
    "proxemic_clarity",
    "blocking_readability",
    "camera_motivation",
    "shot_continuity",
    "subtext_body_voice_camera_alignment",
    "gameplay_handoff_clarity",
]


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def template() -> dict[str, Any]:
    scenes = _load(BLOCKING).get("scenes", [])
    return {
        "version": 1,
        "design_source": "physical_cinematic_direction_pass_32",
        "human_visual_review_required": True,
        "scale": [1, 2, 3, 4, 5],
        "pass_rule": "average >= 4.0 and no blocking criterion below 3",
        "criteria": CRITERIA,
        "reviews": [
            {
                "scene_id": str(scene.get("id", "")),
                "take_id": "pending",
                "scores": {criterion: 0 for criterion in CRITERIA},
                "notes": [],
                "approved": False,
            }
            for scene in scenes
            if isinstance(scene, dict)
        ],
    }


def validate(payload: dict[str, Any]) -> None:
    if payload.get("human_visual_review_required") is not True:
        raise ValueError("human visual review must remain required")
    if payload.get("criteria") != CRITERIA:
        raise ValueError("review criteria drifted")
    for review in payload.get("reviews", []):
        if not isinstance(review, dict):
            raise ValueError("review entry must be an object")
        scores = review.get("scores", {})
        if set(scores) != set(CRITERIA):
            raise ValueError(f"{review.get('scene_id')}: incomplete scores")
        values = [int(scores[key]) for key in CRITERIA]
        if any(value < 0 or value > 5 for value in values):
            raise ValueError(f"{review.get('scene_id')}: scores must be 0..5 while pending, 1..5 once reviewed")
        if review.get("approved") is True:
            if any(value == 0 for value in values):
                raise ValueError(f"{review.get('scene_id')}: approved take has pending score")
            average = sum(values) / len(values)
            if average < 4.0 or min(values) < 3:
                raise ValueError(f"{review.get('scene_id')}: approved take does not meet threshold")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or validate a human staging/cinematic take review")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT.relative_to(ROOT)))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--review", default="")
    args = parser.parse_args()

    if args.review:
        path = Path(args.review)
        if not path.is_absolute():
            path = ROOT / path
        payload = _load(path)
        validate(payload)
        print(f"STAGING_REVIEW_OK: {len(payload.get('reviews', []))} review(s)")
        return 0

    payload = template()
    validate(payload)
    if args.check:
        if len(payload["reviews"]) < 6:
            raise SystemExit("STAGING_REVIEW_ERROR: expected all demo staging scenes")
        print(f"STAGING_REVIEW_TEMPLATE_OK: {len(payload['reviews'])} scene(s)")
        return 0

    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"STAGING_REVIEW_TEMPLATE_WRITTEN: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
