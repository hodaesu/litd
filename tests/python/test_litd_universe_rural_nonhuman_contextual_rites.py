from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.contextual_beliefs_rites_quests_audit import audit_contextual_beliefs_rites_quests
from tools.qa.nonhuman_consciousness_audit import audit_nonhuman_consciousness
from tools.qa.rural_nomadic_cultures_audit import audit_rural_nomadic_cultures


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_rural_world_has_six_lifeways_without_nomad_ethnicity() -> None:
    data = load_json(ROOT / "universe/lore/rural_nomadic_cultures.json")
    assert len(data["lifeways"]) == 6
    assert data["core_rules"]["rural_means_backward"] is False
    assert data["core_rules"]["nomadism_is_ethnicity"] is False
    pastoral = next(item for item in data["lifeways"] if item["id"] == "transhumant_pastoral_networks")
    assert pastoral["name_locked"] is False
    assert pastoral["livestock_species_locked"] is False


def test_saen_is_interlocutor_without_invented_ontology() -> None:
    data = load_json(ROOT / "universe/lore/nonhuman_consciousness.json")
    saen = data["entities"]["saen"]
    assert saen["status"] == "documented_conscious_interlocutor"
    assert saen["ontology"] == "unknown"
    assert "expresses_refusal" in saen["confirmed"]
    assert "representative_of_all_absents" in saen["unconfirmed"]
    assert data["entities"]["absents"]["saen_represents_all"] is False


def test_frontier_remains_reactive_without_being_declared_conscious() -> None:
    data = load_json(ROOT / "universe/lore/nonhuman_consciousness.json")
    frontier = data["entities"]["frontier"]
    assert frontier["causal_reactivity_confirmed"] is True
    assert frontier["consciousness_confirmed"] is False
    assert frontier["hostility_confirmed"] is False


def test_clear_refusal_blocks_capture_recruitment_and_invasive_testing() -> None:
    data = load_json(ROOT / "universe/lore/nonhuman_consciousness.json")
    policy = data["consent_policy"]
    assert policy["capture_after_clear_refusal_allowed"] is False
    assert policy["recruitment_after_clear_refusal_allowed"] is False
    assert policy["invasive_experiment_after_clear_refusal_allowed"] is False


def test_contextual_rites_do_not_close_open_theologies() -> None:
    data = load_json(ROOT / "universe/lore/contextual_beliefs_rites_quests.json")
    assert data["azravel"]["dominant_faith_name_locked"] is False
    assert data["azravel"]["deity_model_locked"] is False
    assert data["lysandra"]["miracle_term_proves_theology"] is False
    assert data["zeje"]["final_geographic_origin_locked_by_this_pass"] is False
    assert data["effrie"]["ancestral_pact_locked"] is False
    assert data["effrie"]["dragon_language_locked"] is False
    assert data["effrie"]["veil_link_locked"] is False


def test_character_practices_are_specific_without_new_stats() -> None:
    data = load_json(ROOT / "universe/lore/contextual_beliefs_rites_quests.json")
    assert len(data["azravel"]["practices"]) == 3
    assert len(data["lysandra"]["practices"]) == 3
    assert len(data["zeje"]["practices"]) == 3
    assert len(data["effrie"]["practices"]) == 3
    gameplay = data["gameplay"]
    assert gameplay["faith_meter"] is False
    assert gameplay["ritual_meter"] is False
    assert gameplay["consciousness_stat"] is False
    assert gameplay["religious_or_ethnic_bonus"] is False


def test_quest_hooks_allow_uncertainty_and_do_not_force_dragon_reveal() -> None:
    data = load_json(ROOT / "universe/lore/contextual_beliefs_rites_quests.json")
    quests = {item["id"]: item for item in data["quest_hooks"]}
    assert len(quests) == 9
    assert quests["zeje_three_versions_same_dead"]["valid_resolution_can_be_unknown"] is True
    assert quests["effrie_not_ours"]["visible_dragon_required"] is False
    assert quests["effrie_not_ours"]["pact_revelation_required"] is False
    assert quests["saen_ask_before_pulling"]["required_rule"] == "clear_refusal_changes_permitted_actions"


def test_all_three_new_audits_pass() -> None:
    rural = audit_rural_nomadic_cultures(ROOT)
    nonhuman = audit_nonhuman_consciousness(ROOT)
    contextual = audit_contextual_beliefs_rites_quests(ROOT)
    assert rural["ok"], rural
    assert nonhuman["ok"], nonhuman
    assert contextual["ok"], contextual


def test_rural_audit_rejects_nomadism_as_ethnicity(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    path = tmp_path / "universe/lore/rural_nomadic_cultures.json"
    data = load_json(path)
    data["core_rules"]["nomadism_is_ethnicity"] = True
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_rural_nomadic_cultures(tmp_path)
    assert not report["ok"]
    assert any("nomadism_is_ethnicity" in error for error in report["errors"]), report


def test_nonhuman_audit_rejects_frontier_consciousness_invention(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    path = tmp_path / "universe/lore/nonhuman_consciousness.json"
    data = load_json(path)
    data["entities"]["frontier"]["consciousness_confirmed"] = True
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_nonhuman_consciousness(tmp_path)
    assert not report["ok"]
    assert any("frontière" in error.lower() for error in report["errors"]), report


def test_contextual_audit_rejects_effrie_pact_becoming_canon(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    path = tmp_path / "universe/lore/contextual_beliefs_rites_quests.json"
    data = load_json(path)
    data["effrie"]["ancestral_pact_locked"] = True
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_contextual_beliefs_rites_quests(tmp_path)
    assert not report["ok"]
    assert any("ancestral_pact_locked" in error for error in report["errors"]), report


def test_contextual_audit_rejects_miracle_as_theology_proof(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    path = tmp_path / "universe/lore/contextual_beliefs_rites_quests.json"
    data = load_json(path)
    data["lysandra"]["miracle_term_proves_theology"] = True
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_contextual_beliefs_rites_quests(tmp_path)
    assert not report["ok"]
    assert any("miracle" in error.lower() for error in report["errors"]), report
