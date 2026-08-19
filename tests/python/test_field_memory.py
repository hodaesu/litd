from pathlib import Path

from tools.qa.field_memory_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_field_memory_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_field_memory_covers_real_campaign_choices_without_new_hud_meter():
    runtime = (ROOT / "scripts/core/field_memory_runtime.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/main_v20.gd").read_text(encoding="utf-8")
    for token in ["creature_captured", "record_boss_outcome", "record_expedition_retreat", "record_resource_choice"]:
        assert token in runtime
    assert "ÉPARGNER" in ui and "ACHEVER" in ui
    assert "ProgressBar.new()" not in ui


def test_field_memories_keep_context_and_can_change_later():
    runtime = (ROOT / "scripts/core/field_memory_runtime.gd").read_text(encoding="utf-8")
    data = (ROOT / "data/field_memory.json").read_text(encoding="utf-8")
    for token in ["zone_id", "witness_mode", "chapter_id", "reevaluations"]:
        assert token in runtime
    for token in ["creature_proved_itself", "spared_enemy_helped", "spared_enemy_betrayed"]:
        assert token in data
