import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMBAT = ROOT / "unreal" / "LITD2" / "Source" / "LITD2" / "Combat"
DATA = ROOT / "unreal" / "LITD2" / "Data"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_sarei_run_keeps_guard_surgeon_contract() -> None:
    run = json.loads(read_text(DATA / "Runs" / "sarei_faubourgs_run.json"))
    z5 = next(zone for zone in run["zones"] if zone["zone_id"] == "Z5_HOSPITAL_ANNEX")
    assert z5["boss_id"] == "SAREI_GUARD_SURGEON"
    assert {"TargetedBleed", "TelegraphedGrab", "InterruptWindow", "SevereTraumaAttack"}.issubset(
        set(z5["mechanics"])
    )


def test_guard_surgeon_is_runtime_ready() -> None:
    registry = json.loads(read_text(DATA / "Combat" / "enemy_runtime_registry.json"))
    entry = next(item for item in registry["entries"] if item["enemy_id"] == "SAREI_GUARD_SURGEON")
    assert entry["native_class"] == "ALITD2GuardSurgeonCharacter"
    assert entry["status"] == "RUNTIME_READY"
    assert entry["role"] == "MiniBoss"


def test_guard_surgeon_has_all_four_gameplay_pillars() -> None:
    header = read_text(COMBAT / "LITD2GuardSurgeonCharacter.h")
    source = read_text(COMBAT / "LITD2GuardSurgeonCharacter.cpp")

    assert "IncisionBleedDamagePerSecond = 9.0f" in header
    assert "IncisionBleedDurationSeconds = 5.0f" in header
    assert "Target->ApplyTemporaryBleed" in source

    assert "GrabLockSeconds = 0.45f" in header
    assert "Player->ApplyExternalMovementLock(GrabLockSeconds)" in source
    assert "!Resolution.bBlocked && !Resolution.bParried" in source

    assert "InterruptWindowSeconds = 0.58f" in header
    assert "InterruptDamageThreshold = 115.0f" in header
    assert "InterruptDamageAccumulated += Resolution.AppliedDamage" in source
    assert "InterruptCurrentAction();" in source

    assert "Payload.TraumaValue = 0.63f" in source
    assert "Payload.bReadableSevereCause = true" in source
    assert "ReportEnemyDefeated(TEXT(\"SAREI_GUARD_SURGEON\"))" in source


def test_temporary_bleed_is_a_wound_not_a_trauma() -> None:
    header = read_text(COMBAT / "LITD2CombatantComponent.h")
    source = read_text(COMBAT / "LITD2CombatantComponent.cpp")

    assert "ApplyTemporaryBleed" in header
    assert "IsBleeding()" in header
    assert "TickTemporaryBleed" in source
    assert "BridgeCombatDamageToRun" in source
    assert "ActiveBleedDamagePerSecond" in source
    assert "LockedHealth" not in source[source.index("void ULITD2CombatantComponent::TickTemporaryBleed"):source.index("void ULITD2CombatantComponent::BridgeCombatDamageToRun")]


def test_guard_surgeon_animation_commits_are_explicit() -> None:
    notify_header = read_text(COMBAT / "LITD2AnimNotify_CombatCommit.h")
    notify_source = read_text(COMBAT / "LITD2AnimNotify_CombatCommit.cpp")
    contracts = json.loads(read_text(DATA / "Combat" / "animation_combat_contracts.json"))

    for event in ("GuardSurgeonIncision", "GuardSurgeonGrab", "GuardSurgeonSevereStrike"):
        assert event in notify_header
        assert event in notify_source

    surgeon_contracts = [item for item in contracts["contracts"] if item["actor"] == "ALITD2GuardSurgeonCharacter"]
    assert {item["commit_event"] for item in surgeon_contracts} == {
        "GuardSurgeonIncision",
        "GuardSurgeonGrab",
        "GuardSurgeonSevereStrike",
    }


def test_player_supports_brief_external_grab_lock() -> None:
    header = read_text(COMBAT / "LITD2PlayerCombatCharacter.h")
    source = read_text(COMBAT / "LITD2PlayerCombatCharacter.cpp")

    assert "ApplyExternalMovementLock" in header
    assert "IsExternallyMovementLocked" in header
    assert "GetCharacterMovement()->DisableMovement();" in source
    assert "GetCharacterMovement()->SetMovementMode(MOVE_Walking);" in source
    assert "CancelQueuedAttack();" in source
