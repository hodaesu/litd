from pathlib import Path

from tools.qa.field_encounter_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_reactive_field_encounter_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_survivor_choice_uses_real_expedition_resources_and_has_no_moral_meter():
    runtime = (ROOT / "scripts/core/field_encounter_runtime.gd").read_text(encoding="utf-8")
    trigger = (ROOT / "scripts/world/field_encounter_trigger.gd").read_text(encoding="utf-8")
    for token in ["ExpeditionManager.can_pay", "ExpeditionManager.consume_bundle", "record_resource_choice"]:
        assert token in runtime
    assert "ProgressBar" not in runtime
    assert "ProgressBar" not in trigger


def test_previous_choices_create_different_later_world_states():
    data = (ROOT / "data/field_encounters.json").read_text(encoding="utf-8")
    for token in [
        "c01_village_survivors",
        "c03_survivor_outpost",
        "c03_survivors_without_aid",
        "c03_spared_witness_return",
        "source_outcomes",
        "requires_boss_outcome",
    ]:
        assert token in data


def test_reactive_encounters_are_saved_and_injected_into_3d_exploration():
    save = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    injector = (ROOT / "scripts/world/field_encounter_injector.gd").read_text(encoding="utf-8")
    trigger = (ROOT / "scripts/world/field_encounter_trigger.gd").read_text(encoding="utf-8")
    assert '"field_encounters": FieldEncounterRuntime.serialize()' in save
    assert "FieldEncounterRuntime.deserialize" in save
    assert "GeneratedBlockout" in injector
    assert "FieldEncounterTrigger.new()" in injector
    assert "extends Area3D" in trigger and "func interact" in trigger
