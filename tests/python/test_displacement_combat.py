from pathlib import Path

from tools.qa.displacement_combat_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_displacement_combat_has_no_hard_errors():
    audit = run(ROOT)
    errors = [item for item in audit["checks"] if not item["ok"]]
    assert not errors, [f"{item['name']}: {item['detail']}" for item in errors]


def test_displacement_combat_covers_push_pull_fear_and_limb_loss():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Poussée ennemie branchée" in names
    assert "Traction ennemie branchée" in names
    assert "Peur maximale provoque un recul" in names
    assert "Démembrement déclenche le déplacement de membre" in names


def test_displacement_combat_has_four_limb_linked_boss_maneuvers():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Quatre boss à phase positionnelle" in names
    assert "Quatre familles de désorganisation couvertes" in names
    assert "Perte du membre journalise PHASE ALTÉRÉE" in names
