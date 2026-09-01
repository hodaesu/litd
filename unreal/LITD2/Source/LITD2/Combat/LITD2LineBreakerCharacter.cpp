#include "Combat/LITD2LineBreakerCharacter.h"

#include "Combat/LITD2CombatantComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Run/LITD2EncounterDirectorSubsystem.h"

ALITD2LineBreakerCharacter::ALITD2LineBreakerCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCharacterMovement()->MaxWalkSpeed = 225.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 360.0f, 0.0f);

    Combatant = CreateDefaultSubobject<ULITD2CombatantComponent>(TEXT("Combatant"));
    Combatant->MaxHealth = 720.0f;
    Combatant->MaxStamina = 85.0f;
    Combatant->StaminaRegenPerSecond = 14.0f;
}

void ALITD2LineBreakerCharacter::BeginPlay()
{
    Super::BeginPlay();
    if (Combatant)
    {
        Combatant->OnDamageResolved.AddDynamic(this, &ALITD2LineBreakerCharacter::HandleDamageResolved);
        Combatant->OnDeath.AddDynamic(this, &ALITD2LineBreakerCharacter::HandleDeath);
    }
}

void ALITD2LineBreakerCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Combatant || Combatant->IsDead()) return;

    if (RecoveryRemaining > 0.0f)
    {
        RecoveryRemaining = FMath::Max(0.0f, RecoveryRemaining - DeltaSeconds);
        return;
    }

    if (bSevereAttackQueued)
    {
        // With a montage assigned, only the animation notify is allowed to apply the hit.
        if (bAttackUsesAnimationCommit) return;

        WindupRemaining -= DeltaSeconds;
        if (WindupRemaining <= 0.0f)
        {
            bSevereAttackQueued = false;
            RecoveryRemaining = SevereRecoverySeconds;
            CommitSevereAttack();
        }
        return;
    }

    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    const float Distance2D = ToPlayer.Size2D();
    if (Distance2D > AggroRange) return;

    if (Distance2D > SevereAttackRange)
    {
        FVector Direction = ToPlayer;
        Direction.Z = 0.0f;
        Direction.Normalize();
        AddMovementInput(Direction, 1.0f);
        return;
    }

    StartSevereAttack();
}

void ALITD2LineBreakerCharacter::StartSevereAttack()
{
    if (bSevereAttackQueued || RecoveryRemaining > 0.0f) return;

    bSevereAttackQueued = true;
    WindupRemaining = SevereWindupSeconds;
    bAttackUsesAnimationCommit = SevereAttackMontage && PlayAnimMontage(SevereAttackMontage) > 0.0f;
    OnSevereTelegraphStarted();
}

void ALITD2LineBreakerCharacter::CommitSevereAttackFromAnimation()
{
    if (!bSevereAttackQueued || !bAttackUsesAnimationCommit || !Combatant || Combatant->IsDead()) return;

    bSevereAttackQueued = false;
    bAttackUsesAnimationCommit = false;
    RecoveryRemaining = SevereRecoverySeconds;
    CommitSevereAttack();
}

void ALITD2LineBreakerCharacter::CommitSevereAttack()
{
    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    if (ToPlayer.Size2D() > SevereAttackRange + 45.0f) return;

    ULITD2CombatantComponent* TargetCombatant = Player->FindComponentByClass<ULITD2CombatantComponent>();
    if (!TargetCombatant) return;

    FLITD2DamageEventPayload Payload;
    Payload.DamageType = ELITD2DamageType::Blunt;
    Payload.HitBone = TEXT("spine_03");
    Payload.HitDirection = ToPlayer.GetSafeNormal();
    Payload.DamageAmount = SevereAttackDamage;
    Payload.ImpactForce = 0.92f;
    Payload.Penetration = 0.08f;
    Payload.BleedValue = 0.15f;
    Payload.TraumaValue = 0.58f;
    Payload.DismembermentValue = 0.10f;
    Payload.bReadableSevereCause = true;

    const FLITD2DamageResolution Resolution = TargetCombatant->ReceiveDamageEvent(Payload);
    if (Resolution.bParried)
    {
        RecoveryRemaining = SevereRecoverySeconds * 2.05f;
        OnParriedPresentation();
    }

    OnSevereAttackCommitted();
}

void ALITD2LineBreakerCharacter::HandleDamageResolved(FLITD2DamageResolution Resolution)
{
    // The heavy trauma swing has commitment/super-armour: normal hit reaction montages must not cancel it.
    if (Resolution.AppliedDamage > 0.0f && !bSevereAttackQueued && HitReactionMontage)
    {
        PlayAnimMontage(HitReactionMontage);
    }
    OnDamagePresentation(Resolution);
}

void ALITD2LineBreakerCharacter::HandleDeath()
{
    bSevereAttackQueued = false;
    bAttackUsesAnimationCommit = false;
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
            Encounter->ReportEnemyDefeated(TEXT("LINE_BREAKER"));
        }
    }

    SetLifeSpan(9.0f);
}
