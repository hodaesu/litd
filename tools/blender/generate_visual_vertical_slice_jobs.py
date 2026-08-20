#!/usr/bin/env python3
"""Generate deterministic Blender jobs for the first LITD visual vertical slice.

This file intentionally uses only the Python standard library so the plan can be
validated on CI or generated before Blender is installed. Blender execution is a
separate, explicit PC step.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/visual_vertical_slice.json"
CHARACTER_JOBS_PATH = ROOT / "data/blender/character_jobs.json"
OUTPUT = ROOT / "data/blender/visual_vertical_slice_jobs.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _character_job(character_id: str, jobs: dict) -> dict:
    for job in jobs.get("jobs", []):
        if str(job.get("character_id", "")) == character_id:
            return dict(job)
    raise KeyError(f"missing character job: {character_id}")


def build_payload(root: Path = ROOT) -> dict:
    contract = _load(root / CONTRACT_PATH.relative_to(ROOT))
    jobs = _load(root / CHARACTER_JOBS_PATH.relative_to(ROOT))

    darius_base = _character_job("darius", jobs)
    ghoul_base = _character_job("enemy_01_goule_affamee", jobs)
    darius = contract["characters"]["darius"]
    ghoul = contract["characters"]["enemy_01_goule_affamee"]
    arena = contract["arena"]

    character_common = {
        "review_gate": "proxy_turntable_before_glb_export",
        "art_bible_authoritative": True,
        "shader_contract": contract["shader"],
        "proxy_only_until_reviewed": True,
    }

    production_jobs = [
        {
            "job_id": "vvs_darius_proxy",
            "kind": "character_proxy",
            "source_job_id": darius_base["job_id"],
            "character_id": "darius",
            "name": darius_base["name"],
            "height_m": darius["height_m"],
            "body_scale": darius_base["body_scale"],
            "reference_targets": [
                contract["reference_rules"]["approved_art_bible_repo_target"],
                contract["reference_rules"]["approved_darius_repo_target"],
            ],
            "silhouette": darius["silhouette"],
            "mandatory_shapes": darius["mandatory_shapes"],
            "detail_focus": darius["detail_focus"],
            "keep_simple": darius["keep_simple"],
            "materials": darius["material_families"],
            "animations": darius["animation_minimum"],
            "output_blend": "builds/vertical_slice/darius/darius_proxy.blend",
            "output_glb": "builds/vertical_slice/darius/darius_proxy.glb",
            **character_common,
        },
        {
            "job_id": "vvs_hungry_ghoul_proxy",
            "kind": "character_proxy",
            "source_job_id": ghoul_base["job_id"],
            "character_id": "enemy_01_goule_affamee",
            "name": ghoul_base["name"],
            "height_m": ghoul["height_m"],
            "effective_hunched_height_m": ghoul["effective_hunched_height_m"],
            "body_scale": ghoul_base["body_scale"],
            "reference_targets": [
                contract["reference_rules"]["approved_art_bible_repo_target"],
                contract["reference_rules"]["approved_ghoul_repo_target"],
            ],
            "silhouette": ghoul["silhouette"],
            "mandatory_shapes": ghoul["mandatory_shapes"],
            "detail_focus": ghoul["detail_focus"],
            "keep_simple": ghoul["keep_simple"],
            "materials": ghoul["material_families"],
            "animations": ghoul["animation_minimum"],
            "output_blend": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_proxy.blend",
            "output_glb": "builds/vertical_slice/hungry_ghoul/hungry_ghoul_proxy.glb",
            **character_common,
        },
        {
            "job_id": "vvs_ashlands_arena_proxy",
            "kind": "environment_proxy",
            "environment_id": "ashlands_visual_arena",
            "size_m": arena["size_m"],
            "playable_clear_zone_m": arena["playable_clear_zone_m"],
            "required_props": arena["required_props"],
            "background": arena["background"],
            "clutter_rule": arena["clutter_rule"],
            "materials": ["ash_ground", "stone_ash", "wood_charred", "ember_emissive"],
            "output_blend": "builds/vertical_slice/arena/ashlands_visual_arena_proxy.blend",
            "output_glb": "builds/vertical_slice/arena/ashlands_visual_arena_proxy.glb",
            "review_gate": "game_camera_readability_before_glb_export",
            "art_bible_authoritative": True,
            "proxy_only_until_reviewed": True,
        },
    ]

    commands = {
        "plan_darius": "blender --background --python tools/blender/build_character_scene.py -- character_darius --plan-only",
        "plan_ghoul": "blender --background --python tools/blender/build_character_scene.py -- character_enemy_01_goule_affamee --plan-only",
        "materials": "blender --background --python tools/blender/build_material_library.py -- --output builds/vertical_slice/materials/litd_materials.blend",
        "review_queue": "python tools/blender/generate_visual_review_queue.py",
    }

    return {
        "version": 2,
        "generator": "tools/blender/generate_visual_vertical_slice_jobs.py",
        "contract": "data/visual_vertical_slice.json",
        "status": "prepared_without_blender",
        "jobs": production_jobs,
        "pc_commands": commands,
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
            raise SystemExit("visual vertical slice Blender jobs are out of date")
        print("visual vertical slice Blender jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
