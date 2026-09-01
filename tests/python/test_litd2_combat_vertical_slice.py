from pathlib import Path

import pytest


ROOT = Path("unreal/LITD2")
TYPES = ROOT / "Source/LITD2/Combat/LITD2CombatTypes.h"
COMPONENT_H = ROOT / "Source/LITD2/Combat/LITD2CombatantComponent.h"
COMPONENT_CPP = ROOT / "Source/LITD2/Combat/LITD2CombatantComponent.cpp"
PLAYER_H = ROOT / "Source/LITD2/Combat/LITD2PlayerCombatCharacter.h"
PLAYER_CPP = ROOT / "Source/LITD2/Combat/LITD2PlayerCombatCharacter.cpp"
WANDERER_H = ROOT / "Source/LITD2/Combat/LITD2AshWandererCharacter.h"
WANDERER_CPP = ROOT / "Source/LITD2/Combat/LITD2AshWandererCharacter.cpp"
GAME_MODE_CPP = ROOT / "Source/LITD2/Combat/LITD2CombatGameMode.cpp"
INPUT = ROOT / "Config/DefaultInput.ini"
ENGINE = ROOT / "Config/DefaultEngine.ini"
RUN_H = ROOT / "Source/LITD2/Run/LITD2RunDirectorSubsystem.h"
INTERACTIONS = ROOT / "Source/LITD2/Run/LITD2RunInteractionActors.cpp"
DOC = Path("docs/LITD2/COMBAT_VERTICAL_SLICE.md")


@pytest.mark.data
def test_damage_payload_contains_full_unified_pipeline_language() -> None:
    text = TYPES.read_text(encoding="utf-8")
    for token in (
        "DamageType",
        "HitBone",
        "HitDirection",
        "DamageAmount",
        "ImpactForce",
        "Penetration",
        "BleedValue",
        "TraumaValue",
        "DismembermentValue",
        "bReadableSevereCause",
        "bBlocked",
        "bParried",
    ):
        assert token in text


@pytest.mark.data
def test_combatant_has_stamina_dodge_parry_block_and_nonrandom_trauma() -> None:
    header = COMPONENT_H.read_text(encoding="utf-8")
    cpp = COMPONENT_CPP.read_text(encoding="utf-8")
    for token in (
        "SpendStamina",
        "BeginParry",
        "StartInvulnerabilityWindow",
        "RestoreRecoverableHealth",
        "ClearTraumaAndRestoreFull",
        "ReceiveDamageEvent",
        "GetRecoverableMaxHealth",
    ):
        assert token in header or token in cpp
    assert "bReadableSevereCause" in cpp
    assert "TraumaValue >= 0.50f" in cpp
    assert "FMath::Rand" not in cpp
    assert "Random" not in cpp
    assert "MaxHealth * 0.45f" in cpp


@pytest.mark.data
def test_player_character_exposes_core_action_combat_actions() -> None:
    header = PLAYER_H.read_text(encoding="utf-8")
    cpp = PLAYER_CPP.read_text(encoding="utf-8")
    for token in (
        "LightAttack",
        "HeavyAttack",
        "Dodge",
        "BeginParry",
        "EndParry",
        "UsePotion",
        "SweepSingleByChannel",
        "LaunchCharacter",
        "CameraBoom",
        "FollowCamera",
    ):
        assert token in header or token in cpp
    assert "SpendStamina(12.0f)" in cpp
    assert "SpendStamina(28.0f)" in cpp
    assert "SpendStamina(22.0f)" in cpp
    assert "StartInvulnerabilityWindow" in cpp


@pytest.mark.data
def test_keyboard_mouse_mapping_and_combat_game_mode_are_playable_defaults() -> None:
    input_text = INPUT.read_text(encoding="utf-8")
    engine_text = ENGINE.read_text(encoding="utf-8")
    game_mode = GAME_MODE_CPP.read_text(encoding="utf-8")
    for mapping in ("MoveForward", "MoveRight", "LightAttack", "HeavyAttack", "Dodge", "Parry", "UsePotion"):
        assert mapping in input_text
    assert "LITD2CombatGameMode" in engine_text
    assert "ALITD2PlayerCombatCharacter::StaticClass()" in game_mode


@pytest.mark.data
def test_ash_wanderer_is_connected_to_combat_and_encounter_director() -> None:
    header = WANDERER_H.read_text(encoding="utf-8")
    cpp = WANDERER_CPP.read_text(encoding="utf-8")
    for token in (
        "OnAttackTelegraphStarted",
        "OnDamagePresentation",
        "OnParriedPresentation",
        "ReceiveDamageEvent",
        "ReportEnemyDefeated",
        "ASH_WANDERER",
    ):
        assert token in header or token in cpp
    assert "Payload.bReadableSevereCause = false" in cpp
    assert "RecoveryRemaining = AttackRecoverySeconds * 1.85f" in cpp


@pytest.mark.data
def test_combat_health_is_synchronized_with_run_healing_contract() -> None:
    run_header = RUN_H.read_text(encoding="utf-8")
    combat_cpp = COMPONENT_CPP.read_text(encoding="utf-8")
    interactions = INTERACTIONS.read_text(encoding="utf-8")
    player_cpp = PLAYER_CPP.read_text(encoding="utf-8")
    assert "ApplyCombatDamage" in run_header
    assert "RunDirector->ApplyCombatDamage" in combat_cpp
    assert "RunDirector->ApplyTrauma" in combat_cpp
    assert "RestoreRecoverableHealth" in interactions
    assert "RunDirector->UsePotion" in player_cpp
    assert "ClearTraumaAndRestoreFull" in player_cpp


@pytest.mark.data
def test_combat_vertical_slice_document_preserves_litd2_rules() -> None:
    text = DOC.read_text(encoding="utf-8")
    assert "LITD 2 uniquement" in text
    assert "Un traumatisme ne peut jamais apparaître via un jet aléatoire" in text
    assert "fontaine" in text.lower()
    assert "potion" in text.lower()
    assert "Errant cendré" in text
