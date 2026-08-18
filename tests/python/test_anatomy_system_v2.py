from pathlib import Path

from tools.qa.anatomy_system_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_advanced_anatomy_system_has_no_hard_errors():
    audit = run(ROOT)
    errors = [item for item in audit["checks"] if not item["ok"]]
    assert not errors, [f"{item['name']}: {item['detail']}" for item in errors]


def test_all_ten_requested_anatomy_steps_are_guarded():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    for step in range(1, 11):
        assert any(name.startswith(f"Étape {step} :") for name in names), step


def test_unique_boss_anatomies_include_campaign_and_deep_vestiges():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Étape 4 : onze anatomies de boss uniques" in names
