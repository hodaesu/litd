from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_campaign_e2e_smoke_script_covers_critical_player_journey():
    script = (ROOT / "scripts/core/campaign_e2e_smoke_test.gd").read_text(encoding="utf-8")
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


def test_ci_runs_campaign_e2e_smoke_in_godot():
    ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    nightly = (ROOT / ".github/workflows/nightly.yml").read_text(encoding="utf-8")
    command = "godot --headless --path . --script res://scripts/core/campaign_e2e_smoke_test.gd"
    assert command in ci
    assert command in nightly
