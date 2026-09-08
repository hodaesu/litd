#!/usr/bin/env python3
"""Generate deterministic Blender anatomy-preparation jobs for LITD v43.

Pure Python by design: CI can validate the production plan without Blender.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/blender/anatomical_pipeline_v43.json"
BODY_V42_PATH = ROOT / "data/body_visual_runtime_v42.json"
CHARACTER_JOBS_PATH = ROOT / "data/blender/character_jobs.json"
COMBAT_ANATOMY_PATH = ROOT / "data/combat_anatomy_v2.json"
OUTPUT = ROOT / "data/blender/anatomical_pipeline_jobs_v43.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _resolve_morphology(character_job: dict, contract: dict, body_v42: dict) -> str:
    morphologies = body_v42.get("morphologies", {})
    for field in ("morphology", "anatomy_profile", "body_profile", "anatomy_type"):
        raw = str(character_job.get(field, "")).strip().upper()
        if raw in morphologies:
            return raw
    if bool(character_job.get("boss", False)):
        return "BOSS_CUSTOM"
    rig_profile = str(character_job.get("rig_profile", "")).strip().lower()
    mapped = str(contract.get("rig_to_morphology", {}).get(rig_profile, ""))
    if mapped in morphologies:
        return mapped
    if "humanoid" in rig_profile:
        return "HUMANOID"
    return "BOSS_CUSTOM"


def _resolve_morphology_contract(key: str, body_v42: dict) -> dict:
    morphologies = body_v42.get("morphologies", {})
    raw = dict(morphologies.get(key, morphologies.get("BOSS_CUSTOM", {})))
    parent = str(raw.get("inherit", ""))
    if not parent:
        return raw
    merged = _resolve_morphology_contract(parent, body_v42)
    merged.update(raw)
    merged.pop("inherit", None)
    return merged


def _boss_parts(character_id: str, combat_anatomy: dict) -> list[str]:
    boss = combat_anatomy.get("boss_anatomies", {}).get(character_id, {})
    return [str(part.get("id", "")) for part in boss.get("parts", []) if str(part.get("id", ""))]


def _severable_boss_parts(character_id: str, combat_anatomy: dict) -> set[str]:
    boss = combat_anatomy.get("boss_anatomies", {}).get(character_id, {})
    return {
        str(part.get("id", ""))
        for part in boss.get("parts", [])
        if str(part.get("id", "")) and bool(part.get("severable", True))
    }


def _part_specs(parts: list[str], severable: set[str] | None, marker_contract: dict) -> list[dict]:
    specs: list[dict] = []
    for part in parts:
        can_f4 = True if severable is None else part in severable
        specs.append({
            "part": part,
            "segment": marker_contract["segment_name"].format(part=part),
            "stump": marker_contract["stump_name"].format(part=part) if can_f4 else "",
            "f3_pose": marker_contract["f3_pose_name"].format(part=part),
            "supports_f3": True,
            "supports_f4": can_f4,
        })
    return specs


def build_payload(root: Path = ROOT) -> dict:
    contract = _load(root / CONTRACT_PATH.relative_to(ROOT))
    body_v42 = _load(root / BODY_V42_PATH.relative_to(ROOT))
    characters = _load(root / CHARACTER_JOBS_PATH.relative_to(ROOT))
    combat_anatomy = _load(root / COMBAT_ANATOMY_PATH.relative_to(ROOT))
    marker_contract = contract["marker_contract"]
    jobs: list[dict] = []

    for character in characters.get("jobs", []):
        character_id = str(character["character_id"])
        morphology = _resolve_morphology(character, contract, body_v42)
        morphology_contract = _resolve_morphology_contract(morphology, body_v42)
        parts = [str(value) for value in morphology_contract.get("parts", [])]
        severable: set[str] | None = None
        if morphology == "BOSS_CUSTOM":
            boss_specific = _boss_parts(character_id, combat_anatomy)
            if boss_specific:
                parts = boss_specific
                severable = _severable_boss_parts(character_id, combat_anatomy)
        sockets = dict(marker_contract.get("weapon_sockets", {}))
        jobs.append({
            "job_id": f"anatomy_v43_{character_id}",
            "character_id": character_id,
            "name": character.get("name", character_id),
            "category": character.get("category", "unknown"),
            "boss": bool(character.get("boss", False)),
            "morphology": morphology,
            "source_character_job": character.get("job_id", ""),
            "parts": _part_specs(parts, severable, marker_contract),
            "required_collections": contract["required_collections"],
            "weapon_sockets": sockets if morphology_contract.get("weapon_side_requirements", {}) else {},
            "declared_markers_only": bool(morphology_contract.get("declared_markers_only", False)),
            "gameplay_neutral": True,
            "output_folder": character.get("output", ""),
        })

    return {
        "version": 43,
        "generator": "tools/blender/generate_anatomical_pipeline_v43.py",
        "contract": str(CONTRACT_PATH.relative_to(ROOT)).replace("\\", "/"),
        "body_visual_contract": str(BODY_V42_PATH.relative_to(ROOT)).replace("\\", "/"),
        "jobs": jobs,
    }


def render(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = render(build_payload())
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("anatomical pipeline v43 jobs are out of date; run the generator")
        print("anatomical pipeline v43 jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"generated {len(build_payload()['jobs'])} anatomical Blender jobs v43")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
