from __future__ import annotations

import json
from pathlib import Path

from tools.cinematics.build_staging_plan import build_plan
from tools.cinematics.staging_take_review import template as review_template, validate as validate_review

ROOT = Path(__file__).resolve().parents[1]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_physical_bible_has_distinct_demo_signatures() -> None:
    data = _load("data/physical_bible.json")
    characters = data["characters"]
    expected = {"darius", "aurelien", "malvor", "lysandra", "hungry_ghoul", "ash_witness"}
    assert expected.issubset(characters)
    centers = {characters[name]["center"] for name in expected}
    assert len(centers) >= 5
    assert characters["darius"]["stillness_budget"] == "high"
    assert characters["hungry_ghoul"]["tempo"].startswith("sudden")


def test_nonverbal_contract_prioritizes_action_and_listening() -> None:
    data = _load("data/nonverbal_language_contract.json")
    rules = data["rules"]
    assert rules["gesture_requires_action_or_reaction"] is True
    assert rules["reaction_may_precede_dialogue"] is True
    assert rules["silence_can_be_primary_response"] is True
    assert rules["contradiction_between_voice_and_body_is_allowed_when_subtext_motivates_it"] is True


def test_relationship_proxemics_cover_core_party_pairs() -> None:
    data = _load("data/relationship_proxemics.json")
    pairs = data["pair_defaults"]
    assert len(pairs) == 6
    assert "darius:aurelien" in pairs
    assert "malvor:lysandra" in pairs
    assert data["rules"]["approach_is_an_action_not_idle_motion"] is True


def test_cinematic_grammar_bans_decorative_camera_motion() -> None:
    data = _load("data/cinematic_grammar.json")
    rules = data["rules"]
    assert rules["blocking_before_shot_list"] is True
    assert rules["camera_move_requires_story_reason"] is True
    assert rules["avoid_orbiting_dialogue_camera"] is True
    assert "orbit" not in data["camera_moves"]


def test_demo_staging_plan_covers_all_six_flow_sections() -> None:
    plan = build_plan(ROOT)
    assert plan["scene_count"] == 6
    flow_ids = {scene["flow_id"] for scene in plan["scenes"]}
    assert flow_ids == {
        "demo_00_sanctuary",
        "demo_01_ash_approach",
        "demo_02_field_choice",
        "demo_03_ghoul",
        "demo_04_witness",
        "demo_05_return",
    }
    for scene in plan["scenes"]:
        assert scene["dramatic_objective"]
        assert scene["handoff"]
        assert len(scene["beats"]) >= 3
        assert all(beat["reason"] for beat in scene["beats"])


def test_dialogue_performance_links_voice_action_to_body_identity() -> None:
    plan = build_plan(ROOT)
    linked = [item for scene in plan["scenes"] for item in scene["dialogue_performance"]]
    assert linked
    by_id = {item["line_id"]: item for item in linked}
    assert by_id["demo_darius_ghoul_01"]["dramatic_action"] == "avertir"
    assert by_id["demo_malvor_survivors_01"]["dramatic_action"] == "désamorcer"
    assert by_id["demo_darius_ghoul_01"]["physical_center"] == "sternum_and_shield_side"


def test_staging_review_remains_human_gate() -> None:
    payload = review_template()
    validate_review(payload)
    assert payload["human_visual_review_required"] is True
    assert len(payload["reviews"]) == 6
    assert all(review["approved"] is False for review in payload["reviews"])


def test_study_protocol_keeps_only_abstract_lessons() -> None:
    data = _load("data/staging_study_protocol.json")
    rules = data["rules"]
    assert rules["store_abstract_observations_only"] is True
    assert rules["do_not_store_movie_clips"] is True
    assert rules["do_not_store_scene_transcripts"] is True
    assert rules["do_not_clone_specific_actor_performance"] is True
