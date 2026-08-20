from __future__ import annotations

import json
from pathlib import Path

from tools.qa.prepc_demo_production_audit import audit

ROOT = Path(__file__).resolve().parents[1]


def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_prepc_demo_cross_audit_passes():
    assert audit(ROOT) == []


def test_vertical_slice_showcase_has_exact_four_damage_hits():
    choreography = load("data/visual_slice_choreography.json")
    sequence = choreography["showcase_script"]
    player_actions = [beat["player"] for beat in sequence]
    damages = choreography["actions"]
    total = sum(damages[action]["damage"] for action in player_actions if action in damages and "damage" in damages[action])
    assert total == choreography["actors"]["enemy_01_goule_affamee"]["max_hp"]


def test_demo_main_story_does_not_require_mortal_hero():
    content = load("data/demo_content_pack.json")
    mains = [quest for quest in content["quests"] if quest["type"] == "main"]
    assert mains
    assert all(quest["mortal_hero_required"] is False for quest in mains)


def test_ui_keeps_psychology_and_social_systems_qualitative():
    ui = load("data/final_ui_contract.json")
    behavior = ui["global_behavior"]
    assert behavior["fear_is_only_visible_psychology_meter"] is True
    assert behavior["hope_meter"] is False
    assert behavior["madness_meter"] is False
    assert behavior["no_social_meters"] is True
    assert behavior["no_morality_meter"] is True


def test_demo_roadmap_holds_other_final_models_until_pc_slice_validation():
    roadmap = load("data/demo_roadmap.json")
    p1 = next(phase for phase in roadmap["phases"] if phase["id"] == "P1_vertical_slice_pc")
    p2 = next(phase for phase in roadmap["phases"] if phase["id"] == "P2_demo_cast")
    assert p1["requires_pc"] is True
    assert p2["requires_pc"] is True
    assert roadmap["production_order_after_vertical_slice"][0]["id"] == "aurelien"
