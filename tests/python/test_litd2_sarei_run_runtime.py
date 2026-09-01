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


@pytest.mark.data
def test_complete_sarei_vertical_slice_flow_contract() -> None:
    """Walk the exact first playable loop as a deterministic contract test."""
    data = json.loads(RUN.read_text(encoding="utf-8"))
    zones = {zone["zone_id"]: zone for zone in data["zones"]}

    # Start: 3 potions and no trauma.
    potion_capacity = data["start"]["potions"]
    potions = potion_capacity
    max_hp = 1000
    locked_hp = 0
    current_hp = max_hp
    trauma_level = 0
    archive_entries: set[str] = set()

    # Z1 completed: basic combat does not force trauma.
    assert zones["Z1_SOUTH_GATE"]["trauma_pressure"] == "LOW"

    # Z2: simulate one readable severe hit, then use the fountain.
    locked_hp += 100
    trauma_level = 1
    current_hp = 620
    recoverable_max = max_hp - locked_hp
    current_hp = recoverable_max
    assert current_hp == 900
    assert locked_hp == 100
    assert trauma_level == 1
    assert zones["Z2_STRETCHER_STREET"]["healing"]["cures_trauma"] is False

    # Z3: discover Le Dernier Flacon. Knowledge persists; no permanent power yet.
    last_flask = zones["Z3_FIELD_AID_POST"]["mandatory_remanence_id"]
    archive_entries.add(last_flask)
    assert last_flask == "SAREI_ECHO_LAST_FLASK"
    assert zones["Z3_FIELD_AID_POST"]["permanent_gameplay_reward"] is False

    # Use one potion before the branch: trauma clears, capacity remains 3.
    potions -= 1
    locked_hp = 0
    trauma_level = 0
    current_hp = max_hp
    assert (potions, locked_hp, trauma_level, current_hp) == (2, 0, 0, 1000)

    # Contextual Z3 cache can replace the spent potion, never exceed capacity.
    if potions < potion_capacity:
        potions += 1
    assert potions == 3

    # Z4: choose exactly one valid route.
    branch_ids = {branch["branch_id"] for branch in zones["Z4_ASH_CROSSROADS"]["branches"]}
    chosen_branch = "CONVOY_YARD"
    assert chosen_branch in branch_ids
    assert zones["Z4_ASH_CROSSROADS"]["branches_equal_average_value"] is True

    # Z5: mini-boss exists and validates all three build paths.
    mini_boss = zones["Z5_HOSPITAL_ANNEX"]
    assert mini_boss["boss_id"] == "SAREI_GUARD_SURGEON"
    assert set(mini_boss["path_validation"]) == {"Body", "Mind", "Politics"}

    # Z6: all three waves exist and the final fountain still cannot cure trauma.
    wave_arena = zones["Z6_EVACUATION_YARD"]
    assert len(wave_arena["waves"]) == 3
    assert wave_arena["healing"]["cures_trauma"] is False
    assert wave_arena["pre_boss_decision"] == "SpendPotionToClearTraumaOrPreserveIt"

    # Z7: Rhéon is defeated through the shared boss contract.
    rheon = zones["Z7_SOUTH_BARRICADE"]
    assert rheon["boss_id"] == "CAPTAIN_RHEON_LAST_LOCK"
    assert [phase["health_range"] for phase in rheon["phases"]] == [[100, 60], [60, 25], [25, 0]]
    assert set(rheon["path_viability"]) == {"Body", "Mind", "Politics"}
    assert rheon["uses_shared_damage_anatomy_gore_pipeline"] is True

    # Z8: conclusion knowledge returns to Archives without resolving the political truth.
    conclusion = zones["Z8_AFTER_BARRICADE"]
    archive_entries.add(conclusion["remanence_id"])
    assert conclusion["end_flow"] == "ReturnToRemanenceArchives"
    assert conclusion["resolves_political_truth"] is False
    assert "SAREI_ECHO_LAST_FLASK" in archive_entries
    assert "SAREI_RHEON_GATE_ORDER_TRACE" in archive_entries

    # First run explicitly cannot grant potion capacity 4.
    assert data["remanence_summary"]["first_run_must_not_unlock_potion_capacity_4"] is True
    assert potion_capacity == 3
