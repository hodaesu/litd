#include "Combat/LITD2PlayerCombatCharacter.h"

#include "Camera/CameraComponent.h"
#include "Combat/LITD2CombatantComponent.h"
#include "Components/InputComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "Run/LITD2RunDirectorSubsystem.h"
#include "TimerManager.h"

ALITD2PlayerCombatCharacter::ALITD2PlayerCombatCharacter()
{
    PrimaryActorTick.bCanEverTick = false;

    bUseControllerRotationPitch = false;
    bUseControllerRotationRoll = false;
    bUseControllerRotationYaw = false;

    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 720.0f, 0.0f);
    GetCharacterMovement()->MaxWalkSpeed = 520.0f;
    GetCharacterMovement()->BrakingDecelerationWalking = 1800.0f;

    CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
    CameraBoom->SetupAttachment(RootComponent);
    CameraBoom->TargetArmLength = 360.0f;
    CameraBoom->bUsePawnControlRotation = true;
    CameraBoom->SocketOffset = FVector(0.0f, 58.0f, 72.0f);

    FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
    FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
    FollowCamera->bUsePawnControlRotation = false;

    Combatant = CreateDefaultSubobject<ULITD2CombatantComponent>(TEXT("Combatant"));
    Combatant->bBridgeTraumaToRunDirector = true;
}

void ALITD2PlayerCombatCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);

    PlayerInputComponent->BindAxis(TEXT("MoveForward"), this, &ALITD2PlayerCombatCharacter::MoveForward);
    PlayerInputComponent->BindAxis(TEXT("MoveRight"), this, &ALITD2PlayerCombatCharacter::MoveRight);
    PlayerInputComponent->BindAxis(TEXT("Turn"), this, &ALITD2PlayerCombatCharacter::Turn);
    PlayerInputComponent->BindAxis(TEXT("LookUp"), this, &ALITD2PlayerCombatCharacter::LookUp);

    PlayerInputComponent->BindAction(TEXT("LightAttack"), IE_Pressed, this, &ALITD2PlayerCombatCharacter::LightAttack);
    PlayerInputComponent->BindAction(TEXT("HeavyAttack"), IE_Pressed, this, &ALITD2PlayerCombatCharacter::HeavyAttack);
    PlayerInputComponent->BindAction(TEXT("Dodge"), IE_Pressed, this, &ALITD2PlayerCombatCharacter::Dodge);
    PlayerInputComponent->BindAction(TEXT("Parry"), IE_Pressed, this, &ALITD2PlayerCombatCharacter::StartBlock);
    PlayerInputComponent->BindAction(TEXT("Parry"), IE_Released, this, &ALITD2PlayerCombatCharacter::StopBlock);
    PlayerInputComponent->BindAction(TEXT("UsePotion"), IE_Pressed, this, &ALITD2PlayerCombatCharacter::UsePotion);
}

void ALITD2PlayerCombatCharacter::MoveForward(float Value)
{
    if (bExternalMovementLocked || !Controller || FMath::IsNearlyZero(Value)) return;
    const FRotator YawRotation(0.0f, Controller->GetControlRotation().Yaw, 0.0f);
    AddMovementInput(FRotationMatrix(YawRotation).GetUnitAxis(EAxis::X), Value);
}

void ALITD2PlayerCombatCharacter::MoveRight(float Value)
{
    if (bExternalMovementLocked || !Controller || FMath::IsNearlyZero(Value)) return;
    const FRotator YawRotation(0.0f, Controller->GetControlRotation().Yaw, 0.0f);
    AddMovementInput(FRotationMatrix(YawRotation).GetUnitAxis(EAxis::Y), Value);
}

void ALITD2PlayerCombatCharacter::Turn(float Value)
{
    AddControllerYawInput(Value);
}

void ALITD2PlayerCombatCharacter::LookUp(float Value)
{
    AddControllerPitchInput(Value);
}

bool ALITD2PlayerCombatCharacter::LightAttack()
{
    if (bExternalMovementLocked || !Combatant || Combatant->IsDead() || bAttackCommitPending || !Combatant->SpendStamina(12.0f)) return false;

    if (LightAttackMontage && PlayAnimMontage(LightAttackMontage) > 0.0f)
    {
        bAttackCommitPending = true;
        PendingAttackKind = ELITD2AttackKind::Light;
        return true;
    }

    return PerformMeleeTrace(ELITD2AttackKind::Light);
}

bool ALITD2PlayerCombatCharacter::HeavyAttack()
{
    if (bExternalMovementLocked || !Combatant || Combatant->IsDead() || bAttackCommitPending || !Combatant->SpendStamina(28.0f)) return false;

    if (HeavyAttackMontage && PlayAnimMontage(HeavyAttackMontage) > 0.0f)
    {
        bAttackCommitPending = true;
        PendingAttackKind = ELITD2AttackKind::Heavy;
        return true;
    }

    return PerformMeleeTrace(ELITD2AttackKind::Heavy);
}

bool ALITD2PlayerCombatCharacter::Dodge()
{
    if (bExternalMovementLocked || !Combatant || Combatant->IsDead() || !Combatant->SpendStamina(22.0f)) return false;

    CancelQueuedAttack();

    FVector Direction = GetLastMovementInputVector();
    if (Direction.IsNearlyZero()) Direction = GetActorForwardVector();
    Direction.Z = 0.0f;
    Direction.Normalize();

    Combatant->SetBlocking(false);
    Combatant->StartInvulnerabilityWindow(DodgeInvulnerabilitySeconds);
    if (DodgeMontage) PlayAnimMontage(DodgeMontage);
    LaunchCharacter(Direction * DodgeStrength + FVector(0.0f, 0.0f, 45.0f), true, false);
    return true;
}

bool ALITD2PlayerCombatCharacter::BeginParry()
{
    if (bExternalMovementLocked || !Combatant || !Combatant->BeginParry()) return false;
    CancelQueuedAttack();
    if (ParryMontage) PlayAnimMontage(ParryMontage);
    return true;
}

void ALITD2PlayerCombatCharacter::EndParry()
{
    if (Combatant) Combatant->SetBlocking(false);
}

bool ALITD2PlayerCombatCharacter::UsePotion()
{
    if (!Combatant || Combatant->IsDead()) return false;
    if (UGameInstance* GI = GetGameInstance())
    {
        if (ULITD2RunDirectorSubsystem* RunDirector = GI->GetSubsystem<ULITD2RunDirectorSubsystem>())
        {
            if (RunDirector->UsePotion())
            {
                Combatant->ClearTraumaAndRestoreFull();
                return true;
            }
        }
    }
    return false;
}

void ALITD2PlayerCombatCharacter::ApplyExternalMovementLock(float DurationSeconds)
{
    if (!Combatant || Combatant->IsDead()) return;

    const float LockDuration = FMath::Max(0.0f, DurationSeconds);
    if (LockDuration <= KINDA_SMALL_NUMBER) return;

    CancelQueuedAttack();
    Combatant->SetBlocking(false);
    bExternalMovementLocked = true;
    GetCharacterMovement()->StopMovementImmediately();
    GetCharacterMovement()->DisableMovement();

    GetWorldTimerManager().ClearTimer(ExternalMovementLockTimer);
    GetWorldTimerManager().SetTimer(
        ExternalMovementLockTimer,
        this,
        &ALITD2PlayerCombatCharacter::ReleaseExternalMovementLock,
        LockDuration,
        false);
}

void ALITD2PlayerCombatCharacter::ReleaseExternalMovementLock()
{
    bExternalMovementLocked = false;
    if (Combatant && !Combatant->IsDead())
    {
        GetCharacterMovement()->SetMovementMode(MOVE_Walking);
    }
}

bool ALITD2PlayerCombatCharacter::CommitQueuedAttackFromAnimation()
{
    if (bExternalMovementLocked || !bAttackCommitPending || !Combatant || Combatant->IsDead()) return false;

    const ELITD2AttackKind AttackKind = PendingAttackKind;
    bAttackCommitPending = false;
    return PerformMeleeTrace(AttackKind);
}

void ALITD2PlayerCombatCharacter::StartBlock()
{
    BeginParry();
}

void ALITD2PlayerCombatCharacter::StopBlock()
{
    EndParry();
}

void ALITD2PlayerCombatCharacter::CancelQueuedAttack()
{
    bAttackCommitPending = false;
}

bool ALITD2PlayerCombatCharacter::PerformMeleeTrace(ELITD2AttackKind AttackKind)
{
    UWorld* World = GetWorld();
    if (!World) return false;

    const FVector Start = GetActorLocation() + GetActorForwardVector() * 55.0f + FVector(0.0f, 0.0f, 75.0f);
    const FVector End = Start + GetActorForwardVector() * AttackReach;
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(LITD2PlayerMelee), false, this);

    const bool bHit = World->SweepSingleByChannel(
        Hit,
        Start,
        End,
        FQuat::Identity,
        ECC_Pawn,
        FCollisionShape::MakeSphere(AttackRadius),
        Params);

    if (!bHit || !Hit.GetActor()) return false;

    ULITD2CombatantComponent* TargetCombatant = Hit.GetActor()->FindComponentByClass<ULITD2CombatantComponent>();
    if (!TargetCombatant || TargetCombatant == Combatant) return false;

    FLITD2DamageEventPayload Payload;
    Payload.DamageType = ELITD2DamageType::Slash;
    Payload.HitBone = Hit.BoneName;
    Payload.HitDirection = GetActorForwardVector();
    Payload.DamageAmount = AttackKind == ELITD2AttackKind::Heavy ? HeavyAttackDamage : LightAttackDamage;
    Payload.ImpactForce = AttackKind == ELITD2AttackKind::Heavy ? 0.78f : 0.42f;
    Payload.Penetration = AttackKind == ELITD2AttackKind::Heavy ? 0.55f : 0.30f;
    Payload.BleedValue = AttackKind == ELITD2AttackKind::Heavy ? 0.50f : 0.28f;
    Payload.TraumaValue = AttackKind == ELITD2AttackKind::Heavy ? 0.38f : 0.10f;
    Payload.DismembermentValue = AttackKind == ELITD2AttackKind::Heavy ? 0.72f : 0.20f;
    Payload.bReadableSevereCause = false;

    TargetCombatant->ReceiveDamageEvent(Payload);
    return true;
}
