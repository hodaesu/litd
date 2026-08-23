import json
from pathlib import Path

ROOT = Path(__file__).parents[1]

def text(path):
    return (ROOT / path).read_text(encoding="utf-8")

def test_robust_save_slots_autosave_integrity_backup_and_migration():
    save = text("scripts/core/save_manager.gd")
    for token in ("SLOT_COUNT := 3", "AUTOSAVE_SLOT := -1", "func autosave", "func slot_metadata", "func all_slots_metadata", "sha256_text", "_atomic_write", "_backup_path", "_migrate", "campaign_memory", "expedition_reports", "preparation_presets"):
        assert token in save
    assert "litd_slot_%d.json" in save and "litd_autosave.json" in save
    assert "DirAccess.rename_absolute" in save

def test_campaign_bounties_are_offered_and_acceptable():
    bounty = text("scripts/core/bounty_contract_director.gd")
    section = bounty[bounty.index("func generate_campaign_board"):bounty.index("func _targets_for")]
    assert "offered_contracts.append" in section
    assert "bounty_board_changed.emit()" in section
    assert "return campaign_offers.duplicate(true)" in section

def test_accessibility_and_audio_are_applied():
    settings = text("scripts/core/game_settings.gd")
    accessibility = text("scripts/ui/accessibility_director.gd")
    audio = text("scripts/core/audio_director.gd")
    for setting in ("voice_volume", "ambience_volume", "ui_volume", "dynamic_range", "mono_output", "animation_speed", "text_scale", "high_contrast", "reduce_flashes", "color_assist"):
        assert setting in settings
    assert "get_tree().root.content_scale_factor" in accessibility
    assert "adjusted_flash_duration" in accessibility
    assert "adjusted_shake_strength" in accessibility
    assert "audio_channels" in accessibility
    assert "GameSettings.voice_volume" in audio
    assert "dynamic_range_multiplier" in audio

def test_tactical_preview_and_partial_timeline_are_live():
    preview = text("scripts/core/combat_preview_director.gd")
    timeline = text("scripts/core/action_timeline_director.gd")
    main = text("scripts/ui/main.gd")
    for field in ("damage_min", "damage_max", "accuracy", "critical", "resistance", "status_chance", "rank_move", "push", "pull", "cost", "cooldown"):
        assert f'"{field}"' in preview
    assert "EnemyCombatDirector.intent_preview" in timeline
    assert "CombatPreviewDirector.describe" in main
    assert "ActionTimelineDirector.preview_lines" in main
    assert "get_tree().paused" not in preview + timeline

def test_effect_tooltips_explain_full_lifecycle():
    formatter = text("scripts/core/effect_tooltip_formatter.gd")
    menu = text("scripts/ui/game_menu_ui.gd")
    for field in ("source", "power", "duration", "stacks", "max_stacks", "dissipation", "stat"):
        assert f'"{field}"' in formatter
    assert "EffectTooltipFormatter.describe" in menu

def test_expedition_reports_cover_requested_outcomes():
    report = text("scripts/core/expedition_report_director.gd")
    main = text("scripts/ui/main.gd")
    menu = text("scripts/ui/game_menu_ui.gd")
    for category in ("consumables", "loot", "injuries_before", "injuries_after", "trait_progress", "relations", "deeds", "enemy_fear_created", "quest_updates", "bounty_updates", "sanctuary_consequences"):
        assert category in report
    assert "record_consumable" in main and "finish_expedition" in main
    assert "func _render_reports" in menu

def test_preparation_presets_and_nonblocking_warnings():
    prep = text("scripts/core/expedition_preparation_director.gd")
    menu = text("scripts/ui/game_menu_ui.gd")
    for warning in ("supplies", "quest", "empty_weapon", "injury", "incompatible_weapon", "empty_item", "no_healer"):
        assert f'"{warning}"' in prep
    assert '"blocking":false' in prep
    assert "save_preset" in prep and "apply_preset" in prep
    assert "func _render_preparation" in menu

def test_replayable_help_and_glossary_are_complete():
    data = json.loads(text("data/help_codex.json"))
    ids = {entry["id"] for entry in data["topics"]}
    assert {"first_steps", "fear", "madness", "hope", "ranks", "injuries", "mutilations", "traits", "cinders", "inspection", "controls", "save"}.issubset(ids)
    assert "func _render_help" in text("scripts/ui/game_menu_ui.gd")

def test_campaign_memory_and_progressive_codex_are_persistent():
    memory = text("scripts/core/campaign_memory_director.gd")
    menu = text("scripts/ui/game_menu_ui.gd")
    save = text("scripts/core/save_manager.gd")
    for category in ("expeditions", "memorial", "decisions", "notable_enemies", "sanctuary_evolution", "codex_knowledge"):
        assert category in memory
    assert "CampaignMemoryDirector.knowledge" in menu
    assert "CampaignMemoryDirector.serialize" in save
    assert "func _render_chronicle" in menu

def test_expanded_audio_options_are_visible():
    menu = text("scripts/ui/game_menu_ui.gd")
    for label in ("Voix et dialogues", "Ambiance", "Interface", "Sortie mono", "Plage dynamique", "Vitesse des animations"):
        assert label in menu

def test_ui_navigation_is_consolidated_without_new_numbered_layer():
    registry = text("scripts/ui/ui_section_registry.gd")
    menu = text("scripts/ui/game_menu_ui.gd")
    architecture = text("docs/ui_consolidation.md")
    assert "UI_SECTIONS.entries()" in menu
    assert "UI_SECTIONS.title(active_tab)" in menu
    assert registry.count('"id":') == 12
    assert "main_v35.gd" in architecture
    assert not (ROOT / "scripts/ui/main_v35.gd").exists()

def test_all_new_modules_are_registered_and_reset():
    project = text("project.godot")
    state = text("scripts/core/game_state.gd")
    for name in ("CombatPreviewDirector", "ActionTimelineDirector", "EffectTooltipFormatter", "ExpeditionReportDirector", "ExpeditionPreparationDirector", "CampaignMemoryDirector", "AccessibilityDirector"):
        assert f"{name}=" in project
    for name in ("ExpeditionReportDirector", "ExpeditionPreparationDirector", "CampaignMemoryDirector"):
        assert f"{name}.reset_new_game()" in state
