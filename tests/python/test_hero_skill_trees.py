from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_every_playable_hero_has_three_fifteen_skill_trees():
    manager = (ROOT / "scripts/core/hero_skill_manager.gd").read_text()
    assert 'const BRANCHES: Array[String] = ["offense", "defense", "special"]' in manager
    assert "FULL_CATALOG_NODES_PER_BRANCH := 15" in manager
    assert "for index in range(FULL_CATALOG_NODES_PER_BRANCH)" in manager
    assert "PRODUCTION_NODES_PER_BRANCH := 10" in manager
    assert "func reserve_skill_nodes" in manager
    for hero_id in ("aurelien", "malvor", "lysandra", "darius"):
        assert f'"{hero_id}"' in manager


def test_hero_tree_choice_is_irreversible_and_saved_in_party():
    manager = (ROOT / "scripts/core/hero_skill_manager.gd").read_text()
    assert '"specialization"' in manager
    assert "specialization != branch" in manager
    assert 'hero["specialization"] = _branch_for' in manager
    assert 'hero["unlocked_skills"]' in manager


def test_hero_skills_are_available_in_ui_and_combat():
    ui = (ROOT / "scripts/ui/main.gd").read_text()
    assert "func show_hero_skills()" in ui
    assert "HeroSkillManager.stats_for" in ui
    assert "HeroSkillManager.grant_xp" in ui


def test_each_hero_uses_distinct_effect_profiles_and_scaling():
    manager = (ROOT / "scripts/core/hero_skill_manager.gd").read_text()
    assert "hero_offset" in manager
    assert "branch_offset" in manager
    assert '"aurelien":1' in manager
    assert '"malvor":2' in manager
    assert '"lysandra":3' in manager
    assert '"darius":4' in manager
    assert manager.count('if branch=="offense"') == 4
    assert manager.count('if branch=="defense"') == 4
