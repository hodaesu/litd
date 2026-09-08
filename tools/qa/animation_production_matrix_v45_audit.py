#!/usr/bin/env python3
"""Static quality gate for LITD animation production matrix v45."""
from __future__ import annotations

import json
from pathlib import Path

from tools.blender.generate_animation_production_matrix_v45 import build_payload
from tools.blender.generate_systemic_animation_v44 import build_payload as build_v44

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/blender/animation_production_matrix_v45.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def audit() -> list[str]:
    errors: list[str] = []
    contract = _load(CONTRACT_PATH)
    payload = build_payload(ROOT)
    v44 = build_v44(ROOT)

    if int(contract.get("version", 0)) != 45:
        errors.append("contract version must be 45")
    if int(payload.get("version", 0)) != 45:
        errors.append("generated payload version must be 45")
    if int(payload.get("source_version", 0)) != 44:
        errors.append("v45 must be generated from v44")
    if payload.get("gameplay_neutral") is not True:
        errors.append("v45 must remain gameplay-neutral")

    requests = payload.get("requests", [])
    masters = payload.get("masters", [])
    requested_count = sum(len(job.get("actions", [])) for job in v44.get("jobs", []))
    if len(requests) != requested_count:
        errors.append(f"v44 coverage mismatch: expected {requested_count}, got {len(requests)}")
    if not requests or not masters:
        errors.append("matrix must contain requests and master clips")

    master_by_key = {str(master.get("canonical_clip_key", "")): master for master in masters}
    if len(master_by_key) != len(masters):
        errors.append("duplicate canonical master clip key detected")

    valid_families = set(contract.get("retarget_families", {}))
    valid_modes = set(contract.get("production_modes", {}))
    valid_priorities = set(contract.get("priority_tiers", {}))
    request_pairs: set[tuple[str, str]] = set()
    shared_keys_by_character: dict[str, set[str]] = {}

    for request in requests:
        character_id = str(request.get("character_id", ""))
        action = str(request.get("action", ""))
        key = str(request.get("canonical_clip_key", ""))
        family = str(request.get("retarget_family", ""))
        mode = str(request.get("production_mode", ""))
        priority = str(request.get("priority", ""))
        budget = str(request.get("mobile_budget_tag", ""))
        pair = (character_id, action)

        if not character_id or not action:
            errors.append("every request needs character_id and action")
        if pair in request_pairs:
            errors.append(f"duplicate per-character action request: {character_id}/{action}")
        request_pairs.add(pair)
        if key not in master_by_key:
            errors.append(f"request points to missing master: {key}")
        if family not in valid_families:
            errors.append(f"unknown retarget family: {family}")
        if mode not in valid_modes:
            errors.append(f"unknown production mode: {mode}")
        if priority not in valid_priorities:
            errors.append(f"unknown priority: {priority}")
        if not budget:
            errors.append(f"missing mobile budget tag: {character_id}/{action}")
        if int(request.get("source_version", 0)) != 44:
            errors.append(f"wrong source version: {character_id}/{action}")
        if mode == "BESPOKE" and not str(request.get("bespoke_reason", "")):
            errors.append(f"bespoke request without reason: {character_id}/{action}")
        if mode != "BESPOKE":
            if character_id in key:
                errors.append(f"shared clip key must not be character-specific: {key}")
            shared_keys_by_character.setdefault(character_id, set()).add(key)

    for master in masters:
        key = str(master.get("canonical_clip_key", ""))
        consumers = master.get("consumers", [])
        if not consumers:
            errors.append(f"master has no consumers: {key}")
        if int(master.get("reuse_count", 0)) != len(set(consumers)):
            errors.append(f"master reuse_count mismatch: {key}")
        if str(master.get("production_mode", "")) == "BESPOKE" and not str(master.get("bespoke_reason", "")):
            errors.append(f"bespoke master without reason: {key}")

    minimum_reuse = float(contract.get("quality_gates", {}).get("minimum_reuse_ratio", 0.0))
    reuse = float(payload.get("reuse_ratio", 0.0))
    if reuse < minimum_reuse:
        errors.append(f"reuse ratio too low: {reuse:.3f} < {minimum_reuse:.3f}")

    priority_summary = payload.get("priority_summary", {})
    if int(priority_summary.get("P0", 0)) <= 0:
        errors.append("P0 playtest tier is empty")
    if int(priority_summary.get("P1", 0)) <= 0:
        errors.append("P1 vertical-slice tier is empty")

    budget = payload.get("mobile_budget", {})
    if int(budget.get("target_fps", 0)) != 60:
        errors.append("mobile target must remain 60 fps")
    if int(budget.get("minimum_fps", 0)) < 30:
        errors.append("mobile minimum fps cannot be below 30")
    if not bool(budget.get("prefer_retarget_over_character_copy", False)):
        errors.append("mobile budget must prefer retargeting")

    skill_policy = payload.get("skill_animation_policy", {})
    if str(skill_policy.get("ultimate", "")) != "BESPOKE":
        errors.append("ultimates must remain bespoke")
    if str(skill_policy.get("normal_skill_default", "")) == "":
        errors.append("normal skill animation policy missing")

    expected_characters = {str(job.get("character_id", "")) for job in v44.get("jobs", [])}
    represented_characters = {str(request.get("character_id", "")) for request in requests}
    if represented_characters != expected_characters:
        missing = sorted(expected_characters - represented_characters)
        extra = sorted(represented_characters - expected_characters)
        errors.append(f"character coverage mismatch missing={missing} extra={extra}")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"V45_AUDIT_ERROR: {error}")
        return 1
    payload = build_payload(ROOT)
    print(
        "ANIMATION_PRODUCTION_V45_AUDIT_OK "
        f"requests={payload['requested_actions']} masters={payload['master_clips']} "
        f"avoided={payload['avoided_duplicate_clips']} reuse={payload['reuse_ratio']:.1%} "
        f"P0={payload['priority_summary']['P0']} P1={payload['priority_summary']['P1']} P2={payload['priority_summary']['P2']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
