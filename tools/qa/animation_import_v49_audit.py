#!/usr/bin/env python3
"""Static audit for the Godot P0 animation import manifest v49."""
from __future__ import annotations

from pathlib import Path

from tools.blender.generate_animation_export_plan_v48 import build_payload as build_v48
from tools.godot.generate_animation_import_manifest_v49 import build_payload

ROOT = Path(__file__).resolve().parents[2]


def audit() -> list[str]:
    errors: list[str] = []
    payload = build_payload(ROOT)
    v48 = build_v48(ROOT)
    bundles = payload.get("bundles", [])
    expected = {
        str(key)
        for item in v48.get("bundles", [])
        for key in item.get("expected_actions", [])
    }
    actual = [
        str(key)
        for item in bundles
        for key in item.get("expected_animations", [])
    ]
    if int(payload.get("version", 0)) != 49 or int(payload.get("source_version", 0)) != 48:
        errors.append("v49 must be sourced from v48")
    if int(payload.get("bundle_count", 0)) != 12 or len(bundles) != 12:
        errors.append("v49 must validate exactly 12 GLB bundles")
    if int(payload.get("master_clip_count", 0)) != 320 or len(actual) != 320:
        errors.append("v49 must validate exactly 320 P0 animations")
    if set(actual) != expected or len(set(actual)) != 320:
        errors.append("v49 expected animations must match v48 exactly once")
    for item in bundles:
        if not str(item.get("resource_path", "")).startswith("res://"):
            errors.append(f"non-Godot resource path: {item.get('bundle_id')}")
        if int(item.get("expected_animation_count", -1)) != len(item.get("expected_animations", [])):
            errors.append(f"animation count mismatch: {item.get('bundle_id')}")
    contract = payload.get("godot_import_contract", {})
    for key in ("validate_every_expected_animation", "block_on_missing_glb", "block_on_missing_animation"):
        if contract.get(key) is not True:
            errors.append(f"Godot import gate must be true: {key}")
    validator = ROOT / "tools/godot/animation_import_validator_v49.gd"
    if not validator.exists():
        errors.append("Godot runtime validator script is missing")
    if payload.get("gameplay_neutral") is not True:
        errors.append("v49 must remain gameplay-neutral")
    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"V49_AUDIT_ERROR: {error}")
        return 1
    payload = build_payload(ROOT)
    print(f"ANIMATION_IMPORT_V49_AUDIT_OK bundles={payload['bundle_count']} clips={payload['master_clip_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
