import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load_war():
    return json.loads((ROOT / "data/canon/last_war.json").read_text(encoding="utf-8"))


def test_last_war_has_locked_structure_without_fake_exact_date():
    war = load_war()
    assert war["id"] == "last_war"
    assert war["status"] == "canon"
    assert war["dating"]["exact_years_locked"] is False
    assert len(war["belligerents"]) == 6
    assert {item["id"] for item in war["belligerents"]} == {
        "azravel", "erhal", "kharad", "sarn", "namar", "odran"
    }


def test_last_war_trigger_preserves_distributed_responsibility_and_remanence():
    war = load_war()
    trigger = war["trigger"]
    assert trigger["id"] == "three_banners_affair"
    assert len(trigger["in_world_versions"]) == 3
    assert set(trigger["knowledge_design"]) == {"trace", "echo", "memoire", "concordance"}
    assert "Aucune puissance centrale" in trigger["author_truth"]


def test_last_war_phases_lead_to_sarn_without_defining_the_night_yet():
    war = load_war()
    phases = war["phases"]
    assert [phase["order"] for phase in phases] == list(range(1, 7))
    assert phases[-1]["id"] == "sarn_convergence"
    assert "Nuit de Sarn" in phases[-1]["locked_boundary"]
    assert "déroulement précis de la Nuit de Sarn" in war["pending_after_this_file"]
    assert "naissance explicite des Trois Éveils" in war["pending_after_this_file"]


def test_last_war_is_gameplay_ready_not_only_lore_text():
    war = load_war()
    gameplay = war["gameplay_translation"]
    assert len(gameplay["mission_families"]) >= 10
    assert "choisir_entre_objectifs" in gameplay["mission_families"]
    assert "propagande" in gameplay["remanence_sources"]
    assert len(gameplay["run_structure"]) >= 5


def test_data_loader_exposes_last_war_runtime_api():
    loader = (ROOT / "scripts/core/data_loader.gd").read_text(encoding="utf-8")
    for token in (
        'res://data/canon/last_war.json',
        'func last_war_phase(',
        'func last_war_phases(',
        'func last_war_trigger(',
        'func last_war_gameplay_translation(',
    ):
        assert token in loader
