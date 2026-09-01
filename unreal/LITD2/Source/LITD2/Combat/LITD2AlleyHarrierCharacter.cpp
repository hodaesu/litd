#include "Combat/LITD2AlleyHarrierCharacter.h"

#include "Combat/LITD2CombatantComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Run/LITD2EncounterDirectorSubsystem.h"

ALITD2AlleyHarrierCharacter::ALITD2AlleyHarrierCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCharacterMovement()->MaxWalkSpeed = 430.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 720.0f, 0.0f);

    Combatant = CreateDefaultSubobject<ULITD2CombatantComponent>(TEXT("Combatant"));
    Combatant->MaxHealth = 190.0f;
    Combatant->MaxStamina = 70.0f;
    Combatant->StaminaRegenPerSecond = 18.0f;
}

void ALITD2AlleyHarrierCharacter::BeginPlay()
{
    Super::BeginPlay();
    OrbitDirectionSign = (GetUniqueID() % 2 == 0) ? 1 : -1;

    if (Combatant)
    {
        Combatant->OnDamageResolved.AddDynamic(this, &ALITD2AlleyHarrierCharacter::HandleDamageResolved);
        Combatant->OnDeath.AddDynamic(this, &ALITD2AlleyHarrierCharacter::HandleDeath);
    }
}

void ALITD2AlleyHarrierCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Combatant || Combatant->IsDead()) return;

    if (RecoveryRemaining > 0.0f)
    {
        RecoveryRemaining = FMath::Max(0.0f, RecoveryRemaining - DeltaSeconds);
        return;
    }

    if (bLungeQueued)
    {
        if (bLungeUsesAnimationCommit) return;

        WindupRemaining -= DeltaSeconds;
        if (WindupRemaining <= 0.0f)
        {
            bLungeQueued = false;
            CommitLunge();
            RecoveryRemaining = RecoverySeconds;
        }
        return;
    }

    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    const float Distance2D = ToPlayer.Size2D();
    if (Distance2D > AggroRange) return;

    if (Distance2D <= LungeRange)
    {
        StartLunge();
        return;
    }

    OrbitPlayer(ToPlayer);
}

void ALITD2AlleyHarrierCharacter::OrbitPlayer(const FVector& ToPlayer)
{
    FVector Horizontal = ToPlayer;
    Horizontal.Z = 0.0f;
    if (Horizontal.IsNearlyZero()) return;

    const FVector Radial = Horizontal.GetSafeNormal();
    const FVector Tangent = FVector::CrossProduct(FVector::UpVector, Radial) * static_cast<float>(OrbitDirectionSign);

    const float Distance2D = Horizontal.Size2D();
    float RadialCorrection = 0.0f;
    if (Distance2D > PreferredOrbitRange + 80.0f) RadialCorrection = 0.55f;
    else if (Distance2D < PreferredOrbitRange - 80.0f) RadialCorrection = -0.45f;

    FVector Desired = Tangent + Radial * RadialCorrection;
    Desired.Normalize();
    AddMovementInput(Desired, 1.0f);
}

void ALITD2AlleyHarrierCharacter::StartLunge()
{
    if (bLungeQueued || RecoveryRemaining > 0.0f) return;

    bLungeQueued = true;
    WindupRemaining = LungeWindupSeconds;
    bLungeUsesAnimationCommit = LungeMontage && PlayAnimMontage(LungeMontage) > 0.0f;
    OnLungeTelegraphStarted();
}

void ALITD2AlleyHarrierCharacter::CommitLungeFromAnimation()
{
    if (!bLungeQueued || !bLungeUsesAnimationCommit || !Combatant || Combatant->IsDead()) return;

    bLungeQueued = false;
    bLungeUsesAnimationCommit = false;
    CommitLunge();
    RecoveryRemaining = RecoverySeconds;
}

void ALITD2AlleyHarrierCharacter::CommitLunge()
{
    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    ToPlayer.Z = 0.0f;
    if (ToPlayer.IsNearlyZero()) return;

    const FVector Direction = ToPlayer.GetSafeNormal();
    LaunchCharacter(Direction * LungeStrength + FVector(0.0f, 0.0f, 55.0f), true, false);

    if (ToPlayer.Size2D() <= LungeRange + 70.0f)
    {
        if (ULITD2CombatantComponent* TargetCombatant = Player->FindComponentByClass<ULITD2CombatantComponent>())
        {
            FLITD2DamageEventPayload Payload;
            Payload.DamageType = ELITD2DamageType::Slash;
            Payload.HitBone = TEXT("spine_02");
            Payload.HitDirection = Direction;
            Payload.DamageAmount = LungeDamage;
            Payload.ImpactForce = 0.46f;
            Payload.Penetration = 0.26f;
            Payload.BleedValue = 0.32f;
            Payload.TraumaValue = 0.0f;
            Payload.DismembermentValue = 0.0f;
            Payload.bReadableSevereCause = false;
            TargetCombatant->ReceiveDamageEvent(Payload);
        }
    }

    OrbitDirectionSign *= -1;
    OnLungeCommitted();
}

void ALITD2AlleyHarrierCharacter::HandleDamageResolved(FLITD2DamageResolution Resolution)
{
    if (Resolution.AppliedDamage > 0.0f)
    {
        bLungeQueued = false;
        bLungeUsesAnimationCommit = false;
        RecoveryRemaining = FMath::Max(RecoveryRemaining, 0.38f);
        if (HitReactionMontage)
        {
            PlayAnimMontage(HitReactionMontage);
        }
    }
    OnDamagePresentation(Resolution);
}

void ALITD2AlleyHarrierCharacter::HandleDeath()
{
    bLungeQueued = false;
    bLungeUsesAnimationCommit = false;
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
            Encounter->ReportEnemyDefeated(TEXT("ALLEY_HARRIER"));
        }
    }

    SetLifeSpan(7.0f);
}
