import json
from pathlib import Path


DATA_PATH = Path("data/pre_fall_political_currents.json")


def load_data():
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def test_pre_fall_political_currents_are_non_exclusive():
    data = load_data()
    assert data["system"] == "Concorde"
    assert data["period"] == "pre_fall"
    assert data["exclusive_membership"] is False
    assert "plusieurs sensibilités" in data["membership_rule"]


def test_pre_fall_has_six_canonical_currents():
    data = load_data()
    currents = data["currents"]
    assert len(currents) == 6
    ids = {current["id"] for current in currents}
    assert ids == {
        "continuities",
        "civic_reformers",
        "city_autonomists",
        "concord_unionists",
        "living_guardians",
        "body_pragmatists",
    }


def test_each_current_has_strength_and_risk():
    data = load_data()
    for current in data["currents"]:
        assert current["name"]
        assert current["core"]
        assert current["strength"]
        assert current["risk"]


def test_example_profile_combines_multiple_sensitivities():
    data = load_data()
    profile = data["example_profile"]
    assert len(set(profile.values())) >= 3


def test_pre_fall_politics_contains_concrete_debates():
    data = load_data()
    assert len(data["typical_debates"]) >= 8
