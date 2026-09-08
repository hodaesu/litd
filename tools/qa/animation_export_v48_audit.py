#!/usr/bin/env python3
"""Static quality gate for the v48 Blender export handoff."""
from __future__ import annotations

from pathlib import Path

from tools.blender.generate_animation_batches_v47 import build_payload as build_v47
from tools.blender.generate_animation_export_plan_v48 import build_payload

ROOT = Path(__file__).resolve().parents[2]


def audit() -> list[str]:
    errors: list[str] = []
    payload = build_payload(ROOT)
    v47 = build_v47(ROOT)
    bundles = payload.get("bundles", [])
    clips = [str(key) for item in bundles for key in item.get("expected_actions", [])]
    expected = {
        str(clip["canonical_clip_key"])
        for batch in v47.get("batches", [])
        for clip in batch.get("clips", [])
    }

    if int(payload.get("version", 0)) != 48 or int(payload.get("source_version", 0)) != 47:
        errors.append("v48 must be sourced from v47")
    if int(payload.get("bundle_count", 0)) != 12 or len(bundles) != 12:
        errors.append(f"expected 12 export bundles (7 shared + 5 boss), got {len(bundles)}")
    if int(payload.get("batch_count", 0)) != 39:
        errors.append(f"expected 39 v47 batches, got {payload.get('batch_count')}")
    if int(payload.get("master_clip_count", 0)) != 320 or len(clips) != 320:
        errors.append(f"expected 320 P0 clips, got {len(clips)}")
    if set(clips) != expected or len(set(clips)) != 320:
        errors.append("v48 clip coverage must match v47 exactly once")

    source_paths = [str(item.get("source_blend", "")) for item in bundles]
    output_paths = [str(item.get("output_glb", "")) for item in bundles]
    if len(set(source_paths)) != 12 or len(set(output_paths)) != 12:
        errors.append("source/output bundle paths must be unique")
    shared = [item for item in bundles if item.get("retarget_family") != "boss_custom"]
    bosses = [item for item in bundles if item.get("retarget_family") == "boss_custom"]
    if len(shared) != 7 or len(bosses) != 5:
        errors.append(f"expected 7 shared and 5 boss bundles, got {len(shared)} and {len(bosses)}")
    if any(item.get("owner_character_id") for item in shared):
        errors.append("shared bundles must not be character-owned")
    if any(not item.get("owner_character_id") for item in bosses):
        errors.append("every boss bundle must be character-owned")
    for item in bundles:
        if int(item.get("clip_count", -1)) != len(item.get("expected_actions", [])):
            errors.append(f"clip count mismatch in {item.get('bundle_id')}")
        if not str(item.get("source_blend", "")).endswith(".blend"):
            errors.append(f"source must be .blend: {item.get('bundle_id')}")
        if not str(item.get("output_glb", "")).endswith(".glb"):
            errors.append(f"output must be .glb: {item.get('bundle_id')}")
        if item.get("block_export_on_missing_or_empty_action") is not True:
            errors.append(f"missing strict action gate: {item.get('bundle_id')}")
    policy = payload.get("source_asset_policy", {})
    if policy.get("ci_must_not_fake_missing_blend_files") is not True:
        errors.append("CI must never fake missing Blender art assets")
    if payload.get("gameplay_neutral") is not True:
        errors.append("v48 must remain gameplay-neutral")
    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"V48_AUDIT_ERROR: {error}")
        return 1
    payload = build_payload(ROOT)
    print(f"ANIMATION_EXPORT_V48_AUDIT_OK bundles={payload['bundle_count']} clips={payload['master_clip_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
