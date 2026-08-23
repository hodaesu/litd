import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def test_first_map_production_contract_is_complete():
    data = json.loads((ROOT / "data/levels/ashlands_first_map_production.json").read_text(encoding="utf-8"))
    assert data["units"] == "meters"
    assert len(data["zones"]) == 5
    assert len(data["routes"]["main"]) == len(data["zones"])
    assert len(data["routes"]["shortcuts"]) >= 2
    assert len(data["routes"]["blocked"]) >= 2
    assert len(data["routes"]["expedition_variants"]) >= 3
    assert len(data["assets"]) >= 5
    assert len(data["enemy_profiles"]) >= 4
    assert len(data["audio_events"]) >= 15
    for zone in data["zones"]:
        assert all(value > 0 for value in zone["size"])
        assert zone["traversal_seconds"] > 0
        assert "giver" in zone and "quests" in zone
    for asset in data["assets"]:
        assert asset["variants"] > 0
        assert asset["lods"] >= 2
        assert asset["poly_budget"] > 0
        assert asset["collision"]
        assert asset["export"].endswith(".glb")
    for enemy in data["enemy_profiles"]:
        assert enemy["rig"]
        assert {"idle", "fear", "panic", "hit", "death"}.issubset(enemy["animations"])


def test_side_quests_are_live_persistent_and_guided():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/core/side_quest_runtime.gd").read_text(encoding="utf-8")
    saves = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    giver = (ROOT / "scripts/ui/quest_giver_presentation.gd").read_text(encoding="utf-8")
    assert 'SideQuestRuntime="*res://scripts/core/side_quest_runtime.gd"' in project
    for state in ("offered", "active", "refused", "failed", "completed"):
        assert state in runtime
    for method in ("accept_quest", "refuse_quest", "record_event", "serialize", "deserialize"):
        assert "func " + method in runtime
    assert "request_world_guidance" in runtime
    assert '"side_quests": SideQuestRuntime.serialize()' in saves
    assert "SideQuestRuntime.deserialize" in saves
    assert "SideQuestRuntime.accept_quest" in giver
    assert "SideQuestRuntime.refuse_quest" in giver


def test_equipped_skills_and_consumables_drive_combat():
    combat = (ROOT / "scripts/ui/main.gd").read_text(encoding="utf-8")
    assert "for slot in range(4)" in combat
    assert "HeroSkillManager.combat_loadout" in combat
    assert "HeroSkillManager.combat_skill" in combat
    assert "func _use_skill_slot" in combat
    assert "func _use_combat_item" in combat
    assert "CombatLoadoutManager.consume" in combat
    assert 'CombatLoadoutManager.HEAL_SLOT' in combat
    assert 'CombatLoadoutManager.GRENADE_SLOT' in combat
    assert 'enemy["burning"] = 2' in combat
    assert 'enemy["accuracy_down"] = 2' in combat
