#include "Combat/LITD2AshWandererCharacter.h"

#include "Combat/LITD2CombatantComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Run/LITD2EncounterDirectorSubsystem.h"

ALITD2AshWandererCharacter::ALITD2AshWandererCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCharacterMovement()->MaxWalkSpeed = 285.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 480.0f, 0.0f);

    Combatant = CreateDefaultSubobject<ULITD2CombatantComponent>(TEXT("Combatant"));
    Combatant->MaxHealth = 260.0f;
    Combatant->MaxStamina = 60.0f;
    Combatant->StaminaRegenPerSecond = 15.0f;
}

void ALITD2AshWandererCharacter::BeginPlay()
{
    Super::BeginPlay();
    if (Combatant)
    {
        Combatant->OnDamageResolved.AddDynamic(this, &ALITD2AshWandererCharacter::HandleDamageResolved);
        Combatant->OnDeath.AddDynamic(this, &ALITD2AshWandererCharacter::HandleDeath);
    }
}

void ALITD2AshWandererCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Combatant || Combatant->IsDead()) return;

    if (RecoveryRemaining > 0.0f)
    {
        RecoveryRemaining = FMath::Max(0.0f, RecoveryRemaining - DeltaSeconds);
        return;
    }

    if (bAttackQueued)
    {
        WindupRemaining -= DeltaSeconds;
        if (WindupRemaining <= 0.0f)
        {
            bAttackQueued = false;
            CommitAttack();
            RecoveryRemaining = AttackRecoverySeconds;
        }
        return;
    }

    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    const float Distance2D = ToPlayer.Size2D();
    if (Distance2D > AggroRange) return;

    if (Distance2D > AttackRange)
    {
        FVector Direction = ToPlayer;
        Direction.Z = 0.0f;
        Direction.Normalize();
        AddMovementInput(Direction, 1.0f);
        return;
    }

    StartAttack();
}

void ALITD2AshWandererCharacter::StartAttack()
{
    if (bAttackQueued || RecoveryRemaining > 0.0f) return;
    bAttackQueued = true;
    WindupRemaining = AttackWindupSeconds;
    OnAttackTelegraphStarted();
}

void ALITD2AshWandererCharacter::CommitAttack()
{
    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    const FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    if (ToPlayer.Size2D() > AttackRange + 35.0f) return;

    ULITD2CombatantComponent* TargetCombatant = Player->FindComponentByClass<ULITD2CombatantComponent>();
    if (!TargetCombatant) return;

    FLITD2DamageEventPayload Payload;
    Payload.DamageType = ELITD2DamageType::Slash;
    Payload.HitBone = TEXT("spine_03");
    Payload.HitDirection = ToPlayer.GetSafeNormal();
    Payload.DamageAmount = AttackDamage;
    Payload.ImpactForce = 0.34f;
    Payload.Penetration = 0.24f;
    Payload.BleedValue = 0.26f;
    Payload.TraumaValue = 0.0f;
    Payload.DismembermentValue = 0.0f;
    Payload.bReadableSevereCause = false;

    const FLITD2DamageResolution Resolution = TargetCombatant->ReceiveDamageEvent(Payload);
    if (Resolution.bParried)
    {
        RecoveryRemaining = AttackRecoverySeconds * 1.85f;
        OnParriedPresentation();
    }
    OnAttackCommitted();
}

void ALITD2AshWandererCharacter::HandleDamageResolved(FLITD2DamageResolution Resolution)
{
    OnDamagePresentation(Resolution);
}

void ALITD2AshWandererCharacter::HandleDeath()
{
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false);
    OnEnemyDeathPresentation();

    if (UGameInstance* GI = GetGameInstance())
    {
        if (ULITD2EncounterDirectorSubsystem* Encounter = GI->GetSubsystem<ULITD2EncounterDirectorSubsystem>())
        {
            Encounter->ReportEnemyDefeated(TEXT("ASH_WANDERER"));
        }
    }

    SetLifeSpan(8.0f);
}
