from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.theatrical_contextual_quests_audit import audit_theatrical_contextual_quests


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def quests_by_hook(root: Path = ROOT) -> dict[str, dict]:
    data = load_json(root / "universe/lore/theatrical_contextual_quests.json")
    return {quest["source_hook_id"]: quest for quest in data["quests"]}


def test_nine_hooks_become_nine_complementary_quests() -> None:
    data = load_json(ROOT / "universe/lore/theatrical_contextual_quests.json")
    hooks = load_json(ROOT / "universe/lore/contextual_beliefs_rites_quests.json")
    assert data["new_quest_count"] == 9
    assert len(data["quests"]) == 9
    assert data["existing_theatrical_quests_preserved"] == 23
    assert data["core_rules"]["replaces_existing_23_quests"] is False
    assert {q["source_hook_id"] for q in data["quests"]} == {h["id"] for h in hooks["quest_hooks"]}


def test_chapter_placement_matches_campaign_logic() -> None:
    quests = quests_by_hook()
    expected = {
        "lhaor_seeds_that_remain": 1,
        "orun_sai_road_without_grave": 1,
        "dhor_khal_bridge_two_valleys": 1,
        "saen_ask_before_pulling": 6,
        "azravel_burned_margins": 8,
        "azravel_table_still_open": 8,
        "lysandra_what_miracle_proves": 9,
        "zeje_three_versions_same_dead": 9,
        "effrie_not_ours": 9,
    }
    assert {hook: quest["chapter"] for hook, quest in quests.items()} == expected


def test_saen_refusal_changes_permitted_actions() -> None:
    quest = quests_by_hook()["saen_ask_before_pulling"]
    assert "invasive_anchor_increase_on_saen" in quest["forbidden_after_clear_refusal"]
    assert quest["saen_staging"]["human_body_language"] is False
    assert quest["saen_staging"]["represents_all_absents"] is False
    assert len(quest["choices"]) == 2
    assert all("invasive" not in choice["id"] for choice in quest["choices"])


def test_lysandra_miracle_keeps_epistemic_and_bodily_limits() -> None:
    quest = quests_by_hook()["lysandra_what_miracle_proves"]
    guards = set(quest["guardrails"])
    assert "miracle_does_not_prove_theology" in guards
    assert "raised_dead_does_not_prove_soul_return" in guards
    assert "healing_does_not_erase_all_bodily_consequences" in guards
    assert "persistent_irregular_scar" in quest["body_system"]
    assert "persistent_numbness" in quest["body_system"]
    assert quest["epistemic_layers"] == ["observed_effect", "testimony", "interpretation", "doctrine"]


def test_zeje_accepts_unknown_without_becoming_prophet() -> None:
    quest = quests_by_hook()["zeje_three_versions_same_dead"]
    assert quest["requires_character"] == "hero.zeje"
    assert "unknown_is_valid" in quest["guardrails"]
    assert "probable_marker_must_be_visible" in quest["guardrails"]
    statuses = {choice["result_status"] for choice in quest["choices"]}
    assert "unknown" in statuses
    assert "probable" in statuses
    assert "no_truth_spell" in quest["guardrails"]
    assert "zeje_not_prophet" in quest["guardrails"]


def test_effrie_quest_does_not_invent_dragon_canon() -> None:
    quest = quests_by_hook()["effrie_not_ours"]
    assert quest["requires_character"] == "hero.effrie"
    assert quest["visible_dragon_required"] is False
    guards = set(quest["guardrails"])
    assert {
        "no_vharren_lock",
        "no_ancestral_pact_reveal",
        "no_dragon_ancestry_proof",
        "no_dragon_language_lock",
        "no_veil_link",
        "activity_does_not_equal_property",
        "no_visible_dragon_needed",
    }.issubset(guards)


def test_all_quests_have_real_tradeoffs_and_remanence() -> None:
    data = load_json(ROOT / "universe/lore/theatrical_contextual_quests.json")
    assert data["core_rules"]["single_hidden_moral_answer"] is False
    assert data["core_rules"]["universal_good_evil_score"] is False
    assert data["core_rules"]["new_universal_quest_meter"] is False
    for quest in data["quests"]:
        assert len(quest["choices"]) >= 2
        assert all(choice.get("costs") for choice in quest["choices"])
        assert quest["remanence"]["source"]
        assert quest["remanence"]["transmission"]
        assert quest["remanence"]["transformation"]


def test_current_theatrical_contextual_quest_audit_passes() -> None:
    report = audit_theatrical_contextual_quests(ROOT)
    assert report["ok"], report


def test_audit_rejects_missing_hook(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    data_path = tmp_path / "universe/lore/theatrical_contextual_quests.json"
    data = load_json(data_path)
    data["quests"] = data["quests"][:-1]
    data["new_quest_count"] = 8
    data_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_theatrical_contextual_quests(tmp_path)
    assert not report["ok"]
    assert any("9 quêtes" in error or "hooks/quêtes" in error for error in report["errors"]), report


def test_audit_rejects_invasive_saen_choice_after_refusal(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    data_path = tmp_path / "universe/lore/theatrical_contextual_quests.json"
    data = load_json(data_path)
    for quest in data["quests"]:
        if quest["source_hook_id"] == "saen_ask_before_pulling":
            quest["forbidden_after_clear_refusal"] = []
            break
    data_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_theatrical_contextual_quests(tmp_path)
    assert not report["ok"]
    assert any("Saen" in error for error in report["errors"]), report


def test_audit_rejects_dragon_pact_reveal(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    data_path = tmp_path / "universe/lore/theatrical_contextual_quests.json"
    data = load_json(data_path)
    for quest in data["quests"]:
        if quest["source_hook_id"] == "effrie_not_ours":
            quest["guardrails"].remove("no_ancestral_pact_reveal")
            break
    data_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_theatrical_contextual_quests(tmp_path)
    assert not report["ok"]
    assert any("draconiques" in error.lower() for error in report["errors"]), report
