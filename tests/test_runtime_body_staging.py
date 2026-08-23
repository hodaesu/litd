from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
PRESENTATION = (ROOT / "scripts" / "ui" / "combat_body_presentation.gd").read_text(encoding="utf-8")
MAIN = (ROOT / "scripts" / "ui" / "main.gd").read_text(encoding="utf-8")

def test_body_presentation_is_live_not_only_a_contract():
    assert 'CombatBodyPresentation="*res://scripts/ui/combat_body_presentation.gd"' in PROJECT
    assert "BodyStateDirector.evaluate(character)" in PRESENTATION
    assert "EnemyBodyDirector.compose_for_enemy" in PRESENTATION
    assert "EnemyFearDirector.body_psychological_state" in PRESENTATION

def test_visible_heroes_and_enemies_are_bound_to_body_profiles():
    assert "CombatBodyPresentation.bind_visual(art, h, false, i)" in MAIN
    assert "CombatBodyPresentation.bind_visual(art, e, true, i)" in MAIN
    assert "CombatBodyPresentation.state_label(h, false)" in MAIN
    assert "CombatBodyPresentation.state_label(e, true)" in MAIN

def test_postures_reflect_psychology_injury_and_personality_diversity():
    for state in ["tense", "terrified", "panic", "anger", "despair", "hope"]:
        assert f'"{state}"' in PRESENTATION
    for state in ["injured", "critical", "mobility_impaired", "dead"]:
        assert f'"{state}"' in PRESENTATION
    assert "signature_seed" in PRESENTATION
    assert "width_variant" in PRESENTATION
    assert "lean_variant" in PRESENTATION
    assert "guard_compaction" in PRESENTATION
    assert "stance_height" in PRESENTATION

def test_proxy_staging_has_entrance_breath_actions_hits_and_death():
    for function in ["_play_entrance", "_play_breath_loop", "stage_action", "stage_hit", "stage_death"]:
        assert f"func {function}" in PRESENTATION
    assert "CombatBodyPresentation.stage_action(hero, false, action)" in MAIN
    assert 'CombatBodyPresentation.stage_action(enemy, true, "strike")' in MAIN
    assert "CombatBodyPresentation.stage_hit(target, true" in MAIN
    assert "CombatBodyPresentation.stage_hit(target, false" in MAIN
    assert "CombatBodyPresentation.stage_death(target, true)" in MAIN
    assert "CombatBodyPresentation.stage_death(target, false)" in MAIN

def test_visual_staging_never_changes_gameplay_timing_contract():
    assert "gameplay_timing_scale" not in PRESENTATION
    assert "target.hp = max(0, target.hp - damage)" in MAIN
    assert "await get_tree().create_timer(0.18).timeout" in MAIN
    assert "await get_tree().create_timer(0.16).timeout" in MAIN
