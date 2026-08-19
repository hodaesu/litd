from pathlib import Path

from tools.qa.community_network_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_community_network_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_living_sanctuary_has_people_rumors_and_emergent_quests_without_moral_meter():
    data = (ROOT / "data/community_network.json").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/core/community_runtime.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/main_v22.gd").read_text(encoding="utf-8")
    for token in ["mara_three_marks", "yoren_three_marks", "iven_three_marks", "q_iven_erased_days", "q_yoren_false_exit"]:
        assert token in data
    for token in ["sanctuary_people", "recent_rumor_lines", "collective_memory", "accept_quest", "quest_entries"]:
        assert token in runtime
    assert "NarrativeLibrary.quest_state_text" in ui
    assert "QUÊTES NÉES DE LA CAMPAGNE" in ui
    assert "ACCEPTER L'HISTOIRE" in ui
    assert "ProgressBar.new()" not in ui


def test_community_save_is_additive_and_keeps_existing_version_contract():
    save = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    assert 'SAVE_VERSION := "0.31"' in save
    assert '"community": CommunityRuntime.serialize()' in save
    assert 'CommunityRuntime.deserialize(payload.get("community",{}))' in save
