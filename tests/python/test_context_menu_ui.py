import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_context_menu_is_registered_and_has_input_action():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'ContextMenuUI="*res://scripts/ui/context_menu_ui.gd"' in project
    assert 'context_menu={' in project


def test_context_menu_exposes_requested_tabs_and_live_managers():
    ui = (ROOT / "scripts" / "ui" / "context_menu_ui.gd").read_text(encoding="utf-8")
    for label in ["INVENTAIRE", "ÉQUIPEMENT", "COMPÉTENCES", "JOURNAL DE QUÊTES", "OPTIONS DE JEU"]:
        assert label in ui
    for contract in [
        "EquipmentManager.items",
        "EquipmentManager.equipped_by_hero",
        "EquipmentManager.equip(",
        "HeroSkillManager.skill_nodes(",
        "HeroSkillManager.unlock(",
        "CampaignState.active_main_quests()",
        "DataLoader.quests",
        "ExpeditionManager.expedition_active",
        "AudioServer.set_bus_volume_db",
        "DisplayServer.window_set_mode",
    ]:
        assert contract in ui


def test_journal_visibly_separates_campaign_and_dungeon_quests():
    ui = (ROOT / "scripts" / "ui" / "context_menu_ui.gd").read_text(encoding="utf-8")
    assert '[CAMPAGNE]' in ui
    assert '[DONJON]' in ui
    assert '_quest_card("CAMPAGNE"' in ui
    assert '_quest_card("DONJON"' in ui


def test_dungeon_quest_data_is_explicitly_typed_and_trackable():
    quests = json.loads((ROOT / "data" / "quests.json").read_text(encoding="utf-8"))
    assert quests
    assert all(quest.get("quest_type") == "dungeon" for quest in quests)
    assert all(quest.get("dungeon_id") for quest in quests)
    assert all(isinstance(quest.get("condition"), dict) and quest["condition"].get("type") for quest in quests)


def test_options_persist_to_user_config():
    ui = (ROOT / "scripts" / "ui" / "context_menu_ui.gd").read_text(encoding="utf-8")
    assert 'user://litd_settings.cfg' in ui
    assert "ConfigFile.new()" in ui
    assert "_save_options()" in ui
    assert "_load_options()" in ui
