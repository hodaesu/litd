from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_targeting_rules_define_four_enemy_ranks_and_frontline_screening():
    source = (ROOT / "scripts/core/combat_targeting_rules.gd").read_text(encoding="utf-8")
    assert 'const ENEMY_FRONT: Array[int] = [0, 1]' in source
    assert 'const ENEMY_FRONT_MID: Array[int] = [0, 1, 2]' in source
    assert 'const ENEMY_ALL: Array[int] = [0, 1, 2, 3]' in source
    assert 'if position >= 2:' in source
    assert 'int(blocker.get("combat_position", 0)) <= 1' in source


def test_melee_reach_and_ranged_profiles_are_distinct():
    source = (ROOT / "scripts/core/combat_targeting_rules.gd").read_text(encoding="utf-8")
    assert 'if skill_id == "heavy_blow":' in source
    assert 'return ENEMY_FRONT.duplicate()' in source
    assert 'if status == "bleed" or source_stat == "bleed_chance":' in source
    assert 'return ENEMY_FRONT_MID.duplicate()' in source
    assert 'if RANGED_CLASSES.has(class_id) or source_stat in ["precision", "critical_chance"]:' in source
    assert 'return ENEMY_ALL.duplicate()' in source


def test_forced_movement_supports_push_and_pull():
    source = (ROOT / "scripts/core/combat_targeting_rules.gd").read_text(encoding="utf-8")
    assert 'skill_id == "heavy_blow"' in source
    assert 'return 1 # repousse vers E4' in source
    assert 'str(hero.get("class_id", "")) == "occultist"' in source
    assert 'return -1 # attire vers E1' in source
    assert 'other["combat_position"] = current' in source
    assert 'enemy["combat_position"] = destination' in source


def test_targeting_ui_refuses_invalid_target_without_consuming_turn():
    source = (ROOT / "scripts/ui/main_v32.gd").read_text(encoding="utf-8")
    assert 'COMBAT_TARGETING_RULES.can_target(hero, skill, target, GameState.battle_enemies)' in source
    denial = source.index('if not COMBAT_TARGETING_RULES.can_target')
    delegation = source.index('super._use_combat_skill(slot)')
    assert denial < delegation
    guarded_block = source[denial:delegation]
    assert 'show_screen("combat")' in guarded_block
    assert '_complete_active_hero_turn()' not in guarded_block


def test_main_scene_activates_targeting_layer():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v32.gd' in scene
    assert 'rangs ennemis, portées de cible' in scene
