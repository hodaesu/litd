import json
from pathlib import Path

from tools.qa.psychology_combat_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_psychology_combat_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_fear_is_the_only_visible_psychological_meter_and_hope_is_event_driven():
    ui = (ROOT / "scripts/ui/main_v16.gd").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/core/psychology_runtime.gd").read_text(encoding="utf-8")
    assert ui.count("ProgressBar.new()") == 1
    assert "PEUR · %s · %d/100" in ui
    assert "resolve_charges" in runtime
    assert "feedback_requested.emit" in runtime
    assert 'hero["hope"] +=' not in ui
    assert 'hero["madness"] +=' not in ui


def test_panic_and_fear_penalties_are_deterministic_and_data_driven():
    data = json.loads((ROOT / "data/psychology_events.json").read_text(encoding="utf-8"))
    runtime = (ROOT / "scripts/core/psychology_runtime.gd").read_text(encoding="utf-8")
    panic = data["combat_rules"]["panic"]
    assert panic["fear_after_crisis"] == 85
    assert panic["fear_after_resolve"] == 70
    assert panic["resolve_charges_max"] == 1
    assert "func combat_modifiers" in runtime
    assert "func resolve_panic_action" in runtime
    assert "_panic_reaction_for" in runtime


def test_psychology_terms_keep_veil_folie_separate_from_real_mental_illness():
    data = json.loads((ROOT / "data/psychology_events.json").read_text(encoding="utf-8"))
    terminology = data["terminology"]
    assert "surnaturel" in terminology["veil_folie"].lower()
    assert "diagnostic" in terminology["veil_folie"].lower()
    forbidden = set(terminology["forbidden_equivalences"])
    assert {
        "mental_illness_equals_violence",
        "mental_illness_equals_evil",
        "mental_illness_equals_supernatural_perception",
        "trauma_always_breaks_or_strengthens",
        "fear_equals_cowardice",
    } <= forbidden
    assert all(rule.get("non_diagnostic") is True for rule in data["trait_definitions"].values())
