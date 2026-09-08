#!/usr/bin/env python3
"""Static quality gate for the twelve Blender master-model production dossiers v51."""
from __future__ import annotations

import json
from pathlib import Path

from tools.blender.generate_animation_export_plan_v48 import build_payload as build_v48

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "data/blender/master_models_v51/index.json"
CAST = ROOT / "data/blender/canonical_cast_v46.json"
BODY = ROOT / "data/body_visual_runtime_v42.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_morphology(name: str, body: dict) -> dict:
    morphologies = body.get("morphologies", {})
    if name not in morphologies:
        raise KeyError(name)
    raw = dict(morphologies[name])
    parent = str(raw.get("inherit", ""))
    if not parent:
        return raw
    merged = resolve_morphology(parent, body)
    merged.update(raw)
    merged.pop("inherit", None)
    return merged


def audit() -> list[str]:
    errors: list[str] = []
    index = load(INDEX)
    cast = load(CAST)
    body = load(BODY)
    v48 = build_v48(ROOT)

    entries = index.get("production_order", [])
    if len(entries) != 12:
        errors.append(f"expected 12 master specs, got {len(entries)}")
    orders = [int(item.get("order", 0)) for item in entries]
    if orders != list(range(1, 13)):
        errors.append(f"production order must be 1..12, got {orders}")

    canonical_items = [
        *cast.get("cast", {}).get("veilleurs", []),
        *cast.get("cast", {}).get("species", []),
        *cast.get("cast", {}).get("bosses", []),
    ]
    canonical_ids = {str(item.get("id", "")) for item in canonical_items}
    canonical_by_id = {str(item.get("id", "")): item for item in canonical_items}
    if len(canonical_ids) != 33:
        errors.append(f"canonical cast must contain 33 unique ids, got {len(canonical_ids)}")

    specs: list[dict] = []
    covered: list[str] = []
    for entry in entries:
        path = ROOT / str(entry.get("spec", ""))
        if not path.exists():
            errors.append(f"missing master dossier: {path.relative_to(ROOT)}")
            continue
        spec = load(path)
        specs.append(spec)
        if int(spec.get("version", 0)) != 51:
            errors.append(f"{path.name}: version must be 51")
        if int(spec.get("order", 0)) != int(entry.get("order", 0)):
            errors.append(f"{path.name}: order mismatch")
        if str(spec.get("id", "")) != str(entry.get("id", "")):
            errors.append(f"{path.name}: id mismatch")
        if spec.get("gameplay_neutral") is not True:
            errors.append(f"{path.name}: production spec must remain gameplay-neutral")
        source = str(spec.get("source_blend", ""))
        if not source.endswith(".blend"):
            errors.append(f"{path.name}: source_blend must target a real .blend path")
        covered.extend(str(value) for value in spec.get("cast_coverage", []))

        if str(spec.get("master_kind", "")) == "shared_retarget_master":
            for morphology in spec.get("runtime_morphologies", []):
                try:
                    runtime = resolve_morphology(str(morphology), body)
                except KeyError:
                    errors.append(f"{path.name}: unknown runtime morphology {morphology}")
                    continue
                runtime_parts = set(str(value) for value in runtime.get("parts", []))
                spec_parts = set(str(value) for value in spec.get("body_segments", []))
                if runtime_parts and not runtime_parts.issubset(spec_parts):
                    errors.append(
                        f"{path.name}: missing runtime parts for {morphology}: {sorted(runtime_parts - spec_parts)}"
                    )
        elif str(spec.get("master_kind", "")) == "bespoke_boss_master":
            owner = str(spec.get("owner_character_id", ""))
            item = canonical_by_id.get(owner, {})
            canonical_parts = set(str(value) for value in item.get("anatomy_parts", []))
            spec_parts = set(str(value) for value in spec.get("body_segments", []))
            if not canonical_parts or spec_parts != canonical_parts:
                errors.append(
                    f"{path.name}: boss parts differ from canonical cast; expected={sorted(canonical_parts)} got={sorted(spec_parts)}"
                )
        else:
            errors.append(f"{path.name}: unknown master_kind")

    if set(covered) != canonical_ids:
        errors.append(
            f"cast coverage mismatch missing={sorted(canonical_ids - set(covered))} "
            f"extra={sorted(set(covered) - canonical_ids)}"
        )
    duplicates = sorted({value for value in covered if covered.count(value) > 1})
    if duplicates:
        errors.append(f"canonical entities assigned to multiple masters: {duplicates}")

    spec_sources = {str(spec.get("source_blend", "")) for spec in specs}
    v48_sources = {str(bundle.get("source_blend", "")) for bundle in v48.get("bundles", [])}
    if spec_sources != v48_sources:
        errors.append(
            f"v51 source paths must exactly match v48; missing={sorted(v48_sources - spec_sources)} "
            f"extra={sorted(spec_sources - v48_sources)}"
        )

    if len([spec for spec in specs if spec.get("master_kind") == "shared_retarget_master"]) != 7:
        errors.append("expected exactly seven shared retarget masters")
    if len([spec for spec in specs if spec.get("master_kind") == "bespoke_boss_master"]) != 5:
        errors.append("expected exactly five bespoke boss masters")

    copiste = next((spec for spec in specs if spec.get("id") == "boss_le_copiste"), {})
    forbidden_colors = {str(value).lower() for value in copiste.get("visual_direction", {}).get("absolute_forbidden_colors", [])}
    if not {"purple", "violet", "magenta", "lilac"}.issubset(forbidden_colors):
        errors.append("Le Copiste must explicitly forbid purple/violet/magenta/lilac")
    if "sci-fi reactor" not in str(copiste.get("visual_direction", {}).get("copy_matrix", "")).lower() and "sci-fi" not in str(copiste).lower():
        errors.append("Le Copiste dossier must explicitly reject sci-fi reactor treatment")

    ishar = next((spec for spec in specs if spec.get("id") == "boss_ishar"), {})
    ishar_forbidden = " ".join(str(value).lower() for value in ishar.get("visual_direction", {}).get("forbidden", []))
    for word in ("cables", "pistons", "sleek_robotics"):
        if word not in ishar_forbidden:
            errors.append(f"Ishar anti-sci-fi constraint missing: {word}")

    truth_rule = str(index.get("truth_rule", ""))
    if ".blend" not in truth_rule or "JSON" not in truth_rule:
        errors.append("index must preserve the distinction between prepared dossiers and real Blender assets")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"MASTER_MODELS_V51_AUDIT_ERROR: {error}")
        return 1
    print("MASTER_MODELS_V51_AUDIT_OK masters=12 shared=7 bosses=5 cast=33")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
