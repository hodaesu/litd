import json
from pathlib import Path

import pytest


RUN_PATH = Path("unreal/LITD2/Data/Runs/sarei_faubourgs_run.json")
DOC_PATH = Path("docs/LITD2/SAREI_FAUBOURGS_RUN.md")
BRANCH_PATH = Path("docs/LITD2/SAREI_FIRST_BRANCH.md")


@pytest.mark.data
def test_first_sarei_run_has_complete_zone_sequence() -> None:
    data = json.loads(RUN_PATH.read_text(encoding="utf-8"))
    assert data["game"] == "LITD2"
    assert data["run_id"] == "SAREI_FAUBOURGS_01"
    ids = [zone["zone_id"] for zone in data["zones"]]
    assert ids == [
        "Z0_PREP",
        "Z1_SOUTH_GATE",
        "Z2_STRETCHER_STREET",
        "Z3_FIELD_AID_POST",
        "Z4_ASH_CROSSROADS",
        "Z5_HOSPITAL_ANNEX",
        "Z6_EVACUATION_YARD",
        "Z7_SOUTH_BARRICADE",
        "Z8_AFTER_BARRICADE",
    ]


@pytest.mark.data
def test_first_sarei_run_respects_healing_and_trauma_rules() -> None:
    data = json.loads(RUN_PATH.read_text(encoding="utf-8"))
    assert data["start"]["potions"] == 3
    assert data["rules"]["ordinary_healing_cures_trauma"] is False
    assert data["rules"]["potion_cures_all_trauma"] is True
    assert data["rules"]["enemy_potion_drops"] is False
    assert data["rules"]["trauma_must_be_readable"] is True
    for zone in data["zones"]:
        if "healing" in zone:
            assert zone["healing"]["cures_trauma"] is False


@pytest.mark.data
def test_all_three_paths_are_required_to_be_independently_boss_viable() -> None:
    data = json.loads(RUN_PATH.read_text(encoding="utf-8"))
    boss = next(zone for zone in data["zones"] if zone["zone_id"] == "Z7_SOUTH_BARRICADE")
    assert data["rules"]["all_three_paths_boss_viable"] is True
    assert set(boss["path_viability"]) == {"Body", "Mind", "Politics"}
    assert data["start"]["mixed_build_required"] is False


@pytest.mark.data
def test_first_run_teaches_remanence_without_skipping_sarei_cadence() -> None:
    data = json.loads(RUN_PATH.read_text(encoding="utf-8"))
    rem = data["remanence_summary"]
    assert "SAREI_ECHO_LAST_FLASK" in rem["mandatory"]
    assert "SAREI_SOURCE_VEL_REPORT" in rem["deferred_to_later_runs"]
    assert "SAREI_THIRD_ARMY_CASE" in rem["deferred_to_later_runs"]
    assert rem["first_run_must_not_unlock_potion_capacity_4"] is True

    branch = BRANCH_PATH.read_text(encoding="utf-8")
    assert "Run 1" in branch and "Dernier Flacon" in branch
    assert "Run 2" in branch and "rapport médical" in branch
    assert "Run 3" in branch and "3 → 4" in branch


@pytest.mark.data
def test_run_has_branch_miniboss_boss_and_archive_return() -> None:
    data = json.loads(RUN_PATH.read_text(encoding="utf-8"))
    by_id = {zone["zone_id"]: zone for zone in data["zones"]}
    assert len(by_id["Z4_ASH_CROSSROADS"]["branches"]) == 2
    assert by_id["Z5_HOSPITAL_ANNEX"]["type"] == "MiniBoss"
    assert by_id["Z7_SOUTH_BARRICADE"]["type"] == "Boss"
    assert by_id["Z8_AFTER_BARRICADE"]["end_flow"] == "ReturnToRemanenceArchives"
    assert by_id["Z7_SOUTH_BARRICADE"]["uses_shared_damage_anatomy_gore_pipeline"] is True


@pytest.mark.data
def test_run_document_locks_litd2_scope_and_core_design_line() -> None:
    text = DOC_PATH.read_text(encoding="utf-8")
    assert "LITD 2 uniquement" in text
    assert "Corps / Esprit / Politique" in text
    assert "Le Dernier Flacon" in text
    assert "Capitaine Rhéon" in text
    assert "aucune potion" in text.lower() or "aucun drop" in text.lower()
    assert "Archives" in text
