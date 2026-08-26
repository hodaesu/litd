from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_qa_room_concentrates_critical_player_flows() -> None:
    matrix = json.loads((ROOT / "data/qa/validation_room_matrix.json").read_text(encoding="utf-8"))
    assert matrix["campaign_state_isolation"] is True
    assert matrix["production_build_visibility"] == "debug_only"
    station_ids = {station["id"] for station in matrix["stations"]}
    assert station_ids == {"movement", "dialogue", "loot", "combat", "systems"}
    combat = next(station for station in matrix["stations"] if station["id"] == "combat")
    for required in ["four_enemies", "skill_slots", "healing_item", "grenade", "capture_indicator", "return_to_same_room"]:
        assert required in combat["tests"]


def test_qa_room_uses_real_interaction_and_combat_contracts() -> None:
    controller = (ROOT / "scripts/qa/qa_test_room_controller.gd").read_text(encoding="utf-8")
    npc = (ROOT / "scripts/qa/qa_test_dialogue_npc.gd").read_text(encoding="utf-8")
    chest = (ROOT / "scripts/qa/qa_test_loot_chest.gd").read_text(encoding="utf-8")
    assert "EncounterTrigger.new()" in controller
    assert 'encounter_id = "qa_mixed_enemy_combat"' in controller
    assert "QuestGiverPresentation.open_dialogue" in npc
    assert "EquipmentManager.grant_random_party_weapon" in chest
    assert "HUDDirector.notify_pickup" in chest


def test_qa_room_is_routable_but_hidden_from_production_menu() -> None:
    router = (ROOT / "scripts/world/ashlands_scene_router.gd").read_text(encoding="utf-8")
    menu = (ROOT / "scripts/ui/main.gd").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert '"qa_validation_room": QA_VALIDATION_SCENE' in router
    assert "start_qa_validation_room" in router
    assert 'OS.is_debug_build()' in menu
    assert '"SALLE DE VALIDATION"' in menu
    assert 'QATestRoomState="*res://scripts/qa/qa_test_room_state.gd"' in project


def test_qa_snapshot_never_uses_campaign_slots() -> None:
    save = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    assert 'QA_SNAPSHOT_PATH := "user://litd_qa_snapshot.json"' in save
    assert "save_qa_snapshot" in save
    assert "load_qa_snapshot" in save
    assert "delete_qa_snapshot" in save
