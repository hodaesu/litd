from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
MENU = (ROOT / "scripts" / "ui" / "game_menu_ui.gd").read_text(encoding="utf-8")
SETTINGS = (ROOT / "scripts" / "core" / "game_settings.gd").read_text(encoding="utf-8")

def test_unified_game_menu_is_registered_and_accessible():
    assert 'GameMenuUI="*res://scripts/ui/game_menu_ui.gd"' in PROJECT
    assert 'GameSettings="*res://scripts/core/game_settings.gd"' in PROJECT
    assert 'game_menu={' in PROJECT
    assert 'launcher = _button("MENU"' in MENU
    assert 'event.is_action_pressed("game_menu")' in MENU

def test_menu_contains_all_required_tabs():
    for tab in ["INVENTAIRE", "CARTE", "JOURNAL", "PERSONNAGES", "OPTIONS"]:
        assert tab in MENU
    for renderer in ["_render_inventory", "_render_map", "_render_journal", "_render_characters", "_render_options"]:
        assert f"func {renderer}" in MENU

def test_inventory_and_map_use_live_game_state():
    assert "EquipmentManager.items" in MENU
    assert "EquipmentManager.guild_stash" in MENU
    assert "EquipmentManager.equip" in MENU
    assert "AshlandsRuntime.discovered_zones" in MENU
    assert "AshlandsRuntime.unlocked_shortcuts" in MENU
    assert "AshlandsRuntime.current_zone_id" in MENU

def test_journal_includes_main_side_and_bounty_quests():
    assert "CampaignState.active_main_quests()" in MENU
    assert '"res://data/quests.json"' in MENU
    assert "BountyContractDirector.active_contracts" in MENU

def test_character_skills_are_selectable_in_four_slots():
    assert "HeroSkillManager.COMBAT_LOADOUT_SIZE" in MENU
    assert "HeroSkillManager.combat_loadout" in MENU
    assert "HeroSkillManager.known_combat_skills" in MENU
    assert "HeroSkillManager.equip_combat_skill" in MENU
    assert "selected_skill_slot" in MENU

def test_options_are_applied_and_saved():
    for setting in ["master_volume", "music_volume", "sfx_volume", "fullscreen", "subtitles", "screen_shake"]:
        assert setting in SETTINGS
    assert 'const PATH := "user://litd_settings.json"' in SETTINGS
    assert "AudioServer.set_bus_volume_db" in SETTINGS
    assert "DisplayServer.window_set_mode" in SETTINGS
    assert "save_settings()" in SETTINGS
