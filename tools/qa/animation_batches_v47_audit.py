#!/usr/bin/env python3
"""Static audit for the v47 canonical P0 Blender batch order."""
from __future__ import annotations

from collections import Counter
from pathlib import Path

from tools.blender.generate_animation_batches_v47 import (
    BOSS_ORDER,
    FAMILY_ORDER,
    MAX_BATCH_CLIPS,
    build_payload,
)
from tools.blender.generate_animation_production_matrix_v46 import build_payload as build_v46

ROOT = Path(__file__).resolve().parents[2]


def audit() -> list[str]:
    errors: list[str] = []
    payload = build_payload(ROOT)
    v46 = build_v46(ROOT)
    expected = {
        str(item.get("canonical_clip_key", ""))
        for item in v46.get("masters", [])
        if item.get("priority") == "P0"
    }
    batches = payload.get("batches", [])
    actual: list[str] = []

    if int(payload.get("version", 0)) != 47 or int(payload.get("source_version", 0)) != 46:
        errors.append("v47 must be sourced from v46")
    if int(payload.get("canonical_cast_count", 0)) != 33:
        errors.append("v47 must remain bound to the 33-entity canonical cast")
    if len(expected) != 320:
        errors.append(f"v46 P0 master count changed: expected 320, got {len(expected)}")
    if int(payload.get("master_clip_count", 0)) != len(expected):
        errors.append("v47 master clip count mismatch")
    if int(payload.get("batch_count", 0)) != len(batches) or not batches:
        errors.append("v47 batch count mismatch or empty batch list")
    if int(payload.get("max_clips_per_batch", 0)) != MAX_BATCH_CLIPS:
        errors.append("v47 batch size contract mismatch")

    expected_sequence = list(range(1, len(batches) + 1))
    if [int(batch.get("sequence", 0)) for batch in batches] != expected_sequence:
        errors.append("batch sequence must be contiguous from 1")

    seen_batch_ids: set[str] = set()
    wave_order = {name: index for index, name in enumerate(payload["ordering_policy"]["waves"])}
    family_order = {name: index for index, name in enumerate(FAMILY_ORDER)}
    previous_order = (-1, -1)

    for batch in batches:
        batch_id = str(batch.get("batch_id", ""))
        if not batch_id or batch_id in seen_batch_ids:
            errors.append(f"invalid or duplicate batch id: {batch_id}")
        seen_batch_ids.add(batch_id)
        clips = batch.get("clips", [])
        if not clips or len(clips) > MAX_BATCH_CLIPS:
            errors.append(f"invalid clip count in {batch_id}: {len(clips)}")
        if int(batch.get("clip_count", -1)) != len(clips):
            errors.append(f"declared clip count mismatch in {batch_id}")
        if batch.get("priority") != "P0":
            errors.append(f"non-P0 batch found: {batch_id}")
        contract = batch.get("production_contract", {})
        if contract.get("visual_review_required") is not True or contract.get("mobile_preview_required") is not True:
            errors.append(f"review/mobile gate missing in {batch_id}")

        family = str(batch.get("retarget_family", ""))
        wave = str(batch.get("wave", ""))
        current_order = (wave_order.get(wave, 99), family_order.get(family, 99))
        if current_order < previous_order and wave != "W4_BOSS_CUSTOM":
            errors.append(f"non-deterministic wave/family ordering at {batch_id}")
        previous_order = current_order
        if family == "boss_custom":
            owner = str(batch.get("owner_character_id", ""))
            if owner not in BOSS_ORDER:
                errors.append(f"unknown boss owner in {batch_id}: {owner}")
            if str(batch.get("source_bundle", "")) != f"boss_custom/{owner}":
                errors.append(f"boss source bundle mismatch in {batch_id}")
        elif str(batch.get("owner_character_id", "")):
            errors.append(f"shared family batch must not lock a character owner: {batch_id}")

        for clip in clips:
            key = str(clip.get("canonical_clip_key", ""))
            actual.append(key)
            if not key or key not in expected:
                errors.append(f"unknown P0 master clip in {batch_id}: {key}")
            if not clip.get("production_mode") or not clip.get("mobile_budget_tag"):
                errors.append(f"production metadata missing for {key}")
            if int(clip.get("reuse_count", 0)) <= 0 or not clip.get("consumers"):
                errors.append(f"consumer coverage missing for {key}")

    counts = Counter(actual)
    duplicates = sorted(key for key, count in counts.items() if count != 1)
    if duplicates:
        errors.append(f"P0 master clips must appear exactly once: {duplicates[:5]}")
    if set(actual) != expected:
        errors.append(
            f"P0 coverage mismatch missing={len(expected - set(actual))} extra={len(set(actual) - expected)}"
        )
    if len(actual) != 320:
        errors.append(f"v47 must schedule exactly 320 clips, got {len(actual)}")

    wave_total = sum(int(value) for value in payload.get("wave_summary", {}).values())
    family_total = sum(int(value) for value in payload.get("family_summary", {}).values())
    if wave_total != 320 or family_total != 320:
        errors.append("wave/family summaries must each cover all 320 P0 masters")
    if set(payload.get("family_summary", {})) != set(FAMILY_ORDER):
        errors.append("all eight retarget families must be represented")
    if len(payload.get("definition_of_done", [])) < 6:
        errors.append("v47 needs an explicit production definition of done")
    if payload.get("gameplay_neutral") is not True:
        errors.append("v47 must remain gameplay-neutral")
    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"V47_AUDIT_ERROR: {error}")
        return 1
    payload = build_payload(ROOT)
    print(
        "ANIMATION_BATCHES_V47_AUDIT_OK "
        f"clips={payload['master_clip_count']} batches={payload['batch_count']} "
        f"waves={payload['wave_summary']} families={payload['family_summary']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
