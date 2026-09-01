import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_three_major_pre_concord_civilizations_exist():
    data = json.loads((ROOT / "data/world/ancient_veil_civilizations.json").read_text())
    ids = {item["id"] for item in data["civilizations"]}
    assert ids == {"ashai_nhal", "or_silex", "watchers_saan"}
    assert all(item["language"] for item in data["civilizations"])
    assert all(item["arts"] for item in data["civilizations"])
    assert all(item["mistake"] for item in data["civilizations"])


def test_ancient_sites_relics_and_absents_are_structured_without_overclaiming_identity():
    data = json.loads((ROOT / "data/world/ancient_veil_civilizations.json").read_text())
    assert len(data["ancient_sites"]) >= 7
    assert len(data["relics"]) >= 6
    status = data["ancient_entities"]["absents"]["status"]
    assert status.startswith("possible_survival")
    assert "not_proven_identity" in status
    assert "stabilisation" in data["first_veil_tree"]["truth"]


def test_deep_history_is_revealed_by_fragmented_dungeon_clues():
    clues = json.loads((ROOT / "data/world/deep_history_clues.json").read_text())
    assert clues["reveal_rules"]["no_single_exposition_dump"] is True
    assert clues["reveal_rules"]["minimum_fragments_for_major_truth"] >= 3
    subjects = {track["id"] for track in clues["clue_tracks"]}
    assert {"ashai_track", "or_silex_track", "saan_track", "tree_track", "project_threshold_connection"}.issubset(subjects)
    assert all(len(track["fragments"]) >= 3 for track in clues["clue_tracks"])


def test_project_threshold_did_not_create_the_veil():
    doc = (ROOT / "docs/CIVILISATIONS_ANTERIEURES_ET_PREMIER_VOILE.md").read_text()
    assert "Le Projet Seuil n'a pas créé le Voile" in doc
    assert "Première Rupture" in doc
    assert "Grande Fermeture" in doc
    assert "Arbre du Premier Voile" in doc
    assert "Absents" in doc


def test_lore_preserves_unknowns_instead_of_overexplaining_veil():
    doc = (ROOT / "docs/CIVILISATIONS_ANTERIEURES_ET_PREMIER_VOILE.md").read_text()
    assert "origine ultime du Voile" in doc
    assert "Mystères à ne pas fermer complètement" in doc
    assert "Aucune ne connaissait tout" in doc
