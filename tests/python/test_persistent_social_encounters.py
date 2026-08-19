from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _data(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_persistent_social_encounter_families_exist() -> None:
    field = _data("data/field_encounters.json")
    encounters = {item["id"]: item for item in field["encounters"]}
    required = {
        "c01_wounded_messenger",
        "c01_separated_family",
        "c01_family_reunion",
        "c01_former_soldier",
        "c01_refugees_low_road",
        "c01_conscious_creature",
        "c03_edrin_return",
        "c03_family_after_reunion",
        "c03_family_independent",
        "c03_former_soldier_return",
        "c03_refugee_route_return",
        "c03_sivra_return",
        "c03_sivra_banished_trace",
    }
    assert required <= encounters.keys()

    choice_groups = {
        "c01_wounded_messenger": {"evacuate", "stabilize_local", "mark_shelter"},
        "c01_separated_family": {"search", "mark_route", "decline"},
        "c01_former_soldier": {"escort_sanctuary", "question_release", "leave_guarded"},
        "c01_refugees_low_road": {"sanctuary_route", "relay_route", "refuse_route"},
        "c01_conscious_creature": {"pact", "release", "banish"},
    }
    for encounter_id, expected in choice_groups.items():
        choices = {choice["id"] for choice in encounters[encounter_id]["choices"]}
        assert expected <= choices


def test_choices_have_real_costs_and_alternate_non_costly_branches() -> None:
    field = _data("data/field_encounters.json")
    survival = _data("data/levels/ashlands_survival_rules.json")
    resources = set(survival["expedition_inventory"])
    encounters = {item["id"]: item for item in field["encounters"]}

    choice_encounter_ids = [
        "c01_wounded_messenger",
        "c01_separated_family",
        "c01_former_soldier",
        "c01_refugees_low_road",
        "c01_conscious_creature",
    ]
    for encounter_id in choice_encounter_ids:
        choices = encounters[encounter_id]["choices"]
        assert any(choice.get("cost") for choice in choices)
        for choice in choices:
            assert set(choice.get("cost", {})) <= resources
            assert choice.get("memory_choice") in {"aid", "keep"}
            assert choice.get("outcome")

    # Un blessé peut légitimement n'avoir que des options qui mobilisent au moins une
    # ressource. Les autres dilemmes conservent bien une branche sans dépense matérielle.
    for encounter_id in [
        "c01_separated_family",
        "c01_former_soldier",
        "c01_refugees_low_road",
        "c01_conscious_creature",
    ]:
        assert any(choice.get("cost", {}) == {} for choice in encounters[encounter_id]["choices"])


def test_alternate_outcomes_return_without_binary_morality() -> None:
    field = _data("data/field_encounters.json")
    encounters = {item["id"]: item for item in field["encounters"]}

    assert encounters["c03_family_independent"]["source_outcomes"] == ["declined"]
    assert "refused" in encounters["c03_refugee_route_return"]["source_outcomes"]
    assert encounters["c03_sivra_banished_trace"]["source_outcomes"] == ["banished"]
    assert {"escorted", "released", "guarded"} <= set(encounters["c03_former_soldier_return"]["variants"])

    joined = json.dumps(field, ensure_ascii=False).lower()
    assert "morality_score" not in joined
    assert "good_choice" not in joined
    assert "bad_choice" not in joined


def test_world_and_sanctuary_people_persist() -> None:
    community = _data("data/community_network.json")
    people = {item["id"]: item for item in community["people"]}
    required_people = {
        "edrin_wounded_messenger",
        "sela_red_thread",
        "nerin_red_thread",
        "tarek_turned_uniform",
        "nima_low_road",
        "sivra_ember_voice",
    }
    assert required_people <= people.keys()

    transitions = community["encounter_transitions"]
    assert transitions["c01_wounded_messenger"]["evacuated"]["people"]["edrin_wounded_messenger"]["sanctuary_presence"] is True
    assert transitions["c01_former_soldier"]["escorted"]["people"]["tarek_turned_uniform"]["sanctuary_presence"] is True
    assert transitions["c01_refugees_low_road"]["sanctuary_route"]["people"]["nima_low_road"]["sanctuary_presence"] is True
    assert transitions["c01_refugees_low_road"]["relay_route"]["people"]["nima_low_road"]["sanctuary_presence"] is False
    assert transitions["c01_conscious_creature"]["pact"]["people"]["sivra_ember_voice"]["sanctuary_presence"] is False


def test_new_emergent_quests_use_real_chapter_three_evidence() -> None:
    community = _data("data/community_network.json")
    chapter3 = _data("data/levels/chapter_03_world.json")
    evidence_ids = {item["id"] for item in chapter3["evidence"]}
    quests = {item["id"]: item for item in community["quests"]}

    for quest_id in ["q_edrin_last_waypoint", "q_tarek_order_without_uniform"]:
        quest = quests[quest_id]
        assert quest["objective"]["type"] == "chapter03_evidence"
        assert quest["objective"]["id"] in evidence_ids
        narrative = quest["narrative"]
        assert len(set(narrative["devices"])) >= 3
        assert len(narrative["dramatic_question"]) >= 80
        assert len(narrative["reframe"]) >= 100
        assert len(narrative["aftermath_seed"]) >= 100
