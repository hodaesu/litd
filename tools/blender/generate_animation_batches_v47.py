#!/usr/bin/env python3
"""Build the deterministic P0 Blender production order for LITD Les Veilleurs v47."""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from tools.blender.generate_animation_production_matrix_v46 import build_payload as build_v46

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/blender/animation_batches_v47.json"
MAX_BATCH_CLIPS = 12

FAMILY_ORDER = [
    "humanoid_standard",
    "construct_biped",
    "humanoid_massive",
    "quadruped",
    "insectoid",
    "serpentine",
    "amorphous",
    "boss_custom",
]
BOSS_ORDER = [
    "ishar_gardien_du_passage",
    "orateur_sans_voix",
    "mere_des_veines",
    "porte_cendres_blanc",
    "le_copiste",
]
ROLE_ORDER = ["base", "global_state", "equipment_fallback", "pose", "transition", "locomotion"]
STATE_ORDER = ["F0", "F1", "F2", "adaptive", "F3", "F4"]


def _rank(value: str, ordered: list[str]) -> int:
    try:
        return ordered.index(value)
    except ValueError:
        return len(ordered)


def _wave(master: dict) -> str:
    state = str(master.get("state", ""))
    role = str(master.get("role", ""))
    if state == "F3":
        return "W2_F3_INJURY"
    if state == "F4":
        return "W3_F4_LOSS"
    if str(master.get("retarget_family", "")) == "boss_custom":
        return "W4_BOSS_CUSTOM"
    if role == "equipment_fallback":
        return "W1_CORE"
    return "W1_CORE"


def _wave_rank(value: str) -> int:
    return {"W1_CORE": 0, "W2_F3_INJURY": 1, "W3_F4_LOSS": 2, "W4_BOSS_CUSTOM": 3}.get(value, 99)


def _sort_key(master: dict) -> tuple:
    family = str(master.get("retarget_family", ""))
    owner = str(master.get("owner_character_id", ""))
    boss_rank = _rank(owner, BOSS_ORDER) if family == "boss_custom" else -1
    return (
        _wave_rank(_wave(master)),
        _rank(family, FAMILY_ORDER),
        boss_rank,
        _rank(str(master.get("role", "")), ROLE_ORDER),
        _rank(str(master.get("state", "")), STATE_ORDER),
        -int(master.get("reuse_count", 0)),
        str(master.get("canonical_clip_key", "")),
    )


def _bundle_key(master: dict) -> str:
    family = str(master.get("retarget_family", ""))
    if family == "boss_custom":
        return f"boss_custom/{master.get('owner_character_id', '')}"
    return family


def build_payload(root: Path = ROOT) -> dict:
    v46 = build_v46(root)
    masters = [dict(item) for item in v46.get("masters", []) if item.get("priority") == "P0"]
    ordered = sorted(masters, key=_sort_key)
    batches: list[dict] = []
    sequence = 1

    current: list[dict] = []
    current_group: tuple[str, str] | None = None

    def flush() -> None:
        nonlocal current, current_group, sequence
        if not current or current_group is None:
            return
        wave, bundle = current_group
        family = str(current[0].get("retarget_family", ""))
        owner = str(current[0].get("owner_character_id", "")) if family == "boss_custom" else ""
        batch_id = f"P0-{sequence:03d}-{wave.lower()}-{bundle.replace('/', '-') }"
        batches.append({
            "sequence": sequence,
            "batch_id": batch_id,
            "priority": "P0",
            "wave": wave,
            "retarget_family": family,
            "source_bundle": bundle,
            "owner_character_id": owner,
            "clip_count": len(current),
            "clips": [
                {
                    "canonical_clip_key": item["canonical_clip_key"],
                    "source_action": item["source_action"],
                    "role": item["role"],
                    "state": item["state"],
                    "production_mode": item["production_mode"],
                    "semantic_part": item["semantic_part"],
                    "reuse_count": item["reuse_count"],
                    "consumers": item["consumers"],
                    "mobile_budget_tag": item["mobile_budget_tag"],
                }
                for item in current
            ],
            "production_contract": {
                "max_clips_per_batch": MAX_BATCH_CLIPS,
                "author_master_only": True,
                "retarget_after_master_validation": family != "boss_custom",
                "visual_review_required": True,
                "mobile_preview_required": True,
            },
        })
        sequence += 1
        current = []
        current_group = None

    for master in ordered:
        group = (_wave(master), _bundle_key(master))
        if current and (group != current_group or len(current) >= MAX_BATCH_CLIPS):
            flush()
        if not current:
            current_group = group
        current.append(master)
    flush()

    wave_summary = Counter(batch["wave"] for batch in batches for _ in batch["clips"])
    family_summary = Counter(batch["retarget_family"] for batch in batches for _ in batch["clips"])
    return {
        "version": 47,
        "generator": "tools/blender/generate_animation_batches_v47.py",
        "source_version": 46,
        "priority": "P0",
        "canonical_cast_count": int(v46.get("cast_count", 0)),
        "master_clip_count": len(ordered),
        "batch_count": len(batches),
        "max_clips_per_batch": MAX_BATCH_CLIPS,
        "ordering_policy": {
            "waves": ["W1_CORE", "W2_F3_INJURY", "W3_F4_LOSS", "W4_BOSS_CUSTOM"],
            "families": FAMILY_ORDER,
            "bosses": BOSS_ORDER,
            "within_group": "role_then_state_then_highest_reuse_then_canonical_key",
        },
        "wave_summary": dict(wave_summary),
        "family_summary": dict(family_summary),
        "batches": batches,
        "definition_of_done": [
            "all_320_p0_master_clips_authored_or_validated",
            "all_shared_clips_retargeted_to_every_declared_consumer",
            "f3_visual_pose_and_transition_verified",
            "f4_body_loss_and_equipment_fallback_verified",
            "all_five_boss_p0_sets_reviewed_as_bespoke",
            "mobile_preview_passes_without_gameplay_displacement_from_animation",
        ],
        "gameplay_neutral": True,
    }


def render(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    payload = build_payload()
    if args.summary:
        print(json.dumps({
            "master_clip_count": payload["master_clip_count"],
            "batch_count": payload["batch_count"],
            "wave_summary": payload["wave_summary"],
            "family_summary": payload["family_summary"],
        }, ensure_ascii=False, indent=2))
        return 0
    expected = render(payload)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("animation batches v47 output is out of date")
        print("animation batches v47 are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"generated {payload['batch_count']} P0 batches covering {payload['master_clip_count']} master clips")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
