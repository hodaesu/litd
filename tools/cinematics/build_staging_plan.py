#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]

PHYSICAL = ROOT / "data/physical_bible.json"
NONVERBAL = ROOT / "data/nonverbal_language_contract.json"
PROXEMICS = ROOT / "data/relationship_proxemics.json"
GRAMMAR = ROOT / "data/cinematic_grammar.json"
BLOCKING = ROOT / "data/demo_cinematic_blocking.json"
DEMO = ROOT / "data/demo_content_pack.json"
DRAMATIC = ROOT / "data/dramatic_voice_overrides.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _demo_lines(demo: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for raw in demo.get("dialogue_barks", []):
        if not isinstance(raw, dict):
            continue
        line_id = str(raw.get("id", ""))
        if line_id:
            result[line_id] = raw
    return result


def _flow_ids(demo: dict[str, Any]) -> set[str]:
    return {
        str(item.get("id", ""))
        for item in demo.get("flow", [])
        if isinstance(item, dict) and item.get("id")
    }


def _validate_physical_bible(physical: dict[str, Any]) -> None:
    required = {"darius", "aurelien", "malvor", "lysandra", "hungry_ghoul", "ash_witness"}
    profiles = physical.get("characters", {})
    missing = sorted(required - set(profiles))
    if missing:
        raise ValueError(f"Physical Bible missing: {missing}")
    for character_id, profile in profiles.items():
        if not isinstance(profile, dict):
            raise ValueError(f"{character_id}: physical profile must be an object")
        for key in ("center", "neutral_posture", "weight_distribution", "gesture_scale", "tempo", "laban", "stillness_budget"):
            if not profile.get(key):
                raise ValueError(f"{character_id}: missing physical field {key}")
        laban = profile["laban"]
        for key in ("space", "weight", "time", "flow"):
            if not laban.get(key):
                raise ValueError(f"{character_id}: missing Laban axis {key}")


def _validate_grammar(grammar: dict[str, Any]) -> None:
    rules = grammar.get("rules", {})
    for key in (
        "blocking_before_shot_list",
        "camera_move_requires_story_reason",
        "camera_does_not_replace_actor_reaction",
        "return_to_gameplay_on_stable_readable_axis",
    ):
        if rules.get(key) is not True:
            raise ValueError(f"cinematic grammar rule must be true: {key}")
    if "orbit" in grammar.get("camera_moves", {}):
        raise ValueError("generic orbit camera is forbidden")


def _validate_scene(
    scene: dict[str, Any],
    flow_ids: set[str],
    lines: dict[str, dict[str, Any]],
    physical_profiles: dict[str, Any],
) -> None:
    scene_id = str(scene.get("id", ""))
    if not scene_id:
        raise ValueError("staging scene without id")
    if str(scene.get("flow_id", "")) not in flow_ids:
        raise ValueError(f"{scene_id}: unknown flow_id")
    if not scene.get("dramatic_objective"):
        raise ValueError(f"{scene_id}: dramatic_objective required")
    if len(scene.get("blocking", [])) < 2:
        raise ValueError(f"{scene_id}: at least two blocking rules required")
    if not scene.get("handoff"):
        raise ValueError(f"{scene_id}: gameplay handoff required")
    beats = scene.get("beats", [])
    if len(beats) < 2:
        raise ValueError(f"{scene_id}: at least two staging beats required")
    for beat in beats:
        if not isinstance(beat, dict):
            raise ValueError(f"{scene_id}: beat must be an object")
        for key in ("id", "body", "camera", "reason"):
            if not str(beat.get(key, "")).strip():
                raise ValueError(f"{scene_id}: beat missing {key}")
        camera = str(beat.get("camera", "")).lower()
        if "orbit" in camera:
            raise ValueError(f"{scene_id}: decorative orbit camera forbidden")
    for line_id in scene.get("dialogue_ids", []):
        if line_id not in lines:
            raise ValueError(f"{scene_id}: unknown dialogue id {line_id}")
        speaker = str(lines[line_id].get("speaker", ""))
        if speaker not in {"narration", ""} and speaker not in physical_profiles:
            raise ValueError(f"{scene_id}: no physical profile for speaker {speaker}")


def build_plan(root: Path = ROOT) -> dict[str, Any]:
    physical = _load(root / "data/physical_bible.json")
    nonverbal = _load(root / "data/nonverbal_language_contract.json")
    proxemics = _load(root / "data/relationship_proxemics.json")
    grammar = _load(root / "data/cinematic_grammar.json")
    blocking = _load(root / "data/demo_cinematic_blocking.json")
    demo = _load(root / "data/demo_content_pack.json")
    dramatic = _load(root / "data/dramatic_voice_overrides.json")

    _validate_physical_bible(physical)
    _validate_grammar(grammar)

    profiles = physical["characters"]
    lines = _demo_lines(demo)
    flow_ids = _flow_ids(demo)
    dramatic_overrides = dramatic.get("overrides", {})
    scenes: list[dict[str, Any]] = []

    for raw_scene in blocking.get("scenes", []):
        if not isinstance(raw_scene, dict):
            continue
        _validate_scene(raw_scene, flow_ids, lines, profiles)
        dialogue_performance: list[dict[str, Any]] = []
        for line_id in raw_scene.get("dialogue_ids", []):
            line = lines[line_id]
            speaker = str(line.get("speaker", ""))
            dramatic_direction = dramatic_overrides.get(line_id, {})
            physical_profile = profiles.get(speaker, {})
            dialogue_performance.append({
                "line_id": line_id,
                "speaker": speaker,
                "text": str(line.get("text", "")),
                "dramatic_action": str(dramatic_direction.get("action", "observe_or_respond")),
                "subtext": str(dramatic_direction.get("subtext", "preserve_authored_scene_intent")),
                "physical_center": physical_profile.get("center"),
                "stillness_budget": physical_profile.get("stillness_budget"),
                "gesture_scale": physical_profile.get("gesture_scale"),
                "eye_contact": physical_profile.get("eye_contact"),
                "hands": physical_profile.get("hands"),
                "rule": "actor receives/listens before speaking; gesture follows action, not emotion label"
            })
        scenes.append({
            **raw_scene,
            "dialogue_performance": dialogue_performance,
        })

    return {
        "version": 1,
        "design_source": "physical_cinematic_direction_pass_32",
        "rules": {
            "physical_action_before_emotion": True,
            "blocking_before_camera": True,
            "camera_move_requires_reason": True,
            "reaction_priority": True,
            "gameplay_handoff_required": True,
            "human_visual_review_required": True,
            "mocap_or_animation_never_overrides_character_baseline_without_review": True,
        },
        "contracts": {
            "physical_bible": "data/physical_bible.json",
            "nonverbal": "data/nonverbal_language_contract.json",
            "proxemics": "data/relationship_proxemics.json",
            "camera": "data/cinematic_grammar.json",
            "blocking": "data/demo_cinematic_blocking.json",
        },
        "nonverbal_channels": nonverbal.get("channels", []),
        "proxemic_pairs": sorted(proxemics.get("pair_defaults", {}).keys()),
        "scene_count": len(scenes),
        "scenes": scenes,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build and validate the LITD physical/cinematic staging plan")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", default="reports/staging-direction-plan.json")
    args = parser.parse_args()
    plan = build_plan(ROOT)
    if args.check:
        if plan["scene_count"] < 6:
            raise SystemExit("STAGING_PLAN_ERROR: expected at least six demo scenes")
        print(f"STAGING_PLAN_OK: {plan['scene_count']} scene(s), {len(plan['proxemic_pairs'])} proxemic pair(s)")
        return 0
    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    _write(output, plan)
    print(f"STAGING_PLAN_WRITTEN: {plan['scene_count']} scene(s) -> {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
