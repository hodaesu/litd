from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
MAIN = (ROOT / "scripts" / "ui" / "main.gd").read_text(encoding="utf-8")
INSPECTION = (ROOT / "scripts" / "ui" / "combatant_inspection_ui.gd").read_text(encoding="utf-8")

def test_combatant_inspection_is_registered():
    assert 'CombatantInspectionUI="*res://scripts/ui/combatant_inspection_ui.gd"' in PROJECT
    assert "extends CanvasLayer" in INSPECTION
    assert "HUDDirector.LEVEL_INSPECTION" in INSPECTION

def test_mouse_hover_shows_preview_for_heroes_and_enemies():
    assert "control.mouse_entered.connect" in INSPECTION
    assert "control.mouse_exited.connect" in INSPECTION
    assert "func show_preview" in INSPECTION
    assert "func hide_preview" in INSPECTION
    assert "CombatantInspectionUI.bind_combatant(hero_button, h, false)" in MAIN
    assert "CombatantInspectionUI.bind_combatant(b, e, true)" in MAIN

def test_touch_click_and_gamepad_open_detailed_inspection():
    assert "control.focus_entered.connect" in INSPECTION
    assert "(control as BaseButton).pressed.connect" in INSPECTION
    assert "func open_detail" in INSPECTION
    assert 'event.is_action_pressed("back")' in INSPECTION
    assert 'event.is_action_pressed("confirm")' in INSPECTION
    assert "hero_button := Button.new()" in MAIN
    assert 'tooltip_text = "Survol : aperçu · Clic/toucher/validation : inspection"' in MAIN

def test_preview_and_detail_show_stats_afflictions_and_skills():
    for function in ["_stat_line", "_affliction_lines", "_skill_lines"]:
        assert f"func {function}" in INSPECTION
    for label in ["STATISTIQUES", "AFFLICTIONS, BUFFS ET DEBUFFS", "COMPÉTENCES"]:
        assert label in INSPECTION
    assert "CharacterTraitDirector.trait_names" in INSPECTION
    assert "PersistentInjuryRuntime.definition" in INSPECTION
    assert "HeroSkillManager.known_combat_skills" in INSPECTION
    assert 'combatant.get("skills", combatant.get("abilities", []))' in INSPECTION

def test_detailed_inspection_pauses_and_restores_combat():
    assert "get_tree().paused = true" in INSPECTION
    assert "get_tree().paused = _paused_before_detail" in INSPECTION
    assert "HUDDirector.set_screen_context(GameState.current_screen)" in INSPECTION
