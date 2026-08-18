from pathlib import Path

from tools.qa.dismemberment_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_dismemberment_audit_has_no_hard_errors():
    audit = run(ROOT)
    errors = [item for item in audit["checks"] if not item["ok"]]
    assert not errors, [f"{item['name']}: {item['detail']}" for item in errors]


def test_dismemberment_is_tactical_not_instant_boss_kill():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Démembrement : boss jamais tué instantanément par perte de membre" in names
    assert "Runtime réduit réellement les dégâts" in names
    assert "Runtime peut réduire la Peur" in names
    assert "Boss exposent un hook mécanique" in names


def test_dismemberment_keeps_accessibility_presentation_modes():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Démembrement : mécanique indépendante du gore" in names
    assert "Démembrement : modes de présentation prévus" in names
