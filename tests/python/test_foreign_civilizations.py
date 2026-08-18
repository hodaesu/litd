import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_four_foreign_civilizations_are_fully_defined():
    data = json.loads((ROOT / "data/world/foreign_civilizations.json").read_text())
    civilizations = {entry["id"]: entry for entry in data["civilizations"]}
    assert set(civilizations) == {"varkhane", "namar", "azravel", "kor_em"}
    assert sum(len(entry["major_cities"]) for entry in civilizations.values()) == 16
    for entry in civilizations.values():
        assert entry["regime"].strip()
        assert entry["identity"].strip()
        assert entry["population"]
        assert entry["military"]
        assert entry["internal_opposition"].strip()
        assert entry["post_fall"]["status"].strip()
        assert entry["post_fall"]["core_conflict"].strip()
        assert entry["post_fall"]["survival_pattern"].strip()


def test_foreign_powers_have_distinct_post_fall_trajectories():
    data = json.loads((ROOT / "data/world/foreign_civilizations.json").read_text())
    statuses = {entry["post_fall"]["status"] for entry in data["civilizations"]}
    assert len(statuses) == 4
    assert statuses == {"fragmented", "maritime_dislocation", "religious_schism", "uneven_survival"}


def test_foreign_populations_are_not_collectively_blamed():
    civilizations = json.loads((ROOT / "data/world/foreign_civilizations.json").read_text())
    conspiracy = json.loads((ROOT / "data/world/external_powers_conspiracy.json").read_text())
    assert "collectivement coupable" in civilizations["canonical_rule"]
    assert "pas collectivement responsables" in conspiracy["canonical_rule"]


def test_document_covers_cities_cultures_armies_populations_and_aftermath():
    text = (ROOT / "docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md").read_text()
    for heading in (
        "## 1. Empire de Varkhane",
        "## 2. Thalassocratie de Namar",
        "## 3. Royaume sacré d'Azravel",
        "## 4. Ligue de Kor-Em",
        "## 6. Les populations étrangères après la catastrophe",
        "## 7. Rencontres futures possibles",
    ):
        assert heading in text
    for city in (
        "Khar-Vor", "Selkaï", "Orvak", "Mera-Tal",
        "Namaris", "Vey-Lor", "Sahrin", "Ilyara",
        "Azh-Meran", "Vel Or", "Serekh", "Damar Az",
        "Kor-Em", "Deyra", "Tal-Ves", "Brannor",
    ):
        assert city in text
