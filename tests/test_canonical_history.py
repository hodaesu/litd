import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load_history():
    return json.loads((ROOT / "data/canonical_history.json").read_text(encoding="utf-8"))


def test_seven_ancient_civilizations_are_present_and_unique():
    data = load_history()
    civilizations = data["ancient_civilizations"]
    ids = [entry["id"] for entry in civilizations]
    assert len(civilizations) == 7
    assert len(ids) == len(set(ids))
    assert ids == [
        "ashai_de_nhal",
        "or_silex",
        "saan",
        "vaor_khal",
        "lyr_mar",
        "sahm_ir",
        "ydris",
    ]


def test_canon_prevents_three_awakenings_and_sanctuary_anachronisms():
    data = load_history()
    rules = "\n".join(data["canon_rules"])
    assert "Trois Éveils" in rules
    assert "Nuit de Sarn" in rules
    assert "Sanctuaires institutionnels" in rules
    assert "Vestige reste inconnu" in rules


def test_knowledge_remanence_has_locked_four_stage_progression():
    data = load_history()
    assert data["knowledge_remanence"]["stages"] == ["trace", "echo", "memoire", "concordance"]


def test_great_closure_keeps_locked_dates_classes_and_survival_channels():
    data = load_history()
    closure = data["great_closure"]
    assert closure["period"] == {"start": -2297, "center": -2290, "end": -2284, "approximate": True}
    assert [entry["id"] for entry in closure["site_classes"]] == ["I", "II", "III", "IV", "V"]
    assert set(closure["survival_channels"]) == {
        "sites_introuvables",
        "sites_sous_veille",
        "faux_fermes",
        "artefacts_voles",
        "archives_sauvees",
        "vivant_altere",
    }


def test_pre_last_war_geopolitics_contains_six_powers_and_two_alliances():
    data = load_history()
    assert {entry["id"] for entry in data["pre_last_war_powers"]} == {
        "azravel", "erhal", "kharad", "sarn", "namar", "odran"
    }
    assert {entry["id"] for entry in data["pre_last_war_alliances"]} == {
        "pacte_des_routes", "ligue_des_frontieres"
    }
    assert len(data["last_war_causes"]) >= 8


def test_unlocked_future_lore_remains_explicitly_pending():
    data = load_history()
    pending = "\n".join(data["pending_not_implemented_as_canon"])
    for subject in ("Dernière Guerre", "Sahra", "Nuit de Sarn", "Projet Seuil", "Chute"):
        assert subject in pending


def test_godot_data_loader_exposes_canonical_history_queries():
    loader = (ROOT / "scripts/core/data_loader.gd").read_text(encoding="utf-8")
    assert 'load_json("res://data/canonical_history.json")' in loader
    for function_name in (
        "ancient_civilization",
        "history_event",
        "history_events_for_era",
        "pre_last_war_power",
        "knowledge_remanence_stages",
        "canon_rules",
        "pending_canon_topics",
    ):
        assert f"func {function_name}" in loader
