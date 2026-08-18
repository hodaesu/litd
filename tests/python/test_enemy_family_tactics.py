from pathlib import Path

from tools.qa.enemy_family_tactics_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_enemy_family_tactics_have_no_hard_errors():
    audit = run(ROOT)
    errors = [item for item in audit["checks"] if not item["ok"]]
    assert not errors, [f"{item['name']}: {item['detail']}" for item in errors]


def test_all_generic_enemies_are_assigned_exactly_once():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Tous les ennemis génériques non-boss sont classés" in names
    assert "Aucun ennemi générique n'est classé deux fois" in names


def test_family_behaviors_and_limb_reactions_are_distinct():
    audit = run(ROOT)
    names = {item["name"] for item in audit["checks"]}
    assert "Chaque famille a une signature tactique propre" in names
    assert "Arachnides peuvent tirer l'arrière-garde" in names
    assert "Aberrations peuvent permuter le centre" in names
    assert "Réaction bestiale peut faire reculer" in names
    assert "Réaction aberrante peut ramener en première ligne" in names
