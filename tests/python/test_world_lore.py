import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(path):
    return json.loads((ROOT / path).read_text())


def test_external_conspiracy_has_distinct_powers_and_non_collective_blame():
    data = _load("data/world/external_powers_conspiracy.json")
    assert data["conspiracy_name"] == "Pacte de l'Horizon Fermé"
    assert data["operation"] == "Projet Seuil"
    assert len(data["powers"]) == 4
    assert len({power["goal"] for power in data["powers"]}) >= 3
    assert "pas collectivement responsables" in data["canonical_rule"]


def test_conspirators_have_morally_distinct_roles_and_late_actions():
    data = _load("data/world/external_powers_conspiracy.json")
    actors = {actor["id"]: actor for actor in data["actors"]}
    assert "veyra_oss" in actors
    assert "edras_nhal" in actors
    assert "bram_torgun" in actors
    assert "eline_sar" in actors
    assert "arrêter" in actors["bram_torgun"]["intent"]
    assert actors["othmar_sevr"]["intent"] != actors["veyra_oss"]["intent"]


def test_veil_is_not_reduced_to_simple_dimension_or_deity():
    data = _load("data/world/veil_creature_cosmology.json")
    veil = data["veil"]
    assert veil["predates_civilizations"] is True
    assert veil["is_confirmed_afterlife"] is False
    assert veil["is_confirmed_deity"] is False
    assert veil["will_status"] == "unresolved"
    assert set(veil["emotion_rules"]) == {"fear", "madness", "hope", "light"}


def test_creature_taxonomy_has_seven_origins_or_statuses_without_species_guilt():
    data = _load("data/world/veil_creature_cosmology.json")
    origins = data["creature_origins"]
    assert len(origins) == 7
    ids = {item["id"] for item in origins}
    assert "destructive_manifestation" in ids
    assert "coexistence_capable" in ids
    destructive = next(item for item in origins if item["id"] == "destructive_manifestation")
    assert destructive["species"] is False
    assert "Aucune origine" in data["rule"]


def test_beliefs_history_and_species_are_plural():
    data = _load("data/world/cultures_faiths_history.json")
    assert len(data["beliefs"]) >= 6
    assert len(data["historical_eras"]) >= 7
    assert all(species["monolithic"] is False for species in data["species"])
    assert len(data["species"]) >= 6
    assert "culture" in data["species_cultural_rule"].lower()


def test_fall_timeline_progresses_from_hours_to_first_month():
    data = _load("data/world/fall_timeline_and_mystery.json")
    ids = [entry["id"] for entry in data["timeline"]]
    assert ids[0] == "pre_6h"
    assert "h0" in ids
    assert "h12" in ids
    assert "d7" in ids
    assert ids[-1] == "month1"
    assert len(data["sanctuary_survival_factors"]) >= 5


def test_main_mystery_has_three_questions_and_keeps_irreducible_unknowns():
    data = _load("data/world/fall_timeline_and_mystery.json")
    questions = {item["id"] for item in data["mystery_questions"]}
    assert questions == {"who_caused_fall", "why_control_failed", "why_concord_survived"}
    assert len(data["irreducible_mysteries"]) >= 5


def test_second_lore_bible_contains_all_nine_requested_axes():
    doc = (ROOT / "docs/LORE_MONDE_VOILE_ET_CHUTE.md").read_text()
    for heading in (
        "Les continents et puissances étrangères",
        "Les responsables de l'ouverture du Voile",
        "Le Voile",
        "Origine des créatures",
        "Religions et philosophies",
        "Histoire ancienne du continent",
        "Espèces et cultures",
        "Chronologie de la Chute",
        "Le grand mystère narratif",
    ):
        assert heading in doc
