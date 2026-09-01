#include "Combat/LITD2CombatantComponent.h"

#include "GameFramework/Actor.h"
#include "Run/LITD2RunDirectorSubsystem.h"

ULITD2CombatantComponent::ULITD2CombatantComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
}

void ULITD2CombatantComponent::BeginPlay()
{
    Super::BeginPlay();
    ResetCombatant();
}

void ULITD2CombatantComponent::ResetCombatant()
{
    Health = MaxHealth;
    Stamina = MaxStamina;
    ParryTimeRemaining = 0.0f;
    InvulnerableTimeRemaining = 0.0f;
    bBlocking = false;
    bDeathBroadcast = false;
    OnHealthChanged.Broadcast(Health);
    OnStaminaChanged.Broadcast(Stamina);
}

void ULITD2CombatantComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    if (ParryTimeRemaining > 0.0f)
    {
        ParryTimeRemaining = FMath::Max(0.0f, ParryTimeRemaining - DeltaTime);
    }
    if (InvulnerableTimeRemaining > 0.0f)
    {
        InvulnerableTimeRemaining = FMath::Max(0.0f, InvulnerableTimeRemaining - DeltaTime);
    }

    if (!IsDead() && Stamina < MaxStamina)
    {
        Stamina = FMath::Min(MaxStamina, Stamina + StaminaRegenPerSecond * DeltaTime);
        OnStaminaChanged.Broadcast(Stamina);
    }
}

bool ULITD2CombatantComponent::SpendStamina(float Amount)
{
    const float Cost = FMath::Max(0.0f, Amount);
    if (Stamina + KINDA_SMALL_NUMBER < Cost)
    {
        return false;
    }
    Stamina -= Cost;
    OnStaminaChanged.Broadcast(Stamina);
    return true;
}

bool ULITD2CombatantComponent::BeginParry()
{
    if (IsDead() || !SpendStamina(8.0f))
    {
        return false;
    }
    bBlocking = true;
    ParryTimeRemaining = ParryWindowSeconds;
    return true;
}

void ULITD2CombatantComponent::EndParry()
{
    ParryTimeRemaining = 0.0f;
}

void ULITD2CombatantComponent::SetBlocking(bool bNewBlocking)
{
    bBlocking = bNewBlocking;
    if (!bBlocking)
    {
        EndParry();
    }
}

void ULITD2CombatantComponent::StartInvulnerabilityWindow(float DurationSeconds)
{
    InvulnerableTimeRemaining = FMath::Max(InvulnerableTimeRemaining, FMath::Max(0.0f, DurationSeconds));
}

ELITD2BodyZone ULITD2CombatantComponent::ResolveBodyZone(FName HitBone) const
{
    const FString Bone = HitBone.ToString().ToLower();
    if (Bone.Contains(TEXT("head")) || Bone.Contains(TEXT("neck"))) return ELITD2BodyZone::Head;
    if (Bone.Contains(TEXT("hand_l")) || Bone.Contains(TEXT("lowerarm_l")) || Bone.Contains(TEXT("upperarm_l"))) return ELITD2BodyZone::ArmLeft;
    if (Bone.Contains(TEXT("hand_r")) || Bone.Contains(TEXT("lowerarm_r")) || Bone.Contains(TEXT("upperarm_r"))) return ELITD2BodyZone::ArmRight;
    if (Bone.Contains(TEXT("calf_l")) || Bone.Contains(TEXT("thigh_l")) || Bone.Contains(TEXT("foot_l"))) return ELITD2BodyZone::LegLeft;
    if (Bone.Contains(TEXT("calf_r")) || Bone.Contains(TEXT("thigh_r")) || Bone.Contains(TEXT("foot_r"))) return ELITD2BodyZone::LegRight;
    if (Bone.Contains(TEXT("spine")) || Bone.Contains(TEXT("pelvis")) || Bone.Contains(TEXT("clavicle"))) return ELITD2BodyZone::Torso;
    return HitBone.IsNone() ? ELITD2BodyZone::WholeBody : ELITD2BodyZone::Unknown;
}

FLITD2DamageResolution ULITD2CombatantComponent::ResolvePipeline(FLITD2DamageEventPayload Payload)
{
    FLITD2DamageResolution Result;
    Result.BodyZone = ResolveBodyZone(Payload.HitBone);

    if (IsInvulnerable())
    {
        return Result;
    }

    if (IsParryWindowActive())
    {
        Payload.bParried = true;
        Result.AppliedDamage = Payload.DamageAmount * ParryDamageMultiplier;
    }
    else if (bBlocking || Payload.bBlocked)
    {
        Payload.bBlocked = true;
        Result.AppliedDamage = Payload.DamageAmount * BlockDamageMultiplier;
    }
    else
    {
        Result.AppliedDamage = Payload.DamageAmount;
    }

    Result.AppliedDamage = FMath::Max(0.0f, Result.AppliedDamage);
    Result.bWoundTriggered = !Payload.bParried && (Payload.BleedValue >= 0.35f || Payload.ImpactForce >= 0.65f || Payload.Penetration >= 0.70f);

    if (!Payload.bParried && Payload.bReadableSevereCause && Payload.TraumaValue >= 0.50f)
    {
        Result.bTraumaTriggered = true;
        if (Payload.TraumaValue >= 0.90f)
        {
            Result.TraumaLevel = 3;
            Result.LockedHealthAmount = FMath::RoundToInt(MaxHealth * 0.15f);
        }
        else if (Payload.TraumaValue >= 0.70f)
        {
            Result.TraumaLevel = 2;
            Result.LockedHealthAmount = FMath::RoundToInt(MaxHealth * 0.10f);
        }
        else
        {
            Result.TraumaLevel = 1;
            Result.LockedHealthAmount = FMath::RoundToInt(MaxHealth * 0.10f);
        }
    }

    Result.bDismembermentCandidate = !Payload.bParried && Payload.DismembermentValue >= 0.80f &&
        Result.BodyZone != ELITD2BodyZone::Torso && Result.BodyZone != ELITD2BodyZone::WholeBody;

    Health = FMath::Clamp(Health - Result.AppliedDamage, 0.0f, MaxHealth);
    Result.bKilled = Health <= 0.0f;
    return Result;
}

FLITD2DamageResolution ULITD2CombatantComponent::ReceiveDamageEvent(const FLITD2DamageEventPayload& Payload)
{
    FLITD2DamageResolution Resolution = ResolvePipeline(Payload);

    if (bBridgeTraumaToRunDirector && Resolution.bTraumaTriggered)
    {
        if (const AActor* OwnerActor = GetOwner())
        {
            if (UGameInstance* GI = OwnerActor->GetGameInstance())
            {
                if (ULITD2RunDirectorSubsystem* RunDirector = GI->GetSubsystem<ULITD2RunDirectorSubsystem>())
                {
                    RunDirector->ApplyTrauma(Resolution.TraumaLevel, Resolution.LockedHealthAmount, FMath::RoundToInt(Resolution.AppliedDamage));
                }
            }
        }
    }

    OnHealthChanged.Broadcast(Health);
    OnDamageResolved.Broadcast(Resolution);

    if (Resolution.bKilled && !bDeathBroadcast)
    {
        bDeathBroadcast = true;
        OnDeath.Broadcast();
    }

    return Resolution;
}
