import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUESTS = json.loads((ROOT / "data" / "quests.json").read_text(encoding="utf-8"))
BOUNTIES = json.loads((ROOT / "data" / "bounty_contracts.json").read_text(encoding="utf-8"))

def test_first_map_has_scenario_main_quest_and_five_side_quests():
    assert QUESTS["map_id"] == "c01_ashlands_first_route"
    assert len(QUESTS["scenario"]["acts"]) == 3
    quests = QUESTS["quests"]
    assert len([q for q in quests if q["quest_type"] == "main"]) == 1
    side = [q for q in quests if q["quest_type"] == "side"]
    assert len(side) == 5
    assert len({q["id"] for q in quests}) == len(quests)
    assert all(q["objectives"] and q.get("reward") for q in quests)

def test_side_quests_cover_exploration_memory_care_creatures_and_lore():
    side_ids = {q["id"] for q in QUESTS["quests"] if q["quest_type"] == "side"}
    assert side_ids == {
        "c01_side_buried_bell",
        "c01_side_names_in_ash",
        "c01_side_last_medic",
        "c01_side_quiet_creature",
        "c01_side_three_testimonies",
        "c01_side_embers_for_night",
    }

def test_bounties_exist_in_every_dungeon_and_campaign():
    rules = BOUNTIES["rules"]
    assert rules["enabled_in_every_dungeon"] is True
    assert rules["enabled_across_campaign"] is True
    assert rules["deterministic_seed"] is True
    assert rules["no_reload_reroll"] is True
    assert rules["board_size"] == 3
    assert rules["max_active"] == 2
    assert len(BOUNTIES["archetypes"]) >= 6
    assert len(BOUNTIES["campaign_bounties"]["archetypes"]) >= 3

def test_bounty_targets_are_valid_for_the_current_dungeon():
    rules = BOUNTIES["rules"]
    assert rules["target_must_exist_in_dungeon"] is True
    assert rules["bosses_excluded_unless_named_contract"] is True
    for archetype in BOUNTIES["archetypes"]:
        assert archetype["event"]
        assert archetype["target_source"]
        assert archetype["counts"]
        assert all(count > 0 for count in archetype["counts"])

def test_bounty_runtime_is_saved_and_wired():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    save = (ROOT / "scripts" / "core" / "save_manager.gd").read_text(encoding="utf-8")
    game = (ROOT / "scripts" / "core" / "game_state.gd").read_text(encoding="utf-8")
    combat = (ROOT / "scripts" / "ui" / "main.gd").read_text(encoding="utf-8")
    journal = (ROOT / "scripts" / "ui" / "quest_journal_ui.gd").read_text(encoding="utf-8")
    assert 'BountyContractDirector="*res://scripts/core/bounty_contract_director.gd"' in project
    assert '"bounty_contracts": BountyContractDirector.serialize()' in save
    assert 'BountyContractDirector.deserialize' in save
    assert 'BountyContractDirector.reset_new_game()' in game
    assert 'BountyContractDirector.record_event("enemy_defeated"' in combat
    assert "CONTRATS DE CHASSE" in journal
