from pathlib import Path

import pytest


LINE_BREAKER_H = Path("unreal/LITD2/Source/LITD2/Combat/LITD2LineBreakerCharacter.h")
LINE_BREAKER_CPP = Path("unreal/LITD2/Source/LITD2/Combat/LITD2LineBreakerCharacter.cpp")
COMBATANT_CPP = Path("unreal/LITD2/Source/LITD2/Combat/LITD2CombatantComponent.cpp")
PLAYER_H = Path("unreal/LITD2/Source/LITD2/Combat/LITD2PlayerCombatCharacter.h")
PLAYER_CPP = Path("unreal/LITD2/Source/LITD2/Combat/LITD2PlayerCombatCharacter.cpp")
DOC = Path("docs/LITD2/COMBAT_VERTICAL_SLICE.md")


@pytest.mark.data
def test_line_breaker_is_first_deterministic_trauma_enemy() -> None:
    header = LINE_BREAKER_H.read_text(encoding="utf-8")
    cpp = LINE_BREAKER_CPP.read_text(encoding="utf-8")

    assert "ALITD2LineBreakerCharacter" in header
    assert "SevereWindupSeconds = 1.10f" in header
    assert "SevereRecoverySeconds = 1.55f" in header
    assert "SevereAttackDamage = 145.0f" in header
    assert 'Payload.DamageType = ELITD2DamageType::Blunt' in cpp
    assert "Payload.TraumaValue = 0.58f" in cpp
    assert "Payload.bReadableSevereCause = true" in cpp
    assert 'ReportEnemyDefeated(TEXT("LINE_BREAKER"))' in cpp
    assert "OnSevereTelegraphStarted" in header
    assert "OnParriedPresentation" in header


@pytest.mark.data
def test_defended_severe_hits_cannot_generate_trauma_or_dismemberment() -> None:
    cpp = COMBATANT_CPP.read_text(encoding="utf-8")

    assert "const bool bDefended = Payload.bParried || Payload.bBlocked;" in cpp
    assert "if (!bDefended && Payload.bReadableSevereCause && Payload.TraumaValue >= 0.50f)" in cpp
    assert "Result.bDismembermentCandidate = !bDefended" in cpp
    assert "Result.bWoundTriggered = !bDefended" in cpp


@pytest.mark.data
def test_first_player_and_line_breaker_montage_slots_are_wired() -> None:
    player_h = PLAYER_H.read_text(encoding="utf-8")
    player_cpp = PLAYER_CPP.read_text(encoding="utf-8")
    breaker_h = LINE_BREAKER_H.read_text(encoding="utf-8")
    breaker_cpp = LINE_BREAKER_CPP.read_text(encoding="utf-8")

    for montage in ("LightAttackMontage", "HeavyAttackMontage", "DodgeMontage", "ParryMontage"):
        assert montage in player_h
        assert f"PlayAnimMontage({montage})" in player_cpp

    for montage in ("SevereAttackMontage", "HitReactionMontage", "DeathMontage"):
        assert montage in breaker_h
        assert f"PlayAnimMontage({montage})" in breaker_cpp


@pytest.mark.data
def test_combat_doc_requires_animnotify_next_and_trauma_i_validation() -> None:
    text = DOC.read_text(encoding="utf-8")

    assert "Briseur de ligne" in text
    assert "Traumatisme I" in text
    assert "AnimNotify" in text
    assert "blocage" in text
    assert "aucun traumatisme" in text
