import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = json.loads((ROOT / "data/levels/ashlands_politics.json").read_text())


def test_first_level_has_six_political_npcs_and_three_quests():
    assert len(DATA["npcs"]) == 6
    assert len(DATA["quests"]) == 3
    assert {quest["id"] for quest in DATA["quests"]} == {
        "ashlands_refugee_gate",
        "ashlands_first_blood",
        "ashlands_conscious_creature",
    }


def test_each_quest_has_meaningful_persistent_effects():
    for quest in DATA["quests"]:
        assert len(quest["choices"]) >= 3
        for choice in quest["choices"].values():
            effects = choice["effects"]
            assert any(key in effects for key in ("trust", "tension", "reputation", "supplies"))
            assert set(effects["three_awakenings"]) == {"body", "spirit", "city"}
            assert choice["flags"]
            assert choice["consequence"]


def test_dialogues_react_to_political_and_creature_context():
    npcs = {npc["id"]: npc for npc in DATA["npcs"]}
    assert "high_tension" in npcs["nara_vey"]["dialogues"]
    assert "low_trust" in npcs["nara_vey"]["dialogues"]
    assert "creature_recruited" in npcs["sela_mor"]["dialogues"]
    assert "refugees_welcomed" in npcs["meira_saan"]["dialogues"]


def test_political_runtime_is_autoloaded_and_saved():
    project = (ROOT / "project.godot").read_text()
    runtime = (ROOT / "scripts/core/political_state.gd").read_text()
    save = (ROOT / "scripts/core/save_manager.gd").read_text()
    compact_save = "".join(save.split())
    game_state = (ROOT / "scripts/core/game_state.gd").read_text()
    assert 'PoliticalState="*res://scripts/core/political_state.gd"' in project
    assert "func complete_quest" in runtime
    assert "func price_modifier" in runtime
    assert "func service_unlocked" in runtime
    assert "func get_npc_dialogue" in runtime
    assert '"politics":PoliticalState.serialize()' in compact_save
    assert 'PoliticalState.deserialize(payload.get("politics",{}))' in compact_save
    assert "PoliticalState.reset_new_game()" in game_state


def test_three_awakenings_and_services_are_persistent_gameplay_axes():
    initial = DATA["sanctuary"]["initial_state"]
    assert initial["three_awakenings"] == {"body": 50, "spirit": 50, "city": 50}
    services = DATA["persistent_rules"]["service_thresholds"]
    assert {"mediation", "creature_habitat", "volunteer_watch", "shared_archive"} <= set(services)
    assert DATA["persistent_rules"]["price_formula"]
