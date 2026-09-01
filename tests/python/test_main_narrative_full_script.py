import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data/narrative/main_script/manifest.json"
CAMPAIGN = ROOT / "data/world/main_campaign.json"
PROJECT = ROOT / "project.godot"
RUNTIME = ROOT / "scripts/core/main_narrative_script_runtime.gd"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def chapter_files():
    manifest = load(MANIFEST)
    for entry in manifest["chapters"]:
        rel = entry["file"].removeprefix("res://")
        yield entry["id"], ROOT / rel


def test_manifest_covers_exactly_main_campaign_chapters():
    manifest = load(MANIFEST)
    campaign = load(CAMPAIGN)
    manifest_ids = [entry["id"] for entry in manifest["chapters"]]
    campaign_ids = [chapter["id"] for chapter in campaign["chapters"]]
    assert manifest_ids == campaign_ids
    assert len(manifest_ids) == 10
    assert manifest["status"] == "production_script_v1"


def test_all_script_files_exist_and_match_manifest():
    for chapter_id, path in chapter_files():
        assert path.exists(), f"missing script {path}"
        data = load(path)
        assert data["chapter_id"] == chapter_id
        assert data["human_question"].strip().endswith("?")
        assert len(data["scenes"]) >= 8


def test_every_scene_is_playable_and_authored():
    scene_ids = []
    allowed_kinds = {"narration", "dialogue", "action", "choice", "silence", "system"}
    for chapter_id, path in chapter_files():
        data = load(path)
        for scene in data["scenes"]:
            scene_ids.append(scene["id"])
            assert scene["chapter_id"] == chapter_id
            assert scene["type"].strip()
            assert scene["trigger"].strip()
            assert scene["purpose"].strip()
            assert scene["staging"]
            assert scene["beats"]
            assert scene["exit_state"]
            for beat in scene["beats"]:
                assert beat["kind"] in allowed_kinds
                if beat["kind"] in {"narration", "dialogue", "action", "silence", "system"}:
                    assert beat.get("text", "").strip()
                if beat["kind"] == "dialogue":
                    assert beat.get("speaker", "").strip()
                    assert beat.get("speaker", "").lower() not in {"protagoniste", "joueur", "player", "hero"}
                if beat["kind"] == "choice":
                    assert beat.get("id", "").strip()
                    assert beat.get("prompt", "").strip()
                    assert len(beat.get("options", [])) >= 2
                    option_ids = []
                    for option in beat["options"]:
                        option_ids.append(option["id"])
                        assert option["label"].strip()
                        assert option.get("response")
                        assert option.get("sets")
                    assert len(option_ids) == len(set(option_ids))
    assert len(scene_ids) == len(set(scene_ids))


def test_every_main_quest_has_authored_scene_coverage():
    campaign = load(CAMPAIGN)
    scripts = {chapter_id: load(path) for chapter_id, path in chapter_files()}
    for chapter in campaign["chapters"]:
        chapter_id = chapter["id"]
        covered = {scene.get("quest_id") for scene in scripts[chapter_id]["scenes"] if scene.get("quest_id")}
        expected = {quest["id"] for quest in chapter.get("main_quests", [])}
        assert expected.issubset(covered), f"{chapter_id}: missing quests {expected - covered}"


def test_every_main_boss_has_authored_resolution_scene():
    campaign = load(CAMPAIGN)
    scripts = {chapter_id: load(path) for chapter_id, path in chapter_files()}
    for chapter in campaign["chapters"]:
        chapter_id = chapter["id"]
        boss_scenes = [scene for scene in scripts[chapter_id]["scenes"] if scene["type"] == "boss"]
        corpus = " ".join(scene["id"] + " " + scene["trigger"] for scene in boss_scenes)
        for boss in chapter.get("bosses", []):
            assert boss["id"] in corpus, f"{chapter_id}: missing boss script {boss['id']}"


def test_each_chapter_has_opening_closing_and_consequence_choices():
    for chapter_id, path in chapter_files():
        data = load(path)
        types = [scene["type"] for scene in data["scenes"]]
        assert "chapter_opening" in types
        assert "chapter_closing" in types
        choices = [beat for scene in data["scenes"] for beat in scene["beats"] if beat["kind"] == "choice"]
        assert choices, f"{chapter_id} has no authored choice"


def test_player_created_character_has_no_forced_fixed_dialogue_voice():
    forbidden_speakers = {"Protagoniste", "Joueur", "Player", "Hero", "Aurélien"}
    for _, path in chapter_files():
        data = load(path)
        for scene in data["scenes"]:
            for beat in scene["beats"]:
                if beat["kind"] == "dialogue":
                    assert beat.get("speaker") not in forbidden_speakers
                if beat["kind"] == "choice":
                    for option in beat["options"]:
                        assert not option["label"].startswith("«"), "player choices must be intentions, not forced quotes"


def test_runtime_is_autoloaded_and_can_run_authored_scenes():
    project = PROJECT.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    assert 'MainNarrativeScriptRuntime="*res://scripts/core/main_narrative_script_runtime.gd"' in project
    assert 'const MANIFEST_PATH := "res://data/narrative/main_script/manifest.json"' in runtime
    for function_name in [
        "chapter_script", "chapter_scenes", "scene", "scenes_for_trigger",
        "start_scene", "advance", "choose", "available_options", "serialize", "deserialize"
    ]:
        assert f"func {function_name}(" in runtime
    assert "EndgameState.active_cycle > 0" in runtime


def test_no_known_legacy_english_placeholders_reappear():
    forbidden = [
        "the gate opens only enough for one body",
        "fear is a witness",
        "keep the weapon side clear",
        "they know our names now",
    ]
    corpus = "\n".join(path.read_text(encoding="utf-8").lower() for _, path in chapter_files())
    for phrase in forbidden:
        assert phrase not in corpus
