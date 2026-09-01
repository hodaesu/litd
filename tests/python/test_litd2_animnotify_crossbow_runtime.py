import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMBAT = ROOT / "unreal" / "LITD2" / "Source" / "LITD2" / "Combat"
DATA = ROOT / "unreal" / "LITD2" / "Data" / "Combat"
RUN = ROOT / "unreal" / "LITD2" / "Data" / "Runs" / "sarei_faubourgs_run.json"


def text(name: str) -> str:
    return (COMBAT / name).read_text(encoding="utf-8")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_shared_animnotify_dispatches_all_current_combat_commits() -> None:
    header = text("LITD2AnimNotify_CombatCommit.h")
    source = text("LITD2AnimNotify_CombatCommit.cpp")

    for event in (
        "PlayerQueuedAttack",
        "AshWandererAttack",
        "LineBreakerSevereAttack",
        "SareiCrossbowRelease",
    ):
        assert event in header
        assert event in source

    assert "CommitQueuedAttackFromAnimation" in source
    assert "CommitAttackFromAnimation" in source
    assert "CommitSevereAttackFromAnimation" in source
    assert "ReleaseShotFromAnimation" in source


def test_player_montage_branch_waits_for_animation_commit() -> None:
    source = text("LITD2PlayerCombatCharacter.cpp")
    header = text("LITD2PlayerCombatCharacter.h")

    assert "bAttackCommitPending" in header
    assert "CommitQueuedAttackFromAnimation" in header
    assert "LightAttackMontage && PlayAnimMontage" in source
    assert "HeavyAttackMontage && PlayAnimMontage" in source
    assert "CancelQueuedAttack();" in source


def test_basic_melee_is_interruptible_but_line_breaker_heavy_is_committed() -> None:
    ash = text("LITD2AshWandererCharacter.cpp")
    breaker = text("LITD2LineBreakerCharacter.cpp")

    assert "bAttackUsesAnimationCommit" in ash
    assert "bAttackQueued = false;" in ash
    assert "RecoveryRemaining = FMath::Max(RecoveryRemaining, 0.30f)" in ash

    assert "bAttackUsesAnimationCommit" in breaker
    assert "!bSevereAttackQueued && HitReactionMontage" in breaker
    assert "Payload.TraumaValue = 0.58f" in breaker
    assert "Payload.bReadableSevereCause = true" in breaker


def test_sarei_crossbow_is_a_real_projectile_ranged_enemy_without_base_trauma() -> None:
    crossbow = text("LITD2SareiCrossbowCharacter.cpp")
    bolt = text("LITD2SareiBoltProjectile.cpp")

    assert "PreferredMinRange = 560.0f" in text("LITD2SareiCrossbowCharacter.h")
    assert "PreferredMaxRange = 1050.0f" in text("LITD2SareiCrossbowCharacter.h")
    assert "World->SpawnActor<ALITD2SareiBoltProjectile>" in crossbow
    assert 'ReportEnemyDefeated(TEXT("SAREI_CROSSBOW"))' in crossbow
    assert "ELITD2DamageType::Pierce" in bolt
    assert "Payload.TraumaValue = 0.0f" in bolt
    assert "Payload.bReadableSevereCause = false" in bolt


def test_animation_contracts_match_runtime_and_run_roster() -> None:
    contracts = load_json(DATA / "animation_combat_contracts.json")
    registry = load_json(DATA / "enemy_runtime_registry.json")
    run = load_json(RUN)

    events = {entry["commit_event"] for entry in contracts["contracts"] if entry["commit_event"]}
    assert {
        "PlayerQueuedAttack",
        "AshWandererAttack",
        "LineBreakerSevereAttack",
        "SareiCrossbowRelease",
    } <= events

    runtime = {entry["enemy_id"]: entry for entry in registry["entries"]}
    assert runtime["ASH_WANDERER"]["status"] == "RUNTIME_READY"
    assert runtime["LINE_BREAKER"]["status"] == "RUNTIME_READY"
    assert runtime["SAREI_CROSSBOW"]["native_class"] == "ALITD2SareiCrossbowCharacter"
    assert runtime["SAREI_CROSSBOW"]["projectile_class"] == "ALITD2SareiBoltProjectile"

    roster = {entry["enemy_id"] for entry in run["enemy_roster"]}
    assert "SAREI_CROSSBOW" in roster

    encounter_ids = set()
    for zone in run["zones"]:
        for encounter in zone.get("encounters", []):
            encounter_ids.add(encounter["enemy_id"])
        for branch in zone.get("branches", []):
            for encounter in branch.get("encounters", []):
                encounter_ids.add(encounter["enemy_id"])
        for wave in zone.get("waves", []):
            for encounter in wave:
                encounter_ids.add(encounter["enemy_id"])
    assert "SAREI_CROSSBOW" in encounter_ids
