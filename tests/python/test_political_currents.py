import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load():
    return json.loads((ROOT / "data" / "political_currents.json").read_text())


def test_concorde_has_five_post_fall_currents():
    data = _load()
    assert data["system"] == "Concorde"
    ids = {current["id"] for current in data["currents"]}
    assert ids == {
        "faithful_concord",
        "exception_guardians",
        "refuge_separatists",
        "purifiers",
        "living_reformers",
    }


def test_political_figures_reference_existing_currents():
    data = _load()
    current_ids = {current["id"] for current in data["currents"]}
    figures = {figure["id"]: figure for figure in data["figures"]}
    assert set(figures) == {"maera_sol", "varos_khel", "ilyan_veyr"}
    assert all(figure["current"] in current_ids for figure in figures.values())
    assert figures["ilyan_veyr"]["lucid_quote"].startswith("Je sais qu'ils ne sont pas tous responsables")


def test_post_fall_politics_preserve_dark_fantasy_direction():
    rules = _load()["narrative_rules"]
    assert rules["no_simple_good_evil_split"] is True
    assert rules["politics_through_people_and_consequences"] is True
    assert rules["humor_as_breathing_room_not_tone_break"] is True
    assert rules["dark_fantasy_remains_dominant"] is True
