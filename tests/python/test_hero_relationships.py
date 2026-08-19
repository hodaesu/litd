from pathlib import Path

from tools.qa.hero_relationships_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_hero_relationships_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_relationships_are_persistent_but_not_extra_hud_gauges():
    runtime = (ROOT / "scripts/core/relationship_runtime.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/main_v18.gd").read_text(encoding="utf-8")
    save = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    assert 'hero["relationships"]' in runtime
    assert '"party": GameState.party' in save
    assert "LIENS MARQUANTS" in ui
    assert "ProgressBar.new()" not in ui


def test_relationships_have_combat_and_sanctuary_consequences():
    runtime = (ROOT / "scripts/core/relationship_runtime.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/main_v18.gd").read_text(encoding="utf-8")
    for token in ["try_interpose", "combat_modifiers", "on_hero_fallen", "sanctuary_conversation"]:
        assert token in runtime
    for token in ["record_heal", "record_boss_finisher", "try_interpose", "LIEN CONSERVÉ"]:
        assert token in ui
