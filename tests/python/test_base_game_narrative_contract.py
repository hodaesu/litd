import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "data/narrative/base_game_story_contract.json"
NARRATOR = ROOT / "data/narrative/base_game_narrator.json"
KEY_SCENES = ROOT / "data/narrative/base_game_key_scenes.json"
CAMPAIGN = ROOT / "data/world/main_campaign.json"
PROJECT = ROOT / "project.godot"
DIRECTOR = ROOT / "scripts/core/base_game_narrative_director.gd"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_story_contract_covers_exactly_the_ten_base_chapters():
    story = load(STORY)
    campaign = load(CAMPAIGN)
    story_ids = [chapter["id"] for chapter in story["chapters"]]
    campaign_ids = [chapter["id"] for chapter in campaign["chapters"]]
    assert story_ids == campaign_ids
    assert len(story_ids) == 10
    assert story["global_rules"]["ngplus_narrative_expansion_frozen"] is True
    assert campaign["story_contract"] == "res://data/narrative/base_game_story_contract.json"
    assert campaign["narrator_contract"] == "res://data/narrative/base_game_narrator.json"
    assert campaign["narrative_priority"] == "cycle_initial_before_ngplus_expansion"


def test_every_chapter_has_human_emotional_and_environmental_spine():
    for chapter in load(STORY)["chapters"]:
        assert chapter["human_question"].strip().endswith("?")
        assert all(chapter["emotional_arc"].get(key, "").strip() for key in ("start", "turn", "end"))
        assert len(chapter["player_knowledge_start"]) >= 2
        assert len(chapter["player_knowledge_end"]) >= 2
        assert chapter["forbidden_reveals"]
        assert len(chapter["environmental_beats"]) >= 4
        assert chapter["character_pressure"]
        assert chapter["choice_echoes"]
        assert chapter["transition_hook"].strip()
        for pressure in chapter["character_pressure"]:
            assert pressure["character"].strip()
            assert pressure["pressure"].strip()
            assert pressure["must_not_become"].strip()


def test_narrator_is_limited_authored_and_covers_all_chapters():
    narrator = load(NARRATOR)
    story = load(STORY)
    assert "non personnifiée" in narrator["identity"]
    assert narrator["style_contract"]["max_sentences_default"] <= 3
    narrator_chapters = narrator["chapters"]
    for chapter in story["chapters"]:
        chapter_id = chapter["id"]
        assert chapter_id in narrator_chapters
        assert narrator_chapters[chapter_id]["opening"]
        assert narrator_chapters[chapter_id]["closing"]
        text = " ".join(
            line
            for lines in narrator_chapters[chapter_id].values()
            for line in lines
        ).lower()
        for forbidden in chapter["forbidden_reveals"]:
            assert forbidden.lower() not in text


def test_narrator_forbidden_tics_are_absent_from_authored_lines():
    narrator = load(NARRATOR)
    all_text = []
    for lines in narrator["generic_lines"].values():
        all_text.extend(lines)
    for chapter in narrator["chapters"].values():
        for lines in chapter.values():
            all_text.extend(lines)
    corpus = " ".join(all_text).lower()
    for tic in narrator["style_contract"]["forbidden_tics"]:
        assert tic.lower() not in corpus


def test_key_scenes_cover_every_chapter_with_action_dialogue_environment_and_aftermath():
    story_ids = [chapter["id"] for chapter in load(STORY)["chapters"]]
    scene_data = load(KEY_SCENES)
    assert set(scene_data["chapters"]) == set(story_ids)
    for chapter_id in story_ids:
        scenes = scene_data["chapters"][chapter_id]
        assert len(scenes) >= scene_data["rules"]["minimum_key_scenes_per_chapter"]
        scene_ids = [scene["id"] for scene in scenes]
        assert len(scene_ids) == len(set(scene_ids))
        for scene in scenes:
            assert scene["function"].strip()
            assert scene["player_action"].strip()
            assert scene["environment"]
            assert scene["dialogue"]
            assert scene["aftermath"].strip()
            for line in scene["dialogue"]:
                assert line["speaker"].strip()
                assert line["text"].strip()


def test_runtime_exposes_base_game_narration_and_key_scenes_without_extending_ngplus():
    project = PROJECT.read_text(encoding="utf-8")
    director = DIRECTOR.read_text(encoding="utf-8")
    assert 'BaseGameNarrativeDirector="*res://scripts/core/base_game_narrative_director.gd"' in project
    assert 'const KEY_SCENES_PATH := "res://data/narrative/base_game_key_scenes.json"' in director
    assert 'func current_human_question()' in director
    assert 'func environmental_beats(' in director
    assert 'func key_scenes(' in director
    assert 'func key_scene(' in director
    assert 'func select_and_log(' in director
    assert 'return EndgameState.active_cycle <= 0' in director
    assert 'select_and_log("closing", _last_chapter_id)' in director
    assert 'select_and_log("opening", current_id)' in director
