from __future__ import annotations

import json
from pathlib import Path

from tools.qa.contextual_quest_ramifications_audit import audit_contextual_quest_ramifications


ROOT = Path(__file__).resolve().parents[2]
RAM_PATH = ROOT / "universe/lore/theatrical_contextual_quest_ramifications.json"
SOURCE_PATH = ROOT / "universe/lore/theatrical_contextual_quests.json"
DOC_PATH = ROOT / "docs/LITD1_NEUF_QUETES_RAMIFICATIONS_V1.md"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_ramification_audit_passes() -> None:
    report = audit_contextual_quest_ramifications(ROOT)
    assert report["ok"], report
    assert report["summary"]["quests"] == 9
    assert report["summary"]["source_choices"] == 26
    assert report["summary"]["ramifications"] == 26


def test_every_source_choice_has_exactly_one_ramification() -> None:
    source = load(SOURCE_PATH)
    data = load(RAM_PATH)
    expected = {
        (quest["id"], choice["id"])
        for quest in source["quests"]
        for choice in quest["choices"]
    }
    actual = [(item["quest_id"], item["choice_id"]) for item in data["ramifications"]]
    assert len(actual) == len(set(actual)) == 26
    assert set(actual) == expected


def test_remanence_never_flows_backwards_from_litd1() -> None:
    data = load(RAM_PATH)
    core = data["core_rules"]
    assert core["remanence_can_cause_past_games"] is False
    assert core["pre_litd1_connections_are_antecedents"] is True
    assert core["post_litd1_can_seed_future_games"] is True
    for item in data["ramifications"]:
        assert item["remanence"] == {
            "pre_litd1_role": "antecedent_only",
            "future_target": "post_litd1",
            "backward_causation": False,
        }


def test_deaths_are_contextual_not_moral_punishment() -> None:
    data = load(RAM_PATH)
    assert data["core_rules"]["deaths_are_automatic_punishment"] is False
    possible = [item for item in data["ramifications"] if item["possible_death"]]
    assert possible
    assert all(item["death_is_automatic"] is False for item in possible)


def test_all_seven_can_react_but_only_conditionally() -> None:
    data = load(RAM_PATH)
    expected = {
        "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
        "hero.marec", "hero.zeje", "hero.anouk",
    }
    represented = {hero for item in data["ramifications"] for hero in item["hero_followups"]}
    assert represented == expected
    assert all(item["hero_dialogue_conditional"] is True for item in data["ramifications"])
    assert data["core_rules"]["complete_seven_order_inferred"] is False


def test_no_new_meter_or_numeric_lore_balance_contract() -> None:
    data = load(RAM_PATH)
    assert data["core_rules"]["new_universal_meter"] is False
    assert data["core_rules"]["global_morality_score"] is False
    assert data["core_rules"]["economic_effects_are_numeric_balance_values"] is False
    assert data["core_rules"]["migration_is_population_score"] is False
    encoded = json.dumps(data, ensure_ascii=False).lower()
    assert "reputation_score" not in encoded
    assert "alignment_score" not in encoded


def test_saen_refusal_is_not_reopened_by_ramifications() -> None:
    source = load(SOURCE_PATH)
    quest = next(q for q in source["quests"] if q["id"] == "quest.litd1.saen_ask_before_pulling")
    assert {choice["id"] for choice in quest["choices"]} == {
        "cut_anchor_and_detour",
        "low_pulses_public_stop_threshold",
    }
    assert "invasive_anchor_increase_on_saen" in quest["forbidden_after_clear_refusal"]


def test_lysandra_followup_keeps_bodily_consequences_visible() -> None:
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "cicatrice reste irrégulière" in doc
    assert "zone demeure insensible" in doc
    assert "rééducation est nécessaire" in doc
    source = load(SOURCE_PATH)
    quest = next(q for q in source["quests"] if q["id"] == "quest.litd1.lysandra_what_miracle_proves")
    assert "miracle_does_not_prove_theology" in quest["guardrails"]


def test_zeje_probable_and_unknown_remain_valid_followups() -> None:
    data = load(RAM_PATH)
    branches = {
        item["choice_id"]
        for item in data["ramifications"]
        if item["quest_id"] == "quest.litd1.zeje_three_versions_same_dead"
    }
    assert "assign_most_probable_identity" in branches
    assert "preserve_unknown_distribute_objects" in branches
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "PROBABLE" in doc
    assert "INCONNU" in doc


def test_effrie_ramifications_do_not_lock_dragon_cosmology() -> None:
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "ne verrouille Vharren" in doc
    assert "Pacte ancestral" in doc
    assert "langue draconique" in doc
    assert "lien au Voile" in doc
    data = load(RAM_PATH)
    branches = {
        item["choice_id"]
        for item in data["ramifications"]
        if item["quest_id"] == "quest.litd1.effrie_not_ours"
    }
    assert branches == {
        "leave_object_document_site",
        "minimal_sample_after_mapping",
        "remove_object_for_human_need",
    }
