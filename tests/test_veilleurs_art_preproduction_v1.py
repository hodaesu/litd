import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/veilleurs/art/asset_catalog_preproduction_v1.json"
FUTURE = ROOT / "data/veilleurs/art/future_content_packets_v1.json"
MANIFEST = ROOT / "data/veilleurs/art/art_preproduction_manifest_v1.json"
SHOTLIST = ROOT / "data/veilleurs/art/concept_shotlist_v1.json"
REFERENCE_PRESETS = ROOT / "data/veilleurs/art/art_reference_presets_v1.json"
REFERENCE_LIBRARY = ROOT / "data/art_reference_library.json"
PLAYTEST_HEAD = "0c905800ec21e646e9252f1c14430ed8ad36ada3"

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


def test_art_manifest_is_isolated_and_all_indexed_files_exist():
    data = load(MANIFEST)
    assert data["version"] >= 3
    assert data["status"] == "art_preproduction_manifest"
    assert data["runtime_wiring"] == "none"
    assert data["source_playtest_pr"] == 173
    assert data["source_playtest_commit"] == PLAYTEST_HEAD
    assert data["parallel_post_playtest_pr_180_dependency"] is False
    assert data["merge_guard"]["no_gameplay_change"] is True
    assert data["merge_guard"]["no_pr_180_dependency"] is True
    for repo_path in data["files"].values():
        assert (ROOT / repo_path).exists(), repo_path
    assert data["canonical_counts"] == {
        "watchers": 4,
        "ordinary_species": 24,
        "bosses": 5,
        "boss_phases": 16,
        "acts": 5,
        "archive_knowledge_states": 5,
        "concept_shots": 36,
        "reference_presets": 10,
    }


def test_visual_contract_keeps_mobile_and_controller_guardrails():
    visual = load(MANIFEST)["visual_contract"]
    assert visual["ui_reference_status"] == "canonical_board_approved_2026_09_07"
    assert visual["mobile_first"] is True
    assert visual["touch_target_min_points"] >= 48
    assert visual["required_long_press"] is False
    assert visual["controller_pointer_dependency"] is False
    assert visual["desktop_is_stretched_mobile"] is False


def test_shotlist_is_sequential_and_counts_match_actual_shots():
    data = load(SHOTLIST)
    assert data["status"] == "art_preproduction_shotlist"
    assert data["runtime_wiring"] == "none"
    assert data["source_playtest_commit"] == PLAYTEST_HEAD
    shots = data["shots"]
    assert len(shots) == 36
    assert [shot["id"] for shot in shots] == [f"ART-{i:03d}" for i in range(1, 37)]
    priority_counts = Counter(shot["priority"] for shot in shots)
    blocked_count = sum(bool(shot["blocked_until_playtest"]) for shot in shots)
    assert priority_counts == Counter({"P1": 20, "P0": 8, "P2": 8})
    assert data["counts"] == {
        "total": 36,
        "p0": priority_counts["P0"],
        "p1": priority_counts["P1"],
        "p2": priority_counts["P2"],
        "blocked_until_playtest": blocked_count,
    }
    assert blocked_count == 3


def test_playtest_blocked_shots_are_only_vfx_prototypes():
    shots = load(SHOTLIST)["shots"]
    blocked = [shot for shot in shots if shot["blocked_until_playtest"]]
    assert {shot["id"] for shot in blocked} == {"ART-006", "ART-007", "ART-008"}
    assert {shot["category"] for shot in blocked} == {"vfx"}
    assert all(shot["priority"] == "P0" for shot in blocked)


def test_reference_presets_use_existing_sources_and_minimum_three():
    presets_data = load(REFERENCE_PRESETS)
    library = load(REFERENCE_LIBRARY)
    source_ids = {ref["id"] for ref in library["references"]}
    presets = presets_data["presets"]
    assert presets_data["runtime_wiring"] == "none"
    assert len(presets) == 10
    assert presets_data["policy"]["minimum_sources_per_preset"] == 3
    assert presets_data["policy"]["extract_abstract_principles_only"] is True
    assert presets_data["policy"]["copying_forbidden"] is True
    for preset in presets:
        assert len(preset["reference_ids"]) >= 3
        assert set(preset["reference_ids"]) <= source_ids, preset["id"]
        assert preset["extract"]
        assert preset["transform"]
        assert preset["forbid"]


def test_reference_policy_matches_central_library_policy():
    manifest_policy = load(MANIFEST)["reference_policy"]
    library_policy = load(REFERENCE_LIBRARY)["usage_policy"]
    assert manifest_policy["source_library"] == "data/art_reference_library.json"
    assert manifest_policy["minimum_sources_per_creation"] == library_policy["minimum_sources_per_creation"] == 3
    assert manifest_policy["abstract_principles_only"] is True
    assert manifest_policy["rights_recheck_before_export"] is True
    assert manifest_policy["copy_trace_signature_imitation_forbidden"] is True
