#!/usr/bin/env python3
"""Static QA for the automatic Blender anatomy pipeline v43."""
from __future__ import annotations

import json
from pathlib import Path

from tools.blender.generate_anatomical_pipeline_v43 import build_payload

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/blender/anatomical_pipeline_v43.json"
BODY_PATH = ROOT / "data/body_visual_runtime_v42.json"
CHARACTER_JOBS_PATH = ROOT / "data/blender/character_jobs.json"


def audit() -> list[str]:
    errors: list[str] = []
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    body = json.loads(BODY_PATH.read_text(encoding="utf-8"))
    characters = json.loads(CHARACTER_JOBS_PATH.read_text(encoding="utf-8"))
    payload = build_payload()

    if int(contract.get("version", 0)) != 43:
        errors.append("contract version must be 43")
    if not bool(contract.get("gameplay_neutral", False)):
        errors.append("pipeline must remain gameplay-neutral")
    if len(payload.get("jobs", [])) != len(characters.get("jobs", [])):
        errors.append("every character Blender job must have one anatomy v43 job")

    valid_morphologies = set(body.get("morphologies", {}).keys())
    ids: set[str] = set()
    hero_count = 0
    for job in payload.get("jobs", []):
        character_id = str(job.get("character_id", ""))
        if not character_id:
            errors.append("job without character_id")
            continue
        if character_id in ids:
            errors.append(f"duplicate character anatomy job: {character_id}")
        ids.add(character_id)
        if job.get("category") == "hero":
            hero_count += 1
        morphology = str(job.get("morphology", ""))
        if morphology not in valid_morphologies:
            errors.append(f"unsupported morphology for {character_id}: {morphology}")
        if not bool(job.get("gameplay_neutral", False)):
            errors.append(f"job is not gameplay-neutral: {character_id}")
        parts = job.get("parts", [])
        if morphology != "BOSS_CUSTOM" and not parts:
            errors.append(f"no body parts generated for {character_id}")
        if morphology == "BOSS_CUSTOM" and not parts and not bool(job.get("declared_markers_only", False)):
            errors.append(f"custom boss without declared-marker policy: {character_id}")
        for part in parts:
            if not str(part.get("segment", "")).startswith("BODY_"):
                errors.append(f"invalid BODY marker for {character_id}")
            if bool(part.get("supports_f4", False)) and not str(part.get("stump", "")).startswith("STUMP_"):
                errors.append(f"invalid STUMP marker for {character_id}:{part.get('part')}")
            if not str(part.get("f3_pose", "")).startswith("POSE_F3_"):
                errors.append(f"invalid F3 marker for {character_id}:{part.get('part')}")
        sockets = job.get("weapon_sockets", {})
        if sockets:
            if sockets.get("left") != "SOCKET_weapon_l" or sockets.get("right") != "SOCKET_weapon_r":
                errors.append(f"invalid weapon sockets for {character_id}")

    if hero_count < 4:
        errors.append("the four core hero production jobs must be covered")
    required_collections = set(contract.get("required_collections", []))
    for required in ("BODY", "ARMATURE", "EQUIPMENT", "SOCKETS", "BODY_STATES", "BODY_GUIDES"):
        if required not in required_collections:
            errors.append(f"missing required Blender collection: {required}")
    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit(1)
    payload = build_payload()
    print(f"ANATOMICAL_PIPELINE_V43_AUDIT_OK jobs={len(payload['jobs'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
