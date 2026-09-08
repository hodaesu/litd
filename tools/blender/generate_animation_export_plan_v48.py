#!/usr/bin/env python3
"""Generate the PC/Blender export bundle plan for canonical P0 animations v48."""
from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from pathlib import Path

from tools.blender.generate_animation_batches_v47 import build_payload as build_v47

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/blender/animation_export_plan_v48.json"


def _slug(bundle: str) -> str:
    return bundle.replace("/", "__")


def build_payload(root: Path = ROOT) -> dict:
    v47 = build_v47(root)
    grouped: OrderedDict[str, dict] = OrderedDict()
    for batch in v47.get("batches", []):
        bundle = str(batch["source_bundle"])
        item = grouped.setdefault(bundle, {
            "source_bundle": bundle,
            "retarget_family": str(batch["retarget_family"]),
            "owner_character_id": str(batch.get("owner_character_id", "")),
            "batch_ids": [],
            "clips": [],
        })
        item["batch_ids"].append(str(batch["batch_id"]))
        item["clips"].extend(str(clip["canonical_clip_key"]) for clip in batch.get("clips", []))

    bundles: list[dict] = []
    for sequence, (bundle, item) in enumerate(grouped.items(), 1):
        family = str(item["retarget_family"])
        owner = str(item["owner_character_id"])
        slug = _slug(bundle)
        if family == "boss_custom":
            source_blend = f"art/blender/bosses/{owner}/{owner}_animation_master.blend"
        else:
            source_blend = f"art/blender/animation_masters/{family}.blend"
        bundles.append({
            "sequence": sequence,
            "bundle_id": f"P0B-{sequence:02d}-{slug}",
            "source_bundle": bundle,
            "retarget_family": family,
            "owner_character_id": owner,
            "source_blend": source_blend,
            "output_glb": f"art/generated/animations/p0/{slug}.glb",
            "sidecar_json": f"art/generated/animations/p0/{slug}.clips.json",
            "batch_ids": item["batch_ids"],
            "clip_count": len(item["clips"]),
            "expected_actions": item["clips"],
            "action_identity": "Blender Action.name or custom property litd_canonical_clip_key must equal canonical_clip_key",
            "minimum_keyframes_per_action": 2,
            "block_export_on_missing_or_empty_action": True,
            "visual_review_required_before_export": True,
        })

    clips = [clip for bundle in bundles for clip in bundle["expected_actions"]]
    return {
        "version": 48,
        "generator": "tools/blender/generate_animation_export_plan_v48.py",
        "source_version": 47,
        "priority": "P0",
        "bundle_count": len(bundles),
        "batch_count": int(v47.get("batch_count", 0)),
        "master_clip_count": len(clips),
        "source_asset_policy": {
            "source_blends_are_artist_authored": True,
            "ci_must_not_fake_missing_blend_files": True,
            "missing_source_blend_is_a_pc_art_blocker": True,
        },
        "export_contract": {
            "format": "GLB",
            "animations": True,
            "root_motion": "gameplay_authoritative_minimal_animation_root_motion",
            "canonical_action_names_preserved": True,
            "sidecar_required": True,
        },
        "pc_commands": {
            "preflight": "python -m tools.blender.run_animation_export_v48 --preflight",
            "dry_run": "python -m tools.blender.run_animation_export_v48 --dry-run",
            "execute": "python -m tools.blender.run_animation_export_v48 --execute",
        },
        "bundles": bundles,
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
            "bundle_count": payload["bundle_count"],
            "batch_count": payload["batch_count"],
            "master_clip_count": payload["master_clip_count"],
            "bundles": [
                {"bundle_id": item["bundle_id"], "clips": item["clip_count"], "source": item["source_blend"]}
                for item in payload["bundles"]
            ],
        }, ensure_ascii=False, indent=2))
        return 0
    expected = render(payload)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("animation export plan v48 output is out of date")
        print("animation export plan v48 is current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"generated {payload['bundle_count']} Blender bundles covering {payload['master_clip_count']} P0 clips")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
