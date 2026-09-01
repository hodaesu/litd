#include "Combat/LITD2SareiCrossbowCharacter.h"

#include "Combat/LITD2CombatantComponent.h"
#include "Combat/LITD2SareiBoltProjectile.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Run/LITD2EncounterDirectorSubsystem.h"

ALITD2SareiCrossbowCharacter::ALITD2SareiCrossbowCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCharacterMovement()->MaxWalkSpeed = 250.0f;
    GetCharacterMovement()->bOrientRotationToMovement = false;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 420.0f, 0.0f);

    Combatant = CreateDefaultSubobject<ULITD2CombatantComponent>(TEXT("Combatant"));
    Combatant->MaxHealth = 230.0f;
    Combatant->MaxStamina = 55.0f;
    Combatant->StaminaRegenPerSecond = 14.0f;

    BoltClass = ALITD2SareiBoltProjectile::StaticClass();
}

void ALITD2SareiCrossbowCharacter::BeginPlay()
{
    Super::BeginPlay();
    if (Combatant)
    {
        Combatant->OnDamageResolved.AddDynamic(this, &ALITD2SareiCrossbowCharacter::HandleDamageResolved);
        Combatant->OnDeath.AddDynamic(this, &ALITD2SareiCrossbowCharacter::HandleDeath);
    }
}

void ALITD2SareiCrossbowCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Combatant || Combatant->IsDead()) return;

    if (RecoveryRemaining > 0.0f)
    {
        RecoveryRemaining = FMath::Max(0.0f, RecoveryRemaining - DeltaSeconds);
        return;
    }

    if (bShotQueued)
    {
        if (bShotUsesAnimationCommit) return;

        AimRemaining -= DeltaSeconds;
        if (AimRemaining <= 0.0f)
        {
            bShotQueued = false;
            ReleaseShot();
            RecoveryRemaining = ShotRecoverySeconds;
        }
        return;
    }

    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!Player) return;

    FVector ToPlayer = Player->GetActorLocation() - GetActorLocation();
    const float Distance2D = ToPlayer.Size2D();
    if (Distance2D > AggroRange) return;

    FacePlayer(ToPlayer);

    if (Distance2D < PreferredMinRange)
    {
        MoveRelativeToPlayer(ToPlayer, -1.0f);
        return;
    }

    if (Distance2D > PreferredMaxRange)
    {
        MoveRelativeToPlayer(ToPlayer, 1.0f);
        return;
    }

    StartAiming();
}

void ALITD2SareiCrossbowCharacter::StartAiming()
{
    if (bShotQueued || RecoveryRemaining > 0.0f) return;

    bShotQueued = true;
    AimRemaining = AimDurationSeconds;
    bShotUsesAnimationCommit = AimAndFireMontage && PlayAnimMontage(AimAndFireMontage) > 0.0f;
    OnShotTelegraphStarted();
}

void ALITD2SareiCrossbowCharacter::ReleaseShotFromAnimation()
{
    if (!bShotQueued || !bShotUsesAnimationCommit || !Combatant || Combatant->IsDead()) return;

    bShotQueued = false;
    bShotUsesAnimationCommit = false;
    ReleaseShot();
    RecoveryRemaining = ShotRecoverySeconds;
}

void ALITD2SareiCrossbowCharacter::ReleaseShot()
{
    UWorld* World = GetWorld();
    ACharacter* Player = UGameplayStatics::GetPlayerCharacter(this, 0);
    if (!World || !Player) return;

    const FVector TargetLocation = Player->GetActorLocation() + FVector(0.0f, 0.0f, 62.0f);
    const FVector SpawnLocation = GetActorLocation() + GetActorForwardVector() * 92.0f + FVector(0.0f, 0.0f, 74.0f);
    const FVector Direction = (TargetLocation - SpawnLocation).GetSafeNormal();
    const FRotator SpawnRotation = Direction.Rotation();

    FActorSpawnParameters SpawnParams;
    SpawnParams.Owner = this;
    SpawnParams.Instigator = this;
    SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    UClass* ProjectileClass = BoltClass ? BoltClass.Get() : ALITD2SareiBoltProjectile::StaticClass();
    if (ALITD2SareiBoltProjectile* Bolt = World->SpawnActor<ALITD2SareiBoltProjectile>(ProjectileClass, SpawnLocation, SpawnRotation, SpawnParams))
    {
        Bolt->InitializeBolt(ShotDamage);
    }

    OnShotReleased();
}

void ALITD2SareiCrossbowCharacter::MoveRelativeToPlayer(const FVector& ToPlayer, float DirectionSign)
{
    FVector Direction = ToPlayer;
    Direction.Z = 0.0f;
    Direction.Normalize();
    AddMovementInput(Direction * DirectionSign, 1.0f);
}

void ALITD2SareiCrossbowCharacter::FacePlayer(const FVector& ToPlayer)
{
    FVector Horizontal = ToPlayer;
    Horizontal.Z = 0.0f;
    if (Horizontal.IsNearlyZero()) return;

    SetActorRotation(Horizontal.Rotation());
}

void ALITD2SareiCrossbowCharacter::HandleDamageResolved(FLITD2DamageResolution Resolution)
{
    if (Resolution.AppliedDamage > 0.0f)
    {
        // Ranged pressure is interruptible: reaching the shooter should be meaningful counterplay.
        bShotQueued = false;
        bShotUsesAnimationCommit = false;
        RecoveryRemaining = FMath::Max(RecoveryRemaining, 0.45f);
        if (HitReactionMontage)
        {
            PlayAnimMontage(HitReactionMontage);
        }
    }
    OnDamagePresentation(Resolution);
}

void ALITD2SareiCrossbowCharacter::HandleDeath()
{
    bShotQueued = false;
    bShotUsesAnimationCommit = false;
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
            Encounter->ReportEnemyDefeated(TEXT("SAREI_CROSSBOW"));
        }
    }

    SetLifeSpan(8.0f);
}
