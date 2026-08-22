from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MENU = ROOT / "scripts" / "ui" / "context_menu_ui_v2.gd"
PROJECT = ROOT / "project.godot"


def test_context_menu_v2_is_active():
    text = PROJECT.read_text(encoding="utf-8")
    assert 'ContextMenuUI="*res://scripts/ui/context_menu_ui_v2.gd"' in text


def test_context_menu_uses_progressive_disclosure():
    text = MENU.read_text(encoding="utf-8")
    assert "_two_panes" in text
    assert "selected_item_id" in text
    assert "selected_skill_id" in text
    assert "selected_quest_key" in text
    assert "show_item_details" in text
    assert '"DÉTAILS"' in text


def test_inventory_and_journal_have_simple_filters():
    text = MENU.read_text(encoding="utf-8")
    for token in ['"TOUT"', '"ÉQUIPEMENT"', '"CONSOMMABLES"', '"QUÊTE"']:
        assert token in text
    for token in ['"TOUTES"', '"CAMPAGNE"', '"DONJON"', '"TERMINÉES"']:
        assert token in text


def test_skills_show_one_branch_at_a_time():
    text = MENU.read_text(encoding="utf-8")
    assert "selected_skill_branch" in text
    assert "HeroSkillManager.skill_nodes(hero, selected_skill_branch)" in text
    assert "for branch_value in HeroSkillManager.BRANCHES" in text


def test_options_are_split_into_categories():
    text = MENU.read_text(encoding="utf-8")
    for category in ['"audio"', '"display"', '"controls"', '"accessibility"']:
        assert category in text
    assert "menu_text_scale" in text
    assert "high_contrast" in text
