from pathlib import Path

from tools.qa.combat_economy_sim import run

ROOT = Path(__file__).resolve().parents[2]


def test_combat_economy_simulation_has_no_hard_errors():
    simulation = run(ROOT)
    assert not simulation.errors, [f"{item['name']}: {item['detail']}" for item in simulation.errors]


def test_combat_economy_simulation_covers_required_checkpoints():
    simulation = run(ROOT)
    assert set(simulation.report["hero_damage_curve"].keys()) == {"1", "10", "20", "30", "40", "50"}
    assert len(simulation.report["scripted_bosses"]) >= 30
    assert len(simulation.report["ngplus_cycles"]) == 6
    assert simulation.report["xp_pacing"]["xp_per_victory"] > 0


def test_combat_economy_simulation_surfaces_known_prototype_risks():
    simulation = run(ROOT)
    warning_names = {item["name"] for item in simulation.warnings}
    assert "Prototype de tour : seul le premier héros vivant agit" in warning_names
    assert "Risque de double récompense sur les combats routés par AshlandsCombatBridge" in warning_names
    assert "Progression XP extrêmement longue jusqu'aux ultimes de niveau 48" in warning_names
