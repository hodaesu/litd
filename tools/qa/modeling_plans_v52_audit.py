#!/usr/bin/env python3
"""Static quality gate for the 12 concrete Blender modeling execution plans v52."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX52 = ROOT / "data/blender/modeling_plans_v52/index.json"
COMMON52 = ROOT / "data/blender/modeling_plans_v52/common_contract.json"
INDEX51 = ROOT / "data/blender/master_models_v51/index.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def audit() -> list[str]:
    errors: list[str] = []
    index52 = load(INDEX52)
    common = load(COMMON52)
    index51 = load(INDEX51)

    entries52 = index52.get("production_order", [])
    entries51 = index51.get("production_order", [])
    if len(entries52) != 12:
        errors.append(f"expected 12 v52 plans, got {len(entries52)}")
    if [int(x.get("order", 0)) for x in entries52] != list(range(1, 13)):
        errors.append("v52 production order must be exactly 1..12")
    ids52 = [str(x.get("id", "")) for x in entries52]
    ids51 = [str(x.get("id", "")) for x in entries51]
    if ids52 != ids51:
        errors.append(f"v52 order/ids must exactly match v51: expected={ids51} got={ids52}")

    if int(common.get("version", 0)) != 52:
        errors.append("common contract must be version 52")
    if common.get("gameplay_neutral") is not True:
        errors.append("common contract must remain gameplay-neutral")
    common_truth = str(common.get("truth_rule", "")).lower()
    if "not a finished 3d model" not in common_truth or "artist-authored" not in common_truth:
        errors.append("common contract must distinguish plans from real artist-authored Blender assets")
    if common.get("naming", {}).get("body") != "BODY_<runtime_part>":
        errors.append("common BODY naming contract changed")
    if common.get("lod_protocol", {}).get("never_merge_across_runtime_damage_boundary") is not True:
        errors.append("LOD protocol must preserve runtime damage boundaries")
    if common.get("animation_preflight", {}).get("do_not_generate_placeholder_actions") is not True:
        errors.append("v52 must explicitly reject placeholder Actions")

    required = set(str(x) for x in index52.get("required_plan_sections", []))
    expected_required = {"blockout", "runtime_objects", "rig_build_order", "materials", "lod_plan", "f3_tests", "f4_tests", "pc_checklist", "done_when"}
    if required != expected_required:
        errors.append(f"required plan sections changed: {sorted(required)}")

    for entry52, entry51 in zip(entries52, entries51):
        plan_path = ROOT / str(entry52.get("plan", ""))
        spec_path = ROOT / str(entry51.get("spec", ""))
        if not plan_path.exists():
            errors.append(f"missing v52 plan: {plan_path.relative_to(ROOT)}")
            continue
        if not spec_path.exists():
            errors.append(f"missing v51 source dossier: {spec_path.relative_to(ROOT)}")
            continue
        plan = load(plan_path)
        spec = load(spec_path)
        label = plan_path.name

        if int(plan.get("version", 0)) != 52:
            errors.append(f"{label}: version must be 52")
        if int(plan.get("order", 0)) != int(entry52.get("order", 0)):
            errors.append(f"{label}: order mismatch")
        if str(plan.get("id", "")) != str(entry52.get("id", "")):
            errors.append(f"{label}: id mismatch")
        if plan.get("gameplay_neutral") is not True:
            errors.append(f"{label}: plan must remain gameplay-neutral")
        if str(plan.get("source_v51", "")) != str(entry51.get("spec", "")):
            errors.append(f"{label}: source_v51 must point to its exact v51 dossier")
        if str(plan.get("source_blend", "")) != str(spec.get("source_blend", "")):
            errors.append(f"{label}: source_blend differs from v51")
        if str(plan.get("common_contract", "")) != "data/blender/modeling_plans_v52/common_contract.json":
            errors.append(f"{label}: wrong common_contract")

        for section in expected_required:
            value = plan.get(section)
            if value in (None, "", [], {}):
                errors.append(f"{label}: empty required section {section}")

        expected_body = {f"BODY_{part}" for part in spec.get("body_segments", [])}
        actual_body = {str(x) for x in plan.get("runtime_objects", [])}
        if actual_body != expected_body:
            errors.append(
                f"{label}: runtime BODY objects differ from v51 anatomy; "
                f"missing={sorted(expected_body - actual_body)} extra={sorted(actual_body - expected_body)}"
            )
        if not str(plan.get("rig_build_order", [""])[0]).startswith("ROOT"):
            errors.append(f"{label}: rig build order must start with ROOT")
        lod = plan.get("lod_plan", {})
        if not all(key in lod for key in ("lod0", "lod1", "lod2")):
            errors.append(f"{label}: LOD0/1/2 plan incomplete")
        if len(plan.get("f3_tests", [])) < 2:
            errors.append(f"{label}: F3 test coverage too small")
        if len(plan.get("f4_tests", [])) < 2:
            errors.append(f"{label}: F4 test coverage too small")
        if len(plan.get("pc_checklist", [])) < 5:
            errors.append(f"{label}: PC checklist must be executable, not a note")
        done = str(plan.get("done_when", "")).lower()
        if "vrai" not in done and "real" not in done:
            errors.append(f"{label}: done_when must refer to the real asset")
        if "godot" not in done:
            errors.append(f"{label}: done_when must include Godot validation")

    ishar = load(ROOT / "data/blender/modeling_plans_v52/08_boss_ishar.json")
    ishar_forbidden = {str(x).lower() for x in ishar.get("materials", {}).get("forbidden", [])}
    for token in ("cables", "pistons", "sleek_robotics", "neon"):
        if token not in ishar_forbidden:
            errors.append(f"Ishar v52 anti-sci-fi constraint missing: {token}")
    anchors = {f"BODY_ANCHOR_{suffix}" for suffix in ("FL", "FR", "RL", "RR")}
    if not anchors.issubset(set(ishar.get("runtime_objects", []))):
        errors.append("Ishar v52 must preserve four independent anchor BODY objects")

    copiste = load(ROOT / "data/blender/modeling_plans_v52/12_boss_le_copiste.json")
    forbidden_colors = {str(x).lower() for x in copiste.get("materials", {}).get("absolute_forbidden_colors", [])}
    if not {"purple", "violet", "magenta", "lilac"}.issubset(forbidden_colors):
        errors.append("Le Copiste v52 must forbid purple/violet/magenta/lilac")
    forbidden_forms = {str(x).lower() for x in copiste.get("materials", {}).get("forbidden_forms", [])}
    if "reactor_core" not in forbidden_forms or "sleek_scifi_armor" not in forbidden_forms:
        errors.append("Le Copiste v52 must explicitly reject reactor/sleek sci-fi treatment")
    if len(copiste.get("color_validation", [])) < 4:
        errors.append("Le Copiste v52 requires an explicit full color audit")
    f4_text = " ".join(str(x).lower() for x in copiste.get("f4_tests", []))
    if "membre virtuel" not in f4_text and "virtual" not in f4_text:
        errors.append("Le Copiste v52 must test that copied Actions cannot invent virtual limbs")

    index_truth = str(index52.get("truth_rule", "")).lower()
    if "does not prove" not in index_truth or ".blend" not in index_truth:
        errors.append("v52 index truth rule must distinguish static validation from real .blend production")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"MODELING_PLANS_V52_AUDIT_ERROR: {error}")
        return 1
    print("MODELING_PLANS_V52_AUDIT_OK plans=12 order=1..12 body_contracts=12 lod=12 f3f4=12")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
