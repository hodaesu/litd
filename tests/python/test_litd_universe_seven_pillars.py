import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PILLARS_PATH = ROOT / "litd_universe" / "seven_pillars.json"
CANON_PATH = ROOT / "litd_universe" / "SEVEN_PILLARS.md"


def load_pillars() -> dict:
    return json.loads(PILLARS_PATH.read_text(encoding="utf-8"))


def test_litd_universe_has_exactly_seven_canonical_pillars() -> None:
    data = load_pillars()
    assert data["status"] == "CANON_MANDATORY"
    assert [pillar["id"] for pillar in data["pillars"]] == [
        "BODY",
        "MIND",
        "POLITICS",
        "FEAR",
        "HOPE",
        "MADNESS",
        "LIGHT",
    ]


def test_pillars_apply_to_every_litd_game_generation() -> None:
    data = load_pillars()
    assert data["applies_to"] == ["LITD_1", "LITD_2", "FUTURE_LITD_PROJECTS"]
    assert all(pillar["non_negotiable"] for pillar in data["pillars"])
    assert all(pillar["core_question"] for pillar in data["pillars"])


def test_human_canon_names_all_seven_pillars() -> None:
    canon = CANON_PATH.read_text(encoding="utf-8")
    for name in ("CORPS", "ESPRIT", "POLITIQUE", "PEUR", "ESPOIR", "FOLIE", "LUMIÈRE"):
        assert f"## " in canon
        assert name in canon


def test_pillars_do_not_force_one_shared_gameplay_system() -> None:
    canon = CANON_PATH.read_text(encoding="utf-8")
    assert "ne prescrivent pas un genre de jeu" in canon
    assert "chaque projet peut les traduire différemment" in canon
