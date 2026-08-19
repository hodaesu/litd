from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_campaign_e2e_smoke_script_covers_critical_player_journey():
    script = (ROOT / "scripts/core/campaign_e2e_smoke_test.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/tests/campaign_e2e_smoke.tscn").read_text(encoding="utf-8")
    assert 'extends Node' in script
    assert 'campaign_e2e_smoke_test.gd' in scene
    for contract in (
        'chapter_01_ashlands',
        'chapter_10_final_choice',
        'stable_coexistence',
        'postgame_routes',
        'postgame_hearing',
        'postgame_memorial',
        'legacy_prepared',
        'HeroSkillManager.multi_tree_enabled()',
        'CreatureManager.multi_tree_enabled()',
        'BossRecruitmentState.enabled()',
        'CAMPAIGN_E2E_SMOKE_OK',
    ):
        assert contract in script


def test_ci_uses_strict_godot_guard_and_autoload_aware_e2e_scene():
    ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    nightly = (ROOT / ".github/workflows/nightly.yml").read_text(encoding="utf-8")
    guard = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    assert "bash tools/build/run_godot_ci.sh" in ci
    assert "bash tools/build/run_godot_ci.sh" in nightly
    assert 'SCRIPT ERROR:' in guard
    assert 'res://scenes/tests/campaign_e2e_smoke.tscn' in guard
    assert 'GODOT_CI_STRICT_OK' in guard
