import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_json(relative_path: str):
    return json.loads((ROOT / relative_path).read_text(encoding="utf-8"))


def test_concord_has_six_major_pre_fall_cities():
    data = load_json("data/concord_political_world.json")
    cities = data["cities"]
    assert len(cities) == 6
    assert {city["id"] for city in cities} == {
        "jian_lu", "sorye", "dhor_khal", "lhaor", "tessen", "orun_sai"
    }


def test_city_currents_reference_known_pre_fall_currents():
    world = load_json("data/concord_political_world.json")
    politics = load_json("data/pre_fall_political_currents.json")
    known = {current["id"] for current in politics["currents"]}
    for city in world["cities"]:
        assert city["dominant_currents"]
        assert set(city["dominant_currents"]).issubset(known)


def test_core_offices_and_limits_exist():
    world = load_json("data/concord_political_world.json")
    offices = {office["id"]: office for office in world["offices"]}
    assert "spokesperson" in offices
    assert offices["spokesperson"]["term_years"] == 2
    assert offices["spokesperson"]["immediate_renewal"] is False
    assert "pact_watcher" in offices
    assert "living_guardian" in offices
    assert "justice_arbiter" in offices


def test_historical_crises_cover_multiple_centuries():
    world = load_json("data/concord_political_world.json")
    crises = world["historical_crises"]
    assert len(crises) >= 6
    dates = [crisis["years_before_fall"] for crisis in crises]
    assert max(dates) >= 700
    assert min(dates) <= 100


def test_political_quests_link_to_existing_cities_and_have_real_choices():
    world = load_json("data/concord_political_world.json")
    quests = load_json("data/political_quests.json")
    city_ids = {city["id"] for city in world["cities"]}
    assert len(quests["quests"]) >= 8
    for quest in quests["quests"]:
        assert quest["origin_city"] in city_ids
        assert len(quest["values"]) >= 3
        assert len(quest["choices"]) >= 3


def test_political_quests_are_not_simple_faction_reputation():
    quests = load_json("data/political_quests.json")
    rule = quests["design_rule"].lower()
    assert "jauge de faction" in rule
    assert "bon/mauvais" in rule
