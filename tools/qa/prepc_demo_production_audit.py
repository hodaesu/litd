#!/usr/bin/env python3
"""Cross-check every PASS 29 contract that can be validated without Blender/Godot visuals."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FILES = {
    "choreography": "data/visual_slice_choreography.json",
    "animations": "data/visual_slice_animation_specs.json",
    "presentation": "data/visual_slice_presentation.json",
    "content": "data/demo_content_pack.json",
    "balance": "data/demo_balance_targets.json",
    "ui": "data/final_ui_contract.json",
    "roadmap": "data/demo_roadmap.json",
    "visual": "data/visual_vertical_slice.json",
    "field": "data/field_encounters.json",
    "bosses": "data/boss_design_contracts.json",
    "creatures": "data/capturable_creatures.json",
    "rarities": "data/equipment_rarities.json",
}


def load(name: str, root: Path = ROOT):
    return json.loads((root / FILES[name]).read_text(encoding="utf-8"))


def audit(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    for rel in FILES.values():
        if not (root / rel).is_file():
            errors.append(f"missing file: {rel}")
    if errors:
        return errors

    choreography = load("choreography", root)
    animations = load("animations", root)
    presentation = load("presentation", root)
    content = load("content", root)
    balance = load("balance", root)
    ui = load("ui", root)
    roadmap = load("roadmap", root)
    visual = load("visual", root)
    field = load("field", root)
    bosses = load("bosses", root)
    creatures = load("creatures", root)
    rarities = load("rarities", root)

    for key, payload in {
        "choreography": choreography,
        "animations": animations,
        "presentation": presentation,
        "content": content,
        "balance": balance,
        "ui": ui,
        "roadmap": roadmap,
    }.items():
        if payload.get("version") != 1:
            errors.append(f"{key} version must be 1")

    if choreography["combat_model"].get("damage_at_impact_marker_only") is not True:
        errors.append("combat must resolve damage at impact marker only")
    for action_id, action in choreography["actions"].items():
        duration = float(action["duration_s"])
        impact = action.get("impact_s")
        anticipation = action.get("anticipation_s", 0.0)
        if impact is not None and not (0 <= float(anticipation) < float(impact) <= duration):
            errors.append(f"invalid action timing: {action_id}")
        if round(duration * 10) != duration * 10:
            errors.append(f"action duration must be tenth-second aligned: {action_id}")

    visual_min = visual["characters"]
    spec_by_actor = {"darius": animations["darius"], "enemy_01_goule_affamee": animations["enemy_01_goule_affamee"]}
    for actor_id, block in spec_by_actor.items():
        authored = {anim["id"] for anim in block["animations"]}
        required = set(visual_min[actor_id]["animation_minimum"])
        missing = sorted(required - authored)
        if missing:
            errors.append(f"missing animation specs for {actor_id}: {missing}")
        for anim in block["animations"]:
            beats = [float(beat["t"]) for beat in anim["beats"]]
            if beats != sorted(beats) or beats[-1] > float(anim["duration_s"]):
                errors.append(f"invalid animation beats: {actor_id}/{anim['id']}")

    vfx_ids = set(presentation["vfx"]["effects"])
    for required in visual["vfx_minimum"]:
        if required not in vfx_ids:
            errors.append(f"missing required VFX spec: {required}")
    audio_ids = set(presentation["audio"]["events"])
    for required in visual["audio_minimum"]:
        if required not in audio_ids:
            errors.append(f"missing required audio spec: {required}")
    if presentation["camera"]["base"]["fov_deg"] != visual["camera"]["fov_degrees"]:
        errors.append("presentation camera FOV must match visual slice contract")

    field_ids = {entry["id"] for entry in field["encounters"]}
    boss_ids = {entry["id"] for entry in bosses["bosses"]}
    creature_ids = {entry["id"] for entry in creatures}
    for quest in content["quests"]:
        source = quest.get("source_encounter")
        followup = quest.get("followup_encounter")
        if source and source not in field_ids:
            errors.append(f"unknown field encounter in quest {quest['id']}: {source}")
        if followup and followup not in field_ids:
            errors.append(f"unknown followup encounter in quest {quest['id']}: {followup}")
    for beat in content["flow"]:
        if beat.get("existing_encounter") and beat["existing_encounter"] not in field_ids:
            errors.append(f"unknown flow encounter: {beat['existing_encounter']}")
        if beat.get("boss_id") and beat["boss_id"] not in boss_ids:
            errors.append(f"unknown flow boss: {beat['boss_id']}")
        if beat.get("creature_id") and beat["creature_id"] not in creature_ids:
            errors.append(f"unknown flow creature: {beat['creature_id']}")
    if content["boss_demo"]["boss_id"] not in boss_ids:
        errors.append("demo boss contract does not resolve")
    if content["capture_demo"]["creature_id"] not in creature_ids:
        errors.append("demo capture creature does not resolve")
    if any(q.get("mortal_hero_required") is True for q in content["quests"] if q["type"] == "main"):
        errors.append("main demo quest cannot require a mortal hero")

    for collection in (content["quests"], content["events"], content["ancient_texts"], content["dialogue_barks"]):
        ids = [entry["id"] for entry in collection]
        if len(ids) != len(set(ids)):
            errors.append("duplicate authored content IDs")
    if len(content["ancient_texts"]) < 6:
        errors.append("demo needs at least six authored ancient texts")
    if len(content["dialogue_barks"]) < 10:
        errors.append("demo needs at least ten authored dialogue barks")

    rarity_contract = balance["equipment_invariants"]["rarities"]
    by_rarity = {entry["id"]: entry for entry in rarities}
    for rarity_id, expected in rarity_contract.items():
        actual = by_rarity.get(rarity_id)
        if not actual:
            errors.append(f"missing rarity {rarity_id}")
            continue
        if actual["affix_count"] != expected["affixes"] or actual["special_affix_count"] != expected["special"]:
            errors.append(f"rarity invariant mismatch: {rarity_id}")
    if balance["psychology"]["madness_visible_meter"] or balance["psychology"]["hope_visible_meter"]:
        errors.append("Madness and Hope must not become visible meters")
    if balance["progression_invariants"]["skills_per_tree_target"] != 15:
        errors.append("skills per tree target must remain 15")

    required_screens = {"combat","inventory","equipment","skill_trees","journal","sanctuary","recruitment","capture","settings"}
    if not required_screens.issubset(ui["screens"]):
        errors.append("final UI contract is missing required screens")
    if not ui["global_behavior"]["contextual_hud"] or not ui["global_behavior"]["exploration_hud_hidden_by_default"]:
        errors.append("HUD must stay contextual and hidden by default during exploration")
    if ui["global_behavior"]["no_morality_meter"] is not True:
        errors.append("UI must not add a morality meter")

    orders = [entry["order"] for entry in roadmap["production_order_after_vertical_slice"]]
    if orders != list(range(1, len(orders) + 1)):
        errors.append("production order must be contiguous")
    phase_ids = [phase["id"] for phase in roadmap["phases"]]
    for required in ["P0_prepc_locked","P1_vertical_slice_pc","P2_demo_cast","P3_demo_world","P4_demo_polish","P5_external_demo"]:
        if required not in phase_ids:
            errors.append(f"missing roadmap phase: {required}")
    if roadmap["release_quality_gates"]["stability"]["crashes"] != 0:
        errors.append("presentable demo crash target must be zero")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print("FAIL -", error)
        print(f"PREPC_DEMO_PRODUCTION_AUDIT_FAILED {len(errors)}")
        return 1
    print("PREPC_DEMO_PRODUCTION_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
