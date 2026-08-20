#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.voice.build_dramatic_voice_registry import build_registry as build_dramatic_registry
from tools.voice.openvoice_v2_pipeline import build_plan as build_openvoice_plan

ROOT = Path(__file__).resolve().parents[2]


def build_performance_plan(root: Path = ROOT) -> dict[str, Any]:
    base = build_openvoice_plan(root)
    dramatic = build_dramatic_registry(root)
    dramatic_by_id = {str(item["line_id"]): item for item in dramatic["entries"]}
    entries: list[dict[str, Any]] = []
    for raw in base.get("entries", []):
        entry = dict(raw)
        line_id = str(entry["line_id"])
        acting = dramatic_by_id.get(line_id)
        if acting is None:
            raise ValueError(f"{line_id}: missing dramatic voice direction")
        base_speed = float(entry["delivery"]["speed"])
        variants = []
        for variant in acting.get("variants", []):
            multiplier = float(variant.get("speed_multiplier", 1.0))
            variants.append({
                **variant,
                "suggested_melotts_speed": round(max(0.65, min(1.25, base_speed * multiplier)), 3),
                "truth_rule": "La vitesse est un candidat de rendu; objectif, sous-texte, écoute et beats restent des critères de direction et d'écoute humaine.",
            })
        entry["acting_direction"] = acting
        entry["interpretation_variants"] = variants
        entries.append(entry)
    return {
        **base,
        "version": 3,
        "dramatic_direction": {
            "enabled": True,
            "registry_generated_from": "tools/voice/build_dramatic_voice_registry.py",
            "study_protocol": "data/voice_acting_study_protocol.json",
            "emotion_is_consequence": True,
            "important_lines_have_multiple_interpretations": True,
            "human_listening_review_required": True,
            "no_claim_of_neural_retraining": True,
        },
        "entries": entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the complete LITD voice performance plan")
    parser.add_argument("--output", default="reports/voice-performance-plan.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    payload = build_performance_plan(ROOT)
    important = [item for item in payload["entries"] if item["acting_direction"]["important"]]
    if args.check:
        if not payload["entries"] or any(len(item["interpretation_variants"]) < 2 for item in important):
            raise SystemExit("voice performance plan is incomplete")
        print(f"VOICE_PERFORMANCE_PLAN_OK: {len(payload['entries'])} rendered line(s), {len(important)} important")
        return 0
    out = Path(args.output)
    if not out.is_absolute():
        out = ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"VOICE_PERFORMANCE_PLAN_WRITTEN: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
