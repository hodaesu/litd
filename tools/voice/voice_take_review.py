#!/usr/bin/env python3
"""Create and score listening-review sheets for emotional voice calibration."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CALIBRATION = ROOT / "data/voice_emotion_calibration.json"
CONTRACT = ROOT / "data/voice_direction_contract.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    calibration = _load(root / "data/voice_emotion_calibration.json")
    contract = _load(root / "data/voice_direction_contract.json")
    emotions = set(contract.get("emotions", {}))
    ids: set[str] = set()
    intensities: set[int] = set()
    for sample in calibration.get("samples", []):
        sample_id = str(sample.get("id", ""))
        if not sample_id or sample_id in ids:
            errors.append(f"duplicate or empty calibration id: {sample_id}")
        ids.add(sample_id)
        emotion = str(sample.get("emotion", ""))
        if emotion not in emotions:
            errors.append(f"{sample_id}: unknown emotion {emotion}")
        intensity = int(sample.get("intensity", 0))
        intensities.add(intensity)
        if intensity not in range(1, 6):
            errors.append(f"{sample_id}: invalid intensity")
        if intensity == 5 and sample.get("manual_review") is not True:
            errors.append(f"{sample_id}: intensity 5 must be manual")
        if not sample.get("expected_cues") or not sample.get("failure_signals"):
            errors.append(f"{sample_id}: missing listening cues")
    if not {1, 2, 3, 4, 5}.issubset(intensities):
        errors.append("calibration corpus must cover intensities 1..5")
    return errors


def build_template(root: Path = ROOT) -> dict[str, Any]:
    calibration = _load(root / "data/voice_emotion_calibration.json")
    return {
        "version": 1,
        "rule": "Écouter sans regarder l'étiquette émotionnelle au premier passage, puis vérifier identité et retenue.",
        "criteria": calibration["review_criteria"],
        "takes": [
            {
                "sample_id": sample["id"],
                "audio_path": "",
                "scores": {criterion: None for criterion in calibration["review_criteria"]},
                "notes": "",
                "approved": False,
            }
            for sample in calibration["samples"]
        ],
    }


def score_review(path: Path, root: Path = ROOT) -> dict[str, Any]:
    calibration = _load(root / "data/voice_emotion_calibration.json")
    review = _load(path)
    criteria = list(calibration["review_criteria"])
    acceptance = calibration["acceptance"]
    results: list[dict[str, Any]] = []
    for take in review.get("takes", []):
        scores = take.get("scores", {})
        values = [int(scores.get(key, 0) or 0) for key in criteria]
        if any(value not in range(1, 6) for value in values):
            raise ValueError(f"{take.get('sample_id')}: every review score must be 1..5")
        average = round(sum(values) / len(values), 2)
        blocking_ok = all(int(scores[key]) >= int(minimum) for key, minimum in acceptance["blocking_min"].items())
        passed = average >= float(acceptance["average_min"]) and blocking_ok and bool(take.get("approved", False))
        results.append({"sample_id": take.get("sample_id"), "average": average, "blocking_ok": blocking_ok, "passed": passed})
    return {"version": 1, "takes": results, "passed": sum(1 for item in results if item["passed"]), "total": len(results)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--template", type=Path)
    parser.add_argument("--score", type=Path)
    parser.add_argument("--output", type=Path, default=Path("reports/voice-calibration-review.json"))
    args = parser.parse_args()
    errors = validate(ROOT)
    if errors:
        for error in errors:
            print("FAIL -", error)
        return 1
    if args.check:
        print("VOICE_CALIBRATION_OK")
        return 0
    if args.template is not None:
        path = args.template if args.template.is_absolute() else ROOT / args.template
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(build_template(ROOT), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"VOICE_CALIBRATION_TEMPLATE_OK: {path}")
        return 0
    if args.score is not None:
        source = args.score if args.score.is_absolute() else ROOT / args.score
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        payload = score_review(source, ROOT)
        output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"VOICE_CALIBRATION_SCORE_OK: {payload['passed']}/{payload['total']} -> {output}")
        return 0
    parser.error("use --check, --template or --score")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
