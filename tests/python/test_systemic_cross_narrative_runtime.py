from __future__ import annotations

import json
from pathlib import Path

from tools.qa.systemic_cross_narrative_audit import audit_systemic_cross_narrative


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_systemic_cross_narrative_audit_passes() -> None:
    report = audit_systemic_cross_narrative(ROOT)
    assert report["ok"], report
    assert report["summary"]["scenes"] == 22
    assert report["summary"]["cross_events"] == 18
    assert report["summary"]["cascades"] == 4


def test_every_systemic_cross_has_one_sanctuary_scene() -> None:
    canon = load_json(ROOT / "universe/lore/contextual_quest_cross_ramifications.json")
    scenes = load_json(ROOT / "data/narrative/systemic_cross_sanctuary_scenes.json")["scenes"]
    expected = {item["id"] for item in canon["cross_events"]} | {
        item["id"] for item in canon["compound_cascades"]
    }
    assert set(scenes) == expected


def test_sanctuary_scenes_remain_short_and_object_led() -> None:
    payload = load_json(ROOT / "data/narrative/systemic_cross_sanctuary_scenes.json")
    assert payload["rules"]["no_new_ui"] is True
    assert payload["rules"]["objects_carry_subtext"] is True
    assert payload["rules"]["silence_is_action"] is True
    assert payload["rules"]["max_spoken_hero_lines"] == 2
    for scene in payload["scenes"].values():
        assert scene["task"]
        assert scene["opening"]
        assert scene["closing"]
        assert 1 <= len(scene["dialogue"]) <= 2
        assert scene["silent_reactions"]


def test_named_death_scene_keeps_person_and_material_cause_dynamic() -> None:
    scenes = load_json(ROOT / "data/narrative/systemic_cross_sanctuary_scenes.json")["scenes"]
    scene = scenes["cross.relationship.named_death_after_difficult_choice"]
    blob = json.dumps(scene, ensure_ascii=False)
    assert "{dead_name}" in blob
    assert "{cause}" in blob
    assert "coupable" in blob.lower()
    assert "verdict" in blob.lower()


def test_runtime_has_no_new_morality_or_reputation_meter() -> None:
    runtime = (ROOT / "scripts/core/systemic_cross_narrative_runtime.gd").read_text(encoding="utf-8")
    for forbidden in ["ProgressBar", "morality_score", "alignment_score", "reputation_score"]:
        assert forbidden not in runtime
    assert 'screen_name != "sanctuary"' in runtime
    assert "GameState.alive_heroes()" in runtime
    assert "seen_scene_ids.has" in runtime
