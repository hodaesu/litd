#pragma once

#include "CoreMinimal.h"
#include "LITD2CombatTypes.generated.h"

UENUM(BlueprintType)
enum class ELITD2DamageType : uint8
{
    Blunt,
    Slash,
    Pierce,
    Burn,
    Shock,
    Arcane,
    Political
};

UENUM(BlueprintType)
enum class ELITD2BodyZone : uint8
{
    Unknown,
    Head,
    ArmLeft,
    ArmRight,
    Torso,
    LegLeft,
    LegRight,
    WholeBody
};

UENUM(BlueprintType)
enum class ELITD2AttackKind : uint8
{
    Light,
    Heavy
};

USTRUCT(BlueprintType)
struct FLITD2DamageEventPayload
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    ELITD2DamageType DamageType = ELITD2DamageType::Slash;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    FName HitBone = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    FVector HitDirection = FVector::ForwardVector;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float DamageAmount = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float ImpactForce = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float Penetration = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float BleedValue = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float TraumaValue = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float DismembermentValue = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bBlocked = false;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bParried = false;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bReadableSevereCause = false;
};

USTRUCT(BlueprintType)
struct FLITD2DamageResolution
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly)
    ELITD2BodyZone BodyZone = ELITD2BodyZone::Unknown;

    UPROPERTY(BlueprintReadOnly)
    float AppliedDamage = 0.0f;

    UPROPERTY(BlueprintReadOnly)
    bool bWoundTriggered = false;

    UPROPERTY(BlueprintReadOnly)
    bool bTraumaTriggered = false;

    UPROPERTY(BlueprintReadOnly)
    int32 TraumaLevel = 0;

    UPROPERTY(BlueprintReadOnly)
    int32 LockedHealthAmount = 0;

    UPROPERTY(BlueprintReadOnly)
    bool bDismembermentCandidate = false;

    UPROPERTY(BlueprintReadOnly)
    bool bKilled = false;
};
