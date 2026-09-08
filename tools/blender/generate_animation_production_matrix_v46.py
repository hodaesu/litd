#!/usr/bin/env python3
"""Generate the LITD Les Veilleurs v46 animation matrix from canonical cast only.

This generator deliberately never reads data/blender/character_jobs.json. It reuses
v44 systemic action rules and v45 retarget/priority/signature rules, but the set of
characters is exclusively data/blender/canonical_cast_v46.json.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from tools.blender.generate_animation_production_matrix_v45 import (
    _bespoke_reason,
    _canonical_key,
    _mobile_budget_tag,
    _priority,
    _production_mode,
    _retarget_family,
    _semantic_class,
    _side,
    _signature_backlog,
)
from tools.blender.generate_systemic_animation_v44 import build_job as build_systemic_job

ROOT = Path(__file__).resolve().parents[2]
CAST_PATH = ROOT / "data/blender/canonical_cast_v46.json"
BODY_PATH = ROOT / "data/body_visual_runtime_v42.json"
SYSTEMIC_CONTRACT_PATH = ROOT / "data/blender/systemic_animation_v44.json"
PRODUCTION_CONTRACT_PATH = ROOT / "data/blender/animation_production_matrix_v45.json"
OUTPUT = ROOT / "data/blender/animation_production_jobs_v46.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _resolved_morphology(key: str, body: dict) -> dict:
    morphologies = body.get("morphologies", {})
    raw = dict(morphologies.get(key, {}))
    if not raw:
        raise ValueError(f"unknown runtime morphology: {key}")
    parent = str(raw.get("inherit", ""))
    if not parent:
        return raw
    merged = _resolved_morphology(parent, body)
    merged.update(raw)
    merged.pop("inherit", None)
    return merged


def _part_specs(parts: list[str]) -> list[dict]:
    return [
        {
            "part": part,
            "supports_f3": True,
            "supports_f4": True,
        }
        for part in parts
    ]


def _canonical_anatomy_job(item: dict, category: str, body: dict) -> dict:
    morphology = str(item.get("morphology", ""))
    if morphology == "BOSS_CUSTOM":
        parts = [str(value) for value in item.get("anatomy_parts", [])]
        weapon_sockets: dict[str, str] = {}
    else:
        profile = _resolved_morphology(morphology, body)
        parts = [str(value) for value in profile.get("parts", [])]
        weapon_sockets = (
            {"left": "SOCKET_weapon_l", "right": "SOCKET_weapon_r"}
            if profile.get("weapon_side_requirements", {})
            else {}
        )
    character_id = str(item["id"])
    return {
        "job_id": f"anatomy_v46_{character_id}",
        "character_id": character_id,
        "name": str(item.get("name", character_id)),
        "category": category,
        "morphology": morphology,
        "parts": _part_specs(parts),
        "weapon_sockets": weapon_sockets,
        "output_folder": f"exports/{'bosses' if category == 'boss' else 'characters'}/{character_id}/",
        "gameplay_neutral": True,
    }


def _canonical_systemic_payload(cast: dict, body: dict, systemic_contract: dict) -> dict:
    category_map = {
        "veilleurs": "veilleur",
        "species": "recruitable_species",
        "bosses": "boss",
    }
    jobs: list[dict] = []
    for group, category in category_map.items():
        for item in cast.get("cast", {}).get(group, []):
            anatomy_job = _canonical_anatomy_job(item, category, body)
            jobs.append(build_systemic_job(anatomy_job, systemic_contract))
    return {
        "version": 46,
        "source_cast_version": 46,
        "systemic_contract_version": int(systemic_contract.get("version", 0)),
        "jobs": jobs,
        "legacy_character_jobs_used": False,
    }


def _build_matrix(systemic: dict, contract: dict) -> dict:
    requests: list[dict] = []
    masters: dict[str, dict] = {}
    family_stats: dict[str, dict] = {}
    tier_rank = {"P0": 0, "P1": 1, "P2": 2}

    for job in systemic.get("jobs", []):
        morphology = str(job.get("morphology", "BOSS_CUSTOM"))
        family = _retarget_family(morphology, contract)
        family_stats.setdefault(family, {"characters": set(), "requests": 0, "masters": set()})
        family_stats[family]["characters"].add(str(job.get("character_id", "")))

        for item in job.get("actions", []):
            mode = _production_mode(item, family, contract)
            priority = _priority(item, job, contract)
            canonical = _canonical_key(item, job, family, mode, contract)
            bespoke_reason = _bespoke_reason(job, family, mode)
            part = str(item.get("part", ""))
            side = _side(part)
            family_spec = contract.get("retarget_families", {}).get(family, {})
            mirrorable = bool(side and family_spec.get("mirror_left_right", False) and family != "boss_custom")
            request = {
                "character_id": str(job.get("character_id", "")),
                "name": str(job.get("name", "")),
                "category": str(job.get("category", "unknown")),
                "morphology": morphology,
                "retarget_family": family,
                "action": str(item.get("name", "")),
                "role": str(item.get("role", "body")),
                "state": str(item.get("state", "adaptive")),
                "part": part,
                "semantic_part": _semantic_class(part, contract) if part else "none",
                "side": side,
                "mirrorable": mirrorable,
                "production_mode": mode,
                "bespoke_reason": bespoke_reason,
                "canonical_clip_key": canonical,
                "priority": priority,
                "mobile_budget_tag": _mobile_budget_tag(priority, mode),
                "source_cast_version": 46,
                "source_systemic_contract_version": int(systemic.get("systemic_contract_version", 0)),
            }
            requests.append(request)
            family_stats[family]["requests"] += 1
            family_stats[family]["masters"].add(canonical)

            master = masters.get(canonical)
            if master is None:
                master = {
                    "canonical_clip_key": canonical,
                    "retarget_family": family,
                    "production_mode": mode,
                    "bespoke_reason": bespoke_reason,
                    "priority": priority,
                    "owner_character_id": request["character_id"],
                    "source_action": request["action"],
                    "role": request["role"],
                    "state": request["state"],
                    "semantic_part": request["semantic_part"],
                    "mobile_budget_tag": request["mobile_budget_tag"],
                    "consumers": [],
                }
                masters[canonical] = master
            elif tier_rank[priority] < tier_rank[str(master["priority"])]:
                master["priority"] = priority
                master["mobile_budget_tag"] = _mobile_budget_tag(priority, mode)
            master["consumers"].append(request["character_id"])

    master_list = list(masters.values())
    for master in master_list:
        master["consumers"] = sorted(set(master["consumers"]))
        master["reuse_count"] = len(master["consumers"])

    family_summary: dict[str, dict] = {}
    for family, stats in family_stats.items():
        request_count = int(stats["requests"])
        master_count = len(stats["masters"])
        family_summary[family] = {
            "characters": len(stats["characters"]),
            "requested_actions": request_count,
            "master_clips": master_count,
            "reuse_ratio": round(1.0 - (master_count / request_count), 4) if request_count else 0.0,
        }

    signatures = _signature_backlog(contract)
    requested = len(requests)
    authored = len(master_list)
    priority_summary = {
        tier: sum(1 for master in master_list if master["priority"] == tier)
        + sum(1 for item in signatures if item["priority"] == tier)
        for tier in ("P0", "P1", "P2")
    }
    mode_summary = {
        mode: sum(1 for master in master_list if master["production_mode"] == mode)
        + sum(1 for item in signatures if item["production_mode"] == mode)
        for mode in contract.get("production_modes", {})
    }
    return {
        "version": 46,
        "generator": "tools/blender/generate_animation_production_matrix_v46.py",
        "source_cast_version": 46,
        "systemic_contract_version": int(systemic.get("systemic_contract_version", 0)),
        "legacy_character_jobs_used": False,
        "cast_count": len({request["character_id"] for request in requests}),
        "requested_actions": requested,
        "master_clips": authored,
        "avoided_duplicate_clips": requested - authored,
        "reuse_ratio": round(1.0 - (authored / requested), 4) if requested else 0.0,
        "signature_count": len(signatures),
        "hero_ultimate_slots": sum(1 for item in signatures if item["category"] == "veilleur_ultimate"),
        "boss_ultimate_slots": sum(1 for item in signatures if item["category"] == "boss_ultimate"),
        "boss_signature_slots": sum(1 for item in signatures if item["category"] == "boss_signature"),
        "boss_phase_slots": sum(1 for item in signatures if item["category"] == "boss_phase"),
        "total_master_clips_with_signatures": authored + len(signatures),
        "priority_summary": priority_summary,
        "production_mode_summary": mode_summary,
        "family_summary": family_summary,
        "masters": master_list,
        "requests": requests,
        "signature_backlog": signatures,
        "skill_primitive_library": contract.get("skill_primitive_library", {}),
        "mobile_budget": contract.get("mobile_budget", {}),
        "skill_animation_policy": contract.get("skill_animation_policy", {}),
        "gameplay_neutral": True,
    }


def build_payload(root: Path = ROOT) -> dict:
    cast = _load(root / CAST_PATH.relative_to(ROOT))
    body = _load(root / BODY_PATH.relative_to(ROOT))
    systemic_contract = _load(root / SYSTEMIC_CONTRACT_PATH.relative_to(ROOT))
    production_contract = _load(root / PRODUCTION_CONTRACT_PATH.relative_to(ROOT))
    systemic = _canonical_systemic_payload(cast, body, systemic_contract)
    return _build_matrix(systemic, production_contract)


def render(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    payload = build_payload()
    if args.summary:
        keys = [
            "cast_count", "requested_actions", "master_clips", "avoided_duplicate_clips",
            "reuse_ratio", "signature_count", "total_master_clips_with_signatures",
            "priority_summary", "production_mode_summary", "family_summary",
        ]
        print(json.dumps({key: payload[key] for key in keys}, ensure_ascii=False, indent=2))
        return 0
    expected = render(payload)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("animation production v46 output is out of date; run the generator")
        print("animation production v46 jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(f"generated v46 animation matrix for {payload['cast_count']} canonical entities")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
