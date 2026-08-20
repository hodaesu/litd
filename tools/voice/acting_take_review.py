#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.voice.build_dramatic_voice_registry import build_registry

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/voice_acting_contract.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def review_template(line_id: str, root: Path = ROOT) -> dict[str, Any]:
    registry = build_registry(root)
    by_id = {str(item["line_id"]): item for item in registry["entries"]}
    if line_id not in by_id:
        raise ValueError(f"Unknown voice line: {line_id}")
    direction = by_id[line_id]
    rubric = _load(root / "data/voice_acting_contract.json")["review_rubric"]
    variants = direction.get("variants", []) or [{"id": "canonical"}]
    return {
        "version": 1,
        "line_id": line_id,
        "speaker_id": direction["speaker_id"],
        "text": direction["text"],
        "acting_direction": direction,
        "blind_listening_rule": "Si possible, écouter d'abord sans regarder l'étiquette émotionnelle; juger si l'objectif et la relation sont perceptibles.",
        "variant_reviews": [
            {
                "variant_id": variant["id"],
                "scores": {criterion: None for criterion in rubric["criteria"]},
                "notes": "",
                "approved": False,
            }
            for variant in variants
        ],
        "selection": {
            "selected_variant_id": None,
            "reason": "Choisir la prise la plus vraie pour l'objectif et la relation, pas la plus démonstrative émotionnellement."
        },
        "rubric": rubric,
    }


def validate_review(payload: dict[str, Any], root: Path = ROOT) -> dict[str, Any]:
    rubric = _load(root / "data/voice_acting_contract.json")["review_rubric"]
    important = bool(payload.get("acting_direction", {}).get("important", False))
    minimum_each = int(rubric["approval"]["important_line_minimum_each"] if important else rubric["approval"]["minimum_each"])
    minimum_average = float(rubric["approval"]["minimum_average"])
    results = []
    for review in payload.get("variant_reviews", []):
        scores = review.get("scores", {})
        values = []
        missing = []
        for criterion in rubric["criteria"]:
            value = scores.get(criterion)
            if not isinstance(value, int) or value not in rubric["scale"]:
                missing.append(criterion)
            else:
                values.append(value)
        average = round(sum(values) / len(values), 3) if values and not missing else 0.0
        passed = not missing and min(values) >= minimum_each and average >= minimum_average
        results.append({
            "variant_id": review.get("variant_id"),
            "average": average,
            "minimum_score": min(values) if values else 0,
            "missing_or_invalid": missing,
            "passed": passed,
        })
    selected = payload.get("selection", {}).get("selected_variant_id")
    selected_result = next((item for item in results if item["variant_id"] == selected), None)
    return {
        "line_id": payload.get("line_id"),
        "important": important,
        "variant_results": results,
        "selected_variant_id": selected,
        "approved": bool(selected_result and selected_result["passed"]),
        "rule": "Une variante sélectionnée doit réussir la grille de jeu; aucune émotion forte ne compense un objectif, une écoute ou un sous-texte faux."
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or validate LITD dramatic acting take reviews")
    sub = parser.add_subparsers(dest="command")
    template = sub.add_parser("template")
    template.add_argument("--line-id", required=True)
    template.add_argument("--output", default="reports/acting-take-review.json")
    validate = sub.add_parser("validate")
    validate.add_argument("--input", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    if args.check:
        registry = build_registry(ROOT)
        important = [item for item in registry["entries"] if item["important"]]
        if not important or any(len(item["variants"]) < 2 for item in important):
            raise SystemExit("acting take review preflight failed")
        sample = review_template(str(important[0]["line_id"]), ROOT)
        if not sample["variant_reviews"]:
            raise SystemExit("acting review template has no variants")
        print(f"ACTING_TAKE_REVIEW_OK: {len(important)} important line(s)")
        return 0

    if args.command == "template":
        payload = review_template(args.line_id, ROOT)
        out = Path(args.output)
        if not out.is_absolute():
            out = ROOT / out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"ACTING_TAKE_REVIEW_TEMPLATE_WRITTEN: {out}")
        return 0
    if args.command == "validate":
        path = Path(args.input)
        if not path.is_absolute():
            path = ROOT / path
        result = validate_review(_load(path), ROOT)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["approved"] else 1
    parser.error("choose template, validate, or --check")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
