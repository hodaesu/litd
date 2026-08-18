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
    assert simulation.report["xp_pacing"]["shared_ui_xp"] > 0
    assert simulation.report["xp_pacing"]["campaign_scaled_xp"] is True


def test_combat_economy_simulation_confirms_reward_corrections_and_surfaces_remaining_risks():
    simulation = run(ROOT)
    warning_names = {item["name"] for item in simulation.warnings}
    assert simulation.report["economy"]["campaign_bridge_removes_shared_reward"] is True
    assert "Risque de double récompense sur les combats routés par AshlandsCombatBridge" not in warning_names
    assert "Progression XP extrêmement longue jusqu'aux ultimes de niveau 48" not in warning_names
    assert "Prototype de tour : seul le premier héros vivant agit" in warning_names
    assert "Talents offensifs/défensifs potentiellement inertes dans le combat principal" in warning_names
