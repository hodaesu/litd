from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_context_hud_is_autoloaded():
    project = (ROOT / "project.godot").read_text()
    assert 'ContextHUD="*res://scripts/ui/context_hud.gd"' in project


def test_hud_is_hidden_by_default_and_only_explicitly_enabled_when_useful():
    hud = (ROOT / "scripts/ui/context_hud.gd").read_text()
    assert 'const HUD_VISIBLE_SCREENS := {' in hud
    assert '"combat": true' in hud
    assert '"market": true' in hud
    assert '"campfire": true' in hud
    for hidden_context in (
        '"sanctuary": true',
        '"expedition": true',
        '"company": true',
        '"politics": true',
        '"journal": true',
        '"title": true',
    ):
        assert hidden_context not in hud
    assert 'HUD_VISIBLE_SCREENS.get(screen_name, false)' in hud


def test_hidden_hud_restores_full_screen_content():
    hud = (ROOT / "scripts/ui/context_hud.gd").read_text()
    assert '_header.visible = visible' in hud
    assert '_main_content.offset_top = HEADER_HEIGHT if visible else 0.0' in hud


def test_hud_can_be_temporarily_requested_by_contextual_interactions():
    hud = (ROOT / "scripts/ui/context_hud.gd").read_text()
    assert 'func show_temporarily()' in hud
    assert 'func restore_context()' in hud
