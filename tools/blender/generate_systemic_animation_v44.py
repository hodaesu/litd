#!/usr/bin/env python3
"""Generate deterministic systemic body-animation jobs from anatomy v43."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/blender/systemic_animation_v44.json"
ANATOMY_JOBS_PATH = ROOT / "data/blender/anatomical_pipeline_jobs_v43.json"
OUTPUT = ROOT / "data/blender/systemic_animation_jobs_v44.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _is_locotion_part(part: str, contract: dict) -> bool:
    lower = part.lower()
    return any(token.lower() in lower for token in contract.get("locomotion_part_keywords", []))


def _is_manipulator(part: str, contract: dict) -> bool:
    lower = part.lower()
    return any(token.lower() in lower for token in contract.get("manipulator_part_keywords", []))


def _action(name: str, state: str, part: str = "", role: str = "body") -> dict:
    return {"name": name, "state": state, "part": part, "role": role, "required": True}


def build_job(anatomy_job: dict, contract: dict) -> dict:
    actions: list[dict] = []
    for name in contract.get("base_actions", []):
        actions.append(_action(str(name), "F0", role="base"))
    for state in ("F0", "F1", "F2"):
        spec = contract["state_contract"][state]
        actions.append(_action(str(spec["global_clip"]), state, role="global_state"))

    locomotion_parts: list[str] = []
    manipulators: list[str] = []
    for part_spec in anatomy_job.get("parts", []):
        part = str(part_spec["part"])
        if _is_locotion_part(part, contract):
            locomotion_parts.append(part)
        if _is_manipulator(part, contract):
            manipulators.append(part)
        if bool(part_spec.get("supports_f3", False)):
            state_spec = contract["state_contract"]["F3"]
            actions.append(_action(state_spec["per_part_pattern"].format(part=part), "F3", part, "pose"))
            actions.append(_action(state_spec["transition_pattern"].format(part=part), "F3", part, "transition"))
            if _is_locotion_part(part, contract):
                actions.append(_action(f"move_f3_{part}", "F3", part, "locomotion"))
        if bool(part_spec.get("supports_f4", False)):
            state_spec = contract["state_contract"]["F4"]
            actions.append(_action(state_spec["per_part_pattern"].format(part=part), "F4", part, "pose"))
            actions.append(_action(state_spec["transition_pattern"].format(part=part), "F4", part, "transition"))
            if _is_locotion_part(part, contract):
                actions.append(_action(f"move_f4_{part}", "F4", part, "locomotion"))

    has_weapon_sockets = bool(anatomy_job.get("weapon_sockets", {}))
    if has_weapon_sockets:
        for name in contract.get("one_hand_actions", []):
            actions.append(_action(str(name), "adaptive", role="equipment_fallback"))

    # De-duplicate while preserving order.
    seen: set[str] = set()
    unique_actions: list[dict] = []
    for item in actions:
        if item["name"] in seen:
            continue
        seen.add(item["name"])
        unique_actions.append(item)

    return {
        "job_id": f"animation_v44_{anatomy_job['character_id']}",
        "character_id": anatomy_job["character_id"],
        "name": anatomy_job.get("name", anatomy_job["character_id"]),
        "category": anatomy_job.get("category", "unknown"),
        "morphology": anatomy_job.get("morphology", "BOSS_CUSTOM"),
        "source_anatomy_job": anatomy_job.get("job_id", ""),
        "actions": unique_actions,
        "locomotion_parts": locomotion_parts,
        "manipulators": manipulators,
        "weapon_sockets": anatomy_job.get("weapon_sockets", {}),
        "equipment_adaptation": contract["equipment_adaptation"],
        "gameplay_neutral": True,
        "output_folder": anatomy_job.get("output_folder", ""),
    }


def build_payload(root: Path = ROOT) -> dict:
    contract = _load(root / CONTRACT_PATH.relative_to(ROOT))
    anatomy_path = root / ANATOMY_JOBS_PATH.relative_to(ROOT)
    if not anatomy_path.exists():
        from tools.blender.generate_anatomical_pipeline_v43 import build_payload as build_anatomy
        anatomy = build_anatomy(root)
    else:
        anatomy = _load(anatomy_path)
    jobs = [build_job(job, contract) for job in anatomy.get("jobs", [])]
    return {
        "version": 44,
        "generator": "tools/blender/generate_systemic_animation_v44.py",
        "contract": str(CONTRACT_PATH.relative_to(ROOT)).replace("\\", "/"),
        "source_anatomy_version": int(anatomy.get("version", 0)),
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
            raise SystemExit("systemic animation v44 jobs are out of date; run the generator")
        print("systemic animation v44 jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"generated {len(build_payload()['jobs'])} systemic animation jobs v44")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
