import json
from pathlib import Path

import pytest


RUN = Path("unreal/LITD2/Data/Runs/sarei_faubourgs_run.json")
RUN_HEADER = Path("unreal/LITD2/Source/LITD2/Run/LITD2RunDirectorSubsystem.h")
RUN_CPP = Path("unreal/LITD2/Source/LITD2/Run/LITD2RunDirectorSubsystem.cpp")
ENCOUNTER_HEADER = Path("unreal/LITD2/Source/LITD2/Run/LITD2EncounterDirectorSubsystem.h")
ENCOUNTER_CPP = Path("unreal/LITD2/Source/LITD2/Run/LITD2EncounterDirectorSubsystem.cpp")
INTERACTION_HEADER = Path("unreal/LITD2/Source/LITD2/Run/LITD2RunInteractionActors.h")
INTERACTION_CPP = Path("unreal/LITD2/Source/LITD2/Run/LITD2RunInteractionActors.cpp")


@pytest.mark.data
def test_sarei_runtime_contract_is_z0_to_z8_and_starts_with_three_potions() -> None:
    data = json.loads(RUN.read_text(encoding="utf-8"))
    zone_ids = [zone["zone_id"] for zone in data["zones"]]
    assert zone_ids == [
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
    assert data["start"]["potions"] == 3
    assert data["rules"]["ordinary_healing_cures_trauma"] is False
    assert data["rules"]["potion_cures_all_trauma"] is True


@pytest.mark.data
def test_run_director_exposes_full_vertical_slice_progression_contract() -> None:
    header = RUN_HEADER.read_text(encoding="utf-8")
    cpp = RUN_CPP.read_text(encoding="utf-8")

    for token in (
        "StartSareiRun",
        "CompleteCurrentZone",
        "ChooseBranch",
        "ApplyTrauma",
        "UseFountain",
        "UsePotion",
        "GrantContextualReplacementPotion",
        "DiscoverRemanence",
        "ReportBossHealthPercent",
        "OnZoneStarted",
        "OnZoneCompleted",
        "OnRemanenceDiscovered",
        "OnBossPhaseChanged",
        "OnRunCompleted",
    ):
        assert token in header or token in cpp

    assert 'State.PotionCapacity = 3' in cpp
    assert 'State.PotionCount = 3' in cpp
    assert 'State.LockedHealth = 0' in cpp
    assert 'GetRecoverableMaxHealth()' in cpp
    assert 'Archives->SetEntryState' in cpp
    assert 'Z4_ASH_CROSSROADS' in cpp
    assert 'CONVOY_YARD' in cpp
    assert 'GLASSMAKERS_STREET' in cpp


@pytest.mark.data
def test_fountain_does_not_clear_trauma_but_potion_does() -> None:
    cpp = RUN_CPP.read_text(encoding="utf-8")
    fountain_body = cpp.split("int32 ULITD2RunDirectorSubsystem::UseFountain()", 1)[1].split(
        "bool ULITD2RunDirectorSubsystem::UsePotion()", 1
    )[0]
    potion_body = cpp.split("bool ULITD2RunDirectorSubsystem::UsePotion()", 1)[1].split(
        "bool ULITD2RunDirectorSubsystem::GrantContextualReplacementPotion()", 1
    )[0]

    assert "LockedHealth = 0" not in fountain_body
    assert "TraumaLevel = 0" not in fountain_body
    assert "LockedHealth = 0" in potion_body
    assert "TraumaLevel = 0" in potion_body


@pytest.mark.data
def test_encounter_director_dispatches_enemies_waves_and_bosses() -> None:
    header = ENCOUNTER_HEADER.read_text(encoding="utf-8")
    cpp = ENCOUNTER_CPP.read_text(encoding="utf-8")

    for token in (
        "BeginZone",
        "ReportEnemyDefeated",
        "ReportBossDefeated",
        "OnEnemySpawnRequested",
        "OnBossSpawnRequested",
        "OnWaveStarted",
        "OnEncounterZoneCompleted",
    ):
        assert token in header or token in cpp

    assert 'TEXT("waves")' in cpp
    assert 'TEXT("branches")' in cpp
    assert 'TEXT("encounters")' in cpp
    assert "StartWave(NextWave)" in cpp
    assert "MarkCurrentZoneObjectiveSatisfied" in cpp


@pytest.mark.data
def test_world_interaction_actors_route_into_run_director() -> None:
    header = INTERACTION_HEADER.read_text(encoding="utf-8")
    cpp = INTERACTION_CPP.read_text(encoding="utf-8")

    for actor in (
        "ALITD2HealingPoint",
        "ALITD2MedicalCache",
        "ALITD2RemanenceTrigger",
        "ALITD2BranchGate",
    ):
        assert actor in header

    assert "UseFountain" in cpp
    assert "GrantContextualReplacementPotion" in cpp
    assert "DiscoverRemanence" in cpp
    assert "ChooseBranch" in cpp
    assert "bConsumed" in header
    assert "bTriggered" in header
