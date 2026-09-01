#include "Combat/LITD2GuardSurgeonCharacter.h"

#include "Combat/LITD2CombatantComponent.h"
#include "Combat/LITD2PlayerCombatCharacter.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Run/LITD2EncounterDirectorSubsystem.h"

ALITD2GuardSurgeonCharacter::ALITD2GuardSurgeonCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCharacterMovement()->MaxWalkSpeed = 285.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 520.0f, 0.0f);

    Combatant = CreateDefaultSubobject<ULITD2CombatantComponent>(TEXT("Combatant"));
    Combatant->MaxHealth = 1800.0f;
    Combatant->MaxStamina = 110.0f;
    Combatant->StaminaRegenPerSecond = 18.0f;
}

void ALITD2GuardSurgeonCharacter::BeginPlay()
{
    Super::BeginPlay();

    if (Combatant)
    {
        Combatant->OnDamageResolved.AddDynamic(this, &ALITD2GuardSurgeonCharacter::HandleDamageResolved);
        Combatant->OnDeath.AddDynamic(this, &ALITD2GuardSurgeonCharacter::HandleDeath);
    }
}

void ALITD2GuardSurgeonCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Combatant || Combatant->IsDead()) return;

    if (RecoveryRemaining > 0.0f)
    {
        RecoveryRemaining = FMath::Max(0.0f, RecoveryRemaining - DeltaSeconds);
        return;
    }

    if (CurrentAction != ELITD2GuardSurgeonAction::None)
    {
        InterruptWindowRemaining = FMath::Max(0.0f, InterruptWindowRemaining - DeltaSeconds);

        if (bActionUsesAnimationCommit) return;

        WindupRemaining -= DeltaSeconds;
        if (WindupRemaining <= 0.0f)
        {
            CommitCurrentAction();
        }
        return;
    }

    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    const float Distance2D = ToPlayer.Size2D();
    if (Distance2D > AggroRange) return;

    if (Distance2D > EngageRange)
    {
        ToPlayer.Z = 0.0f;
        ToPlayer.Normalize();
        AddMovementInput(ToPlayer, 1.0f);
        return;
    }

    StartNextAction();
}

void ALITD2GuardSurgeonCharacter::StartNextAction()
{
    static const ELITD2GuardSurgeonAction Cycle[] =
    {
        ELITD2GuardSurgeonAction::Incision,
        ELITD2GuardSurgeonAction::Grab,
        ELITD2GuardSurgeonAction::SevereStrike
    };

    QueueAction(Cycle[ActionCycleIndex % UE_ARRAY_COUNT(Cycle)]);
    ++ActionCycleIndex;
}

void ALITD2GuardSurgeonCharacter::QueueAction(ELITD2GuardSurgeonAction Action)
{
    if (CurrentAction != ELITD2GuardSurgeonAction::None || RecoveryRemaining > 0.0f) return;

    CurrentAction = Action;
    WindupRemaining = GetWindupForAction(Action);
    InterruptWindowRemaining = FMath::Min(InterruptWindowSeconds, WindupRemaining);
    InterruptDamageAccumulated = 0.0f;

    UAnimMontage* Montage = GetMontageForAction(Action);
    bActionUsesAnimationCommit = Montage && PlayAnimMontage(Montage) > 0.0f;
    OnActionTelegraphStarted(GetActionId(Action));
}

void ALITD2GuardSurgeonCharacter::CommitIncisionFromAnimation()
{
    if (CurrentAction == ELITD2GuardSurgeonAction::Incision && bActionUsesAnimationCommit)
    {
        CommitCurrentAction();
    }
}

void ALITD2GuardSurgeonCharacter::CommitGrabFromAnimation()
{
    if (CurrentAction == ELITD2GuardSurgeonAction::Grab && bActionUsesAnimationCommit)
    {
        CommitCurrentAction();
    }
}

void ALITD2GuardSurgeonCharacter::CommitSevereStrikeFromAnimation()
{
    if (CurrentAction == ELITD2GuardSurgeonAction::SevereStrike && bActionUsesAnimationCommit)
    {
        CommitCurrentAction();
    }
}

void ALITD2GuardSurgeonCharacter::CommitCurrentAction()
{
    const ELITD2GuardSurgeonAction Action = CurrentAction;
    if (Action == ELITD2GuardSurgeonAction::None) return;

    bActionUsesAnimationCommit = false;
    CurrentAction = ELITD2GuardSurgeonAction::None;
    InterruptWindowRemaining = 0.0f;
    InterruptDamageAccumulated = 0.0f;

    switch (Action)
    {
        case ELITD2GuardSurgeonAction::Incision:
            CommitIncision();
            break;
        case ELITD2GuardSurgeonAction::Grab:
            CommitGrab();
            break;
        case ELITD2GuardSurgeonAction::SevereStrike:
            CommitSevereStrike();
            break;
        default:
            break;
    }

    RecoveryRemaining = FMath::Max(RecoveryRemaining, GetRecoveryForAction(Action));
    OnActionCommitted(GetActionId(Action));
}

void ALITD2GuardSurgeonCharacter::CommitIncision()
{
    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    if (ToPlayer.Size2D() > EngageRange + 35.0f) return;

    if (ULITD2CombatantComponent* Target = Player->FindComponentByClass<ULITD2CombatantComponent>())
    {
        FLITD2DamageEventPayload Payload;
        Payload.DamageType = ELITD2DamageType::Slash;
        Payload.HitBone = TEXT("upperarm_r");
        Payload.HitDirection = ToPlayer.GetSafeNormal();
        Payload.DamageAmount = IncisionDamage;
        Payload.ImpactForce = 0.38f;
        Payload.Penetration = 0.52f;
        Payload.BleedValue = 0.88f;
        Payload.TraumaValue = 0.0f;
        Payload.DismembermentValue = 0.08f;
        Payload.bReadableSevereCause = false;

        const FLITD2DamageResolution Resolution = Target->ReceiveDamageEvent(Payload);
        if (Resolution.bWoundTriggered)
        {
            Target->ApplyTemporaryBleed(IncisionBleedDamagePerSecond, IncisionBleedDurationSeconds);
        }
        if (Resolution.bParried)
        {
            RecoveryRemaining = FMath::Max(RecoveryRemaining, IncisionRecoverySeconds * 1.85f);
            OnParriedPresentation(TEXT("INCISION"));
        }
    }
}

void ALITD2GuardSurgeonCharacter::CommitGrab()
{
    ALITD2PlayerCombatCharacter* Player = Cast<ALITD2PlayerCombatCharacter>(UGameplayStatics::GetPlayerCharacter(this, 0));
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    if (ToPlayer.Size2D() > EngageRange + 30.0f) return;

    if (ULITD2CombatantComponent* Target = Player->FindComponentByClass<ULITD2CombatantComponent>())
    {
        FLITD2DamageEventPayload Payload;
        Payload.DamageType = ELITD2DamageType::Blunt;
        Payload.HitBone = TEXT("spine_02");
        Payload.HitDirection = ToPlayer.GetSafeNormal();
        Payload.DamageAmount = GrabDamage;
        Payload.ImpactForce = 0.48f;
        Payload.Penetration = 0.12f;
        Payload.BleedValue = 0.12f;
        Payload.TraumaValue = 0.0f;
        Payload.DismembermentValue = 0.0f;
        Payload.bReadableSevereCause = false;

        const FLITD2DamageResolution Resolution = Target->ReceiveDamageEvent(Payload);
        if (!Resolution.bBlocked && !Resolution.bParried && Resolution.AppliedDamage > 0.0f)
        {
            Player->ApplyExternalMovementLock(GrabLockSeconds);
        }
        else if (Resolution.bParried)
        {
            RecoveryRemaining = FMath::Max(RecoveryRemaining, GrabRecoverySeconds * 1.75f);
            OnParriedPresentation(TEXT("GRAB"));
        }
    }
}

void ALITD2GuardSurgeonCharacter::CommitSevereStrike()
{
    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    if (ToPlayer.Size2D() > EngageRange + 50.0f) return;

    if (ULITD2CombatantComponent* Target = Player->FindComponentByClass<ULITD2CombatantComponent>())
    {
        FLITD2DamageEventPayload Payload;
        Payload.DamageType = ELITD2DamageType::Blunt;
        Payload.HitBone = TEXT("spine_03");
        Payload.HitDirection = ToPlayer.GetSafeNormal();
        Payload.DamageAmount = SevereDamage;
        Payload.ImpactForce = 0.90f;
        Payload.Penetration = 0.18f;
        Payload.BleedValue = 0.20f;
        Payload.TraumaValue = 0.63f;
        Payload.DismembermentValue = 0.10f;
        Payload.bReadableSevereCause = true;

        const FLITD2DamageResolution Resolution = Target->ReceiveDamageEvent(Payload);
        if (Resolution.bParried)
        {
            RecoveryRemaining = FMath::Max(RecoveryRemaining, SevereRecoverySeconds * 1.90f);
            OnParriedPresentation(TEXT("SEVERE_STRIKE"));
        }
    }
}

void ALITD2GuardSurgeonCharacter::InterruptCurrentAction()
{
    if (CurrentAction == ELITD2GuardSurgeonAction::None) return;

    const FName InterruptedAction = GetActionId(CurrentAction);
    StopAnimMontage();
    ClearCurrentAction();
    RecoveryRemaining = InterruptedRecoverySeconds;

    if (InterruptedMontage)
    {
        PlayAnimMontage(InterruptedMontage);
    }
    OnInterruptedPresentation(InterruptedAction);
}

void ALITD2GuardSurgeonCharacter::ClearCurrentAction()
{
    CurrentAction = ELITD2GuardSurgeonAction::None;
    WindupRemaining = 0.0f;
    InterruptWindowRemaining = 0.0f;
    InterruptDamageAccumulated = 0.0f;
    bActionUsesAnimationCommit = false;
}

float ALITD2GuardSurgeonCharacter::GetWindupForAction(ELITD2GuardSurgeonAction Action) const
{
    switch (Action)
    {
        case ELITD2GuardSurgeonAction::Incision: return IncisionWindupSeconds;
        case ELITD2GuardSurgeonAction::Grab: return GrabWindupSeconds;
        case ELITD2GuardSurgeonAction::SevereStrike: return SevereWindupSeconds;
        default: return 0.0f;
    }
}

float ALITD2GuardSurgeonCharacter::GetRecoveryForAction(ELITD2GuardSurgeonAction Action) const
{
    switch (Action)
    {
        case ELITD2GuardSurgeonAction::Incision: return IncisionRecoverySeconds;
        case ELITD2GuardSurgeonAction::Grab: return GrabRecoverySeconds;
        case ELITD2GuardSurgeonAction::SevereStrike: return SevereRecoverySeconds;
        default: return 0.0f;
    }
}

UAnimMontage* ALITD2GuardSurgeonCharacter::GetMontageForAction(ELITD2GuardSurgeonAction Action) const
{
    switch (Action)
    {
        case ELITD2GuardSurgeonAction::Incision: return IncisionMontage;
        case ELITD2GuardSurgeonAction::Grab: return GrabMontage;
        case ELITD2GuardSurgeonAction::SevereStrike: return SevereStrikeMontage;
        default: return nullptr;
    }
}

FName ALITD2GuardSurgeonCharacter::GetActionId(ELITD2GuardSurgeonAction Action) const
{
    switch (Action)
    {
        case ELITD2GuardSurgeonAction::Incision: return TEXT("INCISION");
        case ELITD2GuardSurgeonAction::Grab: return TEXT("GRAB");
        case ELITD2GuardSurgeonAction::SevereStrike: return TEXT("SEVERE_STRIKE");
        default: return NAME_None;
    }
}

void ALITD2GuardSurgeonCharacter::HandleDamageResolved(FLITD2DamageResolution Resolution)
{
    if (Resolution.AppliedDamage > 0.0f)
    {
        if (CurrentAction != ELITD2GuardSurgeonAction::None && InterruptWindowRemaining > 0.0f)
        {
            InterruptDamageAccumulated += Resolution.AppliedDamage;
            if (InterruptDamageAccumulated + KINDA_SMALL_NUMBER >= InterruptDamageThreshold)
            {
                InterruptCurrentAction();
                OnDamagePresentation(Resolution);
                return;
            }
        }

        if (HitReactionMontage && CurrentAction == ELITD2GuardSurgeonAction::None)
        {
            PlayAnimMontage(HitReactionMontage);
        }
    }

    OnDamagePresentation(Resolution);
}

void ALITD2GuardSurgeonCharacter::HandleDeath()
{
    ClearCurrentAction();
    StopAnimMontage();
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false);

    if (DeathMontage)
    {
        PlayAnimMontage(DeathMontage);
    }
    OnEnemyDeathPresentation();

    if (UGameInstance* GI = GetGameInstance())
    {
        if (ULITD2EncounterDirectorSubsystem* Encounter = GI->GetSubsystem<ULITD2EncounterDirectorSubsystem>())
        {
            Encounter->ReportEnemyDefeated(TEXT("SAREI_GUARD_SURGEON"));
        }
    }

    SetLifeSpan(10.0f);
}
