#!/usr/bin/env python3
"""Generate the v45 animation-production matrix from systemic animation v44.

The generator is Blender-independent so CI can prove that every requested v44
action has exactly one production strategy before an artist opens a .blend file.
Signature slots are kept separate from systemic retarget requests so production can
measure reuse without pretending that ultimates or boss set-pieces are shareable.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/blender/animation_production_matrix_v45.json"
OUTPUT = ROOT / "data/blender/animation_production_jobs_v45.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _v44_payload(root: Path) -> dict:
    from tools.blender.generate_systemic_animation_v44 import build_payload

    return build_payload(root)


def _retarget_family(morphology: str, contract: dict) -> str:
    for family, spec in contract.get("retarget_families", {}).items():
        if morphology in spec.get("morphologies", []):
            return str(family)
    return "boss_custom"


def _semantic_class(part: str, contract: dict) -> str:
    lower = part.lower()
    for semantic, tokens in contract.get("semantic_part_classes", {}).items():
        if any(str(token).lower() in lower for token in tokens):
            return str(semantic)
    return "other"


def _side(part: str) -> str:
    lower = part.lower()
    if "left" in lower or lower.endswith("_l"):
        return "left"
    if "right" in lower or lower.endswith("_r"):
        return "right"
    return ""


def _part_shape_token(part: str) -> str:
    token = part.lower().strip()
    token = token.replace("left_", "").replace("right_", "")
    token = token.replace("_left", "").replace("_right", "")
    if token.endswith("_l") or token.endswith("_r"):
        token = token[:-2]
    token = re.sub(r"_\d+$", "", token)
    return token or "part"


def _priority(item: dict, job: dict, contract: dict) -> str:
    rules = contract.get("priority_rules", {})
    name = str(item.get("name", ""))
    role = str(item.get("role", ""))
    state = str(item.get("state", ""))
    part = str(item.get("part", ""))
    semantic = _semantic_class(part, contract) if part else ""

    if name in rules.get("P0_action_names", []) or role in rules.get("P0_roles", []):
        return "P0"
    if bool(rules.get("f3_f4_primary_limb_is_p0", False)) and state in {"F3", "F4"}:
        if semantic in {"upper_manipulator", "lower_locomotor", "axial_locomotor"}:
            return "P0"
    if str(job.get("category", "")) in rules.get("P2_categories", []):
        return "P2"
    if role in rules.get("P1_roles", []):
        return "P1"
    return "P2"


def _production_mode(item: dict, family: str, contract: dict) -> str:
    if family == "boss_custom":
        return "BESPOKE"
    role = str(item.get("role", ""))
    return str(contract.get("role_policy", {}).get(role, "RETARGET_SEMANTIC"))


def _bespoke_reason(job: dict, family: str, mode: str) -> str:
    if mode != "BESPOKE":
        return ""
    if family == "boss_custom":
        return "custom_morphology_or_boss_anatomy_requires_unique_motion"
    return "declared_signature_motion"


def _canonical_key(item: dict, job: dict, family: str, mode: str, contract: dict) -> str:
    name = str(item.get("name", ""))
    role = str(item.get("role", "body"))
    state = str(item.get("state", "adaptive"))
    part = str(item.get("part", ""))
    if mode == "BESPOKE":
        return f"{family}/{job['character_id']}/{name}"
    if mode == "RETARGET_SHARED" or not part:
        return f"{family}/{role}/{name}"

    semantic = _semantic_class(part, contract)
    shape = _part_shape_token(part)
    side = _side(part)
    family_spec = contract.get("retarget_families", {}).get(family, {})
    mirrorable = bool(family_spec.get("mirror_left_right", False))
    side_key = "mirrored" if side and mirrorable else (side or "center")
    return f"{family}/{role}/{state}/{semantic}/{shape}/{side_key}"


def _mobile_budget_tag(priority: str, mode: str) -> str:
    if priority == "P0":
        return "mobile_core"
    if mode == "BESPOKE":
        return "mobile_signature"
    return "mobile_retarget"


def _signature_backlog(contract: dict) -> list[dict]:
    roster = contract.get("canonical_signature_roster", {})
    policy = contract.get("signature_policy", {})
    priority = str(policy.get("priority", "P2"))
    mode = str(policy.get("production_mode", "BESPOKE"))
    backlog: list[dict] = []

    for hero in roster.get("veilleurs", []):
        character_id = str(hero.get("id", ""))
        name = str(hero.get("name", character_id))
        for slot in range(1, int(hero.get("ultimate_slots", 0)) + 1):
            backlog.append({
                "character_id": character_id,
                "name": name,
                "category": "veilleur_ultimate",
                "slot": f"ultimate_tree_{slot}",
                "canonical_clip_key": f"signature/veilleur/{character_id}/ultimate_tree_{slot}",
                "production_mode": mode,
                "priority": priority,
                "bespoke_reason": str(policy.get("hero_ultimate_reason", "ultimate_identity_must_remain_unique")),
                "mobile_budget_tag": "mobile_signature",
                "production_placeholder": True,
                "not_a_lore_name": True,
            })

    for boss in roster.get("bosses", []):
        character_id = str(boss.get("id", ""))
        name = str(boss.get("name", character_id))
        for slot in range(1, int(boss.get("ultimate_slots", 0)) + 1):
            backlog.append({
                "character_id": character_id,
                "name": name,
                "category": "boss_ultimate",
                "slot": f"boss_ultimate_{slot}",
                "canonical_clip_key": f"signature/boss/{character_id}/ultimate_{slot}",
                "production_mode": mode,
                "priority": priority,
                "bespoke_reason": str(policy.get("boss_ultimate_reason", "boss_ultimate_requires_unique_silhouette_and_timing")),
                "mobile_budget_tag": "mobile_signature",
                "production_placeholder": True,
                "not_a_lore_name": True,
            })
        for slot_name_value in boss.get("signature_slots", []):
            slot_name = str(slot_name_value)
            reason_key = "boss_phase_reason" if "phase" in slot_name else "boss_signature_reason"
            backlog.append({
                "character_id": character_id,
                "name": name,
                "category": "boss_phase" if "phase" in slot_name else "boss_signature",
                "slot": slot_name,
                "canonical_clip_key": f"signature/boss/{character_id}/{slot_name}",
                "production_mode": mode,
                "priority": priority,
                "bespoke_reason": str(policy.get(reason_key, "boss_identity_requires_unique_motion")),
                "mobile_budget_tag": "mobile_signature",
                "production_placeholder": True,
                "not_a_lore_name": True,
            })
    return backlog


def build_payload(root: Path = ROOT) -> dict:
    contract = _load(root / CONTRACT_PATH.relative_to(ROOT))
    v44 = _v44_payload(root)
    requests: list[dict] = []
    masters: dict[str, dict] = {}
    family_stats: dict[str, dict] = {}
    tier_rank = {"P0": 0, "P1": 1, "P2": 2}

    for job in v44.get("jobs", []):
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
                "source_version": 44,
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
    hero_ultimates = sum(1 for item in signatures if item["category"] == "veilleur_ultimate")
    boss_ultimates = sum(1 for item in signatures if item["category"] == "boss_ultimate")
    boss_signatures = sum(1 for item in signatures if item["category"] == "boss_signature")
    boss_phases = sum(1 for item in signatures if item["category"] == "boss_phase")

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
        "version": 45,
        "generator": "tools/blender/generate_animation_production_matrix_v45.py",
        "source_version": int(v44.get("version", 0)),
        "requested_actions": requested,
        "master_clips": authored,
        "avoided_duplicate_clips": requested - authored,
        "reuse_ratio": round(1.0 - (authored / requested), 4) if requested else 0.0,
        "signature_count": len(signatures),
        "hero_ultimate_slots": hero_ultimates,
        "boss_ultimate_slots": boss_ultimates,
        "boss_signature_slots": boss_signatures,
        "boss_phase_slots": boss_phases,
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
        print(json.dumps({
            "requested_actions": payload["requested_actions"],
            "master_clips": payload["master_clips"],
            "avoided_duplicate_clips": payload["avoided_duplicate_clips"],
            "reuse_ratio": payload["reuse_ratio"],
            "signature_count": payload["signature_count"],
            "hero_ultimate_slots": payload["hero_ultimate_slots"],
            "boss_ultimate_slots": payload["boss_ultimate_slots"],
            "boss_signature_slots": payload["boss_signature_slots"],
            "boss_phase_slots": payload["boss_phase_slots"],
            "total_master_clips_with_signatures": payload["total_master_clips_with_signatures"],
            "priority_summary": payload["priority_summary"],
            "production_mode_summary": payload["production_mode_summary"],
            "family_summary": payload["family_summary"],
        }, ensure_ascii=False, indent=2))
        return 0
    expected = render(payload)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("animation production v45 output is out of date; run the generator")
        print("animation production v45 matrix is current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    print(
        f"generated v45: {payload['requested_actions']} systemic requests -> "
        f"{payload['master_clips']} shared masters + {payload['signature_count']} signatures "
        f"({payload['reuse_ratio']:.1%} systemic reuse)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
