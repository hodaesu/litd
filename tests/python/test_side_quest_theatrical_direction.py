import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRECTION = ROOT / "data/narrative/side_quest_theatrical_direction.json"
QUESTS = ROOT / "data/quests.json"
SIDE_STORIES = ROOT / "data/narrative/base_game_side_stories.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def side_quest_ids():
    ids = {q["id"] for q in load(QUESTS) if str(q.get("id", "")).startswith("c01_side_")}
    ids.update(q["id"] for q in load(SIDE_STORIES))
    return ids


def test_direction_covers_all_authored_side_quests():
    data = load(DIRECTION)
    expected = side_quest_ids()
    assert len(expected) == 23
    assert set(data["quest_directions"]) == expected


def test_each_side_quest_has_readable_theatrical_blocking():
    data = load(DIRECTION)
    for quest_id, direction in data["quest_directions"].items():
        assert direction["opening_blocking"].strip(), quest_id
        assert direction["emotional_color"].strip(), quest_id
        assert direction["subtext"].strip(), quest_id
        assert direction["completion_blocking"].strip(), quest_id
        assert direction["choice_direction"].strip(), quest_id


def test_direction_does_not_force_created_player_performance():
    data = load(DIRECTION)
    assert data["rules"]["created_player_has_no_forced_voice_or_body_language"] is True
    serialized = json.dumps(data, ensure_ascii=False).lower()
    for forbidden in ["le protagoniste tremble", "le protagoniste sourit", "le protagoniste pleure", "le protagoniste crie"]:
        assert forbidden not in serialized


def test_chapter_one_additional_givers_have_full_profiles():
    data = load(DIRECTION)
    required = {"emotion", "posture", "gaze", "gesture", "breath", "voice", "subtext", "script_note"}
    for giver in ["ilyan_orme", "naima_sol", "tarek_vann", "eno_kesh"]:
        assert required <= set(data["additional_giver_profiles"][giver])
