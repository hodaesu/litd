import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/veilleurs/art/asset_catalog_preproduction_v1.json"
FUTURE = ROOT / "data/veilleurs/art/future_content_packets_v1.json"

EXPECTED_ORDINARY = {
    "delie_affame", "delie_boursoufle", "censeur_fendu", "flagellant_fendu",
    "sentinelle_du_seuil", "executeur_de_pierre", "traque_suie", "brise_os_de_suie",
    "ecouteur_creux", "porte_signe", "marcheur_aphone", "reteneur_de_souffle",
    "veine_rampante", "noeud_ecorche", "porte_sang", "germe_arteriel",
    "marche_pale", "porte_linceul", "effaceur_de_traces", "dormeur_de_cendre",
    "copie_lacunaire", "rature_vivante", "archiviste_de_version", "double_du_seuil",
}
EXPECTED_BOSSES = {
    "ishar_gardien_du_passage",
    "orateur_sans_voix",
    "mere_des_veines",
    "porte_cendres_blanc",
    "le_copiste",
}
EXPECTED_WATCHERS = {"nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_art_catalog_is_preproduction_only():
    data = load(CATALOG)
    assert data["status"] == "art_preproduction_only"
    assert data["runtime_wiring"] == "none"
    assert data["rules"]["mobile_first"] is True
    assert data["rules"]["bosses_recruitable"] is False
    assert data["rules"]["recruited_creatures_are_full_playable_units"] is True
    assert data["rules"]["persistent_injuries_visual_required"] is True


def test_quartet_and_species_are_exact():
    data = load(CATALOG)
    packages = {p["id"]: p for p in data["packages"]}
    assert set(packages["watchers.core_quartet"]["entities"]) == EXPECTED_WATCHERS
    ordinary = set()
    for act in ["i", "ii", "iii", "iv", "v"]:
        ordinary.update(packages[f"ordinary_species.act_{act}"]["entities"])
    assert ordinary == EXPECTED_ORDINARY
    assert len(ordinary) == 24


def test_bosses_and_phase_counts_are_exact():
    data = load(CATALOG)
    bosses = next(p for p in data["packages"] if p["id"] == "bosses.all")
    assert set(bosses["entities"]) == EXPECTED_BOSSES
    assert sum(bosses["phase_counts"].values()) == 16
    assert bosses["phase_counts"]["le_copiste"] == 4
    assert all(v == 3 for k, v in bosses["phase_counts"].items() if k != "le_copiste")


def test_future_packets_cover_five_acts_without_runtime_wiring():
    data = load(FUTURE)
    assert data["runtime_wiring"] == "none"
    assert [a["act"] for a in data["acts"]] == ["I", "II", "III", "IV", "V"]
    ordinary = {e for act in data["acts"] for e in act["ordinary_species"]}
    bosses = {act["boss"] for act in data["acts"]}
    assert ordinary == EXPECTED_ORDINARY
    assert bosses == EXPECTED_BOSSES
    assert sum(len(act["boss_phases"]) for act in data["acts"]) == 16


def test_future_art_does_not_lock_playtest_sensitive_values():
    data = load(FUTURE)
    deferred = " ".join(data["defer_until_playtest"]).lower()
    assert "telegraph" in deferred
    assert "vfx" in deferred
    assert "camera" in deferred
    assert "blood" in deferred
