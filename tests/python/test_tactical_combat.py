from pathlib import Path

from tools.qa.tactical_combat_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_tactical_combat_has_no_hard_errors():
    audit = run(ROOT)
    errors = [item for item in audit["checks"] if not item["ok"]]
    assert not errors, [f"{item['name']}: {item['detail']}" for item in errors]


def test_tactical_combat_has_four_unique_initial_ranks_and_profiles():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Tactique : quatre rangs initiaux uniques" in names
    assert "Tactique : profil pour chaque héros" in names


def test_tactical_combat_locks_movement_targeting_techniques_and_synergies():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Déplacement consomme l'action" in names
    assert "Ciblage dépend du rang ennemi" in names
    assert "Techniques positionnelles actives" in names
    assert "Mur de la Veille branché" in names
    assert "Concorde du Voile branchée" in names
    assert "Faille préparée branchée" in names
