#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from tools.cinematics.build_staging_plan import build_plan
from tools.cinematics.staging_take_review import template as review_template, validate as validate_review

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def main() -> int:
    physical = _load("data/physical_bible.json")
    nonverbal = _load("data/nonverbal_language_contract.json")
    proxemics = _load("data/relationship_proxemics.json")
    grammar = _load("data/cinematic_grammar.json")
    blocking = _load("data/demo_cinematic_blocking.json")
    study = _load("data/staging_study_protocol.json")
    plan = build_plan(ROOT)

    assert physical["rules"]["physical_action_before_emotion_display"] is True
    assert physical["rules"]["stillness_is_meaningful"] is True
    assert nonverbal["rules"]["gesture_requires_action_or_reaction"] is True
    assert nonverbal["rules"]["reaction_may_precede_dialogue"] is True
    assert proxemics["rules"]["approach_is_an_action_not_idle_motion"] is True
    assert grammar["rules"]["blocking_before_shot_list"] is True
    assert grammar["rules"]["camera_move_requires_story_reason"] is True
    assert grammar["rules"]["avoid_orbiting_dialogue_camera"] is True
    assert grammar["rules"]["return_to_gameplay_on_stable_readable_axis"] is True
    assert study["rules"]["store_abstract_observations_only"] is True
    assert study["rules"]["do_not_clone_specific_actor_performance"] is True
    assert len(physical["characters"]) >= 6
    assert len(proxemics["pair_defaults"]) >= 6
    assert len(blocking["scenes"]) >= 6
    assert plan["scene_count"] == len(blocking["scenes"])

    for scene in plan["scenes"]:
        assert scene["dramatic_objective"]
        assert scene["handoff"]
        assert len(scene["beats"]) >= 2
        for beat in scene["beats"]:
            assert beat["camera"]
            assert beat["reason"]
            assert "orbit" not in beat["camera"].lower()

    review = review_template()
    validate_review(review)
    assert len(review["reviews"]) == plan["scene_count"]

    print(
        "CINEMATIC_DIRECTION_AUDIT_OK: "
        f"{len(physical['characters'])} physical profiles, "
        f"{len(proxemics['pair_defaults'])} relationship pairs, "
        f"{plan['scene_count']} staged demo scenes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
