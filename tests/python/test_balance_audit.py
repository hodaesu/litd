from pathlib import Path

from tools.qa.balance_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_balance_audit_has_no_hard_errors():
    audit = run(ROOT)
    assert not audit.errors, [f"{item['name']}: {item['detail']}" for item in audit.errors]


def test_balance_audit_covers_core_progression_systems():
    audit = run(ROOT)
    names = {item["name"] for item in audit.checks}
    assert "Héros : un arbre complet est finissable au niveau 50" in names
    assert "Compagnons : l'ascension s'ancre avant son premier palier" in names
    assert "Fins : six orientations canoniques" in names
    assert "Postgame : NG+ impossible à soft-lock économiquement" in names
    assert "NG+ boss : chaque recrutement possède un contrat de boss" in names
